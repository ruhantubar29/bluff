import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../logic/game_logic.dart';
import '../widgets/glow_background.dart';

/// Greyscales and dims the side nobody picked, mirroring the original's
/// `grayscale(1) brightness(.4)`.
const List<double> _loseMatrix = <double>[
  0.0850, 0.2861, 0.0289, 0, 0,
  0.0850, 0.2861, 0.0289, 0, 0,
  0.0850, 0.2861, 0.0289, 0, 0,
  0, 0, 0, 1, 0,
];

class WouldYouRatherGameScreen extends StatefulWidget {
  const WouldYouRatherGameScreen({
    super.key,
    required this.selectedCategoryIds,
  });

  final List<String> selectedCategoryIds;

  @override
  State<WouldYouRatherGameScreen> createState() =>
      _WouldYouRatherGameScreenState();
}

class _WouldYouRatherGameScreenState extends State<WouldYouRatherGameScreen>
    with SingleTickerProviderStateMixin {
  /// Drives both halves of the card choreography. Entering runs it 0→1 from
  /// off-stage to in place; leaving runs it 0→1 from in place to off-stage.
  /// One controller is enough because only one of the two is ever in flight.
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late WouldYouRatherGameLogic _game;

  /// True while the cards are flying away to make room for the next dilemma.
  bool _leaving = false;

  bool _revealed = false;
  int? _picked;

  /// Advances on every reveal and every advance, so the palette steps through
  /// the category's colours exactly as the original did.
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _game = WouldYouRatherGameLogic(
      selectedCategoryIds: widget.selectedCategoryIds,
      language: LanguageSettings.instance.language,
    );
    _move.addStatusListener(_onMoveStatus);
    // The controller's value is read during build, so every tick has to ask
    // for a frame — without this the cards never leave progress 0.
    _move.addListener(_onMoveTick);
    // Fly the first pair in; without this the deck sits at progress 0 —
    // translated off-stage and fully transparent — forever.
    _move.forward();
  }

  void _onMoveTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  void _onMoveStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_leaving) return;

    setState(() {
      _game.nextQuestion();
      _revealed = false;
      _picked = null;
      _step++;
      _leaving = false;
      _move.duration = const Duration(milliseconds: 650);
      _move.value = 0;
    });
    _move.forward();
  }

  void _pick(int side) {
    if (_revealed || _leaving) return;
    HapticFeedback.lightImpact();
    setState(() {
      _revealed = true;
      _picked = side;
      _step++;
    });
  }

  void _next() {
    if (!_revealed || _leaving) return;
    HapticFeedback.lightImpact();
    setState(() {
      _leaving = true;
      _move.duration = const Duration(milliseconds: 480);
      _move.value = 0;
    });
    _move.forward();
  }

  int get _percent {
    final question = _game.currentQuestion;
    if (question == null) return 0;
    return WouldYouRatherGameLogic.percentageFor(question.en);
  }

  @override
  Widget build(BuildContext context) {
    final category = _game.currentCategory;
    final options = _game.currentOptions;
    final language = LanguageSettings.instance.language;

    if (category == null || !_game.hasQuestions) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0D14),
        body: Center(
          child: Text(
            'No questions available.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    final warm = category.warmAt(_step);
    final cool = category.coolAt(_step);
    final warmNext = category.warmAt(_step + 1);
    final coolNext = category.coolAt(_step + 1);
    final isBangla = language == AppLanguage.bangla;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GlowBackground(warm: warm, cool: cool),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  icon: category.icon,
                  title: category.name(language),
                  count: '${_game.position} / ${_game.deckLength}',
                  onClose: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: _OptionCard(
                              text: options[0],
                              gradient: [warm, warmNext],
                              progress: _move.value,
                              leaving: _leaving,
                              side: 0,
                              revealed: _revealed,
                              isWinner: _revealed && _picked == 0,
                              percent: _percent,
                              onTap: () => _pick(0),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _OptionCard(
                              text: options[1],
                              gradient: [cool, coolNext],
                              progress: _move.value,
                              leaving: _leaving,
                              side: 1,
                              revealed: _revealed,
                              isWinner: _revealed && _picked == 1,
                              percent: _percent,
                              onTap: () => _pick(1),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: _OrDisc(
                          revealed: _revealed,
                          percent: _percent,
                          color: _picked == 0 ? warm : cool,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 96,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _revealed
                          ? _NextButton(onPressed: _next)
                          : Text(
                              isBangla
                                  ? 'একটা পাশে ট্যাপ করো'
                                  : 'Tap an option to choose',
                              key: const ValueKey('hint'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.icon,
    required this.title,
    required this.count,
    required this.onClose,
  });

  final String icon;
  final String title;
  final String count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            count,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _OrDisc extends StatelessWidget {
  const _OrDisc({
    required this.revealed,
    required this.percent,
    required this.color,
  });

  final bool revealed;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          radius: 0.86,
          stops: const [0, 0.55, 0.56],
          colors: revealed
              ? [color, color, const Color(0xFFD0D0D4)]
              : [Colors.white, Colors.white, const Color(0xFFCFCFD4)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: revealed
            ? TweenAnimationBuilder<double>(
                key: ValueKey(percent),
                tween: Tween(begin: 0, end: percent.toDouble()),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  '${value.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : const Text(
                'OR',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: 0.9 + 0.1 * value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111111),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: const Text(
          'NEXT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.text,
    required this.gradient,
    required this.progress,
    required this.leaving,
    required this.side,
    required this.revealed,
    required this.isWinner,
    required this.percent,
    required this.onTap,
  });

  final String text;
  final List<Color> gradient;

  /// Raw travel value, 0 → 1. What that means depends on [leaving].
  final double progress;

  /// True while the cards fly away, false while they arrive.
  final bool leaving;

  /// 0 is the top card, 1 the bottom.
  final int side;
  final bool revealed;
  final bool isWinner;
  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Arrive from one side and leave through the other, mirrored for the
    // bottom card, so the pair crosses through each other as they swap.
    final enterX = side == 0 ? 1.10 : -1.10;
    final exitX = side == 0 ? -1.15 : 1.15;
    final enterRot = side == 0 ? -0.6283 : 0.6283; // ±36°
    final exitRot = side == 0 ? -0.7679 : 0.7679; // ±44°

    final double dx, rot, scale, opacity;
    if (leaving) {
      dx = exitX * progress;
      rot = exitRot * progress;
      scale = 1 - 0.15 * progress;
      opacity = 1 - progress;
    } else {
      dx = enterX * (1 - progress);
      rot = enterRot * (1 - progress);
      scale = 0.85 + 0.15 * progress;
      opacity = progress;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final card = GestureDetector(
          onTap: revealed ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              border: isWinner
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fontSizeFor(text),
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  child: revealed
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '$percent% chose this',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(width: 0, height: 0),
                ),
              ],
            ),
          ),
        );

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            // Built as T·R so the card turns in place and then moves, which is
            // what `translateX() rotateY()` does in CSS.
            transform: Matrix4.translationValues(
                dx * constraints.maxWidth, 0, 0)
              ..rotateY(rot)
              ..setEntry(3, 2, 0.0012),
            child: Transform.scale(
              scale: scale,
              // Only the losing side pays for a colour filter.
              child: revealed && !isWinner
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix(_loseMatrix),
                      child: card,
                    )
                  : card,
            ),
          ),
        );
      },
    );
  }

  static double _fontSizeFor(String text) {
    if (text.length <= 22) return 30;
    if (text.length <= 38) return 25;
    if (text.length <= 54) return 21;
    return 18;
  }
}
