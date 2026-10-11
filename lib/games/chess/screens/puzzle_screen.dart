import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/chess_game.dart';
import '../core/data/puzzle_data.dart';
import '../core/models/player_profile.dart';
import '../core/models/puzzle.dart';
import '../core/rating/elo.dart';
import '../services/chess_storage.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../widgets/board/chess_board_view.dart';
import '../widgets/chess_theme.dart';

/// Puzzle trainer: solve tactical positions from the local dataset.
///
/// The solver always plays the side to move. Correct moves are applied; the
/// scripted opponent reply plays automatically; wrong moves flash the target
/// square and are never applied. Finishing (solving or revealing) records one
/// attempt and updates the local puzzle rating with the standard Elo formula.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, this.isActive = true, this.initialPuzzle});

  /// When this flips to true the stats header reloads.
  final bool isActive;

  /// Forces a specific puzzle (tests, deep links). When null a puzzle is
  /// picked from [PuzzleData], preferring unseen ones near the player rating.
  final ChessPuzzle? initialPuzzle;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  ChessPuzzle? _puzzle;
  ChessGame? _game;

  /// Index of the next expected move in `puzzle.solution`.
  int _step = 0;
  int _wrongAttempts = 0;

  String? _selectedSquare;
  List<String> _legalTargets = const [];
  String? _lastFrom;
  String? _lastTo;
  String? _wrongSquare;
  String? _hintSquare;
  (String, String)? _pendingPromotion;

  bool _finished = false;
  bool _solved = false;
  bool _busy = false; // scripted opponent reply is on its way
  int? _ratingDelta;
  String _feedback = '';

  PuzzleStats? _stats;
  Timer? _replyTimer;

  ChessSettings get _settings => ChessSettingsService.instance.settings;

  bool get _hasPuzzle => _puzzle != null && _game != null;

  /// The board accepts input only while solving and never mid-reply.
  bool get _live => _hasPuzzle && !_finished && !_busy;

  @override
  void initState() {
    super.initState();
    SoundService.instance.preload();
    final forced = widget.initialPuzzle;
    if (forced != null) {
      _startPuzzle(forced);
    } else {
      _loadNext();
    }
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant PuzzleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadStats();
      if (_puzzle == null) _loadNext();
    }
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- lifecycle

  /// Resets all attempt state around [puzzle]. Called from initState without
  /// setState (fields are assigned before the first build) and later wrapped
  /// in setState by the callers.
  void _startPuzzle(ChessPuzzle puzzle) {
    _replyTimer?.cancel();
    _puzzle = puzzle;
    _game = ChessGame(fen: puzzle.fen);
    _step = 0;
    _wrongAttempts = 0;
    _selectedSquare = null;
    _legalTargets = const [];
    _lastFrom = null;
    _lastTo = null;
    _wrongSquare = null;
    _hintSquare = null;
    _pendingPromotion = null;
    _finished = false;
    _solved = false;
    _busy = false;
    _ratingDelta = null;
    _feedback = 'Find the best move for ${puzzle.sideToMoveLabel}';
  }

  Future<void> _loadNext() async {
    final puzzle = await _pickPuzzle();
    if (!mounted || puzzle == null) return;
    setState(() => _startPuzzle(puzzle));
  }

  /// Prefers unseen puzzles close to the player's puzzle rating; falls back to
  /// the full set (and then a wider band) once everything has been seen.
  Future<ChessPuzzle?> _pickPuzzle() async {
    if (widget.initialPuzzle != null) return widget.initialPuzzle;
    final all = PuzzleData.puzzles;
    if (all.isEmpty) return null;

    Set<String> seen;
    try {
      seen = await ChessStorage.instance.loadSeenPuzzleIds();
    } catch (_) {
      seen = const {};
    }

    final rating = _stats?.rating ?? 1200;
    final unseen = all.where((p) => !seen.contains(p.id)).toList();
    final near =
        unseen.where((p) => (p.rating - rating).abs() <= 350).toList();
    final pool = near.isNotEmpty
        ? near
        : unseen.isNotEmpty
            ? unseen
            : all;
    return pool[Random().nextInt(pool.length)];
  }

  Future<void> _loadStats() async {
    try {
      final profile = await SessionService.instance.current;
      if (!mounted) return;
      setState(() => _stats = profile.puzzleStats);
    } catch (_) {
      // Stats are cosmetic; the puzzle stays usable without them.
    }
  }

  // ------------------------------------------------------------- moves

  void _onTapSquare(String square) {
    if (!_live || _pendingPromotion != null) {
      if (_pendingPromotion != null) {
        setState(() => _pendingPromotion = null);
      }
      return;
    }
    final game = _game!;
    if (_selectedSquare != null && _legalTargets.contains(square)) {
      _tryMove(_selectedSquare!, square);
      return;
    }
    if (square == _selectedSquare) {
      setState(() {
        _selectedSquare = null;
        _legalTargets = const [];
      });
      return;
    }
    BoardPiece? piece;
    for (final p in game.pieces) {
      if (p.square == square) {
        piece = p;
        break;
      }
    }
    if (piece != null && piece.isWhite == game.whiteToMove) {
      setState(() {
        _selectedSquare = square;
        _legalTargets = game.legalTargetsFrom(square);
        _hintSquare = null;
        _wrongSquare = null;
      });
    } else {
      setState(() {
        _selectedSquare = null;
        _legalTargets = const [];
      });
    }
  }

  void _tryMove(String from, String to) {
    if (!_live) return;
    final game = _game!;
    final expected = _expectedUci;

    LegalMove? candidate;
    for (final m in game.legalMovesFrom(from)) {
      if (m.to == to) {
        candidate = m;
        break;
      }
    }
    if (candidate == null) {
      _reject(to, 'That piece can’t move there.');
      return;
    }
    if (candidate.isPromotion) {
      setState(() => _pendingPromotion = (from, to));
      return;
    }
    _judge(from, to, null, expected);
  }

  void _onPromotionSelected(String letter) {
    final pending = _pendingPromotion;
    setState(() => _pendingPromotion = null);
    if (pending == null || !_live) return;
    _judge(pending.$1, pending.$2, letter, _expectedUci);
  }

  void _onPromotionCancelled() {
    if (_pendingPromotion == null) return;
    setState(() => _pendingPromotion = null);
  }

  String get _expectedUci {
    final p = _puzzle;
    if (p == null || _step >= p.solution.length) return '';
    return p.solution[_step];
  }

  void _judge(String from, String to, String? promotion, String expectedUci) {
    final (eFrom, eTo, ePromo) = ChessPuzzle.parseUci(expectedUci);
    if (from == eFrom && to == eTo && promotion == ePromo) {
      _applySolverMove(from, to, promotion);
    } else {
      _reject(to, 'Not quite — look for something better.');
    }
  }

  void _reject(String square, String message) {
    SoundService.instance.play('illegal');
    setState(() {
      _wrongAttempts++;
      _wrongSquare = square;
      _selectedSquare = null;
      _legalTargets = const [];
      _hintSquare = null;
      _feedback = message;
    });
  }

  void _applySolverMove(String from, String to, String? promotion) {
    final game = _game!;
    final puzzle = _puzzle!;
    final attempt = game.makeMove(from: from, to: to, promotion: promotion);
    if (!attempt.played || attempt.application == null) return;
    final record = attempt.application!.record;

    SoundService.instance.play(
      record.isCapture
          ? 'capture'
          : record.promotion != null
              ? 'promote'
              : attempt.application!.gaveCheck
                  ? 'check'
                  : 'move',
    );

    setState(() {
      _selectedSquare = null;
      _legalTargets = const [];
      _wrongSquare = null;
      _hintSquare = null;
      _pendingPromotion = null;
      _lastFrom = from;
      _lastTo = to;
      _step++;
      _feedback = 'Find the best move for ${puzzle.sideToMoveLabel}';
    });

    if (_step >= puzzle.solution.length) {
      _finish(solved: true);
      return;
    }
    _busy = true;
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 430), _playReply);
  }

  /// Applies the scripted opponent move at the current step.
  void _playReply() {
    if (!mounted || _finished) return;
    final game = _game;
    final puzzle = _puzzle;
    if (game == null || puzzle == null || _step >= puzzle.solution.length) {
      return;
    }
    final (from, to, promotion) =
        ChessPuzzle.parseUci(puzzle.solution[_step]);
    final attempt = game.makeMove(from: from, to: to, promotion: promotion);
    if (attempt.played) {
      SoundService.instance.play(
        attempt.application!.record.isCapture ? 'capture' : 'move',
      );
      setState(() {
        _lastFrom = from;
        _lastTo = to;
        _step++;
        _busy = false;
      });
      if (_step >= puzzle.solution.length) _finish(solved: true);
    } else {
      // Dataset lines are validated at load time; bail out safely if not.
      setState(() => _busy = false);
    }
  }

  void _hint() {
    final expected = _expectedUci;
    if (expected.isEmpty) return;
    setState(() => _hintSquare = expected.substring(0, 2));
  }

  void _showSolution() {
    if (_finished) return;
    _finish(solved: false);
  }

  // ------------------------------------------------------------- results

  Future<void> _finish({required bool solved}) async {
    if (_finished) return;
    final puzzle = _puzzle;
    if (puzzle == null) return;

    setState(() {
      _finished = true;
      _solved = solved;
      _busy = false;
      _pendingPromotion = null;
      _selectedSquare = null;
      _legalTargets = const [];
      _feedback = solved
          ? (puzzle.comment ?? 'Solved!')
          : 'Solution revealed';
    });

    SoundService.instance.play(solved ? 'win' : 'lose');

    try {
      final profile = await SessionService.instance.current;
      final stats = profile.puzzleStats;
      final ratingBefore = stats.rating;
      final delta = Elo.newRating(
        rating: ratingBefore,
        opponentRating: puzzle.rating,
        score: solved ? 1.0 : 0.0,
        gamesPlayed: stats.attempted,
      );
      final change = delta - ratingBefore;
      stats.record(wasSolved: solved, delta: change);
      await ChessStorage.instance.upsertProfile(profile);

      final attempts = _wrongAttempts + 1;
      await ChessStorage.instance.addPuzzleAttempt(
        PuzzleAttempt(
          puzzleId: puzzle.id,
          solved: solved,
          attempts: attempts,
          timestamp: DateTime.now(),
          ratingBefore: ratingBefore,
          ratingAfter: stats.rating,
        ),
      );

      final seen = await ChessStorage.instance.loadSeenPuzzleIds()
        ..add(puzzle.id);
      await ChessStorage.instance.saveSeenPuzzleIds(seen);

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _ratingDelta = change;
      });
    } catch (_) {
      // Persistence is best-effort; the on-screen result already stands.
    }
  }

  Future<void> _nextPuzzle() async {
    final puzzle = await _pickPuzzleForNext();
    if (!mounted || puzzle == null) return;
    setState(() => _startPuzzle(puzzle));
  }

  /// Like [_pickPuzzle] but always avoids the finished puzzle.
  Future<ChessPuzzle?> _pickPuzzleForNext() async {
    final current = _puzzle;
    final picked = await _pickPuzzle();
    if (picked == null || picked.id == current?.id) {
      final others =
          PuzzleData.puzzles.where((p) => p.id != current?.id).toList();
      if (others.isEmpty) return picked;
      return others[Random().nextInt(others.length)];
    }
    return picked;
  }

  // ------------------------------------------------------------- display

  String get _solutionText {
    final puzzle = _puzzle;
    if (puzzle == null) return '';
    final game = ChessGame(fen: puzzle.fen);
    final parts = <String>[];
    for (var i = 0; i < puzzle.solution.length; i++) {
      final (from, to, promotion) = ChessPuzzle.parseUci(puzzle.solution[i]);
      final attempt =
          game.makeMove(from: from, to: to, promotion: promotion);
      if (!attempt.played || attempt.application == null) break;
      final san = attempt.application!.record.san;
      if (i.isEven) {
        parts.add('${i ~/ 2 + 1}. $san');
      } else {
        parts.add(san);
      }
    }
    return parts.join(' ');
  }

  /// Wrong-move and hint flashes shown on top of the board highlights.
  Map<String, Color> _extraHighlights() {
    final highlights = <String, Color>{};
    final wrong = _wrongSquare;
    if (wrong != null) {
      highlights[wrong] = ChessPalette.danger.withValues(alpha: 0.55);
    }
    final hint = _hintSquare;
    if (hint != null) {
      highlights[hint] = ChessPalette.warning.withValues(alpha: 0.55);
    }
    return highlights;
  }

  String? get _checkedKingSquare {
    final game = _game;
    if (game == null || !game.inCheck) return null;
    final white = game.whiteToMove;
    for (final p in game.pieces) {
      if (p.type == PieceType.king && p.isWhite == white) return p.square;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;
    final game = _game;
    if (puzzle == null || game == null) {
      return const Center(
        child: CircularProgressIndicator(color: ChessPalette.accent),
      );
    }

    final board = ChessBoardView(
      pieces: game.pieces,
      orientationWhite: puzzle.whiteToMove,
      selectedSquare: _selectedSquare,
      legalTargets: _legalTargets,
      lastMoveFrom: _lastFrom,
      lastMoveTo: _lastTo,
      checkSquare: _checkedKingSquare,
      extraHighlights: _extraHighlights(),
      interactive: _live,
      movableSquares: _live
          ? game.legalMoves.map((m) => m.from).toSet()
          : const <String>{},
      showCoordinates: _settings.showCoordinates,
      showLegalDots: _settings.showLegalDots,
      showLastMove: _settings.showLastMove,
      animationDuration: _settings.moveAnimation,
      pendingPromotion: _pendingPromotion,
      onPromotionSelected: _onPromotionSelected,
      onPromotionCancelled: _onPromotionCancelled,
      onTapSquare: _onTapSquare,
      onMoveAttempt: _tryMove,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(puzzle),
        _banner(puzzle),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = min(constraints.maxWidth, constraints.maxHeight);
                return Center(
                  child: SizedBox.square(dimension: size, child: board),
                );
              },
            ),
          ),
        ),
        _controls(),
      ],
    );
  }

  Widget _header(ChessPuzzle puzzle) {
    final stats = _stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InfoChip(
            label: '${puzzle.rating}',
            icon: Icons.insights_rounded,
            color: ChessPalette.accentSoft,
          ),
          InfoChip(
            label: '${puzzle.sideToMoveLabel} to move',
            icon: Icons.swap_horiz_rounded,
          ),
          for (final theme in puzzle.themes.take(3))
            InfoChip(label: themeLabel(theme)),
          if (stats != null)
            InfoChip(
              label: 'Streak ${stats.streak}',
              icon: Icons.local_fire_department_rounded,
            ),
        ],
      ),
    );
  }

  Widget _banner(ChessPuzzle puzzle) {
    Color bg;
    Color fg;
    if (!_finished) {
      bg = _wrongSquare != null
          ? ChessPalette.danger.withValues(alpha: 0.16)
          : ChessPalette.surfaceAlt;
      fg = ChessPalette.textDim;
    } else if (_solved) {
      bg = ChessPalette.success.withValues(alpha: 0.16);
      fg = ChessPalette.text;
    } else {
      bg = ChessPalette.warning.withValues(alpha: 0.14);
      fg = ChessPalette.text;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ChessPalette.chipRadius,
        border: Border.all(color: ChessPalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _finished && !_solved ? _solutionText : _feedback,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: ChessText.body.copyWith(color: fg, height: 1.35),
            ),
          ),
          if (_finished && _ratingDelta != null) ...[
            const SizedBox(width: 8),
            Text(
              '${_ratingDelta! >= 0 ? '+' : ''}$_ratingDelta',
              style: ChessText.mono.copyWith(
                color: _ratingDelta! >= 0
                    ? ChessPalette.success
                    : ChessPalette.danger,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controls() {
    final padding = const EdgeInsets.fromLTRB(16, 6, 16, 14);
    if (_finished) {
      return Padding(
        padding: padding,
        child: PrimaryButton(
          label: 'Next puzzle',
          icon: Icons.arrow_forward_rounded,
          expanded: true,
          onPressed: _nextPuzzle,
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: GhostButton(
              label: 'Hint',
              icon: Icons.lightbulb_outline_rounded,
              expanded: true,
              onPressed: _live ? _hint : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GhostButton(
              label: 'Show solution',
              icon: Icons.visibility_outlined,
              expanded: true,
              onPressed: _showSolution,
            ),
          ),
        ],
      ),
    );
  }
}

/// Human-readable label for a dataset theme tag.
String themeLabel(String theme) => switch (theme) {
      'checkmate' => 'Mate',
      'backRank' => 'Back rank',
      'forcedMate' => 'Forced mate',
      'fork' => 'Fork',
      'check' => 'Check',
      'hangingPiece' => 'Loose piece',
      'endgame' => 'Endgame',
      'promotion' => 'Promotion',
      _ => theme,
    };
