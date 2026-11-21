import 'package:bluff/core/update/force_update.dart';
import 'package:bluff/core/update/update_gate.dart';
import 'package:bluff/screens/update/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Boots a fresh app tree with [fetch] standing in for the version feed.
  ///
  /// Tears the tree down first: pumpWidget otherwise updates in place, which
  /// would carry the gate's state — including the session-long "already put
  /// off" flag — across what is supposed to be the next launch.
  Future<void> launch(
    WidgetTester tester, {
    required Future<String?> Function() fetch,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: const Scaffold(body: Text('home')),
        builder: (context, child) => UpdateGate(
          fetch: fetch,
          child: child ?? const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String?> behind() async => '{"version":"9.9.9"}';
  Future<String?> current() async => '{"version":"$kAppVersion"}';

  testWidgets('prompts when the server is ahead', (tester) async {
    await launch(tester, fetch: behind);

    expect(find.byType(UpdateDialog), findsOneWidget);
    expect(find.text('A new update is available'), findsOneWidget);
    expect(find.text('UPDATE NOW'), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
    expect(find.textContaining('v$kAppVersion'), findsOneWidget);
  });

  testWidgets('stays out of the way when already current', (tester) async {
    await launch(tester, fetch: current);

    expect(find.byType(UpdateDialog), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('offers exactly two ways out and no third', (tester) async {
    await launch(tester, fetch: behind);

    expect(find.byType(ElevatedButton), findsOneWidget, reason: 'UPDATE NOW');
    expect(find.byType(TextButton), findsOneWidget, reason: 'LATER');
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(CloseButton), findsNothing);
  });

  testWidgets('cannot be put off by tapping outside', (tester) async {
    await launch(tester, fetch: behind);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(
      find.byType(UpdateDialog),
      findsOneWidget,
      reason: 'the barrier must ignore taps, or a stray thumb clears it',
    );
  });

  testWidgets('Android back cannot slip past it either', (tester) async {
    await launch(tester, fetch: behind);

    final scope = tester.widget<PopScope>(find.byType(PopScope));
    expect(
      scope.canPop,
      isFalse,
      reason: 'back must refuse, so only LATER or UPDATE NOW get through',
    );
  });

  testWidgets('LATER lasts for this session, and the next launch asks again',
      (tester) async {
    await launch(tester, fetch: behind);
    expect(find.byType(UpdateDialog), findsOneWidget);

    await tester.tap(find.text('LATER'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDialog), findsNothing);

    // Nothing about the dismissal was stored, so a fresh launch re-asks.
    await launch(tester, fetch: behind);
    expect(find.byType(UpdateDialog), findsOneWidget);
  });

  testWidgets('an offline launch keeps asking until the server answers',
      (tester) async {
    var online = false;
    await launch(
      tester,
      fetch: () async => online ? await behind() : null,
    );

    // Offline: no proof yet, so nothing is shown — but the gate is still
    // asking rather than giving up until the next cold start.
    expect(find.byType(UpdateDialog), findsNothing);

    online = true;
    await tester.pump(kUpdateRetryInterval);
    await tester.pumpAndSettle();

    expect(
      find.byType(UpdateDialog),
      findsOneWidget,
      reason: 'coming back online mid-session must be enough to be prompted',
    );
  });
}
