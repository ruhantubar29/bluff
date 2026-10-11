import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/notifications_service.dart';
import 'profile.dart';

/// Local-first identity store with a silent anonymous Firebase session.
///
/// Flow mirrors Splash Party:
///   1. First launch creates a profile on-device, no account required.
///   2. An anonymous Firebase session is created in the background (the
///      "local account") so progress already has somewhere to live.
///   3. Signing in later upgrades the same identity in place — nothing is
///      lost.
///
/// Every cloud call is best-effort: if the network is down the app keeps
/// working entirely on the local copy.
class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository instance = ProfileRepository._();

  static const String profileKey = 'bluff.profile';
  static const String onboardingDoneKey = 'bluff.onboarding.completed';

  /// In-progress onboarding answers (`{step, profile}`), so a crash or
  /// force-stop mid-flow resumes on the same step instead of step one.
  static const String onboardingDraftKey = 'bluff.onboarding.draft';

  static const Duration _networkTimeout = Duration(seconds: 5);

  Profile? _profile;
  bool _onboardingDone = false;
  bool _bootstrapped = false;

  Profile? get profile => _profile;
  bool get onboardingDone => _onboardingDone;
  bool get isSignedIn => _profile?.isSignedIn ?? false;
  String? get uid => _profile?.uid;

  /// Test-only: forget every in-memory flag so each test boots from scratch.
  @visibleForTesting
  void resetForTesting() {
    _profile = null;
    _onboardingDone = false;
    _bootstrapped = false;
  }

  AppStartState get startState {
    if (!_bootstrapped) return AppStartState.loading;
    if (!_onboardingDone) return AppStartState.onboarding;
    return AppStartState.main;
  }

  // ---------------------------------------------------------------------------
  // BOOTSTRAP
  // ---------------------------------------------------------------------------

  /// Loads local state and quietly attaches an anonymous account.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;

    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(profileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _profile = Profile.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Corrupt profile: fall through and start fresh rather than crash.
      }
    }

    _onboardingDone = prefs.getBool(onboardingDoneKey) ?? false;

    // A profile with a name means onboarding already ran at some point.
    if (!_onboardingDone && (_profile?.hasName ?? false)) {
      _onboardingDone = true;
    }

    _bootstrapped = true;

    // Finished onboarding never needs its draft again; drop any leftover
    // from a crash that landed between the flag write and the clear.
    if (_onboardingDone) {
      await clearOnboardingDraft();
    }

    await _ensureAnonymousSession();
    await _restoreFromCloudIfNeeded();

    // Keep the push token attached to the account (Splash's
    // PushNotificationManager does the same on renew).
    NotificationsService.instance.attachRefreshListener(() => _profile?.uid);

    if (_profile?.notificationsEnabled ?? false) {
      unawaited(NotificationsService.instance.optIn(_profile?.uid));
    }
  }

  /// Reads `users/{uid}` back. Returns null when there is nothing to restore.
  ///
  /// This is the Splash-equivalent of their `/v1/auth/renew` + profile fetch:
  /// reinstalling or switching phones brings the profile back instead of
  /// starting over.
  Future<Profile?> _pullFromCloud(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(_networkTimeout);

      final data = snapshot.data();
      if (data == null) return null;

      final cloud = Profile.fromJson(data);
      if (!cloud.hasName) return null;

      return cloud;
    } catch (_) {
      // Offline or no account yet — nothing to restore.
      return null;
    }
  }

  /// Restores the account profile on a fresh install, otherwise pushes the
  /// local profile up. Local data always wins when it exists, so an offline
  /// session on the current device is never clobbered by stale cloud data.
  Future<void> _restoreFromCloudIfNeeded() async {
    final current = _profile;
    final uid = current?.uid;
    if (current == null || uid == null) return;

    if (current.hasName) {
      await pushToCloud();
      return;
    }

    final cloud = await _pullFromCloud(uid);
    if (cloud == null) return;

    _profile = cloud.copyWith(
      uid: uid,
      isSignedIn: current.isSignedIn,
      isMigrated: true,
    );

    // Onboarding already happened on the other device — skip straight to home.
    _onboardingDone = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingDoneKey, true);
    await _saveLocal();
  }

  /// Creates the hidden device account. Never throws, never blocks the UI.
  Future<void> _ensureAnonymousSession() async {
    try {
      final auth = FirebaseAuth.instance;
      final existing = auth.currentUser;

      if (existing != null) {
        _bindUid(existing.uid, signedIn: !existing.isAnonymous);
        return;
      }

      final credential = await auth.signInAnonymously().timeout(
        _networkTimeout,
      );

      _bindUid(credential.user?.uid);
    } catch (_) {
      // Offline or Firebase unavailable — stay local-only, retry next boot.
    }
  }

  void _bindUid(String? uid, {bool signedIn = false}) {
    if (uid == null) return;

    final current = _profile;
    if (current == null) {
      // Remember the uid even before onboarding finishes.
      _profile = Profile(uid: uid, isSignedIn: signedIn);
      _saveLocal();
      return;
    }

    if (current.uid == uid && current.isSignedIn == signedIn) return;

    _profile = current.copyWith(uid: uid, isSignedIn: signedIn);
    _saveLocal();
  }

  // ---------------------------------------------------------------------------
  // ONBOARDING
  // ---------------------------------------------------------------------------

  Future<void> completeOnboarding(Profile profile) async {
    final merged = profile.copyWith(
      createdAt: profile.createdAt == 0
          ? DateTime.now().millisecondsSinceEpoch
          : profile.createdAt,
      uid: _profile?.uid ?? profile.uid,
      isSignedIn: _profile?.isSignedIn ?? false,
      isMigrated: false,
    );

    _profile = merged;
    _onboardingDone = true;

    // Local durability first, in crash-safe order:
    //  1. profile blob (bootstrap treats "profile with a name" as done)
    //  2. the explicit flag
    //  3. retire the draft — only safe once 1+2 are on disk
    // All plain prefs writes; the flow is finished once this returns even if
    // the process dies mid-cloud-push.
    await _saveLocal();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingDoneKey, true);
    await prefs.remove(onboardingDraftKey);

    // Cloud is best-effort; never hold the finish button on it.
    unawaited(pushToCloud());
  }

  // ---------------------------------------------------------------------------
  // ONBOARDING DRAFT (crash/force-stop safety)
  // ---------------------------------------------------------------------------

  /// Persists the in-progress answers. Called after every step, so losing the
  /// process costs the player at most the step they were on — never the flow.
  Future<void> saveOnboardingDraft(Profile draft, int step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        onboardingDraftKey,
        jsonEncode({'step': step, 'profile': draft.toJson()}),
      );
    } catch (_) {
      // Best effort: the flow still works without it, just without resume.
    }
  }

  /// Returns the saved draft, or null when onboarding was never interrupted.
  Future<({Profile profile, int step})?> loadOnboardingDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(onboardingDraftKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);
      final profileJson = map['profile'];
      if (profileJson is! Map) return null;

      final step = (map['step'] as num?)?.toInt() ?? 0;
      return (
        profile: Profile.fromJson(Map<String, dynamic>.from(profileJson)),
        step: step < 0 ? 0 : step,
      );
    } catch (_) {
      // Corrupt draft — restart onboarding from the top instead.
      return null;
    }
  }

  Future<void> clearOnboardingDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(onboardingDraftKey);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // PROFILE UPDATES
  // ---------------------------------------------------------------------------

  Future<void> save(Profile profile) async {
    _profile = profile;
    await _saveLocal();
    await pushToCloud();
  }

  Future<void> _saveLocal() async {
    final current = _profile;
    if (current == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(profileKey, jsonEncode(current.toJson()));
  }

  /// Best-effort write to `users/{uid}`. Silently skipped when signed out.
  Future<void> pushToCloud() async {
    final current = _profile;
    final uid = current?.uid;
    if (current == null || uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            ...current.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_networkTimeout);

      if (!current.isMigrated) {
        _profile = current.copyWith(isMigrated: true);
        await _saveLocal();
      }
    } catch (_) {
      // Offline — keeps isMigrated false, retried on the next save.
    }
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT LIFECYCLE
  // ---------------------------------------------------------------------------

  /// Upgrades the anonymous account to a real one. Returns true on success.
  ///
  /// [linkCredential] is supplied by the sign-in UI (Google, etc.) so this
  /// repository stays free of sign-in provider dependencies.
  Future<bool> linkAccount(AuthCredential credential) async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      User? upgraded;
      if (user != null) {
        try {
          upgraded =
              (await user
                      .linkWithCredential(credential)
                      .timeout(_networkTimeout))
                  .user;
        } on FirebaseAuthException catch (error) {
          // Anonymous account already linked elsewhere, or the provider is
          // used by another account: sign in instead and adopt that uid.
          if (error.code != 'account-exists-with-different-credential') {
            rethrow;
          }
          upgraded =
              (await auth
                      .signInWithCredential(credential)
                      .timeout(_networkTimeout))
                  .user;
        }
      } else {
        upgraded =
            (await auth
                    .signInWithCredential(credential)
                    .timeout(_networkTimeout))
                .user;
      }

      if (upgraded == null) return false;

      final current = _profile ?? const Profile();
      _profile = current.copyWith(
        uid: upgraded.uid,
        isSignedIn: true,
        isMigrated: false,
      );
      await _saveLocal();

      if (current.hasName) {
        // This device already has a profile — push it to the new account.
        await pushToCloud();
      } else {
        // Fresh device signing into an existing account — adopt its profile.
        final cloud = await _pullFromCloud(upgraded.uid);

        if (cloud != null) {
          _profile = cloud.copyWith(
            uid: upgraded.uid,
            isSignedIn: true,
            isMigrated: true,
          );
          _onboardingDone = true;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(onboardingDoneKey, true);
          await _saveLocal();
        } else {
          await pushToCloud();
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      return;
    }

    final current = _profile;
    if (current != null) {
      _profile = current.copyWith(isSignedIn: false, isMigrated: false);
      await _saveLocal();
    }
  }

  /// Wipes local identity and deletes the cloud account when possible.
  Future<void> deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete().timeout(_networkTimeout);
      }
    } catch (_) {
      // Requires a recent login; local wipe still proceeds.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(profileKey);
    await prefs.remove(onboardingDoneKey);
    await prefs.remove(onboardingDraftKey);

    _profile = null;
    _onboardingDone = false;
  }
}
