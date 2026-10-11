import 'package:bluff/games/chess/core/chess_game.dart';
import 'package:bluff/games/chess/core/data/puzzle_data.dart';
import 'package:bluff/games/chess/core/models/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the generated puzzle dataset: every position must load, every
/// solution line must replay legally through the rules engine, and mate
/// puzzles must actually end in checkmate. A corrupt dataset would otherwise
/// surface as an unsolvable puzzle in the trainer.
void main() {
  final puzzles = PuzzleData.puzzles;

  test('dataset has at least 60 puzzles with unique ids and positions', () {
    expect(puzzles.length, greaterThanOrEqualTo(60));

    final ids = puzzles.map((p) => p.id).toSet();
    expect(ids.length, puzzles.length, reason: 'ids must be unique');

    final fens = puzzles.map((p) => p.fen).toSet();
    expect(fens.length, puzzles.length, reason: 'positions must be unique');
  });

  test('every puzzle has sane metadata', () {
    const themes = {
      'checkmate',
      'backRank',
      'forcedMate',
      'fork',
      'check',
      'hangingPiece',
      'endgame',
      'promotion',
    };

    for (final p in puzzles) {
      expect(p.rating, inInclusiveRange(400, 2500), reason: p.id);
      expect(p.themes, isNotEmpty, reason: p.id);
      expect(themes, containsAll(p.themes), reason: '${p.id}: ${p.themes}');
      expect(p.solution, isNotEmpty, reason: p.id);
      expect(p.solution.length, lessThanOrEqualTo(10), reason: p.id);
      expect(p.fen.split(' ').length, 6, reason: '${p.id}: malformed FEN');
      expect(p.comment, isNotNull, reason: p.id);
      expect(p.source, isNotNull, reason: p.id);
    }
  });

  test('every FEN parses into a playable position', () {
    for (final p in puzzles) {
      final game = ChessGame(fen: p.fen);
      // A legal position always has both kings and a side to move.
      expect(game.pieces.where((b) => b.fenChar == 'K').length, 1,
          reason: '${p.id}: white king');
      expect(game.pieces.where((b) => b.fenChar == 'k').length, 1,
          reason: '${p.id}: black king');
      expect(game.isGameOver, isFalse, reason: '${p.id}: game already over');
    }
  });

  test('every solution line replays legally', () {
    for (final p in puzzles) {
      final game = ChessGame(fen: p.fen);
      for (var i = 0; i < p.solution.length; i++) {
        final (from, to, promotion) = ChessPuzzle.parseUci(p.solution[i]);
        final attempt = game.makeMove(from: from, to: to, promotion: promotion);
        expect(
          attempt.played,
          isTrue,
          reason: '${p.id}: ply $i (${p.solution[i]}) rejected: '
              '${attempt.outcome}',
        );
      }
    }
  });

  test('mate puzzles end in checkmate on the final move', () {
    final matePuzzles =
        puzzles.where((p) => p.mateIn != null).toList(growable: false);
    expect(matePuzzles, isNotEmpty);

    for (final p in matePuzzles) {
      final game = ChessGame(fen: p.fen);
      for (final uci in p.solution) {
        final (from, to, promotion) = ChessPuzzle.parseUci(uci);
        game.makeMove(from: from, to: to, promotion: promotion);
      }
      expect(game.isGameOver, isTrue, reason: '${p.id}: game not over');
      expect(game.legalMoves, isEmpty, reason: '${p.id}: replies remain');
      expect(game.inCheck, isTrue, reason: '${p.id}: not checkmate');
      expect(
        p.solution.length,
        p.mateIn! * 2 - 1,
        reason: '${p.id}: mateIn=${p.mateIn} but line has '
            '${p.solution.length} plies',
      );
    }
  });

  test('mate-in-one puzzles are decided by the solver first move', () {
    final ones =
        puzzles.where((p) => p.mateIn == 1).toList(growable: false);
    expect(ones, isNotEmpty);

    for (final p in ones) {
      expect(p.solution.length, 1, reason: p.id);
      final game = ChessGame(fen: p.fen);
      final (from, to, promotion) = ChessPuzzle.parseUci(p.solution.first);
      final attempt = game.makeMove(from: from, to: to, promotion: promotion);
      expect(attempt.played, isTrue, reason: p.id);
      expect(game.legalMoves, isEmpty, reason: '${p.id}: replies remain');
      expect(game.inCheck, isTrue, reason: '${p.id}: not checkmate');
    }
  });

  test('solver moves land on even plies with replies in between', () {
    for (final p in puzzles) {
      expect(p.isSolverMove(0), isTrue, reason: p.id);
      // Fork and forced-mate lines are the scripted exchanges: solver,
      // opponent reply, solver finishes.
      if (p.themes.contains('fork') || p.mateIn == 2) {
        expect(p.solution.length, 3, reason: '${p.id}: ${p.solution}');
      }
    }
  });

  test('ratings span a difficulty range, not one flat band', () {
    final ratings = puzzles.map((p) => p.rating).toList();
    final spread = ratings.reduce((a, b) => a > b ? a : b) -
        ratings.reduce((a, b) => a < b ? a : b);
    expect(spread, greaterThanOrEqualTo(300));
  });
}
