import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Push-notification plumbing, modelled on Splash's `PushNotificationManager`.
///
/// Splash registers an FCM token when the player opts in during onboarding and
/// keeps it on their backend profile so campaign pushes can be targeted. Here
/// the token is stored on `users/{uid}.fcmToken` — the same document the rest
/// of the profile lives in.
class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance =
      NotificationsService._();

  static const Duration _timeout = Duration(seconds: 5);

  String? _token;

  /// Last known FCM token, if any.
  String? get token => _token;

  /// True when the OS currently allows notifications for this app.
  Future<bool> get enabled async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings()
          .timeout(_timeout);

      return settings.authorizationStatus ==
          AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  /// Shows the OS permission dialog (Android 13+/iOS) and returns whether
  /// notifications are allowed afterwards. Never throws.
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance
          .requestPermission()
          .timeout(_timeout);

      final allowed = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus ==
              AuthorizationStatus.provisional;

      if (allowed) {
        await cacheToken();
      }

      return allowed;
    } catch (_) {
      return false;
    }
  }

  /// Fetches and caches the FCM token locally. Never throws.
  Future<void> cacheToken() async {
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(_timeout);

      if (token != null) _token = token;
    } catch (_) {
      // Best-effort: the token is also refreshed via onTokenRefresh.
    }
  }

  /// Writes the cached token to `users/{uid}` when there is one to write.
  Future<void> saveTokenToProfile(String? uid) async {
    if (uid == null || _token == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(
            {'fcmToken': _token},
            SetOptions(merge: true),
          )
          .timeout(_timeout);
    } catch (_) {
      // Offline — the refreshed token is stored on the next sync.
    }
  }

  /// Convenience: request permission, then persist the token to the account.
  /// Returns true when notifications ended up allowed.
  Future<bool> optIn(String? uid) async {
    final allowed = await requestPermission();
    if (allowed) await saveTokenToProfile(uid);
    return allowed;
  }

  /// Firebase rotates tokens; Splash re-syncs theirs, so we listen too.
  /// [uidOf] resolves the current account id at the moment of rotation.
  void attachRefreshListener(
    String? Function() uidOf,
  ) {
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          _token = token;
          await saveTokenToProfile(uidOf());
        },
      );
    } catch (_) {
      // Firebase not initialised (tests, or a very early boot) — best-effort.
    }
  }
}
