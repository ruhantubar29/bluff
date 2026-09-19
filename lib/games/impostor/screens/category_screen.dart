import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../logic/word_deck.dart';

/// ================================================================
/// BLUFF COLORS
/// ================================================================

class BluffColors {
  static const ink = Color(0xFF12080B);
  static const panel = Color(0xFF241118);
  static const panel2 = Color(0xFF33171F);
  static const line = Color(0xFF4A222D);

  static const red = Color(0xFFF0364F);
  static const redDeep = Color(0xFFA8162D);
  static const redLight = Color(0xFFFF7A8C);

  static const cream = Color(0xFFFFEFE3);
  static const muted = Color(0xFFC39AA3);

  static const gold = Color(0xFFFFC94A);
  static const goldTint = Color(0x33FFC94A);

  static const glow = Color(0x47F0364F);

  static const avatars = [
    Color(0xFFFFC94A),
    Color(0xFF7FD6FF),
    Color(0xFFFF8FB1),
    Color(0xFF9BE28A),
    Color(0xFFC9A7FF),
  ];
}

/// ================================================================
/// FONTS
/// ================================================================

TextStyle bluffDisplay(
  double size, {
  Color color = BluffColors.cream,
  FontWeight weight = FontWeight.w800,
  double letterSpacing = 0,
}) {
  return GoogleFonts.balooDa2(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.1,
    letterSpacing: letterSpacing,
  );
}

TextStyle bluffBody(
  double size, {
  Color color = BluffColors.cream,
  FontWeight w = FontWeight.w400,
}) {
  return GoogleFonts.hindSiliguri(
    fontSize: size,
    fontWeight: w,
    color: color,
  );
}

/// ================================================================
/// CATEGORY EMOJIS
/// ================================================================

const Map<String, String> _categoryEmojis = {
  'Animals': '🐾',
  'Food': '🍔',
  'Superheroes': '🦸',
  'Sports': '⚽',
  'Countries': '🌍',
  'Jobs': '💼',
  'Fruits': '🍎',
  'Cartoons': '📺',
  'Brands': '🏷️',
  'Anime': '🍥',
};

/// ================================================================
/// CATEGORY SCREEN
/// ================================================================

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.language,
    required this.selectedCategories,
  });

  final AppLanguage language;
  final List<String> selectedCategories;

  @override
  State<CategoryScreen> createState() =>
      _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late List<String> _categories;
  late Set<String> _picked;

  @override
  void initState() {
    super.initState();

    _categories =
        ImpostorWordDeck.instance.categories(
      widget.language,
    );

    _picked = {...widget.selectedCategories};

    _picked.removeWhere(
      (category) => !_categories.contains(category),
    );
  }

  // ================================================================
  // TOGGLE
  // ================================================================

  void _toggle(String name) {
    setState(() {
      if (_picked.contains(name)) {
        _picked.remove(name);
      } else {
        _picked.add(name);
      }
    });
  }

  // ================================================================
  // SELECT ALL
  // ================================================================

  void _selectAll() {
    setState(() {
      _picked
        ..clear()
        ..addAll(_categories);
    });
  }

  // ================================================================
  // CLEAR
  // ================================================================

  void _clear() {
    setState(() {
      _picked.clear();
    });
  }

  // ================================================================
  // DONE
  // ================================================================

  void _done() {
    final selected = <String>[
      for (final category in _categories)
        if (_picked.contains(category)) category,
    ];

    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final total = _categories.length;
    final count = _picked.length;

    return Scaffold(
      backgroundColor: BluffColors.ink,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, -1.1),
            radius: 1.1,
            colors: [
              BluffColors.glow,
              Color(0x00F0364F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ======================================================
              // HEADER
              // ======================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  0,
                ),
                child: Row(
                  children: [
                    Material(
                      color: BluffColors.panel2,
                      shape: const CircleBorder(
                        side: BorderSide(
                          color: BluffColors.line,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        customBorder:
                            const CircleBorder(),
                        onTap: () {
                          Navigator.of(context)
                              .maybePop();
                        },
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color:
                                BluffColors.cream,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.rotate(
                      angle: -0.035,
                      child: Text(
                        'Categories',
                        style: bluffDisplay(
                          30,
                        ).copyWith(
                          shadows: const [
                            Shadow(
                              color:
                                  BluffColors.redDeep,
                              offset:
                                  Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ======================================================
              // COUNT + QUICK ACTIONS
              // ======================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  8,
                ),
                child: Row(
                  children: [
                    Text(
                      '$count/$total selected',
                      style: bluffDisplay(
                        20,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _LinkButton(
                      'Select all',
                      onTap: _selectAll,
                    ),
                    const SizedBox(width: 16),
                    _LinkButton(
                      'Clear',
                      onTap: _clear,
                    ),
                  ],
                ),
              ),

              // ======================================================
              // CATEGORY GRID
              // ======================================================

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    16,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1 / 0.95,
                  ),
                  itemCount: total,
                  itemBuilder: (_, index) {
                    final category =
                        _categories[index];

                    final selected =
                        _picked.contains(category);

                    final emoji =
                        _categoryEmojis[category] ??
                            '🔸';

                    return _CategoryTile(
                      name: category,
                      emoji: emoji,
                      selected: selected,
                      onTap: () {
                        _toggle(category);
                      },
                    );
                  },
                ),
              ),

              // ======================================================
              // DONE
              // ======================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  18,
                ),
                child: Column(
                  children: [
                    if (count == 0)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: Text(
                          'Select at least one category',
                          style: bluffBody(
                            13.5,
                            color:
                                BluffColors.muted,
                          ),
                        ),
                      ),
                    _ChunkyButton(
                      label: 'DONE',
                      enabled: count > 0,
                      onTap: _done,
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
}

/// ================================================================
/// LINK BUTTON
/// ================================================================

class _LinkButton extends StatelessWidget {
  const _LinkButton(
    this.label, {
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Text(
          label,
          style: bluffBody(
            14,
            color: BluffColors.gold,
            w: FontWeight.w600,
          ).copyWith(
            decoration:
                TextDecoration.underline,
            decorationColor:
                BluffColors.gold,
          ),
        ),
      ),
    );
  }
}

/// ================================================================
/// CATEGORY TILE
/// ================================================================

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration:
          const Duration(milliseconds: 150),
      opacity: selected ? 1 : 0.5,
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        transformAlignment: Alignment.center,

        // ============================================================
        // BENT + CHUNKY SELECTED EFFECT
        // ============================================================

        transform: Matrix4.identity()
          ..rotateZ(
            selected ? -0.035 : 0,
          )
          ..scale(
            selected ? 1.045 : 1.0,
            selected ? 1.045 : 1.0,
            1.0,
          ),

        decoration: BoxDecoration(
          color: selected
              ? BluffColors.red
              : BluffColors.panel,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? BluffColors.redLight
                : BluffColors.line,
            width: 2,
          ),

          // ==========================================================
          // CHUNKY RED SHADOW
          // ==========================================================

          boxShadow: selected
              ? const [
                  BoxShadow(
                    color:
                        BluffColors.redDeep,
                    offset:
                        Offset(0, 5),
                  ),
                ]
              : null,
        ),

        child: Material(
          color: Colors.transparent,
          borderRadius:
              BorderRadius.circular(20),
          child: InkWell(
            borderRadius:
                BorderRadius.circular(20),
            onTap: onTap,
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 6,
                    ),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          emoji,
                          style:
                              const TextStyle(
                            fontSize: 34,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit:
                              BoxFit.scaleDown,
                          child: Text(
                            name,
                            textAlign:
                                TextAlign.center,
                            style: bluffDisplay(
                              15,
                            ).copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ====================================================
                // SELECTED CHECK
                // ====================================================

                if (selected)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration:
                          const BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            BluffColors.cream,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color:
                            BluffColors.redDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ================================================================
/// CHUNKY DONE BUTTON
/// ================================================================

class _ChunkyButton extends StatefulWidget {
  const _ChunkyButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ChunkyButton> createState() =>
      _ChunkyButtonState();
}

class _ChunkyButtonState
    extends State<_ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return GestureDetector(
      onTapDown: enabled
          ? (_) {
              setState(() {
                _down = true;
              });
            }
          : null,
      onTapUp: enabled
          ? (_) {
              setState(() {
                _down = false;
              });
            }
          : null,
      onTapCancel: enabled
          ? () {
              setState(() {
                _down = false;
              });
            }
          : null,
      onTap: enabled ? widget.onTap : null,
      child: SizedBox(
        width: double.infinity,
        height: 71,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration:
                  const Duration(milliseconds: 80),
              top: _down ? 5 : 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 80),
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled
                      ? BluffColors.red
                      : BluffColors.panel2,
                  borderRadius:
                      BorderRadius.circular(22),
                  border: Border.all(
                    color: enabled
                        ? BluffColors.redLight
                        : BluffColors.line,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: enabled
                          ? BluffColors.redDeep
                          : BluffColors.line,
                      offset: Offset(
                        0,
                        _down ? 2 : 7,
                      ),
                    ),
                  ],
                ),
                child: Text(
                  widget.label,
                  style: bluffDisplay(
                    24,
                    color: enabled
                        ? BluffColors.cream
                        : BluffColors.muted,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}