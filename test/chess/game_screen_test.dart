import 'package:bluff/games/chess/core/models/time_control.dart';
import 'package:bluff/games/chess/screens/game_screen.dart';
import 'package:bluff/games/chess/services/settings_service.dart';
import 'package:bluff/games/chess/state/game_controller.dart';
import 'package:bluff/games/chess/widgets/board/chess_board_view.dart';
import 'package:bluff/games/chess/widgets/move_list.dart';
import 'package:bluff/games/chess/widgets/player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final settings = ChessSettingsService.instance.settings;
    settings
      ..showEvalBar = false // keep the analysis isolate out of widget tests
      ..playSounds = false
      ..confirmMoves = false;
  });

  Future<void> pumpGame(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          mode: ChessGameMode.passAndPlay,
          timeControl: TimeControl.byLabel('5 + 0'),
          rated: false,
        ),
      ),
    );
    // Boot awaits session + storage, then builds the controller.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChessBoardView), findsOneWidget, reason: 'booted');
  }

  Future<void> playMove(WidgetTester tester, String from, String to) async {
    final topLeft = tester.getTopLeft(find.byType(ChessBoardView));
    final size = tester.getSize(find.byType(ChessBoardView));

    Offset square(String name) => Offset(
          topLeft.dx +
              (name.codeUnitAt(0) - 'a'.codeUnitAt(0) + 0.5) * size.width / 8,
          topLeft.dy + (8 - int.parse(name.substring(1)) + 0.5) * size.height / 8,
        );

    await tester.tapAt(square(from));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(square(to));
    await tester.pump(const Duration(milliseconds: 320));
  }

  /// Unmounts the tree so the controller's ticker and snack timers stop.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('boots with board, clocks, move list and controls',
      (tester) async {
    await pumpGame(tester);

    expect(find.byType(ChessBoardView), findsOneWidget);
    expect(find.byType(MoveListView), findsOneWidget);
    expect(find.byType(PlayerBar), findsNWidgets(2));

    // Both clocks render as m:ss (the exact value drifts with real time).
    expect(
      find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')),
      findsNWidgets(2),
    );

    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Takeback'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    expect(find.text('Resign'), findsOneWidget);

    // Empty move list invites the first move.
    expect(find.text('Play a move to start the game.'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('plays a move by tapping source and destination',
      (tester) async {
    await pumpGame(tester);

    await playMove(tester, 'e2', 'e4');

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('Play a move to start the game.'), findsNothing);

    // Move number two is now Black's turn.
    await playMove(tester, 'e7', 'e5');
    expect(find.text('e5'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('takeback undoes the last move', (tester) async {
    await pumpGame(tester);

    await playMove(tester, 'e2', 'e4');
    expect(find.text('e4'), findsOneWidget);

    await tester.tap(find.text('Takeback'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('e4'), findsNothing);

    await unmount(tester);
  });

  testWidgets('detects checkmate and shows the result dialog', (tester) async {
    await pumpGame(tester);

    // Scholar's mate: 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7#
    await playMove(tester, 'e2', 'e4');
    await playMove(tester, 'e7', 'e5');
    await playMove(tester, 'f1', 'c4');
    await playMove(tester, 'b8', 'c6');
    await playMove(tester, 'd1', 'h5');
    await playMove(tester, 'g8', 'f6');
    await playMove(tester, 'h5', 'f7');

    // The record saves, then the modal appears after the move animation.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('CHECKMATE')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('White wins · Checkmate'),
      ),
      findsOneWidget,
    );
    expect(find.text('Rematch'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.textContaining('Qxf7'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('resign asks for confirmation, then ends the game',
      (tester) async {
    await pumpGame(tester);

    await playMove(tester, 'e2', 'e4');

    // Resign is disabled until at least one move has been played.
    await tester.tap(find.text('Resign'));
    await tester.pump();

    expect(find.text('Resign?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Resign'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('RESIGNATION')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('White wins · Resignation'),
      ),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('draw offer in pass & play can be accepted', (tester) async {
    await pumpGame(tester);

    await playMove(tester, 'e2', 'e4');

    await tester.tap(find.text('Draw'));
    await tester.pump();
    expect(find.text('Offer a draw?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Offer'));
    await tester.pump();
    expect(find.text('Draw offered'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Accept'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('DRAW'), findsWidgets); // top bar status + dialog chip
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Draw by agreement')),
      findsOneWidget,
    );

    await unmount(tester);
  });
}
