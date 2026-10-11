import 'package:bluff/core/language/app_language.dart';
import 'package:bluff/core/language/language_settings.dart';
import 'package:bluff/core/profile/profile.dart';
import 'package:bluff/core/profile/profile_repository.dart';
import 'package:bluff/screens/home/home_screen.dart';
import 'package:bluff/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recreates Splash's first-run flow end-to-end: language → name → avatar →
/// gender → age → group → source, then straight home. Language is a choice
/// step like the survey questions (tap commits, no CONTINUE bar), the name
/// subtitle never spells out the character budget, the avatar step is a
/// swipeable picture carousel with browse arrows and an own-photo section,
/// and there is no notifications ask and no other finale step. The Bluff ID
/// window is not part of the flow: it pops over home about a second later,
/// with a cross and a "Continue as guest" way out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LanguageSettings.instance.load();
    ProfileRepository.instance.resetForTesting();
  });

  Future<void> pumpOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump();
  }

  /// Choice steps advance themselves 180ms after a tap.
  Future<void> advance(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('walks all seven steps in order and lands on home', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    // ── 1/7 Language: choice-style first step, no CONTINUE bar ──────────
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('বাংলা'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);

    await tester.tap(find.text('English'));
    await advance(tester);
    expect(LanguageSettings.instance.language.code, 'en');

    // ── 2/7 Name ────────────────────────────────────────────────────────
    expect(find.text('2/7'), findsOneWidget);
    expect(find.text("What's your name?"), findsOneWidget);

    // No welcome step, and the subtitle never advertises a character budget.
    expect(find.textContaining('Welcome to'), findsNothing);
    expect(find.text('GET STARTED'), findsNothing);
    expect(find.textContaining('characters'), findsNothing);

    // CONTINUE stays disabled below two characters.
    await tester.enterText(find.byType(TextField).first, 'R');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).first, 'Rakib');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('CONTINUE'));
    await advance(tester);

    // ── 3/7 Avatar: picture carousel + arrows + own-photo section ───────
    expect(find.text('3/7'), findsOneWidget);
    expect(find.text('Select an avatar'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 14'), findsOneWidget);
    expect(find.text('Use your own photo'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // The right arrow browses one character forward.
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('2 / 14'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await advance(tester);

    // ── 4/7 Gender (auto-advances on choice, no CONTINUE bar) ───────────
    expect(find.text('4/7'), findsOneWidget);
    expect(find.text("What's your gender?"), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);

    await tester.tap(find.text('Male'));
    await advance(tester);

    // ── 5/7 Age ─────────────────────────────────────────────────────────
    expect(find.text('5/7'), findsOneWidget);
    expect(find.text('How old are you?'), findsOneWidget);

    await tester.tap(find.text('18–20'));
    await advance(tester);

    // ── 6/7 Group ───────────────────────────────────────────────────────
    expect(find.text('6/7'), findsOneWidget);
    expect(find.text('Who do you most like to play with?'), findsOneWidget);

    await tester.tap(find.text('Friends'));
    await advance(tester);

    // ── 7/7 Source: the last pick finishes the flow ─────────────────────
    // No notifications step, no "are you ready" finale behind it.
    expect(find.text('7/7'), findsOneWidget);
    expect(find.text('How did you hear about us?'), findsOneWidget);
    expect(find.textContaining('Are you ready'), findsNothing);
    expect(find.text("Let's go!"), findsNothing);

    await tester.tap(find.text('Social Media'));
    await advance(tester);
    // finish() saves through a few async hops before pushing home.
    await tester.pump(const Duration(milliseconds: 500));

    // ── Finale: home FIRST — the window is not part of the seven steps ──
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Login with Bluff ID'), findsNothing);

    // The profile is already on disk behind the flow, draft retired.
    expect(ProfileRepository.instance.profile?.name, 'Rakib');
    expect(ProfileRepository.instance.profile?.gender, PlayerGender.male);
    expect(ProfileRepository.instance.profile?.ageBand, AgeBand.age18_20);
    expect(ProfileRepository.instance.profile?.languageCode, 'en');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('bluff.onboarding.completed'), isTrue);
    expect(prefs.getString('bluff.onboarding.draft'), isNull);

    // ── About a second later the Bluff ID window pops over home ─────────
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomeScreen), findsOneWidget); // still behind it
    expect(find.text('Login with Bluff ID'), findsOneWidget);
    expect(find.text("So your progress won't get lost."), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // "Continue as guest" closes the window and remembers the dismissal,
    // so it will not come back on the next launch.
    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Login with Bluff ID'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(prefs.getBool('bluff.bluffid.prompt_dismissed'), isTrue);
  });

  testWidgets('picking বাংলা re-renders the flow in Bangla', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('বাংলা'));
    await advance(tester);

    expect(LanguageSettings.instance.language.code, 'bn');
    expect(find.text('2/7'), findsOneWidget);
    expect(find.text('আপনার নাম কী?'), findsOneWidget);
    expect(find.text('চালিয়ে যান'), findsOneWidget);
  });

  testWidgets('choice steps start empty, have no bar, advance on tap alone', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    // Language is a choice step: nothing pre-picked, no button at all.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.tap(find.text('English'));
    await advance(tester); // → name

    await tester.enterText(find.byType(TextField).first, 'Rakib');
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await advance(tester); // → avatar
    await tester.tap(find.text('CONTINUE'));
    await advance(tester); // → 4/7 gender

    // Nothing preselected, and no button at all: a tap is the commit.
    expect(find.text('4/7'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.tap(find.text('Male'));
    await advance(tester);

    // Picking auto-advanced to the age step, which is also empty.
    expect(find.text('5/7'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.tap(find.text('18–20'));
    await advance(tester);
    expect(find.text('6/7'), findsOneWidget);

    // Going back shows the earlier pick still highlighted.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await advance(tester);
    expect(find.text('5/7'), findsOneWidget);
    expect(find.text('18–20'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('a relaunch mid-flow resumes on the same step', (tester) async {
    // Answer three steps, then "kill" the screen.
    await pumpOnboarding(tester);
    await tester.tap(find.text('English'));
    await advance(tester); // → 2/7 name

    await tester.enterText(find.byType(TextField).first, 'Rakib');
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await advance(tester); // → 3/7 avatar
    await tester.tap(find.text('CONTINUE'));
    await advance(tester); // → 4/7 gender

    expect(find.text('4/7'), findsOneWidget);

    // Relaunch: a brand-new widget over the same prefs.
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump();
    await tester.pump(); // let the async draft load land

    expect(find.text('4/7'), findsOneWidget);
    expect(find.text("What's your gender?"), findsOneWidget);
    // Language was answered on the way here; gender itself was not yet.
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    // Back through the avatar step to the typed name.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await advance(tester);
    expect(find.text('3/7'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await advance(tester);
    expect(find.text('2/7'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'Rakib',
    );
  });
}
