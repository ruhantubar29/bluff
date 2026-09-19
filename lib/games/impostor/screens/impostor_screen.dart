import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../logic/impostor_round_generator.dart';
import '../logic/word_deck.dart';
import '../models/impostor_player.dart';
import '../models/impostor_settings.dart';
import 'category_screen.dart';
import 'game_screen.dart';
import 'impostor_count_screen.dart';
import 'player_screen.dart';

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

TextStyle _display(
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

TextStyle _body(
  double size, {
  Color color = BluffColors.cream,
  FontWeight weight = FontWeight.w400,
}) {
  return GoogleFonts.hindSiliguri(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

class ImpostorScreen extends StatefulWidget {
  const ImpostorScreen({super.key});

  @override
  State<ImpostorScreen> createState() => _ImpostorScreenState();
}

class _ImpostorScreenState extends State<ImpostorScreen> {
  late AppLanguage _language;

  bool _hintsEnabled = true;
  bool _randomImpostorCount = false;

  int _impostorCount = 1;

  List<ImpostorPlayer> _players = [
    ImpostorPlayer(name: 'Player 1'),
    ImpostorPlayer(name: 'Player 2'),
    ImpostorPlayer(name: 'Player 3'),
  ];

  late List<String> _categories;
  late Set<String> _selectedCategories;

  @override
  void initState() {
    super.initState();

    _language = LanguageSettings.instance.language;

    _categories =
        ImpostorWordDeck.instance.categories(_language);

    _selectedCategories = _categories.toSet();
  }

  int _maximumImpostors(int players) {
    if (players >= 16) return 6;
    if (players >= 13) return 5;
    if (players >= 10) return 4;
    if (players >= 7) return 3;
    if (players >= 5) return 2;
    return 1;
  }

  Future<void> _openPlayers() async {
    final result = await Navigator.push<List<ImpostorPlayer>>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          players: _players,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _players = result;

      final maximum = _maximumImpostors(_players.length);

      if (_impostorCount > maximum) {
        _impostorCount = maximum;
      }
    });
  }

  Future<void> _openImpostors() async {
    final result =
        await Navigator.push<ImpostorCountSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => ImpostorCountScreen(
          playerCount: _players.length,
          selectedCount: _impostorCount,
          randomEnabled: _randomImpostorCount,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _impostorCount = result.count;
      _randomImpostorCount = result.randomEnabled;
    });
  }

  Future<void> _openCategories() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryScreen(
          language: _language,
          selectedCategories:
              _selectedCategories.toList(),
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedCategories = result.toSet();
    });
  }

  void _openTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TutorialScreen(),
      ),
    );
  }

  void _startGame() {
    if (_players.length < 3) {
      _showMessage(
        'At least 3 players are required.',
      );
      return;
    }

    final maximum = _maximumImpostors(
      _players.length,
    );

    if (!_randomImpostorCount &&
        (_impostorCount < 1 ||
            _impostorCount > maximum)) {
      _showMessage(
        'Choose between 1 and $maximum impostor(s).',
      );
      return;
    }

    if (_selectedCategories.isEmpty) {
      _showMessage(
        'Pick at least one category to start.',
      );
      return;
    }

    final settings = ImpostorSettings(
      playerCount: _players.length,
      impostorCount: _impostorCount,
      categories: _selectedCategories.toList(),
      hintsEnabled: _hintsEnabled,
      randomImpostorCount: _randomImpostorCount,
      language: _language,
    );

    final round =
        ImpostorRoundGenerator.instance.generate(
      settings: settings,
      players: _players,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          round: round,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: _body(
              15,
              color: BluffColors.cream,
              weight: FontWeight.w600,
            ),
          ),
          backgroundColor: BluffColors.panel2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final playerCount = _players.length;
    final categoryCount = _selectedCategories.length;

    final allCategories =
        categoryCount == _categories.length;

    final canStart =
        playerCount >= 3 &&
        categoryCount > 0;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              28,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _Header(
                  onBack: () =>
                      Navigator.maybePop(context),
                  onHelp: _openTutorial,
                ),

                _SectionHead(
                  'Players',
                  '$playerCount/20',
                ),

                _PlayersSetupCard(
                  players: _players,
                  onTap: _openPlayers,
                ),

                _SectionHead(
                  'Impostors',
                  _randomImpostorCount
                      ? 'random'
                      : '$_impostorCount selected',
                ),

                _SetupTile(
                  leading: _Badge(
                    child: Text(
                      _randomImpostorCount
                          ? '🎲'
                          : '$_impostorCount',
                      style: _display(
                        28,
                        color: BluffColors.cream,
                      ),
                    ),
                  ),
                  title: 'Impostor Count',
                  subtitle: _randomImpostorCount
                      ? 'The game will choose the number'
                      : '$_impostorCount impostor${_impostorCount == 1 ? '' : 's'} selected',
                  onTap: _openImpostors,
                ),

                const SizedBox(height: 14),

                _HintRow(
                  value: _hintsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _hintsEnabled = value;
                    });
                  },
                ),

                _SectionHead(
                  'Categories',
                  '$categoryCount/${_categories.length}',
                ),

                _SetupTile(
                  leading: const _Badge(
                    child: Text(
                      '🗂️',
                      style: TextStyle(
                        fontSize: 26,
                      ),
                    ),
                  ),
                  title: allCategories
                      ? 'All Categories'
                      : '$categoryCount Categories',
                  subtitle: categoryCount == 0
                      ? 'Pick at least one'
                      : _categoryPreview(),
                  onTap: _openCategories,
                ),

                const SizedBox(height: 22),

                _ChunkyButton(
                  label: 'START GAME',
                  enabled: canStart,
                  onTap: _startGame,
                ),

                if (!canStart)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        playerCount < 3
                            ? 'At least 3 players are required'
                            : 'Pick at least one category to start',
                        style: _body(
                          13.5,
                          color: BluffColors.muted,
                        ),
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

  String _categoryPreview() {
    if (_selectedCategories.isEmpty) {
      return '';
    }

    final categories = _selectedCategories.toList();

    final shown = categories.take(3).join(', ');
    final extra = categories.length - 3;

    return extra > 0
        ? '$shown  +$extra more'
        : shown;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onHelp,
  });

  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.arrow_back_rounded,
                color: BluffColors.cream,
                size: 22,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Transform.rotate(
          angle: -0.035,
          child: Text(
            'IMPOSTOR',
            style: _display(
              30,
              letterSpacing: 0.5,
            ).copyWith(
              shadows: const [
                Shadow(
                  color: BluffColors.redDeep,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        Transform.rotate(
          angle: 0.1,
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: Text(
                '🕵️',
                style: TextStyle(
                  fontSize: 42,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 4),

        Material(
          color: BluffColors.panel2,
          shape: const CircleBorder(
            side: BorderSide(
              color: BluffColors.gold,
              width: 2,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onHelp,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: BluffColors.gold,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
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

class _SectionHead extends StatelessWidget {
  const _SectionHead(
    this.title,
    this.meta,
  );

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 22,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            CrossAxisAlignment.baseline,
        textBaseline:
            TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: _display(
              20,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            meta,
            style: _body(
              14,
              color: BluffColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersSetupCard extends StatelessWidget {
  const _PlayersSetupCard({
    required this.players,
    required this.onTap,
  });

  final List<ImpostorPlayer> players;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = players.length;

    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              14,
              16,
            ),
            child: Row(
              children: [
                _LargeAvatarStack(
                  count: count,
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count Players',
                        style: _display(
                          20,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose how many players are playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(
                          13.5,
                          color: BluffColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: BluffColors.gold,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeAvatarStack extends StatelessWidget {
  const _LargeAvatarStack({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    // Show 3 player bubbles by default.
    // Show up to 5 actual player bubbles.
    final visiblePlayers = count.clamp(3, 5);

    // Players beyond 5 are represented by a black +N bubble.
    final extraPlayers = count > 5 ? count - 5 : 0;

    final totalBubbles =
        visiblePlayers + (extraPlayers > 0 ? 1 : 0);

    const size = 48.0;
    const step = 31.0;

    return SizedBox(
      width: size + ((totalBubbles - 1) * step),
      height: 54,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          for (var i = 0; i < visiblePlayers; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BluffColors.avatars[
                    i % BluffColors.avatars.length
                  ],
                  border: Border.all(
                    color: BluffColors.panel,
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: BluffColors.ink,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${i + 1}',
                  style: _display(
                    17,
                    color: BluffColors.ink,
                  ),
                ),
              ),
            ),

          if (extraPlayers > 0)
            Positioned(
              left: visiblePlayers * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(
                    color: BluffColors.panel,
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: BluffColors.ink,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '+$extraPlayers',
                  style: _display(
                    15,
                    color: BluffColors.cream,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: BluffColors.panel,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: BluffColors.line,
      width: 2,
    ),
    boxShadow: const [
      BoxShadow(
        color: BluffColors.ink,
        offset: Offset(0, 5),
      ),
      BoxShadow(
        color: BluffColors.line,
        offset: Offset(0, 6),
      ),
    ],
  );
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                leading,

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: _display(
                          19,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: _body(
                          13.5,
                          color: BluffColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: BluffColors.gold,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BluffColors.panel2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: BluffColors.line,
          width: 2,
        ),
      ),
      child: child,
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value
                        ? BluffColors.goldTint
                        : BluffColors.panel2,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '💡',
                    style: TextStyle(
                      fontSize: 22,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Give hint to impostors',
                        style: _body(
                          16,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Only impostors will receive the hint',
                        style: _body(
                          13.5,
                          color: BluffColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: BluffColors.cream,
                  activeTrackColor: BluffColors.red,
                  inactiveThumbColor:
                      BluffColors.muted,
                  inactiveTrackColor:
                      BluffColors.panel2,
                  trackOutlineColor:
                      WidgetStateProperty.resolveWith(
                    (states) {
                      return states.contains(
                        WidgetState.selected,
                      )
                          ? BluffColors.redLight
                          : BluffColors.line;
                    },
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

class _ChunkyButton extends StatefulWidget {
  const _ChunkyButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

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

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTapDown: enabled
            ? (_) {
                setState(() => _down = true);
              }
            : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
              }
            : null,
        onTapCancel: enabled
            ? () {
                setState(() => _down = false);
              }
            : null,
        onTap: enabled ? widget.onTap : null,
        child: SizedBox(
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
                    color: BluffColors.red,
                    borderRadius:
                        BorderRadius.circular(22),
                    border: Border.all(
                      color: BluffColors.redLight,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: BluffColors.redDeep,
                        offset: Offset(
                          0,
                          _down ? 2 : 7,
                        ),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.label,
                    style: _display(
                      24,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide(
    this.emoji,
    this.title,
    this.body,
  );

  final String emoji;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    '🤫',
    'Secret word',
    'Everyone sees the same secret word — except the impostors. They only get a hint if hints are enabled.',
  ),
  _Slide(
    '🗣️',
    'Give clues',
    'Take turns saying one word about the secret. Be clear enough for the crew, vague enough to fool the impostor.',
  ),
  _Slide(
    '🕵️',
    'Find the impostor',
    'Talk it out, then vote. Who sounded like they were guessing?',
  ),
  _Slide(
    '🎉',
    'Reveal',
    'Catch the impostor and the crew wins. If they survive — or guess the word — they win.',
  ),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
  });

  @override
  State<TutorialScreen> createState() =>
      _TutorialScreenState();
}

class _TutorialScreenState
    extends State<TutorialScreen> {
  final PageController _controller =
      PageController();

  int _page = 0;

  bool get _last =>
      _page == _slides.length - 1;

  void _next() {
    if (_last) {
      Navigator.of(context).pop();
    } else {
      _controller.nextPage(
        duration:
            const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BluffColors.ink,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.0,
            colors: [
              BluffColors.glow,
              Color(0x00F0364F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(),
                  child: Text(
                    'Skip',
                    style: _body(
                      16,
                      color: BluffColors.gold,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() {
                      _page = index;
                    });
                  },
                  itemBuilder: (_, index) {
                    return _SlideView(
                      slide: _slides[index],
                      index: index,
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  for (
                    var i = 0;
                    i < _slides.length;
                    i++
                  )
                    AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      margin:
                          const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      width:
                          i == _page ? 26 : 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? BluffColors.gold
                            : BluffColors.line,
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                    ),
                ],
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  22,
                  18,
                  22,
                ),
                child: _ChunkyButton(
                  label:
                      _last ? "LET'S PLAY" : 'NEXT',
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.index,
  });

  final _Slide slide;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Transform.rotate(
            angle: index.isEven ? -0.05 : 0.05,
            child: Container(
              width: 190,
              height: 190,
              alignment: Alignment.center,
              decoration:
                  _cardDecoration().copyWith(
                borderRadius:
                    BorderRadius.circular(48),
                color: BluffColors.panel2,
              ),
              child: Text(
                slide.emoji,
                style:
                    const TextStyle(fontSize: 96),
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: _display(32),
          ),

          const SizedBox(height: 12),

          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: _body(
              17,
              color: BluffColors.muted,
            ).copyWith(
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}