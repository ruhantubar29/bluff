import 'package:chess/chess.dart' as rules;

import 'board.dart';
import 'models/game_result.dart';
import 'models/move_record.dart';

/// Why an attempted move did (or did not) play.
enum MoveOutcome {
  /// Move played successfully.
  applied,

  /// Not a legal move for the piece/side.
  illegal,

  /// The move is legal but waiting for an explicit confirmation tap
  /// (when the "confirm moves" setting is on).
  awaitingConfirmation,

  /// Pawn to the last rank: the UI must ask for a promotion piece first.
  promotionRequired,

  /// Side to move is not the one that owns the piece.
  notYourTurn,

  /// The game has already ended.
  gameOver,
}

/// Why the position is (or became) a draw.
enum DrawReason {
  stalemate,
  threefoldRepetition,
  fiftyMoveRule,
  insufficientMaterial,
  drawAgreement,
  abandonment,
}

extension DrawReasonLabel on DrawReason {
  String get label {
    switch (this) {
      case DrawReason.stalemate:
        return 'Stalemate';
      case DrawReason.threefoldRepetition:
        return 'Threefold repetition';
      case DrawReason.fiftyMoveRule:
        return 'Fifty-move rule';
      case DrawReason.insufficientMaterial:
        return 'Insufficient material';
      case DrawReason.drawAgreement:
        return 'Draw by agreement';
      case DrawReason.abandonment:
        return 'Abandonment';
    }
  }
}

/// A legal move available to the side to move, in UI form.
class LegalMove {
  const LegalMove({
    required this.from,
    required this.to,
    required this.isCapture,
    required this.isPromotion,
    required this.isCastle,
    required this.isEnPassant,
    required this.san,
    this.promotion,
  });

  final String from;
  final String to;
  final bool isCapture;
  final bool isPromotion;
  final bool isCastle;
  final bool isEnPassant;

  /// Full SAN including `=Q` / `+` / `#` where applicable.
  final String san;

  /// Promotion piece letter (`q`/`r`/`b`/`n`) for promotion moves.
  final String? promotion;

  @override
  String toString() => san;
}

/// Result of a successful move: record plus resulting game state.
class MoveApplication {
  const MoveApplication({
    required this.record,
    this.result,
    this.drawReason,
    this.gaveCheck = false,
  });

  final MoveRecord record;

  /// Set when the move ended the game.
  final GameResult? result;

  /// Set when the move ended the game by draw.
  final DrawReason? drawReason;

  final bool gaveCheck;

  bool get endedGame => result != null;
}

/// Result of asking the game to play a move.
class MoveAttempt {
  const MoveAttempt.applied(this.application) : outcome = MoveOutcome.applied;

  const MoveAttempt.failed(this.outcome) : application = null;

  final MoveOutcome outcome;
  final MoveApplication? application;

  bool get played => outcome == MoveOutcome.applied;
}

/// Application-level chess game: wraps the rules library and exposes a clean,
/// UI-friendly API. All legality (castling, en passant, promotion, checks,
/// repetition, fifty-move, insufficient material) comes from the
/// battle-tested rules implementation — nothing here fakes legal moves.
class ChessGame {
  ChessGame({String? fen})
      : _rules = rules.Chess.fromFEN(fen ?? startingFen);

  static const String startingFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  final rules.Chess _rules;

  /// Move records played from the initial position of this game.
  final List<MoveRecord> _history = [];

  GameResult? _result;
  DrawReason? _endedDrawReason;

  // --------------------------------------------------------------- state --

  String get fen => _rules.fen;

  bool get whiteToMove => _rules.turn == rules.Color.WHITE;

  bool get inCheck => _rules.in_check;

  GameResult? get result => _result;

  DrawReason? get endedDrawReason => _endedDrawReason;

  bool get isGameOver => _result != null || _rules.game_over;

  List<MoveRecord> get history => List.unmodifiable(_history);

  int get moveCount => _history.length;

  /// Pieces on the board, parsed from FEN (row 0 = rank 8).
  List<BoardPiece> get pieces => piecesFromFen(_rules.fen);

  BoardPiece? pieceAt(String square) {
    if (!Squares.isValid(square)) return null;
    final p = _rules.get(square);
    if (p == null) return null;
    return BoardPiece(
      type: _pieceType(p.type.name),
      isWhite: p.color == rules.Color.WHITE,
      square: square,
    );
  }

  /// Square of the king currently in check, if any (check highlighting).
  String? get checkedKingSquare {
    if (!_rules.in_check) return null;
    final side = whiteToMove;
    for (final p in pieces) {
      if (p.type == PieceType.king && p.isWhite == side) return p.square;
    }
    return null;
  }

  // -------------------------------------------------------- legal moves --

  /// All legal moves for the side to move. Promotion moves appear once per
  /// promotion piece.
  List<LegalMove> get legalMoves {
    final raw = _rules.moves({'verbose': true});
    return [for (final m in raw) _toLegalMove(m as Map)];
  }

  /// Legal moves for a specific square (empty when the square holds no piece
  /// of the side to move).
  List<LegalMove> legalMovesFrom(String square) {
    if (!Squares.isValid(square)) return const [];
    final piece = _rules.get(square);
    if (piece == null || piece.color != _rules.turn) return const [];
    final raw = _rules.moves({'square': square, 'verbose': true});
    return [for (final m in raw) _toLegalMove(m as Map)];
  }

  /// Destination squares only — for board indicators (deduped).
  List<String> legalTargetsFrom(String square) {
    final seen = <String>{};
    for (final m in legalMovesFrom(square)) {
      seen.add(m.to);
    }
    return seen.toList(growable: false);
  }

  // ---------------------------------------------------------- making moves --

  /// Plays a move from [from] to [to].
  ///
  /// A pawn move to the last rank without [promotion] resolves to
  /// [MoveOutcome.promotionRequired] and leaves the game untouched, so the UI
  /// can show a promotion picker first. With [autoQueen] the queen is chosen
  /// automatically.
  MoveAttempt makeMove({
    required String from,
    required String to,
    String? promotion,
    bool autoQueen = false,
  }) {
    if (isGameOver) return const MoveAttempt.failed(MoveOutcome.gameOver);

    if (!Squares.isValid(from) || !Squares.isValid(to)) {
      return const MoveAttempt.failed(MoveOutcome.illegal);
    }

    final mover = _rules.get(from);
    if (mover == null) return const MoveAttempt.failed(MoveOutcome.illegal);
    if (mover.color != _rules.turn) {
      return const MoveAttempt.failed(MoveOutcome.notYourTurn);
    }

    final candidates = legalMovesFrom(from).where((m) => m.to == to).toList();
    if (candidates.isEmpty) return const MoveAttempt.failed(MoveOutcome.illegal);

    final isPromotion = candidates.first.isPromotion;
    String? effectivePromotion;
    if (isPromotion) {
      if (promotion == null && !autoQueen) {
        return const MoveAttempt.failed(MoveOutcome.promotionRequired);
      }
      effectivePromotion = promotion ?? 'q';
    }

    LegalMove chosen = candidates.first;
    if (isPromotion) {
      for (final c in candidates) {
        if (c.promotion == effectivePromotion) {
          chosen = c;
          break;
        }
      }
    }

    final moverWasWhite = whiteToMove;
    final capturedLetter = _capturedLetter(from, to, chosen);

    final applied = _rules.move({
      'from': from,
      'to': to,
      'promotion': ?effectivePromotion,
    });
    if (!applied) return const MoveAttempt.failed(MoveOutcome.illegal);

    final gaveCheck = _rules.in_check;
    _resolveEndState();

    final record = MoveRecord(
      san: chosen.san,
      from: from,
      to: to,
      fenAfter: _rules.fen,
      colorWasWhite: moverWasWhite,
      promotion: effectivePromotion,
      capturedPiece: capturedLetter,
      isCapture: chosen.isCapture,
      isCastle: chosen.isCastle,
      isEnPassant: chosen.isEnPassant,
      isCheck: gaveCheck && _result?.reason != GameEndReason.checkmate,
      isCheckmate: _result?.reason == GameEndReason.checkmate,
      sanBeforeSuffix: chosen.san.replaceAll(RegExp(r'[+#]$'), ''),
    );
    _history.add(record);

    return MoveAttempt.applied(
      MoveApplication(
        record: record,
        result: _result,
        drawReason: _endedDrawReason,
        gaveCheck: gaveCheck,
      ),
    );
  }

  /// Whether [from]→[to] is a pawn move that must pick a promotion piece.
  bool needsPromotion(String from, String to) =>
      legalMovesFrom(from).any((m) => m.to == to && m.isPromotion);

  /// Whether [from]→[to] is legal right now (drag-and-drop validation).
  bool isLegal(String from, String to) =>
      legalMovesFrom(from).any((m) => m.to == to);

  // ------------------------------------------------------ game resolution --

  /// Evaluates the current position and sets [result] when the game is over.
  GameResult? _resolveEndState() {
    if (_rules.in_checkmate) {
      _result = GameResult(
        reason: GameEndReason.checkmate,
        winnerIsWhite: !whiteToMove,
      );
      return _result;
    }
    if (_rules.in_stalemate) {
      _endedDrawReason = DrawReason.stalemate;
      _result = const GameResult(
        reason: GameEndReason.stalemate,
        winnerIsWhite: null,
      );
      return _result;
    }
    if (_rules.insufficient_material) {
      _endedDrawReason = DrawReason.insufficientMaterial;
      _result = const GameResult(
        reason: GameEndReason.insufficientMaterial,
        winnerIsWhite: null,
      );
      return _result;
    }
    if (_rules.half_moves >= 100) {
      _endedDrawReason = DrawReason.fiftyMoveRule;
      _result = const GameResult(
        reason: GameEndReason.fiftyMoveRule,
        winnerIsWhite: null,
      );
      return _result;
    }
    if (_rules.in_threefold_repetition) {
      _endedDrawReason = DrawReason.threefoldRepetition;
      _result = const GameResult(
        reason: GameEndReason.threefoldRepetition,
        winnerIsWhite: null,
      );
      return _result;
    }
    return null;
  }

  /// Ends the game externally: resignation, timeout, agreement, abandonment.
  GameResult? endGame(GameResult result) {
    _result = result;
    return result;
  }

  /// Draw that can be claimed in the current position, if any.
  DrawReason? get claimableDrawReason {
    // A recorded result already ends the game; otherwise a restored position
    // that the rules consider finished can still surface its claimable draw.
    if (_result != null) return null;
    if (_rules.in_stalemate) return DrawReason.stalemate;
    if (_rules.insufficient_material) return DrawReason.insufficientMaterial;
    if (_rules.half_moves >= 100) return DrawReason.fiftyMoveRule;
    if (_rules.in_threefold_repetition) return DrawReason.threefoldRepetition;
    return null;
  }

  /// Re-checks the position for an automatic result (after restoring a game).
  GameResult? refreshResult() => _resolveEndState();

  // -------------------------------------------------------------- takeback --

  /// Undoes the last half-move and returns it, or null when there is none.
  MoveRecord? undoLastMove() {
    if (_history.isEmpty) return null;
    final undone = _rules.undo();
    if (undone == null) return null;
    _result = null;
    _endedDrawReason = null;
    return _history.removeLast();
  }

  /// Undoes up to [count] half-moves; returns how many were undone.
  int undoMoves(int count) {
    var undone = 0;
    while (undone < count && _history.isNotEmpty) {
      if (undoLastMove() == null) break;
      undone++;
    }
    return undone;
  }

  // ------------------------------------------------------------ notation --

  /// SAN for a move without playing it, or null when illegal.
  String? sanFor(String from, String to, {String? promotion}) {
    for (final m in legalMovesFrom(from)) {
      if (m.to != to) continue;
      if (m.isPromotion && promotion != null && m.promotion != promotion) {
        continue;
      }
      if (m.isPromotion && promotion == null) continue;
      return m.san;
    }
    // Fall back to the first match for promotions when no piece requested.
    for (final m in legalMovesFrom(from)) {
      if (m.to == to) return m.san;
    }
    return null;
  }

  List<String> get sanMoves =>
      _history.map((m) => m.san).toList(growable: false);

  /// PGN for this game: headers plus the move text.
  String pgn({
    String? white,
    String? black,
    String? event,
    String? date,
    String? whiteElo,
    String? blackElo,
    String? timeControl,
    String? resultToken,
  }) {
    final result = resultToken ?? _result?.pgnToken ?? '*';
    final headers = <String, String>{
      'Event': event ?? 'Casual Game',
      'White': ?white,
      'Black': ?black,
      'WhiteElo': ?whiteElo,
      'BlackElo': ?blackElo,
      'TimeControl': ?timeControl,
      'Date': ?date,
      'Result': result,
    };
    final buf = StringBuffer();
    headers.forEach((k, v) => buf.writeln('[$k "$v"]'));
    buf.writeln();

    final tokens = <String>[];
    for (var i = 0; i < _history.length; i++) {
      if (i.isEven) tokens.add('${i ~/ 2 + 1}.');
      tokens.add(_history[i].san);
    }
    tokens.add(result);

    var line = StringBuffer();
    for (final t in tokens) {
      if (line.length + t.length + 1 > 78) {
        buf.writeln(line.toString().trimRight());
        line = StringBuffer();
      }
      line.write('$t ');
    }
    if (line.isNotEmpty) buf.writeln(line.toString().trimRight());
    return buf.toString();
  }

  // -------------------------------------------------------------- helpers --

  /// Rebuilds a game from a start FEN plus recorded moves (game restore).
  ///
  /// Returns null when any recorded move fails to replay (corrupt data).
  static ChessGame? restore({
    required String startFen,
    required List<MoveRecord> records,
  }) {
    final game = ChessGame(fen: startFen);
    for (final r in records) {
      final attempt = game.makeMove(
        from: r.from,
        to: r.to,
        promotion: r.promotion,
      );
      if (!attempt.played) return null;
    }
    return game;
  }

  MoveAttempt applyRecord(MoveRecord record) => makeMove(
        from: record.from,
        to: record.to,
        promotion: record.promotion,
      );

  String? _capturedLetter(String from, String to, LegalMove move) {
    if (move.isEnPassant) return 'p';
    return _rules.get(to)?.type.name;
  }

  /// Converts a verbose rules move into a [LegalMove]. Promotion piece is
  /// parsed from the `=X` SAN suffix since the library omits it from verbose
  /// output.
  LegalMove _toLegalMove(Map m) {
    final flags = (m['flags'] as String?) ?? '';
    final san = (m['san'] as String?) ?? '';
    String? promotion;
    if (flags.contains('p')) {
      final eq = san.indexOf('=');
      if (eq >= 0 && eq + 1 < san.length) {
        promotion = san[eq + 1].toLowerCase();
      }
    }
    return LegalMove(
      from: m['from'] as String,
      to: m['to'] as String,
      isCapture: flags.contains('c') || flags.contains('e'),
      isPromotion: flags.contains('p'),
      isCastle: flags.contains('k') || flags.contains('q'),
      isEnPassant: flags.contains('e'),
      san: san,
      promotion: promotion,
    );
  }

  PieceType _pieceType(String name) {
    switch (name) {
      case 'p':
        return PieceType.pawn;
      case 'n':
        return PieceType.knight;
      case 'b':
        return PieceType.bishop;
      case 'r':
        return PieceType.rook;
      case 'q':
        return PieceType.queen;
      default:
        return PieceType.king;
    }
  }
}
