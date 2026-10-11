import 'package:shared_preferences/shared_preferences.dart';

/// App-wide audio levels, controlled from Settings.
///
/// Two independent channels:
///  * [sfxVolume] — scales every sound effect (chess cues today). Dragging
///    the SFX slider to zero also flips [enabled] off so the chess sound
///    gate and any future games stay consistent.
///  * [musicVolume] — scales the background music [MusicService].
class SoundSettings {
  SoundSettings._();

  static final SoundSettings instance = SoundSettings._();

  static const String _enabledKey = 'bluff.sound.enabled';
  static const String _sfxKey = 'bluff.sound.sfx';
  static const String _musicKey = 'bluff.sound.music';

  bool _enabled = true;
  double _sfxVolume = 0.7;
  double _musicVolume = 0.6;

  bool get enabled => _enabled;
  double get sfxVolume => _sfxVolume;
  double get musicVolume => _musicVolume;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    _sfxVolume = prefs.getDouble(_sfxKey) ?? (_enabled ? 0.7 : 0.0);
    _musicVolume = prefs.getDouble(_musicKey) ?? 0.6;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value.clamp(0.0, 1.0);
    _enabled = _sfxVolume > 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sfxKey, _sfxVolume);
    await prefs.setBool(_enabledKey, _enabled);
  }

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_musicKey, _musicVolume);
  }
}
