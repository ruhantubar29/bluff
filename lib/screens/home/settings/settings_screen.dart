import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../../../core/sound/music_service.dart';
import '../../../core/sound/sound_settings.dart';
import '../../../core/theme/bluff_theme.dart';

const _highlight = BluffTheme.gold;

/// Keep in sync with `pubspec.yaml` → `version`.
const _appVersion = '1.0.0';

bool get _isBangla => LanguageSettings.instance.language.code == 'bn';

String _t(String en, String bn) => _isBangla ? bn : en;

/// Deliberately small: language and sound. Everything else (profile,
/// players, invite, privacy) lives behind the profile bubble instead.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppLanguage _language = LanguageSettings.instance.language;

  double _sfx = SoundSettings.instance.sfxVolume;
  double _music = SoundSettings.instance.musicVolume;

  Future<void> _changeLanguage(AppLanguage language) async {
    await LanguageSettings.instance.setLanguage(language);

    if (!mounted) return;

    setState(() => _language = language);
  }

  Future<void> _changeSfx(double value) async {
    setState(() => _sfx = value);
    await SoundSettings.instance.setSfxVolume(value);
  }

  Future<void> _changeMusic(double value) async {
    setState(() => _music = value);
    await SoundSettings.instance.setMusicVolume(value);
    await MusicService.instance.syncWithSettings();
  }

  /// Small-caps section label used across the dark account area.
  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Tinted rounded-square icon, the account area's tile mark.
  Widget _badge(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          appBar: AppBar(title: Text(_t('Settings', 'সেটিংস'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _section(_t('Language', 'ভাষা')),
              Card(
                child: RadioGroup<AppLanguage>(
                  groupValue: _language,
                  onChanged: (value) {
                    if (value != null) {
                      _changeLanguage(value);
                    }
                  },
                  child: Column(
                    children: const [
                      RadioListTile<AppLanguage>(
                        value: AppLanguage.bangla,
                        title: Text('বাংলা'),
                      ),
                      RadioListTile<AppLanguage>(
                        value: AppLanguage.english,
                        title: Text('English'),
                      ),
                    ],
                  ),
                ),
              ),

              _section(_t('Sound', 'সাউন্ড')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(
                    children: [
                      _volumeRow(
                        icon: Icons.volume_up_rounded,
                        label: _t('Sound effects', 'সাউন্ড ইফেক্ট'),
                        value: _sfx,
                        onChanged: _changeSfx,
                      ),
                      const Divider(height: 24),
                      _volumeRow(
                        icon: Icons.music_note_rounded,
                        label: _t('Music', 'মিউজিক'),
                        value: _music,
                        onChanged: _changeMusic,
                      ),
                    ],
                  ),
                ),
              ),

              _section(_t('About', 'সম্পর্কে')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _badge(Icons.info_outline_rounded, _highlight),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'BLUFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _t(
                          'This app was created by RuhanTubar.',
                          'এই অ্যাপটি তৈরি করেছেন RuhanTubar।',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          'Current version is $_appVersion.',
                          'বর্তমান ভার্সন $_appVersion।',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          'Thanks for playing!',
                          'খেলার জন্য ধন্যবাদ!',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One labelled volume slider row used by the Sound section.
  Widget _volumeRow({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        _badge(icon, _highlight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ),
      ],
    );
  }
}
