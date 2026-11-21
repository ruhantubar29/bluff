import 'package:bluff/games/would_you_rather/screens/category_screen.dart';
import 'package:bluff/games/would_you_rather/screens/game_screen.dart';
import 'package:bluff/games/would_you_rather/screens/would_you_rather_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The glow drifts forever, so `pumpAndSettle` would hang — every wait here
/// is an explicit duration instead.
const Duration _settle = Duration(milliseconds: 1200);

/// The two option cards are the only `GestureDetector`s directly wrapping an
/// `AnimatedContainer`; `IconButton` and friends hide their own detectors.
final Finder _cards = find.byWidgetPredicate(
  (widget) => widget is GestureDetector && widget.child is AnimatedContainer,
);

void main() {
  testWidgets('home screen builds with its logo and play button',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WouldYouRatherScreen()));
    await tester.pump(_settle);

    expect(tester.takeException(), isNull);
    expect(find.text('Would you'), findsOneWidget);
    expect(find.text('rather?'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('Choose categories'), findsOneWidget);
  });

  testWidgets('category picker accepts several selections at once',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CategoryScreen(selectedCategoryIds: <String>[])),
    );
    await tester.pump(_settle);

    expect(find.byIcon(Icons.check_circle_rounded), findsNothing,
        reason: 'nothing chosen yet');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'DONE'))
          .onPressed,
      isNull,
      reason: 'DONE must be disabled while nothing is selected',
    );

    await tester.tap(find.text('Classic'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('Party'));
    await tester.pump(const Duration(milliseconds: 350));

    // The reported bug: choosing a second mood cleared the first.
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2),
        reason: 'picking a second category must not clear the first');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'DONE'))
          .onPressed,
      isNotNull,
      reason: 'DONE must enable once something is selected',
    );

    await tester.tap(find.text('Spicy'));
    // The fifth tile sits below the fold on a 800x600 surface, the same as it
    // would on a short phone — scroll it in rather than tapping thin air.
    await tester.ensureVisible(find.text('Deep & Dark'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Deep & Dark'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));

    // Tapping an already-lit tile unticks it and leaves the rest alone.
    await tester.ensureVisible(find.text('Party'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Party'));
    // The outgoing tick lingers for AnimatedSwitcher's own transition, and a
    // single pump starts and finishes that animation on the same frame — so
    // start it, then let it run.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
  });

  testWidgets('game screen deals two cards, reveals, then advances',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WouldYouRatherGameScreen(selectedCategoryIds: <String>['classic']),
    ));
    await tester.pump(_settle);

    expect(tester.takeException(), isNull);
    expect(_cards, findsNWidgets(2));
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    expect(find.text('Classic'), findsOneWidget, reason: 'top bar title');
    expect(find.textContaining(' / '), findsOneWidget, reason: 'deck counter');

    await tester.tap(_cards.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('OR'), findsNothing, reason: 'disc shows the share now');
    expect(find.textContaining('chose this'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // cards fly out
    await tester.pump(const Duration(milliseconds: 800)); // new cards fly in

    expect(tester.takeException(), isNull);
    expect(_cards, findsNWidgets(2));
    expect(find.text('NEXT'), findsNothing);
    expect(find.text('OR'), findsOneWidget);
    expect(find.textContaining('chose this'), findsNothing);
  });
}
