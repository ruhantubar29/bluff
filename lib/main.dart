import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/language/language_settings.dart';
import 'core/sound/music_service.dart';
import 'core/sound/sound_settings.dart';
import 'core/sound/ui_sounds.dart';
import 'core/theme/bluff_theme.dart';
import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: no online service is installed here. OnlineService.instance stays
  // on the default StubOnlineService, which reports isAvailable == false, so
  // every online surface honestly shows "server required" rather than
  // pretending to connect. The chess backend is wired up when chess ships.

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await LanguageSettings.instance.load();
  await SoundSettings.instance.load();

  // Build the tap tick buffer and warm its player pool so the first tap is
  // instant. Never blocks startup.
  unawaited(UiSounds.instance.preload());

  // Kick off the ambient music bed to match the saved volume (no-op when the
  // music slider is at zero). Never blocks startup.
  unawaited(MusicService.instance.syncWithSettings());

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
      // Above the Navigator, so every tap on any button, tile or row ticks.
      builder: (context, child) =>
          TapSoundScope(child: child ?? const SizedBox()),
    );
  }
}
