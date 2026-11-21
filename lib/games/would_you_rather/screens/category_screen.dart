import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../data/categories.dart';
import '../widgets/glow_background.dart';

/// Multi-select mood picker.
///
/// Selection is deliberately *not* drawn with radio circles: a hollow circle
/// reads as "pick one" even when the logic accepts many. A picked tile
/// instead lights up in its own category gradient and carries a filled tick,
/// so several can obviously be lit at once.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.selectedCategoryIds});

  final List<String> selectedCategoryIds;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final List<String> _selected = List.of(widget.selectedCategoryIds);

  AppLanguage get _language => LanguageSettings.instance.language;

  void _toggle(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  void _done() => Navigator.pop(context, _selected);

  @override
  Widget build(BuildContext context) {
    final isBangla = _language == AppLanguage.bangla;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: Stack(
        children: [
          const GlowBackground(
            warm: Color(0xFFFF3B30),
            cool: Color(0xFF0A7AFF),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isBangla ? 'ক্যাটাগরি বেছে নাও' : 'Choose categories',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        isBangla
                            ? '${_selected.length}টি নির্বাচিত'
                            : '${_selected.length} selected',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    itemCount: wouldYouRatherCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final category = wouldYouRatherCategories[index];
                      return _CategoryTile(
                        category: category,
                        language: _language,
                        index: index,
                        isSelected: _selected.contains(category.id),
                        onTap: () => _toggle(category.id),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _selected.isEmpty ? null : _done,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD166),
                        foregroundColor: const Color(0xFF111111),
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.1),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        isBangla ? 'হয়ে গেছে' : 'DONE',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.language,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final WouldYouRatherCategory category;
  final AppLanguage language;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(-24 * (1 - value), 0),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [category.warm.first, category.cool.first],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: category.cool.first.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name(language),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.description(language),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // A tick, not a radio dot: several tiles can be lit at once.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('on'),
                        color: Colors.white,
                        size: 26,
                      )
                    : Icon(
                        Icons.add_circle_outline_rounded,
                        key: const ValueKey('off'),
                        color: Colors.white.withValues(alpha: 0.35),
                        size: 26,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
