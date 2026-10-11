import 'package:bluff/games/chess/screens/auth_screen.dart';
import 'package:bluff/games/chess/services/session_service.dart';
import 'package:bluff/games/chess/widgets/chess_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
  });

  /// Pushes an [AuthScreen] on top of a base route so pops are observable.
  Future<void> pumpAuth(
    WidgetTester tester, {
    AuthMode mode = AuthMode.signIn,
  }) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('base'))),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(
            builder: (_) => AuthScreen(initialMode: mode),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Flushes the PBKDF2-backed auth futures and route animations.
  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('sign-in reports a missing account without leaving',
      (tester) async {
    await pumpAuth(tester);

    await tester.enterText(find.byType(TextField).at(0), 'ghost-user');
    await tester.enterText(find.byType(TextField).at(1), 'whatever123');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
    await flush(tester);

    expect(find.text('No account with that username.'), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(SessionService.instance.currentOrNull, isNull);
  });

  testWidgets('sign-in rejects a wrong password', (tester) async {
    final signup = await SessionService.instance.signUp(
      username: 'alice',
      password: 'correcthorse',
    );
    expect(signup.ok, isTrue);

    await pumpAuth(tester);
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'wrongpass1');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
    await flush(tester);

    expect(find.text('Incorrect password.'), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('correct credentials sign in and pop back', (tester) async {
    final signup = await SessionService.instance.signUp(
      username: 'alice',
      password: 'correcthorse',
    );
    expect(signup.ok, isTrue);

    await pumpAuth(tester);
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'correcthorse');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
    await flush(tester);

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text('base'), findsOneWidget);
    expect(SessionService.instance.isGuest, isFalse);
    expect(SessionService.instance.currentOrNull?.username, 'alice');
  });

  testWidgets('sign-up shows the recovery code exactly once', (tester) async {
    await pumpAuth(tester, mode: AuthMode.signUp);
    await tester.enterText(find.byType(TextField).at(0), 'bob');
    await tester.enterText(find.byType(TextField).at(1), 'Bob Builder');
    await tester.enterText(find.byType(TextField).at(2), 'longenough1');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create account'));
    await flush(tester);

    expect(find.text('Save your recovery code'), findsOneWidget);
    final codeFinder = find.textContaining('BLUFF-');
    expect(codeFinder, findsOneWidget);
    final code = tester.widget<Text>(codeFinder).data!;
    expect(
      RegExp(r'^BLUFF-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(code),
      isTrue,
      reason: 'got "$code"',
    );

    await tester.tap(find.widgetWithText(PrimaryButton, 'I saved it'));
    await flush(tester);

    expect(find.byType(AuthScreen), findsNothing);
    expect(SessionService.instance.isGuest, isFalse);
    expect(SessionService.instance.currentOrNull?.username, 'bob');
  });

  testWidgets('sign-up validates the password length', (tester) async {
    await pumpAuth(tester, mode: AuthMode.signUp);
    await tester.enterText(find.byType(TextField).at(0), 'eve');
    await tester.enterText(find.byType(TextField).at(2), 'short');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create account'));
    await flush(tester);

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(SessionService.instance.currentOrNull, isNull);
  });

  testWidgets('recovery code resets a forgotten password', (tester) async {
    final signup = await SessionService.instance.signUp(
      username: 'carol',
      password: 'originalpass',
    );
    expect(signup.ok, isTrue);
    final code = signup.recoveryCode!;

    await pumpAuth(tester, mode: AuthMode.reset);
    await tester.enterText(find.byType(TextField).at(0), 'carol');
    await tester.enterText(find.byType(TextField).at(1), code);
    await tester.enterText(find.byType(TextField).at(2), 'brandnewpass1');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Reset password'));
    await flush(tester);

    expect(find.byType(AuthScreen), findsNothing);
    expect(SessionService.instance.isGuest, isFalse);
    expect(SessionService.instance.currentOrNull?.username, 'carol');
  });

  testWidgets('continue as guest returns without creating an account',
      (tester) async {
    await pumpAuth(tester);

    await tester.tap(find.widgetWithText(GhostButton, 'Continue as guest'));
    await flush(tester);

    expect(find.byType(AuthScreen), findsNothing);
    final profile = await SessionService.instance.current;
    expect(profile.isGuest, isTrue);
  });
}
