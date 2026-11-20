import 'package:bluff/screens/update/force_update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ForceUpdateScreen()),
    );
  }

  testWidgets('offers exactly one way forward', (tester) async {
    await pump(tester);

    expect(find.text('A new update is available'), findsOneWidget);
    expect(find.text('UPDATE NOW'), findsOneWidget);
    expect(find.textContaining('v1.'), findsOneWidget);
  });

  testWidgets('cannot be popped away', (tester) async {
    await pump(tester);

    final scope = tester.widget<PopScope>(find.byType(PopScope));
    expect(
      scope.canPop,
      isFalse,
      reason: 'the wall must refuse Android back as well as any swipe '
          'dismiss, otherwise a player on an old build walks straight in',
    );
  });

  testWidgets('has no dismiss, skip or later control', (tester) async {
    await pump(tester);

    for (final label in ['LATER', 'SKIP', 'CLOSE', 'NOT NOW', 'MAYBE LATER']) {
      expect(find.text(label), findsNothing, reason: '"$label" offered a way past');
    }
    // Only one button on the whole screen: the update itself.
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(CloseButton), findsNothing);
  });
}
