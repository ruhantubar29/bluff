import 'package:flutter/material.dart';

import 'core/language/language_settings.dart';
import 'core/theme/bluff_theme.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LanguageSettings.instance.load();

  runApp(const BluffApp());
}

class BluffApp extends StatelessWidget {
  const BluffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLUFFᴮᴰ',
      theme: BluffTheme.light,
      home: const SplashScreen(),
    );
  }
}