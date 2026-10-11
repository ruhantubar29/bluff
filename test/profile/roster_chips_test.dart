import 'package:bluff/core/profile/player_roster.dart';
import 'package:bluff/core/profile/roster_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shared quick-fill row every pass-and-play roster screen uses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerRoster.instance.resetForTesting();
  });

  Future<void> pumpChips(
    WidgetTester tester,
    ValueChanged<String> onPick,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterChips(onPick: onPick),
        ),
      ),
    );
    // Allow the async roster load to land.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders nothing when the roster is empty',
      (tester) async {
    await pumpChips(tester, (_) {});

    expect(find.text('From your players'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('shows roster names and reports taps',
      (tester) async {
    await PlayerRoster.instance.add(name: 'Rakib');
    await PlayerRoster.instance.add(name: 'Nusrat');

    String? picked;
    await pumpChips(tester, (name) => picked = name);

    expect(find.text('From your players'), findsOneWidget);
    expect(find.text('Rakib'), findsOneWidget);
    expect(find.text('Nusrat'), findsOneWidget);

    await tester.tap(find.text('Nusrat'));
    expect(picked, 'Nusrat');
  });

  testWidgets('caps the row at max names', (tester) async {
    for (var i = 0; i < 12; i++) {
      await PlayerRoster.instance.add(name: 'Player $i');
    }

    await pumpChips(tester, (_) {});

    expect(find.byType(ActionChip), findsNWidgets(8));
  });
}
