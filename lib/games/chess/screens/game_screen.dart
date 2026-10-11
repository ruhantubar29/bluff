import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/engine/chess_engine.dart';
import '../core/game_clock.dart';
import '../core/models/game_record.dart';
import '../core/models/time_control.dart';
import '../core/rating/elo.dart';
import '../services/chess_storage.dart';
import '../services/engine_runner.dart';
import '../services/online_service.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../state/game_controller.dart';
import '../widgets/board/chess_board_view.dart';
import '../widgets/chess_theme.dart';
import '../widgets/eval_bar.dart';
import '../widgets/move_list.dart';
import '../widgets/player_bar.dart';

/// The live game table: board, clocks, move list, controls, result.
///
/// The screen owns a [GameController] for the whole match, persists the
/// finished record (and rated rating changes) and drives the optional eval
/// bar from the analysis engine.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    this.timeControl,
    this.computerLevel,
    this.computerIsWhite = false,
    this.computerElo,
    this.useStockfish = false,
    this.whiteName,
    this.blackName,
    this.rated,
    this.onReview,
    this.liveGame,
    this.localIsWhite = true,
    this.opponentId,
    this.opponentRating,
  });

  final ChessGameMode mode;
  final TimeControl? timeControl;
  final EngineLevel? computerLevel;
  final bool computerIsWhite;

  /// Custom engine strength (Elo slider); overrides [computerLevel] preset.
  final int? computerElo;

  /// Prefer native Stockfish (falls back to the built-in engine).
  final bool useStockfish;

  final String? whiteName;
  final String? blackName;

  /// Defaults: computer games are rated against the engine's strength,
  /// pass & play is not (shared account, no meaningful opponent rating).
  final bool? rated;

  /// Opens the finished game in the analysis/review board.
  final void Function(ChessGameRecord record)? onReview;

  /// The server channel for online games. When set, local moves are relayed
  /// through it and its events (opponent moves, clocks, results) drive the
  /// controller — the server is the authority.
  final LiveGame? liveGame;

  /// Online only: which side this device plays (server-assigned at match
  /// time) and the opponent's identity/rating for the saved record.
  final bool localIsWhite;
  final String? opponentId;
  final int? opponentRating;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController? _controller;
  ChessGameRecord? _record;
  bool _saved = false;
  bool _resultShown = false;
  String? _bootError;

  // Eval bar state.
  int _evalCp = 0;
  bool _evalMate = false;
  int _evalMatePly = 0;
  int _evalDepth = 0;
  int _evalSeq = 0;
  String? _lastEvalFen;

  // Low-time tick bookkeeping.
  bool _whiteTicked = false;
  bool _blackTicked = false;

  // Online game bridge.
  StreamSubscription<LiveGameEvent>? _liveSub;
  bool _connectionLost = false;
  bool _drawPromptOpen = false;

  ChessSettings get _settings => ChessSettingsService.instance.settings;

  bool get _showEvalBar =>
      // Never show engine evaluation during a live online game — it would
      // be a cheating aid against a human opponent.
      _settings.showEvalBar && widget.mode != ChessGameMode.online;

  @override
  void initState() {
    super.initState();
    SoundService.instance.preload();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final profile = await SessionService.instance.current;

      final level = widget.computerLevel;
      final rated = widget.rated ?? widget.mode == ChessGameMode.computer;
      final engineElo = widget.computerElo ?? level?.rating;
      final category =
          widget.timeControl?.ratingCategory ?? RatingCategory.rapid;
      final profileRating = profile.rating(category);

      final whiteIsEngine =
          widget.mode == ChessGameMode.computer && widget.computerIsWhite;
      final online = widget.mode == ChessGameMode.online;

      final controller = GameController(
        mode: widget.mode,
        timeControl: widget.timeControl,
        sound: SoundService.instance,
        computerLevel: level,
        computerIsWhite: widget.computerIsWhite,
        onlineIsWhite: widget.localIsWhite,
        computerElo: widget.computerElo,
        useStockfish: widget.useStockfish,
        whiteName:
            widget.whiteName ??
            (whiteIsEngine ? _engineName(level) : profile.displayName),
        blackName:
            widget.blackName ??
            (!whiteIsEngine && widget.mode == ChessGameMode.computer
                ? _engineName(level)
                : widget.mode == ChessGameMode.computer
                ? profile.displayName
                : 'Player 2'),
        rated: rated,
        whiteId: whiteIsEngine
            ? 'engine'
            : online
                ? (widget.localIsWhite ? profile.id : widget.opponentId)
                : profile.id,
        blackId: !whiteIsEngine && widget.mode == ChessGameMode.computer
            ? 'engine'
            : online
                ? (widget.localIsWhite ? widget.opponentId : profile.id)
                : profile.id,
        whiteRatingBefore: whiteIsEngine
            ? engineElo ?? Elo.startingRating
            : online
                ? (widget.localIsWhite
                    ? profileRating
                    : widget.opponentRating ?? profileRating)
                : profileRating,
        blackRatingBefore:
            !whiteIsEngine && widget.mode == ChessGameMode.computer
            ? engineElo ?? Elo.startingRating
            : online
                ? (widget.localIsWhite
                    ? widget.opponentRating ?? profileRating
                    : profileRating)
                : profileRating,
      );

      controller.onFinished = _handleFinished;
      controller.addListener(_onControllerChanged);

      // Bridge the live server channel: relay local moves out, apply the
      // server's events (opponent moves, clocks, offers, results) in.
      final live = widget.liveGame;
      if (live != null) {
        controller.onLocalMove = (move) {
          live
              .playMove(
                from: move.from,
                to: move.to,
                promotion: move.promotion,
              )
              .catchError((Object _) {
            // Send failures surface as ConnectionLost from the service.
          });
        };
        _liveSub = live.events.listen(
          _onLiveEvent,
          onError: (Object _) {
            if (mounted) setState(() => _connectionLost = true);
          },
          onDone: () {
            // A channel that closes after the game is over is not a
            // connection problem — only a mid-game close is.
            if (mounted && !controller.finished) {
              setState(() => _connectionLost = true);
            }
          },
        );
      }

      // Put the human at the bottom when they chose Black (preference).
      if (widget.mode == ChessGameMode.computer &&
          widget.computerIsWhite &&
          _settings.flipBoardWithColor) {
        controller.flipped = true;
      }
      // Online: always seat the local player at the bottom of the board.
      if (online && !widget.localIsWhite) {
        controller.flipped = true;
      }

      controller.startGame();

      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _requestEval();
    } catch (error) {
      if (mounted) setState(() => _bootError = '$error');
    }
  }

  static String _engineName(EngineLevel? level) =>
      'Computer · ${level?.displayName ?? 'Medium'}';

  @override
  void dispose() {
    _liveSub?.cancel();
    // Leaving the screen releases the channel; the server resolves the
    // game by its own clock if the player simply walked away.
    widget.liveGame?.close();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      controller.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- updates --

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null) return;
    _maybeLowTimeTick(controller);
    _requestEval();
    setState(() {});
  }

  void _maybeLowTimeTick(GameController controller) {
    final clock = controller.clock;
    if (clock == null || controller.finished) return;
    if (clock.isLowTime(
      ClockSide.white,
      threshold: const Duration(seconds: 6),
    )) {
      if (!_whiteTicked) {
        _whiteTicked = true;
        SoundService.instance.lowTime();
      }
    } else if (clock.remaining(ClockSide.white) > const Duration(seconds: 8)) {
      _whiteTicked = false;
    }
    if (clock.isLowTime(
      ClockSide.black,
      threshold: const Duration(seconds: 6),
    )) {
      if (!_blackTicked) {
        _blackTicked = true;
        SoundService.instance.lowTime();
      }
    } else if (clock.remaining(ClockSide.black) > const Duration(seconds: 8)) {
      _blackTicked = false;
    }
  }

  Future<void> _requestEval() async {
    if (!_showEvalBar) return;
    final controller = _controller;
    if (controller == null || controller.finished) return;
    final fen = controller.game.fen;
    if (fen == _lastEvalFen) return;
    _lastEvalFen = fen;
    final seq = ++_evalSeq;
    try {
      final result = await EngineRunner.instance.analyze(
        fen,
        maxDepth: 6,
        timeMs: 450,
      );
      if (!mounted || seq != _evalSeq) return;
      setState(() {
        _evalCp = result.whiteScoreCp;
        _evalMate = result.isMate;
        _evalMatePly = result.mateInPly;
        _evalDepth = result.depth;
      });
    } catch (_) {
      // Analysis is decorative; a failed search never blocks the game.
    }
  }

  // -------------------------------------------------------------- finish --

  Future<void> _handleFinished(GameFinishedEvent event) async {
    if (_saved) return;
    _saved = true;

    final controller = _controller;
    if (controller == null) return;

    int? whiteAfter;
    int? blackAfter;

    if (controller.rated) {
      final category = controller.timeControl.ratingCategory;
      final localIsWhite = widget.mode == ChessGameMode.computer
          ? !widget.computerIsWhite
          : widget.mode == ChessGameMode.online
              ? widget.localIsWhite
              : true;
      final opponentRating = localIsWhite
          ? controller.blackRatingBefore
          : controller.whiteRatingBefore;
      final myScore = localIsWhite
          ? event.result.whiteScore
          : 1 - event.result.whiteScore;

      try {
        final profile = await SessionService.instance.current;
        final rating = profile.ratingFor(category);
        final change = rating.recordGame(
          category: category,
          opponentRating: opponentRating,
          score: myScore,
          at: controller.endedAt,
        );
        await ChessStorage.instance.upsertProfile(profile);

        final localAfter = rating.rating;
        whiteAfter = localIsWhite ? localAfter : opponentRating;
        blackAfter = localIsWhite ? opponentRating : localAfter;
        if (mounted) setState(() => _ratingDelta = change.delta);
      } catch (_) {
        // Rating bookkeeping must never block the result dialog; keep the
        // record's ratings at their pre-game values instead.
        whiteAfter = controller.whiteRatingBefore;
        blackAfter = controller.blackRatingBefore;
      }
    }

    final record = controller.buildRecord(
      whiteRatingAfter: whiteAfter,
      blackRatingAfter: blackAfter,
      openingName: controller.opening?.name,
      openingEco: controller.opening?.eco,
      pgn: controller.game.pgn(),
    );

    if (record != null) {
      _record = record;
      try {
        await ChessStorage.instance.addGame(record);
      } catch (_) {
        // Storage failures are non-fatal; the game is still over.
      }
    }

    if (mounted && !_resultShown) {
      _resultShown = true;
      // Let the final move animation land before the modal.
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (mounted) _showResultDialog(event);
    }
  }

  int? _ratingDelta;

  Future<void> _showResultDialog(GameFinishedEvent event) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final result = event.result;
    final record = _record;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: ChessPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ChessPalette.borderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: result.isDraw
                      ? ChessPalette.surfaceHigh
                      : ChessPalette.accentSoft,
                  borderRadius: ChessPalette.chipRadius,
                  border: Border.all(color: ChessPalette.borderStrong),
                ),
                child: Text(
                  result.headline,
                  style: const TextStyle(
                    color: ChessPalette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                result.isDraw
                    ? result.reasonLabel
                    : '${result.winnerLabel} · ${result.reasonLabel}',
                textAlign: TextAlign.center,
                style: ChessText.title.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                '${controller.whiteName} vs ${controller.blackName}',
                textAlign: TextAlign.center,
                style: ChessText.dim,
              ),
              if (controller.rated && _ratingDelta != null) ...[
                const SizedBox(height: 14),
                InfoChip(
                  label: '${_ratingDelta! >= 0 ? '+' : ''}$_ratingDelta rating',
                  icon: Icons.trending_up_rounded,
                  color: _ratingDelta! >= 0
                      ? ChessPalette.success.withValues(alpha: 0.18)
                      : ChessPalette.danger.withValues(alpha: 0.18),
                  textColor: _ratingDelta! >= 0
                      ? ChessPalette.success
                      : ChessPalette.danger,
                ),
              ],
              const SizedBox(height: 20),
              if (record != null && widget.onReview != null) ...[
                PrimaryButton(
                  label: 'Review game',
                  icon: Icons.insights_rounded,
                  expanded: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onReview!(record);
                  },
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Exit',
                      expanded: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (widget.mode != ChessGameMode.online) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Rematch',
                        expanded: true,
                        icon: Icons.replay_rounded,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _rematch();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rematch() {
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          mode: widget.mode,
          timeControl: widget.timeControl,
          computerLevel: widget.computerLevel,
          computerIsWhite: widget.computerIsWhite,
          whiteName: widget.whiteName,
          blackName: widget.blackName,
          rated: widget.rated,
          onReview: widget.onReview,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ controls --

  bool get _localIsWhite => widget.mode == ChessGameMode.online
      ? widget.localIsWhite
      : widget.mode == ChessGameMode.computer
          ? !widget.computerIsWhite
          : _controller?.isWhiteTurn ?? true;

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ChessPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ChessPalette.borderStrong),
        ),
        title: const Text('Leave the game?', style: ChessText.title),
        content: const Text(
          'The current game will not be saved to your history.',
          style: ChessText.dim,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Leave',
              style: TextStyle(color: ChessPalette.danger),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _resign() async {
    final controller = _controller;
    if (controller == null || controller.finished) return;
    if (_settings.confirmResign) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ChessPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: ChessPalette.borderStrong),
          ),
          title: const Text('Resign?', style: ChessText.title),
          content: Text(
            'You will lose this game as ${_localIsWhite ? 'White' : 'Black'}.',
            style: ChessText.dim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Resign',
                style: TextStyle(color: ChessPalette.danger),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final live = widget.liveGame;
    if (live != null) {
      // Server-authoritative: the board finishes when GameEnded arrives.
      try {
        await live.resign();
        _snack('Resign sent.');
      } catch (error) {
        _snack('Could not resign: $error');
      }
      return;
    }
    controller.resign(byWhite: _localIsWhite);
  }

  Future<void> _offerDraw() async {
    final controller = _controller;
    if (controller == null || controller.finished) return;

    if (controller.mode == ChessGameMode.passAndPlay) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ChessPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: ChessPalette.borderStrong),
          ),
          title: const Text('Offer a draw?', style: ChessText.title),
          content: Text(
            'The other player can accept or decline.',
            style: ChessText.dim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Offer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final offeringWhite = controller.isWhiteTurn;
      await controller.offerDraw(byWhite: offeringWhite);
      if (!mounted || controller.finished) return;

      final accept = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ChessPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: ChessPalette.borderStrong),
          ),
          title: const Text('Draw offered', style: ChessText.title),
          content: Text(
            '${offeringWhite ? controller.blackName : controller.whiteName}, '
            'do you accept the draw?',
            style: ChessText.dim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
      controller.respondToDrawOffer(accepted: accept == true);
      return;
    }

    final live = widget.liveGame;
    if (live != null) {
      // Marks the local offer active, then sends it through the server.
      await controller.offerDraw(byWhite: widget.localIsWhite);
      if (!mounted) return;
      try {
        await live.offerDraw();
        _snack('Draw offer sent.');
      } catch (error) {
        controller.respondToDrawOffer(accepted: false);
        _snack('Could not send draw offer: $error');
      }
      return;
    }

    final accepted = await controller.offerDraw(byWhite: _localIsWhite);
    if (!mounted) return;
    if (!accepted) {
      _snack(controller.statusMessage ?? 'Draw offer declined');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ChessPalette.surfaceHigh,
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  // -------------------------------------------------------------- online --

  String _opponentName(GameController controller) => widget.localIsWhite
      ? controller.blackName
      : controller.whiteName;

  /// Applies a server event to the local controller.
  void _onLiveEvent(LiveGameEvent event) {
    final controller = _controller;
    if (!mounted || controller == null) return;
    switch (event) {
      case OpponentMoved(:final from, :final to, :final promotion):
        controller.applyRemoteMove(from: from, to: to, promotion: promotion);
      case PositionResynced(:final fen, :final whiteMs, :final blackMs):
        controller.applyRemoteSync(
          fen: fen,
          whiteMs: whiteMs,
          blackMs: blackMs,
        );
      case ClockSynced(:final whiteMs, :final blackMs):
        controller.applyRemoteClock(whiteMs: whiteMs, blackMs: blackMs);
      case DrawOffered():
        if (controller.finished) return;
        controller.applyRemoteDrawOffer(byWhite: !widget.localIsWhite);
        unawaited(_promptRemoteDraw());
      case GameEnded(:final result):
        controller.applyRemoteResult(result);
      case ConnectionLost():
        if (!mounted) return;
        setState(() => _connectionLost = true);
        _snack('Connection to the server was lost.');
    }
  }

  /// Asks the local player to answer the opponent's draw offer.
  Future<void> _promptRemoteDraw() async {
    if (_drawPromptOpen) return;
    final controller = _controller;
    if (controller == null || controller.finished) return;
    _drawPromptOpen = true;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ChessPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ChessPalette.borderStrong),
        ),
        title: const Text('Draw offered', style: ChessText.title),
        content: Text(
          '${_opponentName(controller)}, do you accept the draw?',
          style: ChessText.dim,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    _drawPromptOpen = false;
    if (!mounted) return;
    final current = _controller;
    if (current == null || current.finished) return;
    current.respondToDrawOffer(accepted: accept == true);
    final live = widget.liveGame;
    if (live != null) {
      try {
        await live.answerDraw(accept: accept == true);
      } catch (_) {
        // The local answer already applied; a failed relay just means the
        // server never ends the game — the connection banner tells the story.
      }
    }
  }

  void _takeback() {
    final controller = _controller;
    if (controller == null) return;
    final undone = controller.requestTakeback();
    if (undone == 0) {
      _snack(controller.statusMessage ?? 'Takeback unavailable');
    } else if (controller.mode != ChessGameMode.online) {
      _snack('Takeback (${undone == 1 ? '1 move' : '$undone moves'})');
    }
  }

  // --------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final error = _bootError;
    if (error != null) {
      return Scaffold(
        backgroundColor: ChessPalette.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not start the game:\n$error',
              textAlign: TextAlign.center,
              style: ChessText.dim,
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        backgroundColor: ChessPalette.background,
        body: Center(
          child: CircularProgressIndicator(color: ChessPalette.accent),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    return PopScope(
      canPop:
          !controller.started ||
          controller.finished ||
          controller.moves.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: ChessPalette.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(controller),
              if (_connectionLost)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: ChessPalette.danger.withValues(alpha: 0.14),
                    border: Border.all(
                      color: ChessPalette.danger.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 16, color: ChessPalette.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connection lost — the server keeps your clock '
                          'running until the game resolves.',
                          style: ChessText.caption
                              .copyWith(color: ChessPalette.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildBoardArea(controller, wide),
                          _buildControls(controller),
                          if (!wide)
                            SizedBox(
                              height: 168,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  12,
                                ),
                                child: _buildMoveList(controller),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (wide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 14, 14),
                        child: SizedBox(
                          width: 320,
                          child: _buildMoveList(controller),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(GameController controller) {
    final opening = controller.opening;
    String status;
    if (controller.thinking) {
      status = 'Thinking…';
    } else if (controller.statusMessage != null) {
      status = controller.statusMessage!;
    } else if (opening != null) {
      status = opening.name;
    } else {
      status = controller.timeControl.displayLabel;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (controller.started &&
                  !controller.finished &&
                  controller.moves.isNotEmpty) {
                _confirmLeave();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: ChessPalette.text,
              size: 22,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ChessPalette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (opening?.eco != null)
                  Text(
                    '${opening!.eco} · ${controller.timeControl.displayLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChessText.caption,
                  )
                else
                  Text(
                    controller.timeControl.displayLabel,
                    maxLines: 1,
                    style: ChessText.caption,
                  ),
              ],
            ),
          ),
          if (_showEvalBar && _lastEvalFen != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Evaluation to depth $_evalDepth',
                child: EvalPill(
                  scoreCp: _evalCp,
                  isMate: _evalMate,
                  mateInPly: _evalMatePly,
                ),
              ),
            ),
          IconButton(
            onPressed: () =>
                setState(() => controller.flipped = !controller.flipped),
            icon: const Icon(
              Icons.flip_rounded,
              color: ChessPalette.textDim,
              size: 21,
            ),
            tooltip: 'Flip board',
          ),
        ],
      ),
    );
  }

  /// One of the two player rows: the opponent above the board, the local
  /// player below it (they swap when the board is flipped).
  Widget _buildPlayerBar(GameController controller, {required bool atTop}) {
    final whiteOnTop =
        controller.flipped; // white sits at the bottom by default
    final isWhite = atTop ? whiteOnTop : !whiteOnTop;
    final side = isWhite ? ClockSide.white : ClockSide.black;

    final clock = controller.clock;
    final captures = controller.captured;
    final balance = controller.materialBalance(); // from White's perspective

    final engineIsWhite =
        controller.mode == ChessGameMode.computer && controller.computerIsWhite;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: PlayerBar(
        name: isWhite ? controller.whiteName : controller.blackName,
        isWhite: isWhite,
        rating: controller.rated
            ? (isWhite
                  ? controller.whiteRatingBefore
                  : controller.blackRatingBefore)
            : null,
        captured: isWhite ? captures.byWhite : captures.byBlack,
        advantage: isWhite ? balance : -balance,
        clock: clock == null
            ? null
            : isWhite
            ? controller.whiteClock.value
            : controller.blackClock.value,
        clockActive:
            clock != null && clock.isRunning && clock.activeSide == side,
        clockUrgent:
            clock != null &&
            clock.isLowTime(side, threshold: const Duration(seconds: 20)),
        clockCritical: clock != null && clock.isCriticalTime(side),
        thinking: controller.thinking && (isWhite == engineIsWhite),
      ),
    );
  }

  Widget _buildBoardArea(GameController controller, bool wide) {
    final showEval = _showEvalBar;
    final evalWidth = showEval ? 24.0 : 0.0;
    final gap = showEval ? 8.0 : 0.0;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 16 : 10, 4, wide ? 16 : 10, 4),
        child: Column(
          children: [
            _buildPlayerBar(controller, atTop: true),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available = math.min(
                    constraints.maxWidth - evalWidth - gap,
                    constraints.maxHeight,
                  );
                  final size = available.isFinite && available > 80
                      ? available
                      : constraints.maxWidth;

                  final interactive = controller.canInteract;

                  return Center(
                    child: SizedBox(
                      width: size + evalWidth + gap,
                      height: size,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showEval)
                            SizedBox(
                              width: evalWidth,
                              height: size,
                              child: EvalBar(
                                scoreCp: _evalCp,
                                isMate: _evalMate,
                                mateInPly: _evalMatePly,
                                orientationWhite: !controller.flipped,
                                width: evalWidth,
                              ),
                            ),
                          if (showEval) SizedBox(width: gap),
                          Expanded(
                            child: ChessBoardView(
                              pieces: controller.game.pieces,
                              orientationWhite: !controller.flipped,
                              selectedSquare: controller.selectedSquare,
                              legalTargets: controller.legalTargets,
                              lastMoveFrom: controller.lastMoveFrom,
                              lastMoveTo: controller.lastMoveTo,
                              checkSquare: controller.checkedKingSquare,
                              interactive: interactive,
                              movableSquares: interactive
                                  ? controller.game.legalMoves
                                        .map((m) => m.from)
                                        .toSet()
                                  : const <String>{},
                              showCoordinates: _settings.showCoordinates,
                              showLegalDots: _settings.showLegalDots,
                              showLastMove: _settings.showLastMove,
                              animationDuration: _settings.moveAnimation,
                              pendingPromotion: controller.pendingPromotion,
                              onPromotionSelected: controller.completePromotion,
                              onPromotionCancelled: controller.cancelPromotion,
                              onTapSquare: controller.tapSquare,
                              onMoveAttempt: (from, to) =>
                                  controller.playMove(from: from, to: to),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildPlayerBar(controller, atTop: false),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(GameController controller) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 16 : 10, 6, wide ? 16 : 10, 6),
      child: Row(
        children: [
          Expanded(
            child: GhostButton(
              label: 'Draw',
              icon: Icons.handshake_rounded,
              dense: true,
              expanded: true,
              onPressed: controller.finished || controller.drawOfferActive
                  ? null
                  : _offerDraw,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GhostButton(
              label: 'Takeback',
              icon: Icons.undo_rounded,
              dense: true,
              expanded: true,
              onPressed: controller.finished ||
                      controller.moves.isEmpty ||
                      widget.liveGame != null
                  ? null
                  : _takeback,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GhostButton(
              label: 'Flip',
              icon: Icons.flip_rounded,
              dense: true,
              expanded: true,
              onPressed: () =>
                  setState(() => controller.flipped = !controller.flipped),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GhostButton(
              label: 'Resign',
              icon: Icons.flag_rounded,
              dense: true,
              danger: true,
              expanded: true,
              onPressed: controller.finished || controller.moves.isEmpty
                  ? null
                  : _resign,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveList(GameController controller) {
    return MoveListView(
      moves: controller.moves,
      openingName: controller.opening?.name,
      openingEco: controller.opening?.eco,
      emptyLabel: controller.thinking
          ? 'The computer is thinking…'
          : 'Play a move to start the game.',
      selectedIndex: controller.moves.isEmpty
          ? null
          : controller.moves.length - 1,
      border: Border.all(color: ChessPalette.border),
      background: ChessPalette.surfaceAlt,
    );
  }
}
