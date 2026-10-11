import 'package:flutter/material.dart';

import '../../core/profile/profile.dart';
import '../../core/profile/profile_repository.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';

const _dark = Color(0xff09090E);

/// Root of the app: bootstraps the local profile + hidden anonymous account,
/// then lands on the right first screen.
///
///   Loading → Onboarding (language is its first step) → Home
///
/// Returning players skip straight to Home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await ProfileRepository.instance.bootstrap();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (ProfileRepository.instance.startState) {
      case AppStartState.loading:
        return const _LoadingView();

      case AppStartState.onboarding:
        return const OnboardingScreen();

      case AppStartState.main:
        return const HomeScreen();
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _dark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BLUFFᴮᴰ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xffFFD166),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
