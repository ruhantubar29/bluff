import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/bluff_button.dart';
import '../logic/game_logic.dart';

const _correct = Color(0xff22c55e);
const _wrong = Color(0xffef4444);
const _label = Color(0xff374151);

enum _Phase { playing, revealing, over, won }

enum _OptState { idle, correct, wrong, dim }

class GuessTheFlagScreen extends StatefulWidget {
  const GuessTheFlagScreen({super.key});

  @override
  State<GuessTheFlagScreen> createState() => _GuessTheFlagScreenState();
}

class _GuessTheFlagScreenState extends State<GuessTheFlagScreen>
    with SingleTickerProviderStateMixin {
  late GuessTheFlagLogic _logic;
  late AnimationController _timer;

  _Phase _phase = _Phase.playing;

  /// The wrong label the player tapped, if any — it turns red and shakes.
  String? _picked;

  Timer? _pending;

  /// Bumped on every correct answer so the "+points" popup replays.
  int _gainToken = 0;
  int _gainPoints = 0;

  @override
  void initState() {
    super.initState();

    _logic = GuessTheFlagLogic();

    _timer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: roundSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onTimeout();
        }
      });

    _startRound();
  }

  @override
  void dispose() {
    _pending?.cancel();
    _timer.dispose();
    super.dispose();
  }

  void _startRound() {
    _logic.loadRound();

    _phase = _Phase.playing;
    _picked = null;

    _timer.forward(from: 0);
  }

  void _restart() {
    _pending?.cancel();

    setState(() {
      _logic = GuessTheFlagLogic();
      _gainToken = 0;
      _gainPoints = 0;
      _startRound();
    });
  }

  void _onTap(String selected) {
    // Locked: the first tap wins, every later tap is ignored.
    if (_phase != _Phase.playing || _logic.answered) return;

    _logic.answered = true;
    _timer.stop();

    if (selected == _logic.current.name) {
      HapticFeedback.lightImpact();

      final points = _logic.pointsFor(roundSeconds * (1 - _timer.value));

      _logic.score += points;
      _logic.streak++;
      _gainPoints = points;
      _gainToken++;

      setState(() => _phase = _Phase.revealing);

      _pending = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;

        setState(() {
          _logic.advance();

          if (_logic.deckFinished) {
            _phase = _Phase.won;
          } else {
            _startRound();
          }
        });
      });
    } else {
      HapticFeedback.heavyImpact();

      setState(() {
        _phase = _Phase.revealing;
        _picked = selected;
      });

      _pending = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        setState(() => _phase = _Phase.over);
      });
    }
  }

  void _onTimeout() {
    if (_phase != _Phase.playing || _logic.answered) return;

    _logic.answered = true;

    setState(() => _phase = _Phase.revealing);

    _pending = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      setState(() => _phase = _Phase.over);
    });
  }

  _OptState _stateFor(String label) {
    if (_phase == _Phase.playing) return _OptState.idle;

    if (label == _logic.current.name) return _OptState.correct;
    if (label == _picked) return _OptState.wrong;

    return _OptState.dim;
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _phase == _Phase.over || _phase == _Phase.won;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Guess The Flag',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isDone
          ? _EndScreen(
              won: _phase == _Phase.won,
              score: _logic.score,
              onRetry: _restart,
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    _buildCard(),
                    const SizedBox(height: 18),
                    Expanded(child: _buildOptions()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u{1F451}', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 7),
              Text(
                '${_logic.streak}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _label,
                ),
              ),
            ],
          ),
        ),
        Text(
          'INTELLIGENCE TEST',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final country = _logic.current;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            country.colors.first,
            country.colors.length > 1
                ? country.colors[1]
                : country.colors.first,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: _logic.score),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              '$value',
              style: const TextStyle(
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'TOTAL SCORE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Text(
                  country.flagEmoji,
                  style: const TextStyle(
                    fontSize: 110,
                    height: 1.05,
                    // The theme's NotoSans has no regional indicators, so
                    // Android's fallback lands on a font holding the bare
                    // letters but no flag ligature — IN, ID, not a flag.
                    // Flags live in their own system font; the main emoji
                    // font has no regional indicators at all, so both are
                    // listed for devices that predate the split.
                    fontFamilyFallback: [
                      'Noto Color Emoji Flags',
                      'Noto Color Emoji',
                    ],
                  ),
                ),
              ),
              if (_gainToken > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_gainToken),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(
                      opacity: value < 0.2
                          ? value / 0.2
                          : (1 - value) / 0.8,
                      child: Transform.translate(
                        offset: Offset(0, -50 * value),
                        child: child,
                      ),
                    ),
                    child: Text(
                      '+$_gainPoints',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimerBar(),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    return SizedBox(
      width: double.infinity,
      height: 10,
      child: AnimatedBuilder(
        animation: _timer,
        builder: (context, _) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(99),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Container(
                    width:
                        constraints.maxWidth * (1 - _timer.value),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptions() {
    final labels = _logic.options;

    return Column(
      // Rebuilt from scratch every round so animations never replay stale.
      key: ValueKey(_logic.roundIndex),
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _option(labels[0])),
              const SizedBox(width: 12),
              Expanded(child: _option(labels[1])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _option(labels[2])),
              const SizedBox(width: 12),
              Expanded(child: _option(labels[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option(String label) {
    return _OptionButton(
      label: label,
      state: _stateFor(label),
      onTap: _phase == _Phase.playing
          ? () => _onTap(label)
          : null,
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCorrect = state == _OptState.correct;
    final isWrong = state == _OptState.wrong;
    final isDim = state == _OptState.dim;

    final background = isCorrect
        ? _correct
        : isWrong
            ? _wrong
            : Colors.white;

    final foreground = isCorrect || isWrong
        ? Colors.white
        : _label;

    return AnimatedOpacity(
      opacity: isDim ? 0.5 : 1,
      duration: const Duration(milliseconds: 300),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isWrong ? 1 : 0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(math.sin(value * math.pi * 4) * 6, 0),
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndScreen extends StatelessWidget {
  const _EndScreen({
    required this.won,
    required this.score,
    required this.onRetry,
  });

  final bool won;
  final int score;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? '\u{1F3C6}' : '\u{1F480}',
              style: const TextStyle(fontSize: 76),
            ),
            const SizedBox(height: 18),
            Text(
              won ? 'World Conqueror!' : 'Game Over!',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              won
                  ? 'You have mastered every flag on Earth!'
                  : 'Your intelligence was not enough for this round.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 26),
            Container(
              width: 230,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    'FINAL SCORE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: _label,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            BluffButton(
              text: 'TRY AGAIN',
              onPressed: onRetry,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('GAMES MENU'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _label,
                side: BorderSide(
                  color: Colors.grey.shade400,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
