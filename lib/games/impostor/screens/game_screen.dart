// game_screen.dart
//
// BLUFFᴮᴰ Impostor reveal screen
// Sketchbook / doodle style.
//
// Uses the existing BLUFF ImpostorRound mechanics while keeping the
// sketchbook reveal design.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/impostor_round.dart';
import 'vote_screen.dart';

// ───────────────────────── Palette & type ─────────────────────────

const _paper = Color(0xFFFFF3DC);
const _ink = Color(0xFF1B1013);
const _marker = Color(0xFFFFD23F);
const _mint = Color(0xFF9BE28A);
const _sky = Color(0xFF7FD6FF);
const _pink = Color(0xFFFF8FB1);
const _lav = Color(0xFFC9A7FF);
const _orange = Color(0xFFFFA45C);
const _red = Color(0xFFD92F45);

const _artColors = [
  _sky,
  _pink,
  _mint,
  _lav,
  _orange,
];

// There are 20 character PNGs:
// character_1.png ... character_20.png
const int _characterCount = 20;

TextStyle _t(
  double size, {
  Color color = _ink,
  FontWeight w = FontWeight.w700,
}) {
  return GoogleFonts.atma(
    fontSize: size,
    fontWeight: w,
    color: color,
    height: 1.15,
  );
}

// ───────────────────────── Game Screen ─────────────────────────

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.round,
  });

  final ImpostorRound round;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final List<int> revealOrder;
  late final List<int> characterIndexes;

  int step = 0;

  ImpostorRound get round => widget.round;

  int get currentPlayerIndex => revealOrder[step];

  bool get isLastPlayer => step == revealOrder.length - 1;

  @override
  void initState() {
    super.initState();

    // Randomize the order in which players receive their secret.
    revealOrder = List<int>.generate(
      round.players.length,
      (index) => index,
    )..shuffle(math.Random());

    // Give each player one of the 20 characters.
    characterIndexes = _buildCharacterIndexes(
      round.players.length,
    );
  }

  /// Gives every player a character.
  ///
  /// Characters are shuffled and won't repeat until all 20
  /// characters have been used.
  static List<int> _buildCharacterIndexes(int playerCount) {
    final random = math.Random();

    final result = <int>[];
    var bag = <int>[];

    for (var i = 0; i < playerCount; i++) {
      if (bag.isEmpty) {
        bag = List<int>.generate(
          _characterCount,
          (index) => index,
        )..shuffle(random);
      }

      result.add(bag.removeAt(0));
    }

    return result;
  }

  String _characterAsset(int characterIndex) {
    return 'assets/images/characters/character_${characterIndex + 1}.png';
  }

  void _nextPlayer() {
    if (isLastPlayer) {
      _showRoundReady();
      return;
    }

    setState(() {
      step++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerIndex = currentPlayerIndex;
    final player = round.players[playerIndex];

    final isImpostor = round.isImpostor(playerIndex);

    final hint = round.hint?.trim();
    final cleanHint =
        hint == null || hint.isEmpty ? null : hint;

    return RevealScreen(
      key: ValueKey(
        '${playerIndex}_$step',
      ),
      playerName: player.name,
      playerIndex: step,
      total: revealOrder.length,
      isImpostor: isImpostor,
      secretTitle:
          isImpostor ? 'Impostor' : round.secretWord,

      // IMPORTANT:
      // Only the impostor receives the hint.
      secretHint: isImpostor ? cleanHint : null,

      characterAsset: _characterAsset(
        characterIndexes[playerIndex],
      ),
      onNext: _nextPlayer,
      onClose: () {
        Navigator.of(context).maybePop();
      },
      title: 'Impostor',
      pullHint: 'Move up to reveal',
      instruction:
          'Drag your card up to reveal the word. Make sure no one else sees it.',
      nextLabel: isLastPlayer ? 'Start' : 'Next Player',
      lastLabel: 'Start',
      passHint: 'Pass device to the next player',
    );
  }

  void _showRoundReady() {
    final startingIndex = round.startingPlayerIndex;

    final startingPlayer = startingIndex == null
        ? null
        : round.players[startingIndex];

    showModalBottomSheet(
      context: context,
      backgroundColor: _paper,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              20,
              22,
              22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _ink.withAlpha(45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Transform.rotate(
                  angle: -0.02,
                  child: Text(
                    'DISCUSSION TIME',
                    textAlign: TextAlign.center,
                    style: _t(
                      30,
                      color: _ink,
                      w: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const CustomPaint(
                  size: Size(130, 10),
                  painter: _SquigglePainter(_red),
                ),
                const SizedBox(height: 14),
                if (startingPlayer != null)
                  Text(
                    '${startingPlayer.name} will start',
                    textAlign: TextAlign.center,
                    style: _t(
                      20,
                      color: _ink,
                      w: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VoteScreen(
                          round: round,
                        ),
                      ),
                    );
                  },
                  child: _SketchBox(
                    fill: _marker,
                    radius: 20,
                    seed: 41,
                    shadow: const Offset(4, 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'VOTE NOW',
                          style: _t(
                            22,
                            color: _ink,
                            w: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.how_to_vote_rounded,
                          color: _ink,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Reveal Screen ─────────────────────────

class RevealScreen extends StatefulWidget {
  const RevealScreen({
    super.key,
    required this.playerName,
    required this.playerIndex,
    required this.total,
    required this.secretTitle,
    required this.onNext,
    this.onClose,
    this.title = 'Impostor',
    this.secretHint,
    this.isImpostor = false,
    this.characterAsset,
    this.idleAnimation = true,
    this.pullHint = 'Move up to reveal',
    this.instruction =
        'Drag your card up to reveal the word. Make sure no one else sees it.',
    this.nextLabel,
    this.lastLabel = 'Start',
    this.passHint = 'Pass device to the next player',
  });

  final String playerName;
  final int playerIndex;
  final int total;

  final String secretTitle;
  final String? secretHint;

  final bool isImpostor;

  final String? characterAsset;

  final bool idleAnimation;

  final String title;
  final String pullHint;
  final String instruction;

  final String lastLabel;
  final String passHint;
  final String? nextLabel;

  final VoidCallback onNext;
  final VoidCallback? onClose;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen>
    with TickerProviderStateMixin {
  static const _cardRatio = 3 / 4;

  late final AnimationController _reveal =
      AnimationController(
    vsync: this,
    upperBound: 1.0,
  )..addListener(_watchPeek);

  late final AnimationController _hop =
      AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 1500,
    ),
  )..repeat();

  late final AnimationController _idle =
      AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 2600,
    ),
  )..repeat(reverse: true);

  bool _peeked = false;

  bool get _isLast =>
      widget.playerIndex >= widget.total - 1;

  void _watchPeek() {
    if (!_peeked &&
        _reveal.value > 0.4 &&
        mounted) {
      setState(() {
        _peeked = true;
      });
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _hop.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _release() {
    _reveal.animateBack(
      0,
      duration: const Duration(
        milliseconds: 300,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  double _hopOffset(double t) {
    if (t < 0.3) {
      return math.sin(
        math.pi * t / 0.3,
      );
    }

    if (t < 0.5) {
      return 0.4 *
          math.sin(
            math.pi * (t - 0.3) / 0.2,
          );
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _red,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _DoodleBgPainter(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ───────────────── Header ─────────────────

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    22,
                    10,
                    8,
                    0,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: _t(
                              32,
                              color: _paper,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const CustomPaint(
                            size: Size(96, 10),
                            painter: _SquigglePainter(
                              _paper,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // ───────── Progress ─────────

                      _ProgressBadge(
                        current:
                            widget.playerIndex + 1,
                        total: widget.total,
                      ),

                      const SizedBox(width: 2),

                      // ───────── Close ─────────

                      GestureDetector(
                        behavior:
                            HitTestBehavior.opaque,
                        onTap: widget.onClose ??
                            () => Navigator.of(
                                  context,
                                ).maybePop(),
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: CustomPaint(
                            size: Size(26, 26),
                            painter: _GlyphPainter(
                              check: false,
                              color: _paper,
                              width: 4.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ───────────────── Card ─────────────────

                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 26,
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        var w = c.maxWidth;
                        var h = w / _cardRatio;

                        if (h > c.maxHeight - 24) {
                          h = c.maxHeight - 24;
                          w = h * _cardRatio;
                        }

                        return Center(
                          child: Transform.rotate(
                            angle: -0.02,
                            child: SizedBox(
                              width: w,
                              height: h,
                              child: GestureDetector(
                                onVerticalDragUpdate:
                                    (d) {
                                  _reveal.value =
                                      (_reveal.value -
                                              d.delta.dy /
                                                  h)
                                          .clamp(
                                            0.0,
                                            1.0,
                                          )
                                          .toDouble();
                                },
                                onVerticalDragEnd:
                                    (_) => _release(),
                                onVerticalDragCancel:
                                    _release,
                                child:
                                    AnimatedBuilder(
                                  animation: _reveal,
                                  builder: (_, __) =>
                                      Stack(
                                    clipBehavior:
                                        Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child:
                                            _SecretPanel(
                                          title: widget
                                              .secretTitle,
                                          hint: widget
                                              .secretHint,
                                          isImpostor: widget
                                              .isImpostor,
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: Offset(
                                          0,
                                          -_reveal.value *
                                              (h + 30),
                                        ),
                                        child: SizedBox(
                                          width: w,
                                          height: h,
                                          child:
                                              _FrontCard(
                                            name: widget
                                                .playerName,
                                            asset: widget
                                                .characterAsset,
                                            pullHint: widget
                                                .pullHint,
                                            idle: widget
                                                    .idleAnimation
                                                ? _idle
                                                : null,
                                            artColor:
                                                _artColors[
                                              widget.playerIndex %
                                                  _artColors
                                                      .length
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ───────────────── Bottom ─────────────────

                SizedBox(
                  height: 150,
                  child: AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 250,
                    ),
                    child: _peeked
                        ? Column(
                            key: const ValueKey(
                              'next',
                            ),
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _hop,
                                builder: (_, child) =>
                                    Transform.translate(
                                  offset: Offset(
                                    0,
                                    -16 *
                                        _hopOffset(
                                          _hop.value,
                                        ),
                                  ),
                                  child: child,
                                ),
                                child: GestureDetector(
                                  onTap: widget.onNext,
                                  child: _SketchBox(
                                    fill: _marker,
                                    radius: 28,
                                    seed: 21,
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 30,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      widget.nextLabel ??
                                          (_isLast
                                              ? widget
                                                  .lastLabel
                                              : 'Next Player'),
                                      style: _t(24),
                                    ),
                                  ),
                                ),
                              ),
                              if (!_isLast) ...[
                                const SizedBox(
                                  height: 18,
                                ),
                                Text(
                                  widget.passHint,
                                  style: _t(
                                    19,
                                    color: _paper,
                                    w: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Padding(
                            key: const ValueKey(
                              'instruction',
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 30,
                            ),
                            child: Center(
                              child: Text(
                                widget.instruction,
                                textAlign:
                                    TextAlign.center,
                                style: _t(
                                  19,
                                  color: _paper,
                                  w: FontWeight.w500,
                                ).copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Progress Badge ─────────────────────────

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0
        ? 0.0
        : (current / total).clamp(0.0, 1.0);

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0x26FFF3DC),
        border: Border.all(
          color: const Color(0x66FFF3DC),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$current/$total',
            style: _t(
              17,
              color: _paper,
              w: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 5,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(
                    color: const Color(0x33FFF3DC),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      color: _marker,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Front Card ─────────────────────────

class _FrontCard extends StatelessWidget {
  const _FrontCard({
    required this.name,
    required this.asset,
    required this.pullHint,
    required this.artColor,
    this.idle,
  });

  final String name;
  final String pullHint;
  final String? asset;
  final Color artColor;
  final Animation<double>? idle;

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(
      child: Text(
        '🎭',
        style: TextStyle(
          fontSize: 110,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _SketchBox(
            fill: _paper,
            radius: 30,
            seed: 3,
            padding: const EdgeInsets.fromLTRB(
              12,
              20,
              12,
              10,
            ),
            child: Column(
              children: [
                Transform.rotate(
                  angle: -0.03,
                  child: _SketchBox(
                    fill: _marker,
                    radius: 14,
                    strokeWidth: 3,
                    shadow: const Offset(3, 4),
                    seed: 5,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        style: _t(36),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ───────── Character Area ─────────

                Expanded(
                  child: _SketchBox(
                    fill: artColor,
                    radius: 22,
                    strokeWidth: 3,
                    shadow: Offset.zero,
                    seed: 4,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const CustomPaint(
                            painter: _HatchPainter(),
                          ),
                          _Idle(
                            animation: idle,
                            child: asset == null
                                ? placeholder
                                : Image.asset(
                                    asset!,
                                    fit: BoxFit.contain,
                                    alignment:
                                        Alignment
                                            .bottomCenter,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            placeholder,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      const CustomPaint(
                        size: Size(24, 32),
                        painter: _ArrowPainter(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pullHint,
                        style: _t(22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tape

        Positioned(
          top: -10,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: 0.06,
              child: Container(
                width: 84,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xCCFFD23F),
                  borderRadius:
                      BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0x331B1013),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Idle Character ─────────────────────────

class _Idle extends StatelessWidget {
  const _Idle({
    required this.animation,
    required this.child,
  });

  final Animation<double>? animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = animation;

    if (a == null) {
      return child;
    }

    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(
          a.value,
        );

        return Transform.translate(
          offset: Offset(
            0,
            -6 * t,
          ),
          child: Transform.rotate(
            angle: (t - 0.5) * 0.05,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scale: 1 + 0.025 * t,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Secret Panel ─────────────────────────

class _SecretPanel extends StatelessWidget {
  const _SecretPanel({
    required this.title,
    required this.hint,
    required this.isImpostor,
  });

  final String title;
  final String? hint;
  final bool isImpostor;

  @override
  Widget build(BuildContext context) {
    final panel = isImpostor ? _ink : _mint;
    final stroke = isImpostor ? _paper : _ink;
    final textColor = isImpostor ? _paper : _ink;

    return _SketchBox(
      fill: panel,
      stroke: stroke,
      radius: 30,
      seed: 9,
      child: Align(
        alignment: const Alignment(0, 0.62),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: _SketchBox(
                fill: isImpostor
                    ? _red
                    : _marker,
                stroke: stroke,
                radius: 33,
                shadow: const Offset(3, 4),
                seed: 11,
                child: Center(
                  child: CustomPaint(
                    size: const Size(
                      28,
                      28,
                    ),
                    painter: _GlyphPainter(
                      check: !isImpostor,
                      color: _ink,
                      width: 5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _t(
                  46,
                  color: textColor,
                ),
              ),
            ),
            CustomPaint(
              size: const Size(
                110,
                10,
              ),
              painter: _SquigglePainter(
                isImpostor ? _red : _ink,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(
                height: 12,
              ),
              _SketchBox(
                fill: _marker,
                radius: 14,
                strokeWidth: 3,
                shadow: const Offset(3, 4),
                seed: 13,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: _t(
                    17,
                    w: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Sketch Box ─────────────────────────

class _SketchBox extends StatelessWidget {
  const _SketchBox({
    required this.fill,
    this.stroke = _ink,
    this.shadowColor = _ink,
    this.radius = 24,
    this.strokeWidth = 3.5,
    this.shadow = const Offset(5, 6),
    this.seed = 1,
    this.padding = EdgeInsets.zero,
    this.child,
  });

  final Color fill;
  final Color stroke;
  final Color shadowColor;
  final double radius;
  final double strokeWidth;
  final Offset shadow;
  final int seed;
  final EdgeInsets padding;
  final Widget? child;

  static const _jitter = 1.6;

  @override
  Widget build(BuildContext context) {
    final inset =
        strokeWidth + _jitter + 1;

    return CustomPaint(
      painter: _SketchPainter(
        fill: fill,
        stroke: stroke,
        shadowColor: shadowColor,
        radius: radius,
        strokeWidth: strokeWidth,
        shadow: shadow,
        seed: seed,
        inset: inset,
      ),
      child: Padding(
        padding: padding +
            EdgeInsets.fromLTRB(
              inset,
              inset,
              inset + shadow.dx,
              inset + shadow.dy,
            ),
        child: child,
      ),
    );
  }
}

// ───────────────────────── Sketch Painter ─────────────────────────

class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.fill,
    required this.stroke,
    required this.shadowColor,
    required this.radius,
    required this.strokeWidth,
    required this.shadow,
    required this.seed,
    required this.inset,
  });

  final Color fill;
  final Color stroke;
  final Color shadowColor;
  final double radius;
  final double strokeWidth;
  final double inset;
  final Offset shadow;
  final int seed;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width -
          inset * 2 -
          shadow.dx,
      size.height -
          inset * 2 -
          shadow.dy,
    );

    if (rect.width <= 4 ||
        rect.height <= 4) {
      return;
    }

    final r = math.min(
      radius,
      rect.shortestSide / 2,
    );

    final base = _wobblyRRect(
      rect,
      r,
      math.Random(seed),
      _SketchBox._jitter,
    );

    if (shadow != Offset.zero) {
      canvas.drawPath(
        base.shift(shadow),
        Paint()..color = shadowColor,
      );
    }

    canvas.drawPath(
      base,
      Paint()..color = fill,
    );

    canvas.drawPath(
      base,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final second = _wobblyRRect(
      rect.inflate(1.4),
      r,
      math.Random(seed + 91),
      _SketchBox._jitter,
    );

    canvas.drawPath(
      second,
      Paint()
        ..color = stroke.withAlpha(170)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(
    covariant _SketchPainter o,
  ) {
    return o.fill != fill ||
        o.stroke != stroke ||
        o.shadowColor != shadowColor ||
        o.radius != radius ||
        o.strokeWidth != strokeWidth ||
        o.shadow != shadow ||
        o.seed != seed ||
        o.inset != inset;
  }
}

// ───────────────────────── Wobbly Shape ─────────────────────────

Path _wobblyRRect(
  Rect rect,
  double radius,
  math.Random rnd,
  double jitter,
) {
  final src = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius),
      ),
    );

  final pts = <Offset>[];

  for (final m in src.computeMetrics()) {
    final steps = math.max(
      8,
      (m.length / 18).round(),
    );

    for (var i = 0; i < steps; i++) {
      final t = m.getTangentForOffset(
        m.length * i / steps,
      );

      if (t == null) {
        continue;
      }

      final n = Offset(
        -t.vector.dy,
        t.vector.dx,
      );

      final j =
          (rnd.nextDouble() * 2 - 1) *
              jitter;

      pts.add(
        t.position + n * j,
      );
    }
  }

  Offset mid(
    Offset a,
    Offset b,
  ) {
    return Offset(
      (a.dx + b.dx) / 2,
      (a.dy + b.dy) / 2,
    );
  }

  final start = mid(
    pts.last,
    pts.first,
  );

  final path = Path()
    ..moveTo(
      start.dx,
      start.dy,
    );

  for (var i = 0; i < pts.length; i++) {
    final p = pts[i];

    final m = mid(
      p,
      pts[(i + 1) % pts.length],
    );

    path.quadraticBezierTo(
      p.dx,
      p.dy,
      m.dx,
      m.dy,
    );
  }

  return path..close();
}

// ───────────────────────── Hatch ─────────────────────────

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rnd = math.Random(2);

    final p = Paint()
      ..color = const Color(0x1F1B1013)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (
      double x = -size.height;
      x < size.width;
      x += 14
    ) {
      canvas.drawLine(
        Offset(
          x + rnd.nextDouble() * 3,
          size.height,
        ),
        Offset(
          x +
              size.height +
              rnd.nextDouble() * 3,
          0,
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}

// ───────────────────────── Squiggle ─────────────────────────

class _SquigglePainter extends CustomPainter {
  const _SquigglePainter(
    this.color,
  );

  final Color color;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final path = Path()
      ..moveTo(
        0,
        size.height / 2,
      );

    for (
      double x = 0;
      x <= size.width;
      x += 3
    ) {
      path.lineTo(
        x,
        size.height / 2 +
            math.sin(x / 6) *
                size.height /
                3,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(
    covariant _SquigglePainter o,
  ) {
    return o.color != color;
  }
}

// ───────────────────────── Check / X ─────────────────────────

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.check,
    required this.color,
    required this.width,
  });

  final bool check;
  final Color color;
  final double width;

  @override
  void paint(
    Canvas canvas,
    Size s,
  ) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = s.width;
    final h = s.height;

    if (check) {
      canvas.drawPath(
        Path()
          ..moveTo(
            w * .12,
            h * .54,
          )
          ..quadraticBezierTo(
            w * .30,
            h * .68,
            w * .40,
            h * .82,
          )
          ..quadraticBezierTo(
            w * .58,
            h * .40,
            w * .90,
            h * .16,
          ),
        p,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(
            w * .14,
            h * .12,
          )
          ..quadraticBezierTo(
            w * .52,
            h * .46,
            w * .88,
            h * .90,
          ),
        p,
      );

      canvas.drawPath(
        Path()
          ..moveTo(
            w * .88,
            h * .10,
          )
          ..quadraticBezierTo(
            w * .46,
            h * .54,
            w * .12,
            h * .88,
          ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _GlyphPainter o,
  ) {
    return o.check != check ||
        o.color != color ||
        o.width != width;
  }
}

// ───────────────────────── Up Arrow ─────────────────────────

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(
    Canvas canvas,
    Size s,
  ) {
    final p = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(
          s.width * .5,
          s.height,
        )
        ..quadraticBezierTo(
          s.width * .58,
          s.height * .5,
          s.width * .5,
          3,
        ),
      p,
    );

    canvas.drawPath(
      Path()
        ..moveTo(
          s.width * .08,
          s.height * .34,
        )
        ..quadraticBezierTo(
          s.width * .3,
          s.height * .2,
          s.width * .5,
          3,
        )
        ..quadraticBezierTo(
          s.width * .7,
          s.height * .2,
          s.width * .94,
          s.height * .32,
        ),
      p,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}

// ───────────────────────── Background Doodles ─────────────────────────

class _DoodleBgPainter extends CustomPainter {
  const _DoodleBgPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rnd = math.Random(7);

    final line = Paint()
      ..color = const Color(0x33FFF3DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final solid = Paint()
      ..color = const Color(0x2EFFF3DC);

    for (var i = 0; i < 18; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );

      switch (i % 4) {
        case 0:
          // Plus

          canvas.drawLine(
            o.translate(-8, 0),
            o.translate(8, 0),
            line,
          );

          canvas.drawLine(
            o.translate(0, -8),
            o.translate(0, 8),
            line,
          );

        case 1:
          // Circle

          canvas.drawCircle(
            o,
            6 + rnd.nextDouble() * 6,
            line,
          );

        case 2:
          // Squiggle

          final path = Path()
            ..moveTo(
              o.dx,
              o.dy,
            );

          for (
            double x = 0;
            x <= 36;
            x += 3
          ) {
            path.lineTo(
              o.dx + x,
              o.dy +
                  math.sin(x / 5) * 4,
            );
          }

          canvas.drawPath(
            path,
            line,
          );

        default:
          // Sparkle

          canvas.drawPath(
            Path()
              ..moveTo(
                o.dx,
                o.dy - 11,
              )
              ..quadraticBezierTo(
                o.dx,
                o.dy,
                o.dx + 11,
                o.dy,
              )
              ..quadraticBezierTo(
                o.dx,
                o.dy,
                o.dx,
                o.dy + 11,
              )
              ..quadraticBezierTo(
                o.dx,
                o.dy,
                o.dx - 11,
                o.dy,
              )
              ..quadraticBezierTo(
                o.dx,
                o.dy,
                o.dx,
                o.dy - 11,
              )
              ..close(),
            solid,
          );
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}