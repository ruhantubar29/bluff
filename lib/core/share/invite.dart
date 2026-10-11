import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../language/app_language.dart';
import '../language/language_settings.dart';

/// Splash's invite flow: open the real OS share sheet, and if sharing is
/// unavailable fall back to copying the link so the player never walks away
/// empty-handed.
///
/// Where the invite actually lands: the GitHub Pages download site, which is
/// the only distribution channel right now (APK via GitHub releases).
const String inviteStoreUrl = 'https://ruhantubar29.github.io/bluff/';

bool get _isBangla => LanguageSettings.instance.language == AppLanguage.bangla;

String inviteMessage() => _isBangla
    ? 'আসুন একসাথে খেলি! BLUFF 🎲 — দশটি পার্টি গেম, এক অ্যাপ।\n$inviteStoreUrl'
    : "Let's play together! BLUFF 🎲 — 10 party games in one app.\n$inviteStoreUrl";

/// Shares the invite. Returns true when the share sheet was shown, false
/// when the message was only copied to the clipboard.
Future<bool> shareInvite(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    await SharePlus.instance.share(ShareParams(text: inviteMessage()));
    return true;
  } catch (_) {
    // Share sheet unavailable (desktop, restricted profile) — copy instead.
  }

  try {
    await Clipboard.setData(ClipboardData(text: inviteMessage()));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _isBangla
              ? 'আমন্ত্রণ কপি হয়েছে! যেকোনো জায়গায় পেস্ট করুন।'
              : 'Invite copied! Paste it anywhere.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (_) {
    // Clipboard blocked — nothing else to try.
  }

  return false;
}
