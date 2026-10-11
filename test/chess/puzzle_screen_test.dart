import 'package:bluff/games/chess/core/chess_game.dart';
import 'package:bluff/games/chess/core/data/puzzle_data.dart';
import 'package:bluff/games/chess/core/models/puzzle.dart';
import 'package:bluff/games/chess/core/rating/elo.dart';
import 'package:bluff/games/chess/screens/puzzle_screen.dart';
import 'package:bluff/games/chess/services/chess_storage.dart';
import 'package:bluff/games/chess/services/session_service.dart';
import 'package:bluff/games/chess/services/settings_service.dart';
import 'package:bluff/games/chess/widgets/board/chess_board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
    final settings = ChessSettingsService.instance.settings;
    settings
      ..showEvalBar = false
      ..playSounds = false
      ..confirmMoves = false;
  });

  /// A guaranteed mate-in-one from the generated dataset.
  ChessPuzzle mateInOne() =>
      PuzzleData.puzzles.firstWhere((p) => p.mateIn == 1);

  /// A mate-in-one that also offers at least one alternative legal move
  /// (used to exercise the wrong-move path).
  ChessPuzzle mateWithAlternatives() => PuzzleData.puzzles.firstWhere((p) {
        if (p.mateIn != 1) return false;
        final game = ChessGame(fen: p.fen);
        return game.legalMoves
            .any((m) => '${m.from}${m.to}' != p.solution.first);
      });

  /// A full three-ply line: solver, scripted reply, solver finishes.
  ChessPuzzle threePly() => PuzzleData.puzzles.firstWhere(
        (p) =>
            p.solution.length == 3 &&
            p.solution.every((u) => u.length == 4),
      );

  Future<void> pumpPuzzle(WidgetTester tester, ChessPuzzle puzzle) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PuzzleScreen(initialPuzzle: puzzle)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Tap-taps a move on the board, honoring the board's orientation.
  Future<void> playMove(
    WidgetTester tester,
    String from,
    String to,
  ) async {
    final boardFinder = find.byType(ChessBoardView);
    final board = tester.widget<ChessBoardView>(boardFinder);
    final rect = tester.getRect(boardFinder);
    final cell = rect.width / 8;
    final whiteAtBottom = board.orientationWhite;

    Offset point(String name) {
      final file = name.codeUnitAt(0) - 97;
      final rank = int.parse(name.substring(1));
      final col = whiteAtBottom ? file : 7 - file;
      final row = whiteAtBottom ? 8 - rank : rank - 1;
      return Offset(
        rect.left + (col + 0.5) * cell,
        rect.top + (row + 0.5) * cell,
      );
    }

    await tester.tapAt(point(from));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point(to));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the position, prompt and controls', (tester) async {
    final puzzle = mateInOne();
    await pumpPuzzle(tester, puzzle);

    expect(find.byType(ChessBoardView), findsOneWidget);
    expect(
      find.text('Find the best move for ${puzzle.sideToMoveLabel}'),
      findsOneWidget,
    );
    expect(find.text('${puzzle.rating}'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Show solution'), findsOneWidget);
    expect(find.text('Next puzzle'), findsNothing);
  });

  testWidgets('solving a mate in one records the attempt and rating',
      (tester) async {
    final puzzle = mateInOne();
    await pumpPuzzle(tester, puzzle);

    final (from, to, promotion) = ChessPuzzle.parseUci(puzzle.solution.first);
    await playMove(tester, from, to);
    if (promotion != null) {
      await tester.tap(find.text(promotion.toUpperCase()));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));

    // Result banner shows the dataset comment plus the Next puzzle action.
    expect(find.text(puzzle.comment!), findsOneWidget);
    expect(find.text('Next puzzle'), findsOneWidget);

    final attempts = await ChessStorage.instance.loadPuzzleAttempts();
    expect(attempts, hasLength(1));
    expect(attempts.single.solved, isTrue);
    expect(attempts.single.puzzleId, puzzle.id);

    final profile = await SessionService.instance.current;
    expect(profile.puzzleStats.solved, 1);
    expect(profile.puzzleStats.attempted, 1);
    // Rating moved by exactly the Elo delta the attempt recorded.
    final expected = Elo.newRating(
      rating: 1200,
      opponentRating: puzzle.rating,
      score: 1.0,
      gamesPlayed: 0,
    );
    expect(profile.puzzleStats.rating, expected);
    expect(attempts.single.ratingAfter, expected);
  });

  testWidgets('a wrong move is rejected without changing the position',
      (tester) async {
    final puzzle = mateWithAlternatives();
    await pumpPuzzle(tester, puzzle);

    final game = ChessGame(fen: puzzle.fen);
    final wrong = game.legalMoves
        .firstWhere((m) => '${m.from}${m.to}' != puzzle.solution.first);

    await playMove(tester, wrong.from, wrong.to);

    expect(
      find.text('Not quite — look for something better.'),
      findsOneWidget,
    );
    expect(find.text('Next puzzle'), findsNothing);

    // Nothing was recorded yet — the puzzle is still live.
    final attempts = await ChessStorage.instance.loadPuzzleAttempts();
    expect(attempts, isEmpty);
    final profile = await SessionService.instance.current;
    expect(profile.puzzleStats.attempted, 0);
  });

  testWidgets('three-ply lines auto-play the scripted reply', (tester) async {
    final puzzle = threePly();
    await pumpPuzzle(tester, puzzle);

    // Solver's first move.
    final (f0, t0, p0) = ChessPuzzle.parseUci(puzzle.solution[0]);
    await playMove(tester, f0, t0);
    if (p0 != null) {
      await tester.tap(find.text(p0.toUpperCase()));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The scripted opponent reply lands automatically.
    await tester.pump(const Duration(milliseconds: 500));
    final board = tester.widget<ChessBoardView>(find.byType(ChessBoardView));
    expect(board.lastMoveTo, puzzle.solution[1].substring(2, 4));
    expect(find.text('Next puzzle'), findsNothing);

    // Solver finishes the line.
    final (f2, t2, p2) = ChessPuzzle.parseUci(puzzle.solution[2]);
    await playMove(tester, f2, t2);
    if (p2 != null) {
      await tester.tap(find.text(p2.toUpperCase()));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Next puzzle'), findsOneWidget);
    final attempts = await ChessStorage.instance.loadPuzzleAttempts();
    expect(attempts.single.solved, isTrue);
  });

  testWidgets('showing the solution reveals the line and fails the attempt',
      (tester) async {
    final puzzle = mateInOne();
    await pumpPuzzle(tester, puzzle);

    await tester.tap(find.text('Show solution'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('1. '), findsOneWidget);
    expect(find.text('Next puzzle'), findsOneWidget);

    final attempts = await ChessStorage.instance.loadPuzzleAttempts();
    expect(attempts, hasLength(1));
    expect(attempts.single.solved, isFalse);
  });

  testWidgets('next puzzle loads a fresh solving state', (tester) async {
    final puzzle = mateInOne();
    await pumpPuzzle(tester, puzzle);

    final (from, to, promotion) = ChessPuzzle.parseUci(puzzle.solution.first);
    await playMove(tester, from, to);
    if (promotion != null) {
      await tester.tap(find.text(promotion.toUpperCase()));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Next puzzle'), findsOneWidget);

    await tester.tap(find.text('Next puzzle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Next puzzle'), findsNothing);
    expect(find.text('Show solution'), findsOneWidget);
    expect(find.textContaining('Find the best move for'), findsOneWidget);

    // Only the first attempt was recorded so far.
    final attempts = await ChessStorage.instance.loadPuzzleAttempts();
    expect(attempts, hasLength(1));
  });

  testWidgets('hint highlights the expected from-square without solving',
      (tester) async {
    final puzzle = mateInOne();
    await pumpPuzzle(tester, puzzle);

    await tester.tap(find.text('Hint'));
    await tester.pump();

    expect(find.text('Next puzzle'), findsNothing);
    final board = tester.widget<ChessBoardView>(find.byType(ChessBoardView));
    expect(
      board.extraHighlights.containsKey(puzzle.solution.first.substring(0, 2)),
      isTrue,
    );
    final attempts = await ChessStorage.instance.loadPuzzleAttempts();
    expect(attempts, isEmpty);
  });
}
