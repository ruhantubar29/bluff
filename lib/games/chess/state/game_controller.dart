import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/chess_game.dart';
import '../core/engine/chess_engine.dart';
import '../core/game_clock.dart';
import '../core/models/game_record.dart';
import '../core/models/game_result.dart';
import '../core/models/move_record.dart';
import '../core/models/time_control.dart';
import '../core/openings/opening_book.dart';
import '../services/engine_runner.dart';
import '../services/settings_service.dart';
import '../services/stockfish_runner.dart';

/// Which environment a live game is running in.
enum ChessGameMode {
  /// Human vs engine (singleplayer screen).
  computer,

  /// Two humans sharing one device (pass & play screen).
  passAndPlay,

  /// Human vs human over a connection (multiplayer screen).
  online,
}

/// Sound cues the game emits; implemented by the audio service, stubbed in
/// tests so gameplay logic never depends on a plugin.
abstract class ChessSound {
  void move({required bool capture, required bool castle, required bool promotion});
  void check();
  void gameEnd({required bool isDraw, required bool localWon});
  void illegal();
  void lowTime();
  void start();
}

/// No-op implementation used by tests and headless playback.
class SilentChessSound implements ChessSound {
  const SilentChessSound();
  @override
  void move({required bool capture, required bool castle, required bool promotion}) {}
  @override
  void check() {}
  @override
  void gameEnd({required bool isDraw, required bool localWon}) {}
  @override
  void illegal() {}
  @override
  void lowTime() {}
  @override
  void start() {}
}

/// Result metadata produced when a game finishes.
class GameFinishedEvent {
  const GameFinishedEvent({
    required this.result,
    required this.whiteMsLeft,
    required this.blackMsLeft,
    this.ratedChangeApplied = false,
  });

  final GameResult result;
  final int? whiteMsLeft;
  final int? blackMsLeft;
  final bool ratedChangeApplied;
}

/// Orchestrates a single live game: rules, clock, engine replies, draw
/// offers, takebacks and end-of-game bookkeeping.
///
/// The controller is the only place allowed to mutate the game, so every
/// path into the rules (touch, drag, engine reply, remote move) behaves the
/// same way.
class GameController extends ChangeNotifier {
  GameController({
    required this.mode,
    ChessGame? game,
    TimeControl? timeControl,
    this.whiteName = 'White',
    this.blackName = 'Black',
    this.whiteId,
    this.blackId,
    this.computerLevel,
    this.computerIsWhite = false,
    this.onlineIsWhite = true,
    this.computerElo,
    this.useStockfish = false,
    this.rated = false,
    this.whiteRatingBefore = 1200,
    this.blackRatingBefore = 1200,
    this.sound = const SilentChessSound(),
    ChessSettings? settings,
    EngineRunner? engine,
  })  : game = game ?? ChessGame(),
        _engine = engine ?? EngineRunner.instance,
        _settings = settings ?? ChessSettingsService.instance.settings {
    timeControl ??= TimeControl.byLabel(_settings.defaultTimeControlLabel) ??
        TimeControl.presets[7];
    this.timeControl = timeControl;
    if (timeControl.hasClock) {
      clock = GameClock(timeControl: timeControl);
    }
  }

  final ChessGameMode mode;

  /// Replaced wholesale on a server resync (online path).
  ChessGame game;
  final ChessSound sound;
  final EngineRunner _engine;
  final ChessSettings _settings;

  late final TimeControl timeControl;
  GameClock? clock;

  final String whiteName;
  final String blackName;
  final String? whiteId;
  final String? blackId;

  /// Engine difficulty (only for [ChessGameMode.computer]).
  final EngineLevel? computerLevel;
  final bool computerIsWhite;

  /// For [ChessGameMode.online]: the side this device plays, assigned by
  /// the server when the match was made.
  final bool onlineIsWhite;

  /// Custom opponent strength from the Elo slider (250–3200). When set it
  /// wins over [computerLevel]'s preset strength but the level still drives
  /// names/ratings.
  final int? computerElo;

  /// Ask native Stockfish first (falls back to the built-in engine when the
  /// platform doesn't ship it).
  final bool useStockfish;
  final bool rated;
  final int whiteRatingBefore;
  final int blackRatingBefore;

  // ------------------------------------------------------------- UI state --

  String? _selectedSquare;
  List<String> _legalTargets = const [];
  String? _lastMoveFrom;
  String? _lastMoveTo;
  bool _flipped = false;
  bool _thinking = false;
  bool _finished = false;
  bool _started = false;

  /// Bumped whenever the position changes out from under an in-flight engine
  /// search (takeback, finish) so stale replies are dropped.
  int _generation = 0;

  /// Set once [dispose] runs; async continuations must not touch the state.
  bool _disposed = false;

  /// Pending promotion request (from, to) awaiting a piece choice.
  (String, String)? _pendingPromotion;

  /// Move waiting for a "confirm" tap when the confirm-moves setting is on.
  (String, String)? _pendingConfirmation;

  GameResult? _result;
  DrawReason? _drawReason;

  // Draw offer / takeback negotiation.
  bool _drawOfferedByWhite = false;
  bool _drawOfferedByBlack = false;
  bool _takebackRequested = false;
  String? _statusMessage;

  DateTime startedAt = DateTime.now();
  DateTime? endedAt;

  Timer? _ticker;
  final ValueNotifier<Duration> whiteClock = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> blackClock = ValueNotifier(Duration.zero);

  // Callbacks the shell wires up (saving, ratings, navigation).
  void Function(GameFinishedEvent event)? onFinished;

  /// Relay for online play: fired after every move the local player makes
  /// so the shell can send it to the server. Never fires for moves that
  /// arrived *from* the server.
  void Function(MoveRecord move)? onLocalMove;

  // ----------------------------------------------------------- derived state --

  bool get isWhiteTurn => game.whiteToMove;

  /// Which side the human at this device is playing (drives sounds, the
  /// resign/draw sides and the rating perspective).
  bool get localIsWhite => mode == ChessGameMode.computer
      ? !computerIsWhite
      : mode == ChessGameMode.online
          ? onlineIsWhite
          : true;

  bool get hasClock => clock != null;

  bool get finished => _finished;

  GameResult? get result => _result;

  DrawReason? get drawReason => _drawReason;

  bool get thinking => _thinking;

  bool get started => _started;

  String? get selectedSquare => _selectedSquare;

  List<String> get legalTargets => _legalTargets;

  String? get lastMoveFrom => _lastMoveFrom;

  String? get lastMoveTo => _lastMoveTo;

  (String, String)? get pendingPromotion => _pendingPromotion;

  (String, String)? get pendingConfirmation => _pendingConfirmation;

  GameResult? get pendingResult => _result;

  String? get statusMessage => _statusMessage;

  bool get canClaimDraw => game.claimableDrawReason != null && !_finished;

  DrawReason? get claimableDraw => game.claimableDrawReason;

  bool get drawOfferActive =>
      _drawOfferedByWhite || _drawOfferedByBlack;

  bool get takebackPending => _takebackRequested;

  /// Whether the human at the screen may move right now.
  bool get canInteract {
    if (_finished || _thinking || _pendingPromotion != null) return false;
    if (mode == ChessGameMode.computer) {
      return game.whiteToMove != computerIsWhite;
    }
    if (mode == ChessGameMode.online) {
      // You may only move your own side; the server enforces this too.
      return game.whiteToMove == onlineIsWhite;
    }
    return true;
  }

  /// Board orientation: flipped when the human plays Black.
  bool get flipped => _flipped;
  set flipped(bool value) {
    if (_flipped == value) return;
    _flipped = value;
    notifyListeners();
  }

  /// Square of the king currently in check.
  String? get checkedKingSquare =>
      _settings.showCheckHighlight ? game.checkedKingSquare : null;

  List<MoveRecord> get moves => game.history;

  MoveRecord? get lastMove => game.history.isEmpty ? null : game.history.last;

  /// Active opening name from the ECO book (null before/after theory).
  OpeningMatch? get opening => OpeningBook.identify(game.sanMoves);

  /// Pieces captured BY white / BY black, for the captured-material trays.
  ({List<String> byWhite, List<String> byBlack}) get captured {
    final byWhite = <String>[];
    final byBlack = <String>[];
    for (final m in game.history) {
      final captured = m.capturedPiece;
      if (captured == null) continue;
      if (m.colorWasWhite) {
        byWhite.add(captured);
      } else {
        byBlack.add(captured);
      }
    }
    return (byWhite: byWhite, byBlack: byBlack);
  }

  /// Material advantage in pawns (positive = White ahead), for the tray.
  double materialBalance() {
    const values = {
      'p': 1.0,
      'n': 3.0,
      'b': 3.0,
      'r': 5.0,
      'q': 9.0,
    };
    final c = captured;
    double sum(Iterable<String> pieces) =>
        pieces.fold(0, (acc, p) => acc + (values[p] ?? 0));
    return sum(c.byWhite) - sum(c.byBlack);
  }

  /// The side whose clock is ticking (null without a clock).
  ClockSide? get clockSide =>
      clock == null || !clock!.isRunning ? null : clock!.activeSide;

  // ------------------------------------------------------------- interaction --

  /// Handles a tap on [square]: select / move / clear.
  void tapSquare(String square) {
    if (!canInteract) return;

    // A pending confirmation swallows the next tap unless it's the same move.
    if (_pendingConfirmation != null) {
      final (from, to) = _pendingConfirmation!;
      if (square == to) {
        _confirmPending();
        return;
      }
      if (square == from) {
        _pendingConfirmation = null;
        notifyListeners();
        return;
      }
      // Tapping another own piece re-targets instead of dead-ending.
      _pendingConfirmation = null;
    }

    if (_selectedSquare != null && _legalTargets.contains(square)) {
      playMove(from: _selectedSquare!, to: square);
      return;
    }

    final piece = game.pieceAt(square);
    if (piece != null && piece.isWhite == game.whiteToMove) {
      _select(square);
      return;
    }

    _clearSelection();
  }

  void _select(String square) {
    _selectedSquare = square;
    _legalTargets = game.legalTargetsFrom(square);
    notifyListeners();
  }

  void _clearSelection() {
    if (_selectedSquare == null && _legalTargets.isEmpty) return;
    _selectedSquare = null;
    _legalTargets = const [];
    notifyListeners();
  }

  void clearSelection() => _clearSelection();

  /// Attempts the move [from] → [to]. Returns how it resolved.
  MoveAttempt playMove({required String from, required String to}) {
    if (_finished) return MoveAttempt.failed(MoveOutcome.gameOver);

    // Promotion needs a piece choice unless the setting auto-queens.
    if (!_settings.autoQueen && game.needsPromotion(from, to)) {
      _pendingPromotion = (from, to);
      _selectedSquare = null;
      _legalTargets = const [];
      notifyListeners();
      return MoveAttempt.failed(MoveOutcome.promotionRequired);
    }

    if (_settings.confirmMoves && mode != ChessGameMode.online) {
      if (game.isLegal(from, to)) {
        _pendingConfirmation = (from, to);
        _selectedSquare = null;
        _legalTargets = const [];
        notifyListeners();
        return const MoveAttempt.failed(MoveOutcome.awaitingConfirmation);
      }
    }

    return _applyMove(from: from, to: to, promotion: null);
  }

  /// Completes a pending promotion with [piece] ('q'/'r'/'b'/'n').
  void completePromotion(String piece) {
    final pending = _pendingPromotion;
    if (pending == null) return;
    _pendingPromotion = null;
    final (from, to) = pending;
    _applyMove(from: from, to: to, promotion: piece);
  }

  void cancelPromotion() {
    _pendingPromotion = null;
    notifyListeners();
  }

  void _confirmPending() {
    final pending = _pendingConfirmation;
    _pendingConfirmation = null;
    if (pending == null) return;
    final (from, to) = pending;
    _applyMove(from: from, to: to, promotion: null);
  }

  void cancelPendingConfirmation() {
    if (_pendingConfirmation == null) return;
    _pendingConfirmation = null;
    notifyListeners();
  }

  MoveAttempt _applyMove({
    required String from,
    required String to,
    String? promotion,
    bool remote = false,
  }) {
    final attempt = game.makeMove(
      from: from,
      to: to,
      promotion: promotion,
      autoQueen: promotion == null && _settings.autoQueen,
    );

    if (!attempt.played) {
      if (attempt.outcome != MoveOutcome.promotionRequired) {
        sound.illegal();
        _clearSelection();
      }
      return attempt;
    }

    final applied = attempt.application!;
    final record = applied.record;

    _started = true;
    _selectedSquare = null;
    _legalTargets = const [];
    _pendingConfirmation = null;
    _takebackRequested = false;
    _lastMoveFrom = record.from;
    _lastMoveTo = record.to;

    // Relay local moves to the server in online games (never echoes —
    // moves that came *from* the server pass `remote: true`).
    if (!remote && mode == ChessGameMode.online) {
      onLocalMove?.call(record);
    }

    // Clock: increment for the mover, hand over to the opponent.
    final c = clock;
    if (c != null) {
      c.movePlayed(record.colorWasWhite ? ClockSide.white : ClockSide.black);
      _syncClocks();
      final flagged = c.checkTimeout();
      if (flagged != null) {
        _finishByTimeout(flagged);
        return attempt;
      }
    }

    // Sounds.
    sound.move(
      capture: record.isCapture,
      castle: record.isCastle,
      promotion: record.promotion != null,
    );
    if (record.isCheck) sound.check();
    // Automatic results (mate/stalemate/draw rules).
    if (applied.result != null) {
      _finish(applied.result!, drawReason: applied.drawReason);
      return attempt;
    }

    _clearDrawOffers();
    _startTickerIfNeeded();
    notifyListeners();

    _maybeEngineReply();
    return attempt;
  }

  // ---------------------------------------------------------- engine reply --

  Future<void> _maybeEngineReply() async {
    if (_finished || mode != ChessGameMode.computer) return;
    final level = computerLevel;
    final elo = computerElo ?? level?.rating;
    if (level == null && elo == null) return;
    if (game.whiteToMove != computerIsWhite) return; // not the engine's turn
    final gen = _generation;

    _thinking = true;
    notifyListeners();

    try {
      var result = EngineResult.empty;

      // Native Stockfish first when requested. A null answer means this
      // platform doesn't ship the binary — fall through to the built-in
      // engine instead of freezing the game.
      if (useStockfish && elo != null) {
        result = await StockfishRunner.instance.search(
              game.fen,
              elo: elo,
              timeMs: _stockfishMoveMs(elo),
            ) ??
            EngineResult.empty;
      }

      if (!result.hasMove) {
        final custom = computerElo;
        result = custom != null
            ? await _engine.searchAtElo(game.fen, custom)
            : await _engine.searchAtLevel(
                game.fen,
                level ?? EngineLevel.medium,
              );
      }

      if (gen != _generation) return; // position changed (takeback)
      if (_finished || !result.hasMove) {
        // No legal reply: if we're here the position already ended, but be
        // defensive and re-check for mate/stalemate.
        final ended = game.refreshResult();
        if (ended != null) _finish(ended);
        return;
      }
      _applyMove(
        from: result.from!,
        to: result.to!,
        promotion: result.promotion,
      );
    } finally {
      if (gen == _generation) {
        _thinking = false;
        if (!_finished) notifyListeners();
      }
    }
  }

  /// Thinking budget for Stockfish: stronger opponents get more time.
  static int _stockfishMoveMs(int elo) =>
      elo >= 2600 ? 1500 : elo >= 1900 ? 900 : 500;

  /// Forces an immediate engine move (used by tests and "hint").
  Future<void> playEngineMoveNow() => _maybeEngineReply();

  // ------------------------------------------------------------- takeback --

  /// Undoes the last move(s) according to mode.
  ///
  /// * pass & play: undo one ply.
  /// * computer: undo the engine's reply plus the human's move so it is the
  ///   human's turn again.
  /// * online: only *requests* a takeback — the peer decides.
  /// Returns how many half-moves were undone.
  int requestTakeback() {
    if (_finished || game.moveCount == 0) return 0;
    if (!_settings.allowTakebacks) return 0;

    if (mode == ChessGameMode.online) {
      _takebackRequested = true;
      _statusMessage = 'Takeback requested';
      notifyListeners();
      return 0; // remote side must approve
    }

    var undone = 0;
    if (mode == ChessGameMode.computer) {
      // Remove the engine's reply (if it has moved) and then the human's move
      // so the human is back at the position where they can choose again.
      final humanIsWhite = !computerIsWhite;
      if (game.moveCount > 0 && game.whiteToMove == humanIsWhite) {
        if (game.undoLastMove() != null) undone++;
      }
      if (game.moveCount > 0 && game.whiteToMove != humanIsWhite) {
        if (game.undoLastMove() != null) undone++;
      }
      _thinking = false;
    } else {
      if (game.undoLastMove() != null) undone = 1;
    }

    if (undone > 0) {
      // Invalidate any engine reply still in flight for the old position.
      _generation++;
      final c = clock;
      if (c != null && !c.isExpired) {
        c.reset();
        _syncClocks();
        _startTickerIfNeeded();
      }
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _pendingConfirmation = null;
      _clearDrawOffers();
      _statusMessage = 'Takeback';
      notifyListeners();
      _maybeEngineReply();
    }
    return undone;
  }

  /// Approves a takeback the peer requested (online side).
  void approveTakeback() {
    _takebackRequested = false;
    _statusMessage = null;
    requestTakeback();
  }

  void declineTakeback() {
    _takebackRequested = false;
    _statusMessage = 'Takeback declined';
    notifyListeners();
  }

  // ------------------------------------------------------------ draw offers --

  /// Offers a draw to the opponent.
  ///
  /// * pass & play: the other player answers with a dialog.
  /// * computer: the engine accepts when it is clearly worse (its honest
  ///   evaluation), otherwise declines.
  /// * online: the offer goes to the peer through the connection layer.
  Future<bool> offerDraw({required bool byWhite}) async {
    if (_finished) return false;
    if (byWhite) {
      _drawOfferedByWhite = true;
    } else {
      _drawOfferedByBlack = true;
    }
    notifyListeners();

    if (mode == ChessGameMode.computer) {
      final accept = await _engineDrawDecision();
      if (_disposed) return false;
      if (accept) {
        _finish(const GameResult(
          reason: GameEndReason.drawAgreement,
          winnerIsWhite: null,
        ));
      } else {
        _drawOfferedByWhite = false;
        _drawOfferedByBlack = false;
        _statusMessage = 'Draw offer declined';
        notifyListeners();
      }
      return accept;
    }

    if (mode == ChessGameMode.passAndPlay) {
      // The other player answers via respondToDrawOffer().
      return false;
    }

    // Online: waiting on the peer.
    return false;
  }

  /// Answers a pending draw offer (pass & play and online paths).
  void respondToDrawOffer({required bool accepted}) {
    if (_finished) return;
    final active = _drawOfferedByWhite || _drawOfferedByBlack;
    if (!active) return;
    if (accepted) {
      _finish(const GameResult(
        reason: GameEndReason.drawAgreement,
        winnerIsWhite: null,
      ));
    } else {
      _drawOfferedByWhite = false;
      _drawOfferedByBlack = false;
      _statusMessage = 'Draw offer declined';
      notifyListeners();
    }
  }

  /// True when the opponent owes an answer to a draw offer.
  bool get awaitingDrawResponse {
    if (!drawOfferActive || _finished) return false;
    if (mode == ChessGameMode.passAndPlay) {
      // The side to move answers their own offer only if they didn't make it.
      return true;
    }
    return false;
  }

  Future<bool> _engineDrawDecision() async {
    // The engine accepts a draw when it is at least 3 pawns worse — a
    // standard practical heuristic, computed from its own point of view.
    try {
      final eval = await _engine.analyze(game.fen, maxDepth: 5, timeMs: 600);
      final engineIsWhite = computerIsWhite;
      final engineScore = engineIsWhite ? eval.whiteScoreCp : -eval.whiteScoreCp;
      return engineScore <= -300;
    } catch (_) {
      return false;
    }
  }

  void _clearDrawOffers() {
    if (!_drawOfferedByWhite && !_drawOfferedByBlack) return;
    _drawOfferedByWhite = false;
    _drawOfferedByBlack = false;
  }

  // -------------------------------------------------------------- outcomes --

  /// Claims a draw that the rules allow (repetition / fifty-move / material).
  bool claimDraw() {
    if (_finished) return false;
    final reason = game.claimableDrawReason;
    if (reason == null) return false;
    _finish(GameResult(
      reason: switch (reason) {
        DrawReason.stalemate => GameEndReason.stalemate,
        DrawReason.threefoldRepetition => GameEndReason.threefoldRepetition,
        DrawReason.fiftyMoveRule => GameEndReason.fiftyMoveRule,
        DrawReason.insufficientMaterial => GameEndReason.insufficientMaterial,
        DrawReason.drawAgreement => GameEndReason.drawAgreement,
        DrawReason.abandonment => GameEndReason.abandonment,
      },
      winnerIsWhite: null,
    ));
    return true;
  }

  /// Resigns for [byWhite]'s side.
  void resign({required bool byWhite}) {
    if (_finished) return;
    _finish(GameResult(
      reason: GameEndReason.resignation,
      winnerIsWhite: !byWhite,
    ));
  }

  /// Ends by abandonment (connection lost).
  void abandon({required bool whiteAbandoned}) {
    if (_finished) return;
    _finish(GameResult(
      reason: GameEndReason.abandonment,
      winnerIsWhite: whiteAbandoned ? false : true,
    ));
  }

  /// Ends the game in a draw by mutual agreement (pass & play path).
  void agreeDraw() {
    if (_finished) return;
    _finish(const GameResult(
      reason: GameEndReason.drawAgreement,
      winnerIsWhite: null,
    ));
  }

  void _finishByTimeout(ClockSide flagged) {
    _finish(GameResult(
      reason: GameEndReason.timeout,
      winnerIsWhite: flagged != ClockSide.white,
    ));
  }

  void _finish(GameResult result, {DrawReason? drawReason}) {
    if (_finished || _disposed) return;
    _generation++; // drop any engine search still running
    _finished = true;
    _result = result;
    _drawReason = drawReason ?? game.endedDrawReason;
    endedAt = DateTime.now();

    game.endGame(result);
    clock?.halt();
    _stopTicker();
    _syncClocks();

    final localWon = result.winnerIsWhite == localIsWhite;
    sound.gameEnd(isDraw: result.isDraw, localWon: localWon);

    _statusMessage = result.headline;
    notifyListeners();

    onFinished?.call(GameFinishedEvent(
      result: result,
      whiteMsLeft: clock?.whiteMs(),
      blackMsLeft: clock?.blackMs(),
    ));
  }

  // ------------------------------------------------------------------ clock --

  void _startTickerIfNeeded() {
    if (clock == null || !clock!.hasClock || _finished) return;
    clock!.start(forSide: game.whiteToMove ? ClockSide.white : ClockSide.black);
    _syncClocks();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_finished) {
        _stopTicker();
        return;
      }
      final flagged = clock?.checkTimeout();
      if (flagged != null) {
        _finishByTimeout(flagged);
        return;
      }
      _syncClocks();
      notifyListeners();
    });
  }

  void _syncClocks() {
    final c = clock;
    if (c == null) return;
    whiteClock.value = c.whiteRemaining;
    blackClock.value = c.blackRemaining;
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    clock?.stop();
  }

  /// Pauses the clock (app backgrounded).
  void pauseClock() {
    _ticker?.cancel();
    _ticker = null;
    clock?.stop();
    notifyListeners();
  }

  /// Resumes after a pause.
  void resumeClock() {
    if (_finished || !started) return;
    _startTickerIfNeeded();
  }

  // -------------------------------------------------------------- lifecycle --

  /// Called once when the game screen opens: starts the clock for White (or
  /// the side to move from a restored position) and the ticking loop.
  void startGame() {
    if (_finished) return;
    _started = true;
    _startTickerIfNeeded();
    notifyListeners();
  }

  /// Builds the record for this finished game (null before it ends).
  ChessGameRecord? buildRecord({
    int? whiteRatingAfter,
    int? blackRatingAfter,
    String? openingName,
    String? openingEco,
    String? pgn,
  }) {
    final end = endedAt;
    if (end == null) return null;
    return ChessGameRecord(
      id: '${end.millisecondsSinceEpoch}',
      startedAt: startedAt,
      endedAt: end,
      startFen: ChessGame.startingFen,
      moves: game.history,
      result: _result!,
      timeControlLabel: timeControl.displayLabel,
      timeCategory: timeControl.category,
      source: switch (mode) {
        ChessGameMode.computer => GameSource.computer,
        ChessGameMode.passAndPlay => GameSource.passAndPlay,
        ChessGameMode.online => GameSource.online,
      },
      whiteName: whiteName,
      blackName: blackName,
      whiteRatingBefore: whiteRatingBefore,
      blackRatingBefore: blackRatingBefore,
      rated: rated,
      whiteRatingAfter: whiteRatingAfter,
      blackRatingAfter: blackRatingAfter,
      whiteId: whiteId,
      blackId: blackId,
      computerLevel: computerLevel?.name,
      openingName: openingName,
      openingEco: openingEco,
      pgn: pgn,
    );
  }

  /// Applies a move received from the peer (online path).
  MoveAttempt applyRemoteMove({
    required String from,
    required String to,
    String? promotion,
  }) {
    // Remote moves bypass `canInteract` (it's the other player's move anyway)
    // but still go through the rules layer, so an illegal payload is rejected
    // exactly like a local one.
    return _applyMove(from: from, to: to, promotion: promotion, remote: true);
  }

  // ----------------------------------------------------------- online sync --

  /// Applies authoritative clock values from the server (ms remaining).
  void applyRemoteClock({required int whiteMs, required int blackMs}) {
    if (_finished || clock == null) return;
    final c = clock!;
    c.setRemaining(ClockSide.white, Duration(milliseconds: whiteMs));
    c.setRemaining(ClockSide.black, Duration(milliseconds: blackMs));
    if (_started && !c.isRunning && !c.isExpired) {
      c.start(forSide: game.whiteToMove ? ClockSide.white : ClockSide.black);
    }
    _syncClocks();
    notifyListeners();
  }

  /// The opponent's draw offer arrived from the server.
  void applyRemoteDrawOffer({required bool byWhite}) {
    if (_finished) return;
    if (byWhite) {
      _drawOfferedByWhite = true;
    } else {
      _drawOfferedByBlack = true;
    }
    _statusMessage = 'Opponent offers a draw';
    notifyListeners();
  }

  /// A result decided by the server (resignation, flag, agreement, rules).
  void applyRemoteResult(GameResult result) => _finish(result);

  /// Resets to the server's authoritative position and clocks — used when a
  /// move was rejected or after reconnecting.
  void applyRemoteSync({
    required String fen,
    required int whiteMs,
    required int blackMs,
  }) {
    if (_finished) return;
    if (game.fen != fen) {
      _generation++; // drop any in-flight engine search on the old position
      game = ChessGame(fen: fen);
      _selectedSquare = null;
      _legalTargets = const [];
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _pendingPromotion = null;
      _pendingConfirmation = null;
      _takebackRequested = false;
      _clearDrawOffers();
      _started = true;
      notifyListeners();
    }
    applyRemoteClock(whiteMs: whiteMs, blackMs: blackMs);
  }

  /// Snapshots clocks for persistence.
  Map<String, dynamic>? clockSnapshot() => clock?.toJson();

  @override
  void dispose() {
    _disposed = true;
    _generation++; // orphan any engine search still running
    _stopTicker();
    whiteClock.dispose();
    blackClock.dispose();
    super.dispose();
  }
}
