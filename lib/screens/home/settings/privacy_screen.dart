import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../../../core/profile/player_roster.dart';
import '../../../core/profile/profile_repository.dart';
import '../../../core/theme/bluff_theme.dart';

bool get _isBangla => LanguageSettings.instance.language == AppLanguage.bangla;

String _t(String en, String bn) => _isBangla ? bn : en;

/// Section-label style shared by the dark account screens.
const _sectionStyle = TextStyle(
  color: Colors.white70,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.6,
);

/// Privacy & data: shows exactly what Bluff keeps about the player and lets
/// them take it all away as one JSON file (Splash's data-export parity).
///
/// Everything here is local-first — the export works with no account and no
/// network.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    // The roster count shown below is read from memory — make sure it's there.
    PlayerRoster.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Everything the app stores about this player, in one object.
  Future<Map<String, dynamic>> _collectData() async {
    final roster = PlayerRoster.instance;
    await roster.load();

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'profile':
          ProfileRepository.instance.profile?.toJson() ?? <String, dynamic>{},
      'roster': roster.players.map((player) => player.toJson()).toList(),
      'settings': {
        'language': LanguageSettings.instance.language.code,
        'notificationsEnabled':
            ProfileRepository.instance.profile?.notificationsEnabled ?? false,
      },
    };
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final data = await _collectData();
      final pretty = const JsonEncoder.withIndent('  ').convert(data);

      final file = XFile.fromData(
        utf8.encode(pretty),
        mimeType: 'application/json',
        name: 'bluff-my-data.json',
      );

      await SharePlus.instance.share(ShareParams(files: [file]));
    } catch (_) {
      // Share unavailable — tell the player instead of failing silently.
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileRepository.instance.profile;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: BluffTheme.ink,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: BluffTheme.dark,
        child: Scaffold(
          appBar: AppBar(title: Text(_t('Privacy & data', 'গোপনীয়তা ও ডেটা'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_t('What we keep', 'আমরা কী রাখি'), style: _sectionStyle),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    _fact(
                      Icons.person_rounded,
                      _t('Your profile', 'আপনার প্রোফাইল'),
                      profile == null || !profile.hasName
                          ? _t(
                              'Nothing yet — you never set a name.',
                              'এখনো কিছু নেই — নাম দেননি।',
                            )
                          : '${profile.name} · ${_t('avatar', 'অ্যাভাটার')} '
                                '${profile.avatarIndex + 1}',
                    ),
                    _fact(
                      Icons.group_rounded,
                      _t('Saved players', 'সংরক্ষিত খেলোয়াড়'),
                      _t(
                        '${PlayerRoster.instance.count} remembered for pass & play.',
                        'পাস অ্যান্ড প্লেয়ের জন্য ${PlayerRoster.instance.count} জন মনে রাখা হয়েছে।',
                      ),
                    ),
                    _fact(
                      Icons.cloud_rounded,
                      _t('Backup', 'ব্যাকআপ'),
                      ProfileRepository.instance.isSignedIn
                          ? _t(
                              'Saved to your account so a new phone can restore it.',
                              'নতুন ফোনে ফেরত আনতে আপনার অ্যাকাউন্টে সংরক্ষিত।',
                            )
                          : _t(
                              'Only on this device. No account, no tracking.',
                              'শুধু এই ডিভাইসে। অ্যাকাউন্ট নেই, ট্র্যাকিং নেই।',
                            ),
                    ),
                    _fact(
                      Icons.notifications_rounded,
                      _t('Notifications', 'নোটিফিকেশন'),
                      (profile?.notificationsEnabled ?? false)
                          ? _t(
                              'On — only for new games and features.',
                              'চালু — শুধু নতুন গেম ও ফিচারের জন্য।',
                            )
                          : _t(
                              'Off. Nothing will ever ping you.',
                              'বন্ধ। কিছুই আপনাকে জানাবে না।',
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _t('Take it with you', 'নিজের কাছে নিয়ে যান'),
                style: _sectionStyle,
              ),
              const SizedBox(height: 4),
              Text(
                _t(
                  'Downloads everything above as one readable JSON file.',
                  'উপরের সবকিছু একটি JSON ফাইলে নামান।',
                ),
                style: const TextStyle(fontSize: 12.5, color: Colors.white60),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_t('Export my data', 'ডেটা রপ্তানি করুন')),
              ),
              const SizedBox(height: 24),
              Text(
                _t('Your control', 'আপনার নিয়ন্ত্রণ'),
                style: _sectionStyle,
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                  ),
                  title: Text(_t('Delete everything', 'সবকিছু মুছুন')),
                  subtitle: Text(
                    _t(
                      'Settings → Profile → Delete account removes the profile on this device and in the cloud.',
                      'সেটিংস → প্রোফাইল → অ্যাকাউন্ট মুছুন — এই ডিভাইস ও ক্লাউড থেকে প্রোফাইল মুছে যাবে।',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12.5, color: Colors.white60),
      ),
    );
  }
}
