import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/language/language_settings.dart';
import 'core/sound/sound_settings.dart';
import 'core/sound/ui_sounds.dart';
import 'core/theme/bluff_theme.dart';
import 'core/update/update_gate.dart';
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
      // Lets the update prompt be raised from wherever the player happens to
      // be, including from outside the route tree.
      navigatorKey: appNavigatorKey,
      // Above the Navigator, so both survive every screen change: taps are
      // checked against the widgets actually hit, so only buttons, tiles and
      // options tick — blank space is silent. The gate outlives the splash
      // screen and keeps checking for a newer release while the app is open.
      builder: (context, child) => UpdateGate(
        child: TapSoundScope(child: child ?? const SizedBox()),
      ),
    );
  }
}
