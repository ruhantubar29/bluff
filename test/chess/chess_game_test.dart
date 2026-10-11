import 'package:bluff/games/chess/core/board.dart';
import 'package:bluff/games/chess/core/chess_game.dart';
import 'package:bluff/games/chess/core/models/game_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChessGame basics', () {
    test('starts from the standard position', () {
      final g = ChessGame();
      expect(g.pieces, hasLength(32));
      expect(g.whiteToMove, isTrue);
      expect(g.moveCount, 0);
      expect(g.history, isEmpty);
    });

    test('normal move applies and records SAN', () {
      final g = ChessGame();
      final attempt = g.makeMove(from: 'e2', to: 'e4');
      expect(attempt.played, isTrue);
      expect(g.history.single.san, 'e4');
      expect(g.whiteToMove, isFalse);
    });

    test('illegal moves are rejected', () {
      final g = ChessGame();
      expect(g.makeMove(from: 'e2', to: 'e5').outcome, MoveOutcome.illegal);
      expect(g.makeMove(from: 'e7', to: 'e5').outcome, MoveOutcome.notYourTurn);
      expect(g.makeMove(from: 'a3', to: 'a4').outcome, MoveOutcome.illegal);
      expect(g.moveCount, 0);
    });

    test('legal move generation matches piece movement', () {
      final g = ChessGame();
      expect(g.legalTargetsFrom('e2'), ['e3', 'e4']);
      expect(g.legalTargetsFrom('g1'), ['f3', 'h3']);
      expect(g.legalTargetsFrom('e7'), isEmpty); // opponent piece
    });

    test('checkmate ends the game (fool\'s mate)', () {
      final g = ChessGame();
      for (final m in [
        ['f2', 'f3'],
        ['e7', 'e5'],
        ['g2', 'g4'],
        ['d8', 'h4'],
      ]) {
        final attempt = g.makeMove(from: m[0], to: m[1]);
        expect(attempt.played, isTrue, reason: 'move ${m.join('->')}');
      }
      expect(g.isGameOver, isTrue);
      final result = g.result!;
      expect(result.reason, GameEndReason.checkmate);
      expect(result.winnerIsWhite, isFalse);
      expect(result.pgnToken, '0-1');
    });

    test('castling works both sides', () {
      // White: clear the way and castle kingside.
      final g = ChessGame();
      for (final m in [
        ['e2', 'e4'],
        ['e7', 'e5'],
        ['g1', 'f3'],
        ['b8', 'c6'],
        ['f1', 'c4'],
        ['g8', 'f6'],
        ['e1', 'g1'],
      ]) {
        expect(g.makeMove(from: m[0], to: m[1]).played, isTrue,
            reason: 'move ${m.join('->')}');
      }
      expect(g.pieceAt('g1')?.type, PieceType.king);
      expect(g.pieceAt('f1')?.type, PieceType.rook);
      expect(g.history.last.isCastle, isTrue);
      expect(g.history.last.san, 'O-O');
    });

    test('castling through check is illegal', () {
      // Black bishop on a6 controls f1, so white cannot castle kingside
      // (the king would cross f1), but queenside remains legal.
      final g = ChessGame(fen: '4k3/b7/8/8/8/8/8/R3K2R w KQ - 0 1');
      expect(g.legalTargetsFrom('e1'), isNot(contains('g1')));
      expect(g.legalTargetsFrom('e1'), contains('c1'));
      expect(g.makeMove(from: 'e1', to: 'g1').outcome, MoveOutcome.illegal);

      // With the bishop gone, kingside castling is legal.
      final g2 = ChessGame(fen: '4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      expect(g2.makeMove(from: 'e1', to: 'g1').played, isTrue);
      expect(g2.pieceAt('g1')?.type, PieceType.king);
      expect(g2.pieceAt('f1')?.type, PieceType.rook);
    });

    test('castling rights are lost after the king moves', () {
      final g = ChessGame(fen: 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      expect(g.legalTargetsFrom('e1'), containsAll(['c1', 'g1']));
      g.makeMove(from: 'e1', to: 'e2');
      g.makeMove(from: 'e8', to: 'e7');
      g.makeMove(from: 'e2', to: 'e1');
      g.makeMove(from: 'e7', to: 'e8');
      // King returned, but rights are gone.
      expect(g.legalTargetsFrom('e1'), isNot(contains('g1')));
      expect(g.legalTargetsFrom('e1'), isNot(contains('c1')));
    });

    test('en passant is available and then expires', () {
      final g = ChessGame();
      for (final m in [
        ['e2', 'e4'],
        ['a7', 'a6'],
        ['e4', 'e5'],
        ['d7', 'd5'],
      ]) {
        expect(g.makeMove(from: m[0], to: m[1]).played, isTrue);
      }
      expect(g.legalTargetsFrom('e5'), contains('d6'));
      final attempt = g.makeMove(from: 'e5', to: 'd6');
      expect(attempt.played, isTrue);
      expect(attempt.application!.record.isEnPassant, isTrue);
      expect(g.pieceAt('d5'), isNull);
      expect(g.pieceAt('d6')?.isWhite, isTrue);
    });

    test('en passant right expires after one ply', () {
      final g = ChessGame();
      for (final m in [
        ['e2', 'e4'],
        ['a7', 'a6'],
        ['e4', 'e5'],
        ['d7', 'd5'],
      ]) {
        expect(g.makeMove(from: m[0], to: m[1]).played, isTrue);
      }
      // White plays a quiet move instead of capturing immediately.
      expect(g.makeMove(from: 'h2', to: 'h3').played, isTrue);
      // The e5 pawn can no longer capture on d6: the en passant right is
      // gone and d6 is not occupied by a capturable piece.
      expect(g.legalTargetsFrom('e5'), isNot(contains('d6')));
    });

    test('promotion requires choosing a piece', () {
      final g = ChessGame(
        fen: '8/P6k/8/8/8/8/8/K7 w - - 0 1',
      );
      final attempt = g.makeMove(from: 'a7', to: 'a8');
      expect(attempt.outcome, MoveOutcome.promotionRequired);
      expect(g.moveCount, 0);

      final queen = g.makeMove(from: 'a7', to: 'a8', promotion: 'q');
      expect(queen.played, isTrue);
      expect(g.pieceAt('a8')?.type, PieceType.queen);
      expect(queen.application!.record.san, 'a8=Q');
    });

    test('underpromotion to a knight produces legal SAN', () {
      final g = ChessGame(fen: '8/P6k/8/8/8/8/8/K7 w - - 0 1');
      final knight = g.makeMove(from: 'a7', to: 'a8', promotion: 'n');
      expect(knight.played, isTrue);
      expect(g.pieceAt('a8')?.type, PieceType.knight);
      expect(knight.application!.record.san, 'a8=N');
    });

    test('autoQueen promotes without a dialog', () {
      final g = ChessGame(fen: '8/P6k/8/8/8/8/8/K7 w - - 0 1');
      final attempt = g.makeMove(from: 'a7', to: 'a8', autoQueen: true);
      expect(attempt.played, isTrue);
      expect(g.pieceAt('a8')?.type, PieceType.queen);
    });

    test('stalemate is a draw', () {
      // Classic stalemate: black king on a8, white king b6, queen c7?
      // Use the well-known position: Ka8, white Kb6, Qb7? that's mate.
      // Stalemate: black king a8, white king c7? no...
      // Known: black Ka8, white Kc7? no. Use: black king h8, white king f7,
      // queen g6 -> stalemate? Kf7, Qg6, Kh8: king can go h7? g6 Q covers h7.
      // Actually Qg6 covers h7,g7,g8,h5... king h8: h7 covered, g8 covered,
      // g7 covered => stalemate. Check it's not check first.
      final g = ChessGame(fen: '7k/5K2/6Q1/8/8/8/8/8 b - - 0 1');
      final result = g.refreshResult();
      expect(result, isNotNull);
      expect(result!.reason, GameEndReason.stalemate);
      expect(result.isDraw, isTrue);
    });

    test('insufficient material is a draw', () {
      final g = ChessGame(fen: '8/8/4k3/8/8/4K3/8/8 w - - 0 1');
      expect(g.refreshResult()?.reason, GameEndReason.insufficientMaterial);
    });

    test('fifty-move rule triggers at 100 half-moves', () {
      final g = ChessGame(
        fen: '7k/8/8/8/8/8/R7/K7 w - - 99 80',
      );
      // Make a quiet rook move that does not reset the counter.
      final attempt = g.makeMove(from: 'a1', to: 'b1');
      expect(attempt.played, isTrue);
      expect(attempt.application?.result?.reason, GameEndReason.fiftyMoveRule);
    });

    test('resignation ends the game with the correct winner', () {
      final g = ChessGame();
      g.endGame(const GameResult(
        reason: GameEndReason.resignation,
        winnerIsWhite: false,
      ));
      expect(g.isGameOver, isTrue);
      expect(g.result!.winnerLabel, 'Black wins');
      expect(g.makeMove(from: 'e2', to: 'e4').outcome, MoveOutcome.gameOver);
    });

    test('takeback restores the previous position', () {
      final g = ChessGame();
      g.makeMove(from: 'e2', to: 'e4');
      g.makeMove(from: 'e7', to: 'e5');
      expect(g.moveCount, 2);
      expect(g.undoMoves(1), 1);
      expect(g.moveCount, 1);
      expect(g.whiteToMove, isFalse);
      expect(g.pieceAt('e5'), isNull);
      expect(g.pieceAt('e7')?.type, PieceType.pawn);
    });

    test('restore replays a recorded game', () {
      final g = ChessGame();
      g.makeMove(from: 'e2', to: 'e4');
      g.makeMove(from: 'c7', to: 'c5');
      g.makeMove(from: 'g1', to: 'f3');
      final records = g.history;

      final restored = ChessGame.restore(
        startFen: ChessGame.startingFen,
        records: records,
      );
      expect(restored, isNotNull);
      expect(restored!.moveCount, 3);
      expect(restored.fen, g.fen);
      expect(restored.sanMoves, ['e4', 'c5', 'Nf3']);
    });

    test('restore rejects corrupt records', () {
      final g = ChessGame();
      g.makeMove(from: 'e2', to: 'e4');
      final records = [...g.history];
      // Tamper: replay the same white move twice (second is black's turn).
      final restored = ChessGame.restore(
        startFen: ChessGame.startingFen,
        records: [...records, records.first],
      );
      expect(restored, isNull);
    });

    test('PGN contains headers, moves and result', () {
      final g = ChessGame();
      g.makeMove(from: 'e2', to: 'e4');
      g.makeMove(from: 'e7', to: 'e5');
      g.endGame(const GameResult(
        reason: GameEndReason.resignation,
        winnerIsWhite: true,
      ));
      final pgn = g.pgn(
        white: 'Alice',
        black: 'Bob',
        whiteElo: '1500',
        blackElo: '1450',
        event: 'Test Event',
        date: '2026.10.03',
      );
      expect(pgn, contains('[White "Alice"]'));
      expect(pgn, contains('[Black "Bob"]'));
      expect(pgn, contains('[WhiteElo "1500"]'));
      expect(pgn, contains('1. e4 e5'));
      expect(pgn, contains('1-0'));
    });
  });

  group('check highlighting', () {
    test('checked king square is reported', () {
      // White to move in check: rook check on back rank.
      final g = ChessGame(fen: '4k3/8/8/8/8/8/8/4K2r w - - 0 1');
      expect(g.inCheck, isTrue);
      expect(g.checkedKingSquare, 'e1');
    });
  });
}
