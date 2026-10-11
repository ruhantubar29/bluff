import 'dart:math';

import 'package:chess/chess.dart' as rules;

/// How strong the engine plays. Each level maps to a search effort plus a
/// human-like error rate, so lower levels deliberately play imperfect moves.
enum EngineLevel {
  /// ~400 Elo: mostly random legal moves with occasional good ones.
  beginner(depth: 1, timeMs: 150, blunderChance: 0.45, noise: 350),

  /// ~800 Elo: shallow search, frequent inaccuracies.
  easy(depth: 2, timeMs: 250, blunderChance: 0.25, noise: 200),

  /// ~1200 Elo: 3-ply search with moderate noise.
  medium(depth: 3, timeMs: 500, blunderChance: 0.10, noise: 110),

  /// ~1600 Elo: deep search, small noise, rare mistakes.
  hard(depth: 4, timeMs: 900, blunderChance: 0.03, noise: 55),

  /// ~1900 Elo: time-managed iterative deepening.
  expert(depth: 6, timeMs: 1600, blunderChance: 0.0, noise: 25),

  /// ~2200 Elo: deep, patient search with no injected noise.
  master(depth: 8, timeMs: 3000, blunderChance: 0.0, noise: 0);

  const EngineLevel({
    required this.depth,
    required this.timeMs,
    required this.blunderChance,
    required this.noise,
  });

  /// Maximum search depth in plies.
  final int depth;

  /// Time budget in milliseconds (iterative deepening stops here).
  final int timeMs;

  /// Chance the engine picks a clearly inferior move instead of the best.
  final double blunderChance;

  /// Random noise (centipawns) added to evaluations when choosing.
  final int noise;

  String get displayName {
    switch (this) {
      case EngineLevel.beginner:
        return 'Beginner';
      case EngineLevel.easy:
        return 'Easy';
      case EngineLevel.medium:
        return 'Medium';
      case EngineLevel.hard:
        return 'Hard';
      case EngineLevel.expert:
        return 'Expert';
      case EngineLevel.master:
        return 'Master';
    }
  }

  /// Default rating shown for this level (used for rated vs-computer games
  /// and matchmaking hints).
  int get rating {
    switch (this) {
      case EngineLevel.beginner:
        return 400;
      case EngineLevel.easy:
        return 800;
      case EngineLevel.medium:
        return 1200;
      case EngineLevel.hard:
        return 1600;
      case EngineLevel.expert:
        return 1900;
      case EngineLevel.master:
        return 2200;
    }
  }
}

/// Result of an engine search.
class EngineResult {
  const EngineResult({
    required this.from,
    required this.to,
    required this.promotion,
    required this.scoreCp,
    required this.whiteScoreCp,
    required this.depth,
    required this.pv,
    required this.nodes,
    required this.moveTimeMs,
    required this.bestSan,
    required this.isMate,
    required this.mateInPly,
  });

  /// Source square ('e2'), or null when there is no legal move.
  final String? from;
  final String? to;
  final String? promotion;

  /// Evaluation in centipawns from the *side to move's* point of view.
  final int scoreCp;

  /// Evaluation from White's point of view (for the evaluation bar).
  final int whiteScoreCp;

  final int depth;
  final List<String> pv;
  final int nodes;
  final int moveTimeMs;
  final String? bestSan;

  /// True when the side to move is (currently) checkmated.
  final bool isMate;
  final int mateInPly;

  bool get hasMove => from != null;

  static const EngineResult empty = EngineResult(
    from: null,
    to: null,
    promotion: null,
    scoreCp: 0,
    whiteScoreCp: 0,
    depth: 0,
    pv: [],
    nodes: 0,
    moveTimeMs: 0,
    bestSan: null,
    isMate: false,
    mateInPly: 0,
  );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'promotion': promotion,
        'scoreCp': scoreCp,
        'whiteScoreCp': whiteScoreCp,
        'depth': depth,
        'pv': pv,
        'nodes': nodes,
        'moveTimeMs': moveTimeMs,
        'bestSan': bestSan,
        'isMate': isMate,
        'mateInPly': mateInPly,
      };

  factory EngineResult.fromJson(Map<String, dynamic> json) => EngineResult(
        from: json['from'] as String?,
        to: json['to'] as String?,
        promotion: json['promotion'] as String?,
        scoreCp: (json['scoreCp'] as num?)?.toInt() ?? 0,
        whiteScoreCp: (json['whiteScoreCp'] as num?)?.toInt() ?? 0,
        depth: (json['depth'] as num?)?.toInt() ?? 0,
        pv: (json['pv'] as List?)?.cast<String>() ?? const [],
        nodes: (json['nodes'] as num?)?.toInt() ?? 0,
        moveTimeMs: (json['moveTimeMs'] as num?)?.toInt() ?? 0,
        bestSan: json['bestSan'] as String?,
        isMate: json['isMate'] as bool? ?? false,
        mateInPly: (json['mateInPly'] as num?)?.toInt() ?? 0,
      );
}

// Piece values (centipawns) — king is never captured so its value is moot.
const int _pawnValue = 100;
const int _knightValue = 320;
const int _bishopValue = 330;
const int _rookValue = 500;
const int _queenValue = 900;

/// Piece-square tables (from White's perspective, index 0 = a8 ... 63 = h1,
/// matching FEN reading order). Encourage central development and piece
/// activity; mirrored for Black.
const List<int> _pstPawn = [
  0, 0, 0, 0, 0, 0, 0, 0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];

const List<int> _pstKnight = [
  -50, -40, -30, -30, -30, -30, -40, -50,
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];

const List<int> _pstBishop = [
  -20, -10, -10, -10, -10, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];

const List<int> _pstRook = [
  0, 0, 0, 0, 0, 0, 0, 0,
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];

const List<int> _pstQueen = [
  -20, -10, -10, -5, -5, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];

// King middlegame/endgame tables.
const List<int> _pstKingMid = [
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];

const List<int> _pstKingEnd = [
  -50, -40, -30, -20, -20, -30, -40, -50,
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -50, -50,
];

const int _mateScore = 100000;
const int _mateThreshold = 90000;

/// Search configuration passed to the engine (must be sendable across
/// isolates: plain data only).
class EngineSearchRequest {
  const EngineSearchRequest({
    required this.fen,
    required this.maxDepth,
    required this.timeMs,
    required this.randomSeed,
    required this.noise,
    required this.blunderChance,
    this.rootMoves = const [],
  });

  final String fen;
  final int maxDepth;
  final int timeMs;
  final int randomSeed;
  final int noise;
  final double blunderChance;

  /// Restrict the search to these from→to pairs (used by the analysis board
  /// to search only a variation).
  final List<String> rootMoves;

  factory EngineSearchRequest.fromLevel({
    required String fen,
    required EngineLevel level,
    int? seed,
  }) =>
      EngineSearchRequest(
        fen: fen,
        maxDepth: level.depth,
        timeMs: level.timeMs,
        randomSeed: seed ?? DateTime.now().millisecondsSinceEpoch,
        noise: level.noise,
        blunderChance: level.blunderChance,
      );

  /// Custom strength on the 250–3200 slider scale: interpolates the same
  /// knobs the named levels use (depth, time, noise, blunder rate) so any
  /// Elo in between plays like a believable opponent.
  factory EngineSearchRequest.fromElo({
    required String fen,
    required int elo,
    int? seed,
  }) {
    final e = elo.clamp(250, 3200).toInt();
    return EngineSearchRequest(
      fen: fen,
      maxDepth: (e ~/ 300).clamp(1, 9).toInt(),
      timeMs: (e * 0.9).clamp(150, 3500).round(),
      randomSeed: seed ?? DateTime.now().millisecondsSinceEpoch,
      noise: ((1900 - e) * 0.45).round().clamp(0, 750).toInt(),
      blunderChance: switch (e) {
        < 700 => 0.42,
        < 1000 => 0.28,
        < 1400 => 0.12,
        < 1800 => 0.03,
        _ => 0.0,
      },
    );
  }
}

/// Negamax alpha-beta engine with iterative deepening, move ordering,
/// quiescence search and light positional knowledge.
///
/// Pure Dart, no Flutter dependencies — safe to run in an isolate.
class ChessEngine {
  ChessEngine._();

  static const int infinity = 999999;

  /// Entry point for a full search. Stateless: one call, one result.
  static EngineResult search(EngineSearchRequest request) {
    final game = rules.Chess.fromFEN(request.fen);
    final sw = Stopwatch()..start();

    final legal = game.moves({'asObjects': true});
    if (legal.isEmpty) {
      return EngineResult.empty;
    }

    final whiteToMove = game.turn == rules.Color.WHITE;
    final seed = Random(request.randomSeed);

    // Low-effort levels: pick from a shortlist with injected noise instead
    // of a deep search, so they feel human rather than random.
    final rootMoves = _rootMoveKeys(game);
    final filtered = request.rootMoves.isEmpty
        ? rootMoves
        : rootMoves.where(request.rootMoves.contains).toList();
    final candidates =
        filtered.isEmpty ? rootMoves : filtered;

    final scores = <String, int>{};
    var nodes = 0;
    var reachedDepth = 0;
    EngineResult? best;

    // --- iterative deepening ------------------------------------------
    for (var depth = 1; depth <= request.maxDepth; depth++) {
      var bestAtDepth = _SearchLine(
        key: candidates.first,
        score: -infinity,
        pv: const [],
      );

      // Order the candidates by the previous iteration's scores for better
      // pruning.
      final ordered = [...candidates];
      if (scores.isNotEmpty) {
        ordered.sort((a, b) => (scores[b] ?? -infinity).compareTo(scores[a] ?? -infinity));
      }

      var alpha = -infinity;
      var aborted = false;
      for (final key in ordered) {
        if (sw.elapsedMilliseconds > request.timeMs && depth > 1) {
          aborted = true;
          break;
        }
        final parts = _splitKey(key);
        game.move({
          'from': parts[0],
          'to': parts[1],
          if (parts.length > 2) 'promotion': parts[2],
        });
        final score = -_negamax(
          game,
          depth - 1,
          -infinity,
          -alpha,
          whiteToMove: !whiteToMove,
          deadline: sw,
          timeMs: request.timeMs,
          counter: () => nodes++,
          deep: depth,
        );
        game.undo_move();
        nodes++;

        scores[key] = score;
        if (score > bestAtDepth.score) {
          bestAtDepth = _SearchLine(key: key, score: score, pv: [key]);
        }
        if (score > alpha) alpha = score;
      }

      if (aborted && depth > 1) break;

      reachedDepth = depth;
      best = _buildResult(
        game: game,
        key: bestAtDepth.key,
        score: bestAtDepth.score,
        depth: depth,
        nodes: nodes,
        elapsedMs: sw.elapsedMilliseconds,
        whiteToMove: whiteToMove,
        seed: seed,
        noise: request.noise,
        blunderChance: request.blunderChance,
        alternatives: scores,
      );

      // Stop early when the remaining budget is nearly exhausted.
      if (sw.elapsedMilliseconds > request.timeMs) break;
      // Don't bother going deeper in clearly decided positions.
      if (bestAtDepth.score.abs() > _mateThreshold) break;
    }

    best ??= _buildResult(
      game: game,
      key: candidates.first,
      score: scores[candidates.first] ?? 0,
      depth: reachedDepth,
      nodes: nodes,
      elapsedMs: sw.elapsedMilliseconds,
      whiteToMove: whiteToMove,
      seed: seed,
      noise: request.noise,
      blunderChance: request.blunderChance,
      alternatives: scores,
    );

    return best;
  }

  // ------------------------------------------------------------- helpers --

  /// Evaluation in centipawns from White's point of view (for the eval bar).
  static int staticEvalFor(String fen) {
    final game = rules.Chess.fromFEN(fen);
    return _evaluate(game, whiteToMove: true);
  }

  static List<String> _rootMoveKeys(rules.Chess game) {
    final raw = game.moves({'verbose': true});
    return [
      for (final m in raw)
        _keyFromVerbose(m as Map, game),
    ];
  }

  static String _keyFromVerbose(Map m, rules.Chess game) {
    // Verbose moves carry flags; rebuild the UCI-style key including
    // promotion piece parsed from SAN (verbose omits it).
    final flags = (m['flags'] as String?) ?? '';
    if (!flags.contains('p')) return '${m['from']}${m['to']}';
    final san = (m['san'] as String?) ?? '';
    final eq = san.indexOf('=');
    final promo = eq >= 0 && eq + 1 < san.length ? san[eq + 1].toLowerCase() : 'q';
    return '${m['from']}${m['to']}$promo';
  }

  static List<String> _splitKey(String key) => [
        key.substring(0, 2),
        key.substring(2, 4),
        if (key.length > 4) key.substring(4, 5),
      ];

  static int _negamax(
    rules.Chess game,
    int depth,
    int alpha,
    int beta, {
    required bool whiteToMove,
    required Stopwatch deadline,
    required int timeMs,
    required void Function() counter,
    required int deep,
  }) {
    counter();

    if (game.in_checkmate) return -_mateScore + (deep - depth);
    if (game.in_stalemate || game.insufficient_material) return 0;
    if (depth <= 0) {
      return _quiescence(game, alpha, beta, whiteToMove: whiteToMove, deadline: deadline, timeMs: timeMs, counter: counter, deep: deep);
    }
    if (deadline.elapsedMilliseconds > timeMs) {
      return _evaluate(game, whiteToMove: whiteToMove);
    }

    final moves = _orderedMoves(game);
    var bestScore = -infinity;
    for (final move in moves) {
      game.make_move(move);
      final score = -_negamax(
        game,
        depth - 1,
        -beta,
        -alpha,
        whiteToMove: !whiteToMove,
        deadline: deadline,
        timeMs: timeMs,
        counter: counter,
        deep: deep,
      );
      game.undo_move();

      if (score > bestScore) bestScore = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break; // beta cutoff
    }
    if (bestScore == -infinity) {
      // No pseudo-legal moves: mate or stalemate.
      return game.in_check ? -_mateScore + (deep - depth) : 0;
    }
    return bestScore;
  }

  /// Search only captures/checks to the horizon — stops the engine hanging
  /// pieces at the edge of the search tree.
  static int _quiescence(
    rules.Chess game,
    int alpha,
    int beta, {
    required bool whiteToMove,
    required Stopwatch deadline,
    required int timeMs,
    required void Function() counter,
    required int deep,
  }) {
    counter();
    if (deadline.elapsedMilliseconds > timeMs) {
      return _evaluate(game, whiteToMove: whiteToMove);
    }

    final stand = _evaluate(game, whiteToMove: whiteToMove);
    if (stand >= beta) return beta;
    if (stand > alpha) alpha = stand;

    final moves = _orderedMoves(game, capturesOnly: true);
    for (final move in moves) {
      game.make_move(move);
      final score = -_quiescence(
        game,
        -beta,
        -alpha,
        whiteToMove: !whiteToMove,
        deadline: deadline,
        timeMs: timeMs,
        counter: counter,
        deep: deep,
      );
      game.undo_move();

      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  /// Move ordering: promotions and captures (MVV-LVA) first, then the rest.
  static List<rules.Move> _orderedMoves(rules.Chess game, {bool capturesOnly = false}) {
    final raw = game.moves({'asObjects': true});
    final moves = raw.cast<rules.Move>();
    final scored = <MapEntry<rules.Move, int>>[];
    for (final m in moves) {
      final isCapture = m.captured != null;
      if (capturesOnly && !isCapture) continue;
      var s = 0;
      if (m.promotion != null) s += 800 + _valueOf(m.promotion!);
      if (isCapture) {
        s += 1000 + _valueOf(m.captured!) - _valueOf(m.piece) ~/ 10;
      }
      scored.add(MapEntry(m, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in scored) e.key];
  }

  static int _valueOf(rules.PieceType t) {
    if (t == rules.PieceType.PAWN) return _pawnValue;
    if (t == rules.PieceType.KNIGHT) return _knightValue;
    if (t == rules.PieceType.BISHOP) return _bishopValue;
    if (t == rules.PieceType.ROOK) return _rookValue;
    if (t == rules.PieceType.QUEEN) return _queenValue;
    return 0;
  }

  /// Static evaluation in centipawns from [whiteToMove]'s point of view.
  ///
  /// Tables are indexed from White's point of view with row 0 = rank 8 (FEN
  /// order); Black uses the vertically mirrored index. King placement blends
  /// middlegame/endgame tables by the amount of remaining piece material.
  static int _evaluate(rules.Chess game, {required bool whiteToMove}) {
    final board = game.board;
    var whiteScore = 0;
    var blackScore = 0;
    var whiteBishops = 0;
    var blackBishops = 0;
    var phase = 0; // 24 = all pieces present, 0 = pure endgame

    for (var i = 0; i < 128; i++) {
      if ((i & 0x88) != 0) continue;
      final piece = board[i];
      if (piece == null || piece.type == rules.PieceType.KING) continue;

      // FEN-order index (row 0 = rank 8); Black reads the mirrored row.
      final row = (i >> 4);
      final col = (i & 15);
      final isWhite = piece.color == rules.Color.WHITE;
      final idx = isWhite ? row * 8 + col : (7 - row) * 8 + col;

      final type = piece.type;
      final material = _valueOf(type);
      final pst = switch (type) {
        rules.PieceType.PAWN => _pstPawn[idx],
        rules.PieceType.KNIGHT => _pstKnight[idx],
        rules.PieceType.BISHOP => _pstBishop[idx],
        rules.PieceType.ROOK => _pstRook[idx],
        _ => _pstQueen[idx],
      };

      switch (type) {
        case rules.PieceType.KNIGHT:
          phase += 1;
        case rules.PieceType.BISHOP:
          phase += 1;
          if (isWhite) {
            whiteBishops++;
          } else {
            blackBishops++;
          }
        case rules.PieceType.ROOK:
          phase += 2;
        case rules.PieceType.QUEEN:
          phase += 4;
        default:
          break;
      }

      if (isWhite) {
        whiteScore += material + pst;
      } else {
        blackScore += material + pst;
      }
    }

    // King placement, evaluated once the full phase is known.
    final blend = phase.clamp(0, 24) / 24;
    for (var i = 0; i < 128; i++) {
      if ((i & 0x88) != 0) continue;
      final piece = board[i];
      if (piece == null || piece.type != rules.PieceType.KING) continue;
      final row = (i >> 4);
      final col = (i & 15);
      final isWhite = piece.color == rules.Color.WHITE;
      final idx = isWhite ? row * 8 + col : (7 - row) * 8 + col;
      final mid = _pstKingMid[idx];
      final end = _pstKingEnd[idx];
      final placement = (mid * blend + end * (1 - blend)).round();
      if (isWhite) {
        whiteScore += placement;
      } else {
        blackScore += placement;
      }
    }

    // Bishop pair bonus.
    if (whiteBishops >= 2) whiteScore += 30;
    if (blackBishops >= 2) blackScore += 30;

    final whiteEval = whiteScore - blackScore;
    return whiteToMove ? whiteEval : -whiteEval;
  }

  /// Applies noise/blunders for weaker levels and converts the chosen root
  /// key into a fully populated [EngineResult].
  static EngineResult _buildResult({
    required rules.Chess game,
    required String key,
    required int score,
    required int depth,
    required int nodes,
    required int elapsedMs,
    required bool whiteToMove,
    required Random seed,
    required int noise,
    required double blunderChance,
    required Map<String, int> alternatives,
  }) {
    var chosenKey = key;
    var chosenScore = score;

    final entries = alternatives.entries.toList();
    if (entries.length > 1) {
      // Injected blunder: pick a clearly worse move sometimes.
      if (blunderChance > 0 && seed.nextDouble() < blunderChance) {
        final best = entries.reduce((a, b) => a.value >= b.value ? a : b);
        final worse = entries
            .where((e) => e.key != best.key && e.value < best.value - 40)
            .toList();
        if (worse.isNotEmpty) {
          worse.sort((a, b) => b.value.compareTo(a.value));
          final pick = worse[seed.nextInt(worse.length.clamp(1, 3))];
          chosenKey = pick.key;
          chosenScore = pick.value;
        }
      }

      // Evaluation noise: shuffle near-equal moves so play isn't robotic.
      if (noise > 0) {
        final jittered = <MapEntry<String, int>>[
          for (final e in entries)
            MapEntry(e.key, e.value + seed.nextInt(noise * 2 + 1) - noise),
        ];
        jittered.sort((a, b) => b.value.compareTo(a.value));
        chosenKey = jittered.first.key;
        chosenScore = alternatives[chosenKey] ?? chosenScore;
      }
    }

    final parts = _splitKey(chosenKey);
    final whitePerspective =
        whiteToMove ? chosenScore : -chosenScore;

    // Principal variation: best line at the chosen depth (best-effort —
    // returns the single chosen move plus the opponent's best reply).
    final pv = _principalVariation(game, chosenKey, depth.clamp(1, 3));

    final isMate = chosenScore.abs() >= _mateThreshold;
    return EngineResult(
      from: parts[0],
      to: parts[1],
      promotion: parts.length > 2 ? parts[2] : null,
      scoreCp: chosenScore,
      whiteScoreCp: whitePerspective,
      depth: depth,
      pv: pv,
      nodes: nodes,
      moveTimeMs: elapsedMs,
      bestSan: _sanForKey(game, chosenKey),
      isMate: isMate,
      mateInPly: isMate ? (_mateScore - chosenScore.abs()).clamp(1, 99) : 0,
    );
  }

  /// Walks the principal variation forward from the root position.
  static List<String> _principalVariation(
    rules.Chess game,
    String rootKey,
    int plies,
  ) {
    final pv = <String>[];
    final snapshot = rules.Chess.fromFEN(game.fen);
    var key = rootKey;
    for (var i = 0; i < plies; i++) {
      final parts = _splitKey(key);
      final san = _sanForKey(snapshot, key);
      final legal = snapshot.move({
        'from': parts[0],
        'to': parts[1],
        if (parts.length > 2) 'promotion': parts[2],
      });
      if (!legal) break;
      if (san != null) pv.add(san);

      final replies = _rootMoveKeys(snapshot);
      if (replies.isEmpty) break;
      // Choose the reply our static eval likes best for the side to move.
      var bestKey = replies.first;
      var bestScore = -infinity;
      for (final reply in replies) {
        final p = _splitKey(reply);
        snapshot.move({
          'from': p[0],
          'to': p[1],
          if (p.length > 2) 'promotion': p[2],
        });
        final s = _evaluate(
          snapshot,
          whiteToMove: snapshot.turn == rules.Color.WHITE,
        );
        snapshot.undo_move();
        if (s > bestScore) {
          bestScore = s;
          bestKey = reply;
        }
      }
      key = bestKey;
    }
    return pv;
  }

  static String? _sanForKey(rules.Chess game, String key) {
    final parts = _splitKey(key);
    final verbose = game.moves({
      'square': parts[0],
      'verbose': true,
    });
    for (final m in verbose) {
      final map = m as Map;
      if (map['to'] != parts[1]) continue;
      if (parts.length > 2) {
        final san = (map['san'] as String?) ?? '';
        if (!san.toUpperCase().endsWith('=${parts[2].toUpperCase()}')) {
          continue;
        }
      }
      return map['san'] as String?;
    }
    return null;
  }
}

class _SearchLine {
  _SearchLine({required this.key, required this.score, required this.pv});
  final String key;
  final int score;
  final List<String> pv;
}
