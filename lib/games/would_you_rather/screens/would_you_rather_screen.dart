import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../../../widgets/bluff_button.dart';
import '../data/categories.dart';
import '../widgets/glow_background.dart';
import 'category_screen.dart';
import 'game_screen.dart';
import 'tutorial_screen.dart';

/// Landing screen for Would You Rather.
///
/// Kept at this path and under this name because both `singleplayer_screen`
/// and `pass_and_play_screen` construct it as `const WouldYouRatherScreen()`.
class WouldYouRatherScreen extends StatefulWidget {
  const WouldYouRatherScreen({super.key});

  @override
  State<WouldYouRatherScreen> createState() => _WouldYouRatherScreenState();
}

class _WouldYouRatherScreenState extends State<WouldYouRatherScreen>
    with SingleTickerProviderStateMixin {
  /// Selected category ids. Several at once — they all shuffle into one deck.
  List<String> _selected = ['classic'];

  /// Slow bob for the logo pills.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  Future<void> _openCategories() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => CategoryScreen(selectedCategoryIds: _selected)),
    );
    if (result != null && mounted) setState(() => _selected = result);
  }

  void _openTutorial() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TutorialScreen()),
    );
  }

  void _play() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WouldYouRatherGameScreen(selectedCategoryIds: _selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageSettings.instance.language;
    final isBangla = language == AppLanguage.bangla;
    final selectedCategories = wouldYouRatherCategories
        .where((category) => _selected.contains(category.id))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const GlowBackground(
            warm: Color(0xFFFF3B30),
            cool: Color(0xFF0A7AFF),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackButton(color: Colors.white),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _Logo(bob: _bob),
                        const SizedBox(height: 18),
                        Text(
                          isBangla
                              ? 'একটা পাশ বেছে নাও। ফেরত নেই।'
                              : 'Pick a side. No take-backs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _SelectionCard(
                          count: selectedCategories.length,
                          summary: selectedCategories.isEmpty
                              ? (isBangla ? 'কোনোটি নেই' : 'None chosen')
                              : selectedCategories
                                  .map((c) => '${c.icon} ${c.name(language)}')
                                  .join('  ·  '),
                          label: isBangla
                              ? 'ক্যাটাগরি বেছে নাও'
                              : 'Choose categories',
                          onTap: _openCategories,
                        ),
                        const SizedBox(height: 16),
                        _GhostButton(
                          label: isBangla ? 'কীভাবে খেলবে' : 'How to play',
                          onTap: _openTutorial,
                        ),
                        const SizedBox(height: 40),
                        BluffButton(
                          text: isBangla ? 'খেলো' : 'PLAY',
                          onPressed: _selected.isEmpty ? null : _play,
                        ),
                      ],
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

class _Logo extends StatelessWidget {
  const _Logo({required this.bob});

  final Animation<double> bob;

  Widget _pill(String text, List<Color> colors, double tilt) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bob,
      builder: (context, _) {
        final t = bob.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, -8 * t),
              child: _pill(
                'Would you',
                const [Color(0xFFFF3B30), Color(0xFFFF9500)],
                -0.052,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFFCFCECD), width: 6),
                  ),
                ),
                child: const Text(
                  'OR',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -8 * (1 - t)),
              child: _pill(
                'rather?',
                const [Color(0xFF0A7AFF), Color(0xFF4FB4FF)],
                0.044,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.count,
    required this.summary,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String summary;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
