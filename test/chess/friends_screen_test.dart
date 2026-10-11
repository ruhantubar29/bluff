import 'package:bluff/games/chess/core/models/friendship.dart';
import 'package:bluff/games/chess/screens/friends_screen.dart';
import 'package:bluff/games/chess/services/chess_storage.dart';
import 'package:bluff/games/chess/services/online_service.dart';
import 'package:bluff/games/chess/widgets/chess_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Default to the offline stub so challenge gating is deterministic.
    OnlineService.instance = const StubOnlineService();
  });

  ChessFriend friend(String handle, {String? name, DateTime? addedAt}) =>
      ChessFriend(
        id: 'friend_$handle',
        username: handle,
        displayName: name ?? handle,
        addedAt: addedAt ?? DateTime(2026, 1, 1),
      );

  Future<void> pumpFriends(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FriendsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the empty roster with an honest banner', (tester) async {
    await pumpFriends(tester);

    expect(find.text('FRIENDS'), findsOneWidget);
    expect(find.textContaining('No friends yet'), findsOneWidget);
    expect(find.textContaining('neither is simulated'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Add friend'), findsOneWidget);
  });

  testWidgets('adds a friend through the dialog and persists it',
      (tester) async {
    await pumpFriends(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Add friend'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'maya');
    await tester.enterText(find.byType(TextField).at(1), 'Maya Chen');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Add'));
    await flush(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('@maya'), findsOneWidget);

    final stored = await ChessStorage.instance.loadFriends();
    expect(stored, hasLength(1));
    expect(stored.single.username, 'maya');
    expect(stored.single.displayName, 'Maya Chen');
  });

  testWidgets('rejects a duplicate username in the dialog', (tester) async {
    await ChessStorage.instance
        .saveFriends([friend('maya', name: 'Maya')]);
    await pumpFriends(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Add friend'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(0), '  MAYA  ');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Add'));
    await tester.pump();

    expect(
      find.text('That friend is already on your roster.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);

    final stored = await ChessStorage.instance.loadFriends();
    expect(stored, hasLength(1));
  });

  testWidgets('challenges are honestly gated behind the server',
      (tester) async {
    await ChessStorage.instance
        .saveFriends([friend('maya', name: 'Maya')]);
    await pumpFriends(tester);

    await tester.tap(find.byTooltip('Challenge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Challenges go through the BLUFF server'),
      findsOneWidget,
    );
    // No challenge record was staged — nothing faked.
    expect(await ChessStorage.instance.loadChallenges(), isEmpty);

    // Unmount so the SnackBar timer is disposed.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('removes a friend from the roster', (tester) async {
    await ChessStorage.instance
        .saveFriends([friend('maya', name: 'Maya')]);
    await pumpFriends(tester);
    expect(find.text('@maya'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await flush(tester);

    expect(find.text('@maya'), findsNothing);
    expect(find.textContaining('No friends yet'), findsOneWidget);
    expect(await ChessStorage.instance.loadFriends(), isEmpty);
  });
}
