import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../language/app_language.dart';
import '../language/language_settings.dart';
import 'profile_repository.dart';

/// The `client_type: 3` (web) OAuth client from google-services.json.
/// Android resolves its client id from the platform config file; Flutter web
/// has no such file, so the id must be handed to `initialize()` explicitly.
const String _webClientId =
    '149296809595-a2ka0oagfl1g24utoc8n5tap08f4gj0p'
    '.apps.googleusercontent.com';

/// `GoogleSignIn.initialize()` may be called **exactly once** per process —
/// the web plugin throws `StateError` on every later call, and the docs say
/// repeat calls are undefined behavior on all platforms. This caches the
/// single attempt so every sign-in tap (Profile screen or the onboarding
/// outro) awaits the same future; a failed attempt is dropped so a later
/// tap may retry (on web the plugin still refuses a second `init()`, and
/// that StateError is mapped to a "restart the app" message by
/// [_signInErrorMessage]).
Future<void>? _googleSignInInit;

Future<void> ensureGoogleSignInInitialized() {
  final pending = _googleSignInInit;
  if (pending != null) return pending;

  final init = GoogleSignIn.instance.initialize(
    // `serverClientId` is deliberately not passed: it is asserted against
    // on web, and Android already reads `default_web_client_id` from the
    // bundled google-services.json.
    clientId: kIsWeb ? _webClientId : null,
  );
  _googleSignInInit = init;
  init.catchError((Object _) {
    if (identical(_googleSignInInit, init)) {
      _googleSignInInit = null;
    }
  });
  return init;
}

bool get _isBangla => LanguageSettings.instance.language.code == 'bn';

String _t(String en, String bn) => _isBangla ? bn : en;

/// Maps a thrown error to a specific, honest message instead of a
/// catch-all "Sign in failed" (which tells the player nothing).
String _signInErrorMessage(Object error) {
  if (error is TimeoutException) {
    return _t(
      'Google sign-in timed out. Check your connection and Google Play '
          'services, then try again.',
      'গুগল সাইন ইন সময় শেষ হয়েছে। ইন্টারনেট ও Google Play সার্ভিস দেখে '
          'আবার চেষ্টা করুন।',
    );
  }

  // The plugin only allows one initialize() per process; after a failed
  // first attempt the only way out is a restart.
  if (error is StateError &&
      error.message.toString().contains('init() has already been called')) {
    return _t(
      'Google sign-in needs an app restart. Close the app fully and open '
          'it again, then retry.',
      'গুগল সাইন ইনের জন্য অ্যাপ রিস্টার্ট দিতে হবে। অ্যাপটি সম্পূর্ণ '
          'বন্ধ করে আবার খুলুন, তারপর আবার চেষ্টা করুন।',
    );
  }

  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        return _t(
          'Sign-in was canceled. Tap again when you\'re ready.',
          'সাইন ইন বাতিল হয়েছে। প্রস্তুত হলে আবার চাপুন।',
        );
      case GoogleSignInExceptionCode.providerConfigurationError:
        return _t(
          'Google Play services isn\'t available or is out of date on '
              'this device. Update it, then try again.',
          'এই ডিভাইসে Google Play সার্ভিস নেই বা পুরনো। আপডেট করে আবার '
              'চেষ্টা করুন।',
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
        return _t(
          'Sign-in isn\'t configured for this build yet (Google OAuth '
              'setup). See tool/GOOGLE_SIGNIN_SETUP.md.',
          'এই বিল্ডের জন্য সাইন ইন কনফিগার করা হয়নি (Google OAuth '
              'সেটআপ)।',
        );
      case GoogleSignInExceptionCode.uiUnavailable:
        return _t(
          'Couldn\'t open the Google sign-in window. Switch back to the '
              'app and try again.',
          'গুগল সাইন ইন উইন্ডু খোলা যায়নি। অ্যাপে ফিরে আবার চেষ্টা করুন।',
        );
      case GoogleSignInExceptionCode.userMismatch:
      case GoogleSignInExceptionCode.unknownError:
        break;
    }
    debugPrint(
      'Bluff: GoogleSignInException '
      '(${error.code}): ${error.description}',
    );
  } else {
    debugPrint('Bluff: Google sign-in failed: $error');
  }

  return _t(
    'Sign in failed. Please try again.',
    'সাইন ইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
  );
}

/// Signs the player in with Google and upgrades the local anonymous profile
/// in place, so nothing already on the device is lost.
///
/// Returns `null` on success, or a player-facing bilingual error message.
/// Shared by the Profile screen and the onboarding outro — both must go
/// through here so `initialize()` is never called twice.
Future<String?> signInWithBluffId() async {
  // Google Play services can hang without ever throwing (seen on a wedged
  // device). Time the picker out so the button can't stay stuck on
  // "Signing in…" forever.
  const pickerTimeout = Duration(seconds: 45);

  try {
    final signIn = GoogleSignIn.instance;
    await ensureGoogleSignInInitialized().timeout(pickerTimeout);

    final account = await signIn.authenticate().timeout(pickerTimeout);

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google returned no idToken');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);

    final ok = await ProfileRepository.instance.linkAccount(credential);
    if (ok) return null;

    return _t(
      'Sign in failed. Please try again.',
      'সাইন ইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
    );
  } catch (error) {
    return _signInErrorMessage(error);
  }
}
