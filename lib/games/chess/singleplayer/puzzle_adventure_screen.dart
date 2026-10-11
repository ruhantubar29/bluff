import 'package:flutter/material.dart';

import '../core/data/puzzle_data.dart';
import '../core/models/puzzle.dart';
import '../screens/puzzle_screen.dart';
import '../services/chess_storage.dart';
import '../widgets/chess_theme.dart';

/// Level states on the tower.
enum _NodeState { cleared, current, locked, cloud }

/// Campaign map for the puzzle folder, styled like a level-select from a
/// match-3 game: 24 levels climb a swaying stair path from the bottom of the
/// screen. Cleared levels wear a gold star, the next level pulses, the few
/// levels after it are visible but locked, and everything beyond is hidden
/// behind clouds so the tower reads as much taller than it is.
///
/// Progress is derived from real puzzle attempts — a level counts as cleared
/// only when its puzzle was actually solved (a revealed solution doesn't
/// open the path), so the map never fakes completion.
class PuzzleAdventureScreen extends StatefulWidget {
  const PuzzleAdventureScreen({super.key});

  /// Deliberately limited: a full campaign, not a thousand fake levels.
  static const int levelCount = 24;

  @override
  State<PuzzleAdventureScreen> createState() =>
      _PuzzleAdventureScreenState();
}

class _PuzzleAdventureScreenState extends State<PuzzleAdventureScreen>
    with SingleTickerProviderStateMixin {
  static const double _step = 112; // vertical distance between levels
  static const double _node = 66;
  static const double _margin = 46;

  /// Horizontal sway of the stair path (fractions of the usable width).
  static const List<double> _sway = [0.0, 0.3, 0.62, 0.94, 0.62, 0.3];

  final ScrollController _scroll = ScrollController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..repeat(reverse: true);

  Set<String> _solved = {};
  bool _loading = true;
  bool _scrolledToStart = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static ChessPuzzle _puzzleFor(int level) => PuzzleData.puzzles[
      (level - 1) % PuzzleData.puzzles.length];

  /// Consecutive cleared levels from level 1 — the reachable frontier.
  int get _progress {
    var n = 0;
    while (n < PuzzleAdventureScreen.levelCount &&
        _solved.contains(_puzzleFor(n + 1).id)) {
      n++;
    }
    return n;
  }

  _NodeState _stateOf(int level) {
    if (_solved.contains(_puzzleFor(level).id)) return _NodeState.cleared;
    final frontier = _progress + 1;
    if (level == frontier) return _NodeState.current;
    if (level <= frontier + 3) return _NodeState.locked;
    return _NodeState.cloud;
  }

  Future<void> _load() async {
    final attempts =
        await ChessStorage.instance.loadPuzzleAttempts();
    final solved = {
      for (final attempt in attempts)
        if (attempt.solved) attempt.puzzleId,
    };
    if (!mounted) return;
    setState(() {
      _solved = solved;
      _loading = false;
    });
    if (!_scrolledToStart) {
      _scrolledToStart = true;
      // Start the view at the bottom of the tower: level 1 is home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _openLevel(int level) async {
    final puzzle = _puzzleFor(level);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleScreen(initialPuzzle: puzzle),
      ),
    );
    await _load(); // refresh stars/unlocks with fresh attempts
  }

  void _tapLevel(int level, _NodeState state) {
    switch (state) {
      case _NodeState.cleared:
      case _NodeState.current:
        _openLevel(level);
      case _NodeState.locked:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Clear level ${_progress + 1} to unlock level $level.',
            ),
          ),
        );
      case _NodeState.cloud:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hidden in the clouds — climb the levels below to reach it.',
            ),
          ),
        );
    }
  }

  // ----------------------------------------------------------------- math --

  double _centerX(int level, double width) {
    final usable = (width - 2 * _margin - _node).clamp(0.0, double.infinity);
    return _margin + _node / 2 +
        _sway[(level - 1) % _sway.length] * usable;
  }

  double _totalHeight() =>
      96 + // sky above the peak
      (PuzzleAdventureScreen.levelCount - 1) * _step +
      120; // base below level 1

  double _centerY(int level) =>
      _totalHeight() - 120 - (level - 1) * _step;

  // ---------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChessPalette.background,
      appBar: AppBar(
        backgroundColor: ChessPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ChessPalette.text,
        elevation: 0,
        title: const Text('Puzzle Tower', style: ChessText.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      controller: _scroll,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          return SizedBox(
                            height: _totalHeight(),
                            width: width,
                            child: Stack(
                              children: _buildLayers(width),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = PuzzleAdventureScreen.levelCount;
    final progress = _progress.clamp(0, total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LEVEL $progress / $total',
                style: ChessText.label.copyWith(
                  color: ChessPalette.text,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '${_solved.length} puzzles solved',
                style: ChessText.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress / total,
              minHeight: 6,
              color: ChessPalette.gold,
              backgroundColor: ChessPalette.surfaceHigh,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLayers(double width) {
    final children = <Widget>[];

    // Dotted path first (nodes and clouds paint over it).
    for (var level = 1; level < PuzzleAdventureScreen.levelCount; level++) {
      children.addAll(_buildPathDots(level, width));
    }

    // Levels themselves.
    for (var level = 1; level <= PuzzleAdventureScreen.levelCount; level++) {
      final state = _stateOf(level);
      final cx = _centerX(level, width);
      final cy = _centerY(level);
      if (state == _NodeState.cloud) {
        children.add(Positioned(
          left: cx - 70,
          top: cy - 44,
          child: GestureDetector(
            onTap: () => _tapLevel(level, state),
            behavior: HitTestBehavior.opaque,
            child: _buildCloud(140),
          ),
        ));
      } else {
        children.add(Positioned(
          left: cx - _node / 2,
          top: cy - _node / 2,
          child: GestureDetector(
            onTap: () => _tapLevel(level, state),
            behavior: HitTestBehavior.opaque,
            child: _buildNode(level, state),
          ),
        ));
      }
    }

    // Peak decoration: a star waits above the top level.
    final peakX = _centerX(PuzzleAdventureScreen.levelCount, width);
    children.add(Positioned(
      left: peakX - 26,
      top: _centerY(PuzzleAdventureScreen.levelCount) - 96,
      child: Opacity(
        opacity: 0.9,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: ChessPalette.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: ChessPalette.borderStrong),
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: ChessPalette.gold,
            size: 26,
          ),
        ),
      ),
    ));

    return children;
  }

  /// Three fading dots between two levels; stops short when the upper level
  /// disappears into the clouds.
  List<Widget> _buildPathDots(int level, double width) {
    final below = _stateOf(level);
    final above = _stateOf(level + 1);
    final x1 = _centerX(level, width);
    final y1 = _centerY(level);
    final x2 = _centerX(level + 1, width);
    final y2 = _centerY(level + 1);

    final traveled = below == _NodeState.cleared;
    final color = traveled
        ? ChessPalette.gold.withValues(alpha: 0.65)
        : ChessPalette.borderStrong;

    final stops = above == _NodeState.cloud
        ? <double>[0.35] // the path walks into the mist and stops
        : <double>[0.3, 0.55, 0.8];
    final dots = <Widget>[];
    for (final t in stops) {
      dots.add(Positioned(
        left: x1 + (x2 - x1) * t - 4,
        top: y1 + (y2 - y1) * t - 4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ));
    }
    return dots;
  }

  Widget _buildNode(int level, _NodeState state) {
    switch (state) {
      case _NodeState.cleared:
        return _nodeShell(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD166), Color(0xFFD9991A)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          child: const Icon(Icons.star_rounded,
              color: Colors.white, size: 30),
          badge: _numberBadge(level, dark: true),
        );
      case _NodeState.current:
        final scale = Tween<double>(begin: 1.0, end: 1.07).animate(
          CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
        );
        return ScaleTransition(
          scale: scale,
          child: _nodeShell(
            color: ChessPalette.surfaceHigh,
            border: Border.all(color: ChessPalette.accent, width: 3),
            child: Text(
              '$level',
              style: ChessText.title.copyWith(fontSize: 22),
            ),
            badge: _numberBadge(level, accent: true),
          ),
        );
      case _NodeState.locked:
        return _nodeShell(
          color: ChessPalette.surfaceAlt,
          border: Border.all(color: ChessPalette.border),
          child: Text(
            '$level',
            style: ChessText.title.copyWith(
              fontSize: 20,
              color: ChessPalette.textFaint,
            ),
          ),
          badge: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: ChessPalette.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 13,
              color: ChessPalette.textFaint,
            ),
          ),
        );
      case _NodeState.cloud:
        return const SizedBox.shrink(); // handled by the cloud layer
    }
  }

  Widget _nodeShell({
    Color? color,
    Gradient? gradient,
    required Border border,
    required Widget child,
    Widget? badge,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _node,
          height: _node,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            shape: BoxShape.circle,
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: child),
        ),
        if (badge != null)
          Positioned(right: -6, bottom: -4, child: badge),
      ],
    );
  }

  Widget _numberBadge(int level, {bool dark = false, bool accent = false}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: dark
            ? ChessPalette.background
            : accent
                ? ChessPalette.accent
                : ChessPalette.surface,
        shape: BoxShape.circle,
        border: Border.all(color: ChessPalette.borderStrong),
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: dark ? ChessPalette.gold : Colors.white,
        ),
      ),
    );
  }

  /// Soft overlapping puffs with a faint "?" — the level behind is hidden.
  Widget _buildCloud(double width) {
    const color = Color(0x2EFFFFFF);
    Widget puff(double size, {double? left, double? right, double? bottom}) =>
        Positioned(
          left: left,
          right: right,
          bottom: bottom ?? 0,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );

    return SizedBox(
      width: width,
      height: width * 0.66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          puff(width * 0.5, left: 0),
          puff(width * 0.64, left: width * 0.18, bottom: width * 0.1),
          puff(width * 0.5, right: 0),
          Positioned.fill(
            child: Center(
              child: Text(
                '?',
                style: ChessText.display.copyWith(
                  color: ChessPalette.textFaint,
                  fontSize: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
