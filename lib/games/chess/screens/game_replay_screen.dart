import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/chess_game.dart';
import '../core/models/game_record.dart';
import '../core/models/move_record.dart';
import '../services/engine_runner.dart';
import '../widgets/board/chess_board_view.dart';
import '../widgets/chess_theme.dart';
import '../widgets/eval_bar.dart';
import '../widgets/move_list.dart';
import '../widgets/player_bar.dart';

/// Step through a finished game move by move (also the entry point for the
/// game review flow). Shows the engine evaluation, best line and depth for
/// every position via the analysis lane.
class GameReplayScreen extends StatefulWidget {
  const GameReplayScreen({
    super.key,
    required this.record,
    this.autoAnalyze = true,
  });

  final ChessGameRecord record;

  /// Analyses each position automatically when true (off in tests so no
  /// isolate is spawned; the refresh button can still analyse manually).
  final bool autoAnalyze;

  @override
  State<GameReplayScreen> createState() => _GameReplayScreenState();
}

class _GameReplayScreenState extends State<GameReplayScreen> {
  /// -1 = start position, otherwise the ply index in [ChessGameRecord.moves].
  int _ply = -1;
  bool _flipped = false;

  // Analysis state for the current position.
  bool _analyzing = false;
  bool _hasEval = false;
  int _evalCp = 0;
  bool _evalMate = false;
  int _evalMatePly = 0;
  int _evalDepth = 0;
  List<String> _bestLine = const [];

  /// Monotonic id so stale engine responses are dropped.
  int _request = 0;

  List<MoveRecord> get _moves => widget.record.moves;

  String get _fen {
    final ply = _ply;
    if (ply < 0) return widget.record.startFen;
    return _moves[ply].fenAfter;
  }

  ChessGame get _position => ChessGame(fen: _fen);

  @override
  void initState() {
    super.initState();
    // Post-frame so the first setState inside the analysis isn't synchronous
    // with initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  void _go(int ply) {
    final clamped = ply.clamp(-1, _moves.length - 1);
    if (clamped == _ply) return;
    setState(() => _ply = clamped);
    _analyze();
  }

  /// Evaluates the current position on the analysis lane. Superseded requests
  /// (fast navigation) are ignored via [_request].
  Future<void> _analyze({bool manual = false}) async {
    if (!manual && !widget.autoAnalyze) return;
    if (!mounted) return;
    final seq = ++_request;
    setState(() => _analyzing = true);
    try {
      final result = await EngineRunner.instance.analyze(
        _fen,
        maxDepth: 7,
        timeMs: 1200,
      );
      if (!mounted || seq != _request) return;
      setState(() {
        _analyzing = false;
        if (result.depth > 0 || result.pv.isNotEmpty) {
          _hasEval = true;
          _evalCp = result.whiteScoreCp;
          _evalMate = result.isMate;
          _evalMatePly = result.mateInPly;
          _evalDepth = result.depth;
          _bestLine = result.pv;
        }
      });
    } catch (_) {
      if (mounted && seq == _request) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final position = _position;
    final last = _ply >= 0 ? _moves[_ply] : null;

    String? checkSquare;
    if (position.inCheck) {
      for (final piece in position.pieces) {
        if (piece.type == PieceType.king &&
            piece.isWhite == position.whiteToMove) {
          checkSquare = piece.square;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: ChessPalette.background,
      body: SafeArea(
          child: Column(
            children: [
              _topBar(record),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                  child: Column(
                    children: [
                      PlayerBar(
                        name: _flipped ? record.whiteName : record.blackName,
                        isWhite: _flipped,
                        rating: _flipped
                            ? record.whiteRatingBefore
                            : record.blackRatingBefore,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const evalWidth = 22.0;
                            const gap = 8.0;
                            final size = math.min(
                              constraints.maxWidth - evalWidth - gap,
                              constraints.maxHeight,
                            );

                            return Center(
                              child: SizedBox(
                                width: size + evalWidth + gap,
                                height: size,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: evalWidth,
                                      height: size,
                                      child: EvalBar(
                                        scoreCp: _hasEval ? _evalCp : 0,
                                        isMate: _hasEval && _evalMate,
                                        mateInPly: _evalMatePly,
                                        orientationWhite: !_flipped,
                                        width: evalWidth,
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    Expanded(
                                      child: ChessBoardView(
                                        pieces: position.pieces,
                                        orientationWhite: !_flipped,
                                        lastMoveFrom: last?.from,
                                        lastMoveTo: last?.to,
                                        checkSquare: checkSquare,
                                        interactive: false,
                                        showCoordinates: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      PlayerBar(
                        name: _flipped ? record.blackName : record.whiteName,
                        isWhite: !_flipped,
                        rating: _flipped
                            ? record.blackRatingBefore
                            : record.whiteRatingBefore,
                      ),
                    ],
                  ),
                ),
              ),
              _transport(),
              _analysisPanel(),
              SizedBox(
                height: 152,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: MoveListView(
                    moves: widget.record.moves,
                    openingName: record.openingName,
                    openingEco: record.openingEco,
                    selectedIndex: _ply < 0 ? null : _ply,
                    onMoveTap: _go,
                    emptyLabel: 'This game has no moves.',
                    background: ChessPalette.surfaceAlt,
                    border: Border.all(color: ChessPalette.border),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _topBar(ChessGameRecord record) {
    final result = record.result;
    final headline = result.isDraw
        ? 'DRAW · ${result.reasonLabel.toUpperCase()}'
        : '${result.winnerLabel.toUpperCase()} · ${result.reasonLabel.toUpperCase()}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: ChessPalette.text, size: 22),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ChessPalette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${record.timeControlLabel} · '
                  '${_sourceLabel(record.source)}',
                  maxLines: 1,
                  style: ChessText.caption,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _flipped = !_flipped),
            icon: const Icon(Icons.flip_rounded,
                color: ChessPalette.textDim, size: 21),
            tooltip: 'Flip board',
          ),
        ],
      ),
    );
  }

  String _sourceLabel(GameSource source) => switch (source) {
        GameSource.computer => 'vs Computer',
        GameSource.passAndPlay => 'Pass & Play',
        GameSource.online => 'Online',
      };

  Widget _transport() {
    final total = _moves.length;
    final atStart = _ply <= -1;
    final atEnd = _ply >= total - 1;

    Widget button(IconData icon, VoidCallback? onTap, {String? tip}) {
      final enabled = onTap != null;
      return IconButton(
        onPressed: onTap,
        tooltip: tip,
        icon: Icon(
          icon,
          color: enabled ? ChessPalette.text : ChessPalette.textFaint,
          size: 22,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          button(Icons.first_page_rounded, atStart ? null : () => _go(-1),
              tip: 'Start'),
          button(Icons.chevron_left_rounded, atStart ? null : () => _go(_ply - 1),
              tip: 'Previous'),
          Expanded(
            child: Center(
              child: InfoChip(
                label: total == 0
                    ? '0 moves'
                    : 'Move ${(_ply + 1).clamp(0, total)} / $total',
              ),
            ),
          ),
          button(Icons.chevron_right_rounded, atEnd ? null : () => _go(_ply + 1),
              tip: 'Next'),
          button(
            Icons.last_page_rounded,
            atEnd ? null : () => _go(total - 1),
            tip: 'End',
          ),
        ],
      ),
    );
  }

  /// Eval pill + depth + engine best line for the position on screen.
  Widget _analysisPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 2),
      child: Row(
        children: [
          if (_hasEval)
            EvalPill(
              scoreCp: _evalCp,
              isMate: _evalMate,
              mateInPly: _evalMatePly,
            )
          else
            InfoChip(label: _analyzing ? 'Analysing\u2026' : 'No eval'),
          const SizedBox(width: 8),
          if (_analyzing)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ChessPalette.accent,
              ),
            )
          else if (_hasEval)
            Text('depth $_evalDepth', style: ChessText.caption),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _bestLine.isEmpty
                  ? 'Engine best line shows here'
                  : _bestLine.join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ChessText.caption,
            ),
          ),
          IconButton(
            onPressed: _analyzing ? null : () => _analyze(manual: true),
            tooltip: 'Analyse this position',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 17,
              color: ChessPalette.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
