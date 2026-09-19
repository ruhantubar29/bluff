import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language/app_language.dart';
import '../../core/language/language_settings.dart';
import '../home/home_screen.dart';

const _dark = Color(0xff09090E);
const _red = Color(0xffC62828);
const _highlight = Color(0xffFFD166);

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() =>
      _LanguageScreenState();
}

class _LanguageScreenState
    extends State<LanguageScreen> {
  // English is selected by default on first launch.
  AppLanguage _selectedLanguage =
      AppLanguage.english;

  Future<void> _continue() async {
    await LanguageSettings.instance.setLanguage(
      _selectedLanguage,
    );

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      'bluff.first_launch_completed',
      true,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBangla =
        _selectedLanguage == AppLanguage.bangla;

    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            40,
            24,
            24,
          ),
          child: Column(
            children: [
              const Spacer(),

              const Text(
                'BLUFFᴮᴰ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                isBangla
                    ? 'আপনার ভাষা বেছে নিন'
                    : 'Choose your language',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                isBangla
                    ? 'আপনি যে ভাষায় খেলতে চান সেটি নির্বাচন করুন।'
                    : 'Select the language you want to play in.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 34),

              _LanguageCard(
                title: 'বাংলা',
                subtitle: 'Bangla',
                selected:
                    _selectedLanguage ==
                        AppLanguage.bangla,
                onTap: () {
                  setState(() {
                    _selectedLanguage =
                        AppLanguage.bangla;
                  });
                },
              ),

              const SizedBox(height: 12),

              _LanguageCard(
                title: 'English',
                subtitle: 'English',
                selected:
                    _selectedLanguage ==
                        AppLanguage.english,
                onTap: () {
                  setState(() {
                    _selectedLanguage =
                        AppLanguage.english;
                  });
                },
              ),

              const SizedBox(height: 28),

              Text(
                isBangla
                    ? 'এই ভাষাটি গেমের শব্দ, হিন্ট, বাক্য ও অন্যান্য লেখায় ব্যবহার করা হবে।'
                    : 'This language will be used for the words, hints, phrases, sentences, and other text in the games.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                isBangla
                    ? 'আপনি পরে Home screen-এর Settings থেকে ভাষা পরিবর্তন করতে পারবেন।'
                    : 'You can change your language anytime later from Settings on the Home screen.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _continue,
                  child: Text(
                    isBangla
                        ? 'চালিয়ে যান'
                        : 'CONTINUE',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            color: selected
                ? _red.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _red
                  : Colors.white.withValues(alpha: 0.10),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? _highlight
                    : Colors.white38,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}