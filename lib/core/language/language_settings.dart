import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

class LanguageSettings {
  LanguageSettings._();

  static final LanguageSettings instance =
      LanguageSettings._();

  static const String _languageKey =
      'bluff.language';

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  Future<void> load() async {
    final prefs =
        await SharedPreferences.getInstance();

    final savedLanguage =
        prefs.getString(_languageKey);

    if (savedLanguage == 'bn') {
      _language = AppLanguage.bangla;
    } else {
      _language = AppLanguage.english;
    }
  }

  Future<void> setLanguage(
    AppLanguage language,
  ) async {
    _language = language;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _languageKey,
      language.code,
    );
  }
}