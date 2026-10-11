import '../chess_game.dart';
import 'game_result.dart';
import 'move_record.dart';
import 'time_control.dart';

/// Where a game was played.
enum GameSource {
  /// Against the built-in engine.
  computer,

  /// Two humans sharing one device.
  passAndPlay,

  /// Over the network against another real player.
  online,
}

extension GameSourceLabel on GameSource {
  String get label {
    switch (this) {
      case GameSource.computer:
        return 'vs Computer';
      case GameSource.passAndPlay:
        return 'Pass & Play';
      case GameSource.online:
        return 'Online';
    }
  }
}

/// A finished game, stored for history, review and analysis.
class ChessGameRecord {
  const ChessGameRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.startFen,
    required this.moves,
    required this.result,
    required this.timeControlLabel,
    required this.timeCategory,
    required this.source,
    required this.whiteName,
    required this.blackName,
    required this.whiteRatingBefore,
    required this.blackRatingBefore,
    this.rated = false,
    this.whiteRatingAfter,
    this.blackRatingAfter,
    this.whiteId,
    this.blackId,
    this.computerLevel,
    this.openingName,
    this.openingEco,
    this.pgn,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String startFen;
  final List<MoveRecord> moves;
  final GameResult result;

  /// e.g. "3 + 2" — matches [TimeControl.presets] labels for filters.
  final String timeControlLabel;
  final TimeCategory timeCategory;
  final GameSource source;

  final String whiteName;
  final String blackName;
  final int whiteRatingBefore;
  final int blackRatingBefore;
  final bool rated;
  final int? whiteRatingAfter;
  final int? blackRatingAfter;
  final String? whiteId;
  final String? blackId;

  /// Engine difficulty when [source] is [GameSource.computer] — stored as the
  /// enum name.
  final String? computerLevel;
  final String? openingName;
  final String? openingEco;

  /// PGN snapshot; generated on demand when null.
  final String? pgn;

  int get whiteRatingDelta => (whiteRatingAfter ?? whiteRatingBefore) - whiteRatingBefore;
  int get blackRatingDelta => (blackRatingAfter ?? blackRatingBefore) - blackRatingBefore;

  /// Half-moves played.
  int get ply => moves.length;

  /// Full moves (pair of plies).
  int get fullMoves => (ply + 1) ~/ 2;

  /// Score from [isWhite]'s point of view (1 / 0.5 / 0).
  double scoreFor(bool isWhite) => result.whiteScore == 0.5
      ? 0.5
      : ((result.whiteScore == 1.0) == isWhite ? 1.0 : 0.0);

  /// Rebuilds the live game so the review/analysis board can step through it.
  ChessGame? restoreGame() => ChessGame.restore(startFen: startFen, records: moves);

  String pgnOrGenerate() {
    final existing = pgn;
    if (existing != null && existing.isNotEmpty) return existing;
    final game = restoreGame();
    if (game == null) return '';
    return game.pgn(
      white: whiteName,
      black: blackName,
      whiteElo: '$whiteRatingBefore',
      blackElo: '$blackRatingBefore',
      date: '${startedAt.year}.${startedAt.month.toString().padLeft(2, '0')}.'
          '${startedAt.day.toString().padLeft(2, '0')}',
      timeControl: timeControlLabel.replaceAll(' + ', ':'),
      resultToken: result.pgnToken,
    );
  }

  String get resultToken => result.pgnToken;

  /// Compact summary used in the history list.
  String get matchupLabel => '$whiteName vs $blackName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'startFen': startFen,
        'moves': [for (final m in moves) _moveToJson(m)],
        'result': {
          'reason': result.reason.name,
          'winnerIsWhite': result.winnerIsWhite,
        },
        'timeControlLabel': timeControlLabel,
        'timeCategory': timeCategory.name,
        'source': source.name,
        'whiteName': whiteName,
        'blackName': blackName,
        'whiteRatingBefore': whiteRatingBefore,
        'blackRatingBefore': blackRatingBefore,
        'rated': rated,
        'whiteRatingAfter': whiteRatingAfter,
        'blackRatingAfter': blackRatingAfter,
        'whiteId': whiteId,
        'blackId': blackId,
        'computerLevel': computerLevel,
        'openingName': openingName,
        'openingEco': openingEco,
        'pgn': pgn,
      };

  factory ChessGameRecord.fromJson(Map<String, dynamic> json) => ChessGameRecord(
        id: json['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['startedAt'] as num).toInt(),
        ),
        endedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['endedAt'] as num).toInt(),
        ),
        startFen: json['startFen'] as String,
        moves: [
          for (final m in (json['moves'] as List))
            _moveFromJson(m as Map<String, dynamic>),
        ],
        result: GameResult(
          reason: GameEndReason.values.firstWhere(
            (r) => r.name == (json['result'] as Map)['reason'],
            orElse: () => GameEndReason.resignation,
          ),
          winnerIsWhite: (json['result'] as Map)['winnerIsWhite'] as bool?,
        ),
        timeControlLabel: json['timeControlLabel'] as String? ?? 'Unlimited',
        timeCategory: TimeCategory.values.firstWhere(
          (c) => c.name == json['timeCategory'],
          orElse: () => TimeCategory.rapid,
        ),
        source: GameSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => GameSource.passAndPlay,
        ),
        whiteName: json['whiteName'] as String? ?? 'White',
        blackName: json['blackName'] as String? ?? 'Black',
        whiteRatingBefore: (json['whiteRatingBefore'] as num?)?.toInt() ?? 1200,
        blackRatingBefore: (json['blackRatingBefore'] as num?)?.toInt() ?? 1200,
        rated: json['rated'] as bool? ?? false,
        whiteRatingAfter: (json['whiteRatingAfter'] as num?)?.toInt(),
        blackRatingAfter: (json['blackRatingAfter'] as num?)?.toInt(),
        whiteId: json['whiteId'] as String?,
        blackId: json['blackId'] as String?,
        computerLevel: json['computerLevel'] as String?,
        openingName: json['openingName'] as String?,
        openingEco: json['openingEco'] as String?,
        pgn: json['pgn'] as String?,
      );

  static Map<String, dynamic> _moveToJson(MoveRecord m) => {
        'san': m.san,
        'from': m.from,
        'to': m.to,
        'fenAfter': m.fenAfter,
        'colorWasWhite': m.colorWasWhite,
        'promotion': m.promotion,
        'capturedPiece': m.capturedPiece,
        'isCapture': m.isCapture,
        'isCastle': m.isCastle,
        'isEnPassant': m.isEnPassant,
        'isCheck': m.isCheck,
        'isCheckmate': m.isCheckmate,
        'whiteMsLeft': m.whiteMsLeft,
        'blackMsLeft': m.blackMsLeft,
      };

  static MoveRecord _moveFromJson(Map<String, dynamic> m) => MoveRecord(
        san: m['san'] as String,
        from: m['from'] as String,
        to: m['to'] as String,
        fenAfter: m['fenAfter'] as String,
        colorWasWhite: m['colorWasWhite'] as bool? ?? true,
        promotion: m['promotion'] as String?,
        capturedPiece: m['capturedPiece'] as String?,
        isCapture: m['isCapture'] as bool? ?? false,
        isCastle: m['isCastle'] as bool? ?? false,
        isEnPassant: m['isEnPassant'] as bool? ?? false,
        isCheck: m['isCheck'] as bool? ?? false,
        isCheckmate: m['isCheckmate'] as bool? ?? false,
        whiteMsLeft: (m['whiteMsLeft'] as num?)?.toInt(),
        blackMsLeft: (m['blackMsLeft'] as num?)?.toInt(),
      );
}
