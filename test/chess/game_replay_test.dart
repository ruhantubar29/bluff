import 'package:bluff/games/chess/core/chess_game.dart';
import 'package:bluff/games/chess/core/models/game_record.dart';
import 'package:bluff/games/chess/core/models/game_result.dart';
import 'package:bluff/games/chess/core/models/time_control.dart';
import 'package:bluff/games/chess/screens/game_replay_screen.dart';
import 'package:bluff/games/chess/widgets/board/chess_board_view.dart';
import 'package:bluff/games/chess/widgets/eval_bar.dart';
import 'package:bluff/games/chess/widgets/move_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChessGameRecord sampleRecord() {
    final game = ChessGame();
    final first = game.makeMove(from: 'e2', to: 'e4');
    final second = game.makeMove(from: 'e7', to: 'e5');
    return ChessGameRecord(
      id: 'replay-1',
      startedAt: DateTime(2026, 2, 1, 18),
      endedAt: DateTime(2026, 2, 1, 18, 6),
      startFen: ChessGame.startingFen,
      moves: [first.application!.record, second.application!.record],
      result: const GameResult(
        reason: GameEndReason.resignation,
        winnerIsWhite: true,
      ),
      timeControlLabel: '10 + 0',
      timeCategory: TimeCategory.rapid,
      source: GameSource.computer,
      whiteName: 'Maggie',
      blackName: 'Computer \u00b7 Medium',
      whiteRatingBefore: 1215,
      blackRatingBefore: 1200,
      rated: true,
    );
  }

  Future<void> pumpReplay(
    WidgetTester tester, {
    bool autoAnalyze = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameReplayScreen(
          record: sampleRecord(),
          autoAnalyze: autoAnalyze,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders board, move list, transport and analysis panel',
      (tester) async {
    await pumpReplay(tester);

    expect(find.byType(ChessBoardView), findsOneWidget);
    expect(find.byType(EvalBar), findsOneWidget);
    expect(find.byType(MoveListView), findsOneWidget);

    expect(find.text('e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('Move 0 / 2'), findsOneWidget);

    // Analysis off: neutral state before any engine call.
    expect(find.text('No eval'), findsOneWidget);
    expect(find.text('Engine best line shows here'), findsOneWidget);

    // Result headline from the record.
    expect(find.text('WHITE WINS \u00b7 RESIGNATION'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('transport buttons step through the game', (tester) async {
    await pumpReplay(tester);

    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    expect(find.text('Move 1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('End'));
    await tester.pump();
    expect(find.text('Move 2 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Start'));
    await tester.pump();
    expect(find.text('Move 0 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous'));
    await tester.pump();
    expect(find.text('Move 0 / 2'), findsOneWidget); // already at the start

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('tapping a move in the list jumps to it', (tester) async {
    await pumpReplay(tester);

    await tester.tap(find.text('e5'));
    await tester.pump();
    expect(find.text('Move 2 / 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('flip button mirrors the board orientation', (tester) async {
    await pumpReplay(tester);

    final board = tester.widget<ChessBoardView>(find.byType(ChessBoardView));
    expect(board.orientationWhite, isTrue);

    await tester.tap(find.byTooltip('Flip board'));
    await tester.pump();

    final flipped = tester.widget<ChessBoardView>(find.byType(ChessBoardView));
    expect(flipped.orientationWhite, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('manual analysis produces eval, depth and best line',
      (tester) async {
    await pumpReplay(tester);

    await tester.tap(find.byTooltip('Analyse this position'));
    await tester.pump();
    expect(find.text('Analysing\u2026'), findsOneWidget);

    // Engine searches on a real isolate: let real time pass.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2500)),
    );
    await tester.pump();

    expect(find.byType(EvalPill), findsOneWidget);
    expect(find.text('No eval'), findsNothing);
    expect(find.text('Engine best line shows here'), findsNothing);
    expect(find.textContaining('depth '), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
