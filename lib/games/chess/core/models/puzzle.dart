/// A chess puzzle: a position where the side to move has a winning tactic.
///
/// The [solution] is the full main line in UCI form (`e2e4`, `e7e8q`), where
/// the first move belongs to the solver. Validation replays the line against
/// the rules engine, so a malformed puzzle is rejected at load time rather
/// than silently shown to the player.
class ChessPuzzle {
  const ChessPuzzle({
    required this.id,
    required this.fen,
    required this.solution,
    required this.rating,
    required this.themes,
    this.mateIn,
    this.opening,
    this.source,
    this.comment,
  });

  final String id;

  /// Position before the solver's first move.
  final String fen;

  /// Main line in UCI notation, starting with the solver's move.
  final List<String> solution;

  /// Puzzle strength (roughly a rating the solver needs to solve reliably).
  final int rating;

  /// Tactical motifs, e.g. `['fork', 'doubleAttack']`.
  final List<String> themes;

  /// Set when the line ends in mate on this solver move index (1-based).
  final int? mateIn;

  final String? opening;
  final String? source;

  /// Short explanation shown after solving.
  final String? comment;

  /// White is to move when the FEN's active-color field is `w`.
  bool get whiteToMove =>
      fen.split(' ').length > 1 && fen.split(' ')[1] == 'w';

  /// 'White' or 'Black' — the side the solver plays.
  String get sideToMoveLabel => whiteToMove ? 'White' : 'Black';

  /// Number of half-moves in the line.
  int get length => solution.length;

  /// Whether [index] is the solver's own move (0, 2, 4, …).
  bool isSolverMove(int index) => index.isEven;

  /// Parses a UCI token into from/to/promotion.
  static (String, String, String?) parseUci(String uci) {
    if (uci.length < 4) return (uci, '', null);
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : null;
    return (from, to, promotion);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fen': fen,
        'solution': solution,
        'rating': rating,
        'themes': themes,
        if (mateIn != null) 'mateIn': mateIn,
        if (opening != null) 'opening': opening,
        if (source != null) 'source': source,
        if (comment != null) 'comment': comment,
      };

  factory ChessPuzzle.fromJson(Map<String, dynamic> json) => ChessPuzzle(
        id: json['id'] as String,
        fen: json['fen'] as String,
        solution: (json['solution'] as List).cast<String>(),
        rating: (json['rating'] as num).toInt(),
        themes: (json['themes'] as List?)?.cast<String>() ?? const [],
        mateIn: (json['mateIn'] as num?)?.toInt(),
        opening: json['opening'] as String?,
        source: json['source'] as String?,
        comment: json['comment'] as String?,
      );

  @override
  String toString() => 'ChessPuzzle($id, ${solution.length} plies)';
}

/// A solver's record on a puzzle (for streaks and history).
class PuzzleAttempt {
  const PuzzleAttempt({
    required this.puzzleId,
    required this.solved,
    required this.attempts,
    required this.timestamp,
    required this.ratingBefore,
    required this.ratingAfter,
  });

  final String puzzleId;
  final bool solved;
  final int attempts;
  final DateTime timestamp;
  final int ratingBefore;
  final int ratingAfter;

  Map<String, dynamic> toJson() => {
        'puzzleId': puzzleId,
        'solved': solved,
        'attempts': attempts,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'ratingBefore': ratingBefore,
        'ratingAfter': ratingAfter,
      };

  factory PuzzleAttempt.fromJson(Map<String, dynamic> json) => PuzzleAttempt(
        puzzleId: json['puzzleId'] as String,
        solved: json['solved'] as bool? ?? false,
        attempts: (json['attempts'] as num?)?.toInt() ?? 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num?)?.toInt() ?? 0,
        ),
        ratingBefore: (json['ratingBefore'] as num?)?.toInt() ?? 0,
        ratingAfter: (json['ratingAfter'] as num?)?.toInt() ?? 0,
      );
}
