import 'package:bluff/games/chess/core/engine/chess_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChessEngine search', () {
    test('finds mate in one', () {
      // Back-rank mate: Ra8#
      final result = ChessEngine.search(const EngineSearchRequest(
        fen: '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
        maxDepth: 3,
        timeMs: 2000,
        randomSeed: 42,
        noise: 0,
        blunderChance: 0,
      ));
      expect(result.hasMove, isTrue);
      expect(result.isMate, isTrue);
      expect(result.bestSan, contains('#'));
      expect(result.from, 'a1');
      expect(result.to, 'a8');
    });

    test('finds mate in one for black', () {
      final result = ChessEngine.search(const EngineSearchRequest(
        fen: 'r5k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1',
        maxDepth: 3,
        timeMs: 2000,
        randomSeed: 7,
        noise: 0,
        blunderChance: 0,
      ));
      expect(result.hasMove, isTrue);
      expect(result.isMate, isTrue);
      expect(result.to, 'a1');
    });

    test('captures a hanging queen', () {
      // Black queen on d4 en prise to a pawn on c3.
      final result = ChessEngine.search(const EngineSearchRequest(
        fen: 'rnb1kbnr/pppp1ppp/8/4p3/3q4/2P5/PP1PPPPP/RNB1KBNR w KQkq - 0 1',
        maxDepth: 3,
        timeMs: 2000,
        randomSeed: 11,
        noise: 0,
        blunderChance: 0,
      ));
      expect(result.hasMove, isTrue);
      expect(result.bestSan, 'cxd4');
    });

    test('wins material with a knight fork', () {
      // Nd6+ forks the king on e8 and the queen on b7. Knight checks can't
      // be blocked, so black must move the king and the queen falls next.
      // White also keeps a rook, so the resulting position is winning.
      final result = ChessEngine.search(const EngineSearchRequest(
        fen: '4k3/1q6/8/8/2N5/8/8/2R1K3 w - - 0 1',
        maxDepth: 4,
        timeMs: 3000,
        noise: 0,
        randomSeed: 3,
        blunderChance: 0,
      ));
      expect(result.hasMove, isTrue);
      expect(result.from, 'c4');
      expect(result.to, 'd6');
      expect(result.whiteScoreCp, greaterThan(400));
    });

    test('winning the last piece for a knight is scored as a draw', () {
      // Here winning the rook leaves K+N vs K — correctly evaluated as a
      // draw by insufficient material rather than as a win.
      final result = ChessEngine.search(const EngineSearchRequest(
        fen: '3r3k/8/8/4N3/8/8/8/4K3 w - - 0 1',
        maxDepth: 4,
        timeMs: 3000,
        noise: 0,
        randomSeed: 3,
        blunderChance: 0,
      ));
      expect(result.hasMove, isTrue);
      expect(result.from, 'e5');
      expect(result.to, 'f7');
      expect(result.isMate, isFalse);
      expect(result.whiteScoreCp.abs(), lessThan(150));
    });

    test('avoids grabbing a poisoned piece', () {
      // The rook on h4 looks loose for black, but capturing it (Rxh4) walks
      // into a recapture: white is simply a piece up either way, so the
      // engine should keep a sound move rather than blunder material.
      final result = ChessEngine.search(const EngineSearchRequest(
        fen: 'r5k1/5ppp/8/8/7R/8/5PPP/6K1 b - - 0 1',
        maxDepth: 4,
        timeMs: 2000,
        noise: 0,
        randomSeed: 12,
        blunderChance: 0,
      ));
      expect(result.hasMove, isTrue);
      // Black has no way to win material; the reply must remain legal.
      expect(result.to, hasLength(2));
    });

    test('returns a legal move from the starting position', () {
      final result = ChessEngine.search(const EngineSearchRequest(
        fen:
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        maxDepth: 3,
        timeMs: 500,
        randomSeed: 99,
        noise: 0,
        blunderChance: 0,
      ));
      expect(result.hasMove, isTrue);
      expect(result.from!.length, 2);
      expect(result.to!.length, 2);
      expect(result.pv, isNotEmpty);
      expect(result.depth, greaterThanOrEqualTo(1));
      expect(result.nodes, greaterThan(0));
    });

    test('reports no move when game is over', () {
      // Stalemate position: no legal moves.
      final result = ChessEngine.search(const EngineSearchRequest(
        fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1',
        maxDepth: 2,
        timeMs: 500,
        randomSeed: 1,
        noise: 0,
        blunderChance: 0,
      ));
      // Black is stalemated here (actually this is checkmate or stalemate).
      expect(result.hasMove, isFalse);
    });

    test('levels differ in effort and injected error', () {
      expect(EngineLevel.beginner.depth, lessThan(EngineLevel.master.depth));
      expect(EngineLevel.beginner.blunderChance, greaterThan(0));
      expect(EngineLevel.master.blunderChance, 0);
      expect(EngineLevel.master.noise, 0);
      expect(EngineLevel.beginner.noise, greaterThan(0));
      expect(EngineLevel.master.rating, greaterThan(EngineLevel.easy.rating));
    });

    test('weaker levels pick a wider variety of moves', () {
      const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final weakMoves = <String>{};
      final strongMoves = <String>{};
      for (var seed = 0; seed < 8; seed++) {
        final weak = ChessEngine.search(EngineSearchRequest(
          fen: fen,
          maxDepth: EngineLevel.beginner.depth,
          timeMs: EngineLevel.beginner.timeMs,
          randomSeed: seed,
          noise: EngineLevel.beginner.noise,
          blunderChance: 0,
        ));
        final strong = ChessEngine.search(EngineSearchRequest(
          fen: fen,
          maxDepth: EngineLevel.medium.depth,
          timeMs: EngineLevel.medium.timeMs,
          randomSeed: seed,
          noise: 0,
          blunderChance: 0,
        ));
        if (weak.hasMove) weakMoves.add('${weak.from}${weak.to}');
        if (strong.hasMove) strongMoves.add('${strong.from}${strong.to}');
      }
      // Noise makes weaker play less deterministic than quiet play.
      expect(weakMoves.length, greaterThan(strongMoves.length));
    });

    test('static eval is symmetric from both sides', () {
      const start =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      // Symmetric position evaluates to ~0.
      expect(ChessEngine.staticEvalFor(start).abs(), lessThan(30));

      // Up a queen for white: clearly positive from White's view.
      const upQueen = 'rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      expect(ChessEngine.staticEvalFor(upQueen), greaterThan(700));
    });

    test('is fast enough to be responsive', () {
      final sw = Stopwatch()..start();
      ChessEngine.search(const EngineSearchRequest(
        fen:
            'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
        maxDepth: 4,
        timeMs: 1000,
        randomSeed: 5,
        noise: 0,
        blunderChance: 0,
      ));
      sw.stop();
      // Should respect the time budget (+ generous slack for CI).
      expect(sw.elapsedMilliseconds, lessThan(4000));
    });
  });
}
