import 'package:shared_preferences/shared_preferences.dart';

/// App-wide sound-effect level, controlled from Settings.
///
/// Dragging the SFX slider to zero also flips [enabled] off so the sound
/// gate and any future games stay consistent. The app has no background
/// music — SFX is the only channel.
class SoundSettings {
  SoundSettings._();

  static final SoundSettings instance = SoundSettings._();

  static const String _enabledKey = 'bluff.sound.enabled';
  static const String _sfxKey = 'bluff.sound.sfx';

  bool _enabled = true;
  double _sfxVolume = 0.7;

  bool get enabled => _enabled;
  double get sfxVolume => _sfxVolume;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    _sfxVolume = prefs.getDouble(_sfxKey) ?? (_enabled ? 0.7 : 0.0);
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
}
