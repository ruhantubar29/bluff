import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/game_card.dart';

import '../../games/impostor/screens/impostor_screen.dart';
import '../../games/would_you_rather/screens/would_you_rather_screen.dart';
import '../../games/truth_or_dare/screens/truth_or_dare_screen.dart';
import '../../games/wrong_answer_only/screens/wrong_answer_only_screen.dart';
import '../../games/who_am_i/screens/who_am_i_screen.dart';
import '../../games/perfect_circle/screens/perfect_circle_screen.dart';
import '../../games/chess/screens/chess_screen.dart';
import '../../games/never_have_i_ever/screens/never_have_i_ever_screen.dart';
import '../../games/charades/screens/charades_screen.dart';
import '../../games/mafia/screens/mafia_screen.dart';

import '../settings/settings_screen.dart';

const _dark = Color(0xff09090E);
const _red = Color(0xffC62828);
const _highlight = Color(0xffFFD166);

const String _favoritesKey = 'bluff.favorite_games';
const String _recentGamesKey = 'bluff.recent_games';

enum _PlayMode {
  singleplayer,
  multiplayer,
  passAndPlay,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  _PlayMode _selectedMode = _PlayMode.singleplayer;

  final ScrollController _scrollController =
      ScrollController();

  double _scrollOffset = 0;

  final List<String> _favoriteGameTitles =
      <String>[];

  final Set<String> _favoriteGames =
      <String>{};

  List<String> _recentGameTitles =
      <String>[];

  late final AnimationController _flagController;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _flagController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    )..repeat();

    _loadGamePreferences();
  }

  Future<void> _loadGamePreferences() async {
    final prefs =
        await SharedPreferences.getInstance();

    final favorites =
        prefs.getStringList(_favoritesKey) ??
            <String>[];

    final recent =
        prefs.getStringList(_recentGamesKey) ??
            <String>[];

    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteGameTitles
        ..clear()
        ..addAll(favorites);

      _favoriteGames
        ..clear()
        ..addAll(favorites);

      _recentGameTitles = recent;
    });
  }

  void _onScroll() {
    if (!mounted) {
      return;
    }

    setState(() {
      _scrollOffset =
          _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(
      _onScroll,
    );
    _scrollController.dispose();
    _flagController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(
    _GameData game,
  ) async {
    setState(() {
      if (_favoriteGames.contains(game.title)) {
        _favoriteGames.remove(game.title);
        _favoriteGameTitles.remove(game.title);
      } else {
        _favoriteGames.add(game.title);
        _favoriteGameTitles.add(game.title);
      }
    });

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      _favoritesKey,
      _favoriteGameTitles,
    );
  }

  Future<void> _markRecent(
    _GameData game,
  ) async {
    if (_favoriteGames.contains(game.title)) {
      return;
    }

    setState(() {
      _recentGameTitles.remove(game.title);
      _recentGameTitles.insert(
        0,
        game.title,
      );
    });

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      _recentGamesKey,
      _recentGameTitles,
    );
  }

  _GameData? _findGame(String title) {
    for (final game in _games) {
      if (game.title == title) {
        return game;
      }
    }

    return null;
  }

  List<_GameData> get _orderedGames {
    final result = <_GameData>[];
    final used = <String>{};

    // Favorites always stay pinned at the top.
    for (final title in _favoriteGameTitles) {
      final game = _findGame(title);

      if (game != null) {
        result.add(game);
        used.add(game.title);
      }
    }

    // Recent games come after favorites.
    for (final title in _recentGameTitles) {
      if (_favoriteGames.contains(title)) {
        continue;
      }

      final game = _findGame(title);

      if (game != null &&
          used.add(game.title)) {
        result.add(game);
      }
    }

    // Everything else keeps its original order.
    for (final game in _games) {
      if (used.add(game.title)) {
        result.add(game);
      }
    }

    return result;
  }

  void _openGame(_GameData game) {
    if (!_favoriteGames.contains(game.title)) {
      _markRecent(game);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => game.screen,
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SettingsScreen(),
      ),
    );
  }

  void _showSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _GameSearchScreen(
          favorites: _favoriteGames,
          flagAnimation: _flagController,
          onFavoriteToggle:
              _toggleFavorite,
          onGameSelected: _openGame,
          onProfilePressed: _showProfile,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _dark,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              24,
              12,
              24,
              32,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        Colors.white.withValues(
                      alpha: 0.07,
                    ),
                    border: Border.all(
                      color:
                          Colors.white.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white70,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PLAYER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your profile will live here.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(
                      backgroundColor:
                          Colors.white
                              .withValues(
                        alpha: 0.07,
                      ),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                      _openSettings();
                    },
                    icon: const Icon(
                      Icons.settings_rounded,
                      size: 21,
                    ),
                    label: const Text(
                      'Settings',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
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

  String get _modeTitle {
    switch (_selectedMode) {
      case _PlayMode.singleplayer:
        return 'Singleplayer';
      case _PlayMode.multiplayer:
        return 'Multiplayer';
      case _PlayMode.passAndPlay:
        return 'Pass & Play';
    }
  }

  String get _modeDescription {
    switch (_selectedMode) {
      case _PlayMode.singleplayer:
        return 'Play alone or play with AI/bots.';
      case _PlayMode.multiplayer:
        return 'Play online with friends and other players.';
      case _PlayMode.passAndPlay:
        return 'Play together on one device.';
    }
  }

  String _descriptionForMode(
    _GameData game,
  ) {
    switch (_selectedMode) {
      case _PlayMode.singleplayer:
        return game.singleplayerDescription;
      case _PlayMode.multiplayer:
        return game.multiplayerDescription;
      case _PlayMode.passAndPlay:
        return game.passAndPlayDescription;
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = _orderedGames;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _dark,
        systemNavigationBarIconBrightness:
            Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _dark,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                controller:
                    _scrollController,
                physics:
                    const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 76,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildModeSelector(),
                          const SizedBox(height: 24),
                          Text(
                            _modeTitle,
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _modeDescription,
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.42,
                              ),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      28,
                    ),
                    sliver: SliverGrid(
                      delegate:
                          SliverChildBuilderDelegate(
                        (context, index) {
                          final game =
                              games[index];

                          return _buildGameCard(
                            game,
                          );
                        },
                        childCount:
                            games.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 5 / 7,
                      ),
                    ),
                  ),
                ],
              ),
              _buildFloatingHeader(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(
    _GameData game,
  ) {
    final isFavorite =
        _favoriteGames.contains(
      game.title,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GameCard(
          title: game.title,
          description:
              _descriptionForMode(game),
          imagePath:
              game.imagePath,
          onTap: () {
            _openGame(game);
          },
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _FavoriteButton(
            isFavorite: isFavorite,
            onTap: () {
              _toggleFavorite(game);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingHeader() {
    final movement =
        (_scrollOffset / 110.0)
            .clamp(0.0, 1.0);

    final sideOpacity =
        (1.0 - movement)
            .clamp(0.0, 1.0);

    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final logoWidth =
        _logoWidth(context);

    const startLeft = 20.0;

    final centeredLeft =
        (screenWidth - logoWidth) / 2;

    final logoLeft =
        startLeft +
        (centeredLeft - startLeft) *
            movement;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter:
                    _HeaderBackgroundPainter(
                  scrollProgress:
                      movement,
                ),
              ),
            ),

            Positioned(
              left: logoLeft,
              top: 0,
              bottom: 0,
              child: Align(
                alignment:
                    Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation:
                      _flagController,
                  builder:
                      (context, child) {
                    return _buildLogo(
                      _flagController.value,
                    );
                  },
                ),
              ),
            ),

            Positioned(
              right: 16,
              top: 17,
              child: IgnorePointer(
                ignoring:
                    sideOpacity < 0.05,
                child: Opacity(
                  opacity:
                      sideOpacity,
                  child:
                      _buildActionButtons(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _logoWidth(
    BuildContext context,
  ) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'BLUFF',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          height: 0.9,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    )..layout();

    return painter.width + 3 + 30;
  }

  Widget _buildLogo(
    double flagTime,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'BLUFF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight:
                FontWeight.w900,
            letterSpacing: -1.2,
            height: 0.9,
          ),
        ),
        const SizedBox(width: 3),
        Transform.translate(
          offset:
              const Offset(0, -5),
          child: SizedBox(
            width: 30,
            height: 21,
            child: CustomPaint(
              painter:
                  _BangladeshFlagPainter(
                time: flagTime,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      height: 42,
      padding:
          const EdgeInsets.all(3),
      decoration:
          BoxDecoration(
        color: Colors.black
            .withValues(
          alpha: 0.38,
        ),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: Colors.white
              .withValues(
            alpha: 0.12,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.20,
            ),
            blurRadius: 14,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _headerActionButton(
            icon:
                Icons.search_rounded,
            onTap: _showSearch,
          ),
          Container(
            width: 1,
            height: 22,
            color: Colors.white
                .withValues(
              alpha: 0.12,
            ),
          ),
          _headerActionButton(
            icon:
                Icons.person_rounded,
            onTap: _showProfile,
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 36,
          child: Icon(
            icon,
            color: Colors.white70,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 48,
      padding:
          const EdgeInsets.all(4),
      decoration:
          BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: 0.055,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: Colors.white
              .withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: Row(
        children: [
          _modeButton(
            mode:
                _PlayMode.singleplayer,
            label:
                'SINGLEPLAYER',
          ),
          _modeButton(
            mode:
                _PlayMode.multiplayer,
            label:
                'MULTIPLAYER',
          ),
          _modeButton(
            mode:
                _PlayMode.passAndPlay,
            label:
                'PASS & PLAY',
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required _PlayMode mode,
    required String label,
  }) {
    final selected =
        _selectedMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 220,
          ),
          curve:
              Curves.easeOut,
          alignment:
              Alignment.center,
          decoration:
              BoxDecoration(
            color: selected
                ? _red
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: FittedBox(
            fit:
                BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white54,
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
                letterSpacing:
                    0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton
    extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.black
          .withValues(
        alpha: 0.48,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder:
            const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOutBack,
          width: 34,
          height: 34,
          decoration:
              BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isFavorite
                  ? _highlight
                  : Colors.white
                      .withValues(
                    alpha: 0.18,
                  ),
              width:
                  isFavorite ? 1.2 : 1,
            ),
          ),
          child: AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            transitionBuilder:
                (
              child,
              animation,
            ) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Icon(
              isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              key: ValueKey(
                isFavorite,
              ),
              color: isFavorite
                  ? _highlight
                  : Colors.white70,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBackgroundPainter
    extends CustomPainter {
  final double scrollProgress;

  const _HeaderBackgroundPainter({
    required this.scrollProgress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rect =
        Offset.zero & size;

    final paint = Paint()
      ..shader = LinearGradient(
        begin:
            Alignment.topCenter,
        end:
            Alignment.bottomCenter,
        colors: [
          _dark.withValues(
            alpha: 0.97,
          ),
          _dark.withValues(
            alpha: 0.72,
          ),
          _dark.withValues(
            alpha: 0.0,
          ),
        ],
        stops: const [
          0.0,
          0.55,
          1.0,
        ],
      ).createShader(rect);

    canvas.drawRect(
      rect,
      paint,
    );

    final fogPaint = Paint()
      ..color = _red.withValues(
        alpha:
            0.018 +
            scrollProgress * 0.018,
      )
      ..maskFilter =
          const MaskFilter.blur(
        BlurStyle.normal,
        22,
      );

    canvas.drawCircle(
      Offset(
        size.width * 0.48,
        size.height * 0.35,
      ),
      size.width * 0.42,
      fogPaint,
    );
  }

  @override
  bool shouldRepaint(
    _HeaderBackgroundPainter
        oldDelegate,
  ) {
    return oldDelegate
            .scrollProgress !=
        scrollProgress;
  }
}

class _BangladeshFlagPainter
    extends CustomPainter {
  final double time;

  const _BangladeshFlagPainter({
    required this.time,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const green =
        Color(0xff006A4E);

    const red =
        Color(0xffF42A41);

    const samples = 100;

    final phase =
        time * math.pi * 2;

    canvas.save();

    final flagPath = Path();

    for (int i = 0;
        i <= samples;
        i++) {
      final t =
          i / samples;

      final x =
          size.width * t;

      final wave =
          _wave(
            t,
            phase,
          );

      if (i == 0) {
        flagPath.moveTo(
          x,
          wave,
        );
      } else {
        flagPath.lineTo(
          x,
          wave,
        );
      }
    }

    for (int i = samples;
        i >= 0;
        i--) {
      final t =
          i / samples;

      final x =
          size.width * t;

      final wave =
          _wave(
            t,
            phase,
          );

      flagPath.lineTo(
        x,
        size.height + wave,
      );
    }

    flagPath.close();

    canvas.clipPath(
      flagPath,
    );

    final greenPaint = Paint()
      ..color = green
      ..isAntiAlias = true;

    canvas.drawRect(
      Offset.zero & size,
      greenPaint,
    );

    final circleT = 0.48;

    final circleWave =
        _wave(
          circleT,
          phase,
        );

    final circleCenter =
        Offset(
      size.width * circleT,
      size.height * 0.50 +
          circleWave * 0.72,
    );

    final circlePaint = Paint()
      ..color = red
      ..isAntiAlias = true;

    canvas.drawCircle(
      circleCenter,
      size.height * 0.30,
      circlePaint,
    );

    final textPainter =
        TextPainter(
      text: const TextSpan(
        text: 'BD',
        style: TextStyle(
          color: Colors.white,
          fontSize: 4.5,
          fontWeight:
              FontWeight.w900,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        circleCenter.dx -
            textPainter.width / 2,
        circleCenter.dy -
            textPainter.height / 2,
      ),
    );

    canvas.restore();
  }

  double _wave(
    double t,
    double phase,
  ) {
    final envelope =
        math.sin(t * math.pi);

    final primary =
        math.sin(
          t * math.pi * 2.2 +
              phase,
        );

    final secondary =
        math.sin(
          t * math.pi * 4.0 +
              phase * 1.35,
        );

    return envelope *
        (primary * 1.15 +
            secondary * 0.30);
  }

  @override
  bool shouldRepaint(
    _BangladeshFlagPainter
        oldDelegate,
  ) {
    return oldDelegate.time !=
        time;
  }
}

class _GameSearchScreen
    extends StatefulWidget {
  const _GameSearchScreen({
    required this.favorites,
    required this.flagAnimation,
    required this.onFavoriteToggle,
    required this.onGameSelected,
    required this.onProfilePressed,
  });

  final Set<String> favorites;

  final Animation<double>
      flagAnimation;

  final Future<void> Function(
    _GameData game,
  ) onFavoriteToggle;

  final void Function(
    _GameData game,
  ) onGameSelected;

  final VoidCallback onProfilePressed;

  @override
  State<_GameSearchScreen> createState() =>
      _GameSearchScreenState();
}

class _GameSearchScreenState
    extends State<_GameSearchScreen> {
  final TextEditingController
      _searchController =
      TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _query =
          _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController
        .removeListener(
      _onSearchChanged,
    );
    _searchController.dispose();
    super.dispose();
  }

  List<_GameData> get _results {
    final query =
        _query.trim().toLowerCase();

    if (query.isEmpty) {
      return _games;
    }

    return _games.where((game) {
      return game.title
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  void _toggleFavorite(
    _GameData game,
  ) {
    widget.onFavoriteToggle(
      game,
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme:
            Theme.of(context)
                .colorScheme
                .copyWith(
          primary: _red,
        ),
        textSelectionTheme:
            const TextSelectionThemeData(
          cursorColor: _highlight,
          selectionColor:
              Color(0x55C62828),
          selectionHandleColor:
              _red,
        ),
      ),
      child: AnnotatedRegion<
          SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.light,
          statusBarBrightness:
              Brightness.dark,
          systemNavigationBarColor:
              _dark,
          systemNavigationBarIconBrightness:
              Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: _dark,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildSearchField(),
                const SizedBox(
                  height: 14,
                ),
                Expanded(
                  child: _results.isEmpty
                      ? const Center(
                          child: Text(
                            'No games found',
                            style:
                                TextStyle(
                              color:
                                  Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            20,
                            0,
                            20,
                            28,
                          ),
                          physics:
                              const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing:
                                14,
                            mainAxisSpacing:
                                14,
                            childAspectRatio:
                                5 / 7,
                          ),
                          itemCount:
                              _results.length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final game =
                                _results[index];

                            final isFavorite =
                                widget.favorites
                                    .contains(
                              game.title,
                            );

                            return Stack(
                              clipBehavior:
                                  Clip.none,
                              children: [
                                GameCard(
                                  title:
                                      game.title,
                                  description:
                                      game
                                          .singleplayerDescription,
                                  imagePath:
                                      game.imagePath,
                                  onTap: () {
                                    widget
                                        .onGameSelected(
                                      game,
                                    );
                                  },
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child:
                                      _FavoriteButton(
                                    isFavorite:
                                        isFavorite,
                                    onTap: () {
                                      _toggleFavorite(
                                        game,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
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

  Widget _buildTopBar() {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(
                context,
              );
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color:
                  Colors.white70,
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation:
                widget.flagAnimation,
            builder:
                (context, child) {
              return Row(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BLUFF',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 23,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          -1.1,
                    ),
                  ),
                  const SizedBox(
                    width: 3,
                  ),
                  Transform.translate(
                    offset:
                        const Offset(
                      0,
                      -4,
                    ),
                    child: SizedBox(
                      width: 24,
                      height: 18,
                      child:
                          CustomPaint(
                        painter:
                            _BangladeshFlagPainter(
                          time: widget
                              .flagAnimation
                              .value,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          Padding(
            padding:
                const EdgeInsets.only(
              right: 8,
            ),
            child: Material(
              color: Colors.transparent,
              shape:
                  const CircleBorder(),
              child: InkWell(
                customBorder:
                    const CircleBorder(),
                onTap:
                    widget
                        .onProfilePressed,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color: Colors
                        .white
                        .withValues(
                      alpha: 0.07,
                    ),
                    border:
                        Border.all(
                      color: Colors
                          .white
                          .withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .person_rounded,
                    color:
                        Colors.white70,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Container(
        height: 52,
        decoration:
            BoxDecoration(
          color: Colors.white
              .withValues(
            alpha: 0.055,
          ),
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          border: Border.all(
            color:
                _red.withValues(
              alpha: 0.70,
            ),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  _red.withValues(
                alpha: 0.07,
              ),
              blurRadius: 14,
            ),
          ],
        ),
        child: TextField(
          controller:
              _searchController,
          autofocus: true,
          cursorColor:
              _highlight,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          decoration:
              InputDecoration(
            border:
                InputBorder.none,
            contentPadding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            prefixIcon:
                const Icon(
              Icons.search_rounded,
              color:
                  Colors.white54,
            ),
            suffixIcon:
                _query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController
                              .clear();
                        },
                        icon:
                            const Icon(
                          Icons
                              .clear_rounded,
                          color:
                              Colors.white54,
                        ),
                      )
                    : null,
            hintText:
                'Search games...',
            hintStyle:
                const TextStyle(
              color:
                  Colors.white38,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameData {
  const _GameData({
    required this.title,
    required this.screen,
    required this.singleplayerDescription,
    required this.multiplayerDescription,
    required this.passAndPlayDescription,
    this.imagePath,
  });

  final String title;
  final Widget screen;
  final String? imagePath;

  final String
      singleplayerDescription;
  final String
      multiplayerDescription;
  final String
      passAndPlayDescription;
}

final List<_GameData> _games = [
  _GameData(
    title: 'IMPOSTOR',
    screen:
        const ImpostorScreen(),
    imagePath:
        'assets/images/game_cards/impostor_card.jpeg',
    singleplayerDescription:
        'Find the impostor with AI players.',
    multiplayerDescription:
        'Find the impostor with players online.',
    passAndPlayDescription:
        'Pass the phone and find the impostor.',
  ),
  _GameData(
    title:
        'WOULD YOU RATHER',
    screen:
        const WouldYouRatherScreen(),
    imagePath:
        'assets/images/game_cards/would_you_rather_card.jpeg',
    singleplayerDescription:
        'Make impossible choices on your own.',
    multiplayerDescription:
        'Compare your choices with players online.',
    passAndPlayDescription:
        'Take turns choosing with your friends.',
  ),
  _GameData(
    title: 'TRUTH OR DARE',
    screen:
        const TruthOrDareScreen(),
    imagePath:
        'assets/images/game_cards/truth_or_dare_card.jpeg',
    singleplayerDescription:
        'Challenge yourself with truth or dare.',
    multiplayerDescription:
        'Play truth or dare with players online.',
    passAndPlayDescription:
        'Pass the phone and challenge your friends.',
  ),
  _GameData(
    title:
        'WRONG ANSWER ONLY',
    screen:
        const WrongAnswerOnlyScreen(),
    imagePath:
        'assets/images/game_cards/wrong_answer_only_card.jpeg',
    singleplayerDescription:
        'Give the funniest wrong answers.',
    multiplayerDescription:
        'Compete with players online.',
    passAndPlayDescription:
        'Take turns giving ridiculous answers.',
  ),
  _GameData(
    title: 'WHO AM I?',
    screen:
        const WhoAmIScreen(),
    imagePath:
        'assets/images/game_cards/who_am_i_card.jpeg',
    singleplayerDescription:
        'Guess who you are with AI players.',
    multiplayerDescription:
        'Guess with players online.',
    passAndPlayDescription:
        'Guess together on one device.',
  ),
  _GameData(
    title: 'PERFECT CIRCLE',
    screen:
        const PerfectCircleScreen(),
    imagePath:
        'assets/images/game_cards/perfect_circle_card.jpeg',
    singleplayerDescription:
        'Draw the closest circle you can.',
    multiplayerDescription:
        'Compete against players online.',
    passAndPlayDescription:
        'Take turns drawing the perfect circle.',
  ),
  _GameData(
    title: 'CHESS',
    screen:
        const ChessScreen(),
    imagePath:
        'assets/images/game_cards/chess_card.jpeg',
    singleplayerDescription:
        'Challenge the computer.',
    multiplayerDescription:
        'Play chess against someone online.',
    passAndPlayDescription:
        'Play chess together on one device.',
  ),
  _GameData(
    title:
        'NEVER HAVE I EVER',
    screen:
        const NeverHaveIEverScreen(),
    imagePath:
        'assets/images/game_cards/never_have_i_ever_card.jpeg',
    singleplayerDescription:
        'Discover interesting things about yourself.',
    multiplayerDescription:
        'Play with people online.',
    passAndPlayDescription:
        'Reveal secrets with your friends.',
  ),
  _GameData(
    title: 'CHARADES',
    screen:
        const CharadesScreen(),
    imagePath:
        'assets/images/game_cards/charades_card.jpeg',
    singleplayerDescription:
        'Play charades with AI players.',
    multiplayerDescription:
        'Play charades with players online.',
    passAndPlayDescription:
        'Act it out for the people beside you.',
  ),
  _GameData(
    title: 'MAFIA',
    screen:
        const MafiaScreen(),
    imagePath:
        'assets/images/game_cards/mafia_card.jpeg',
    singleplayerDescription:
        'Survive the night against AI players.',
    multiplayerDescription:
        'Play Mafia with players online.',
    passAndPlayDescription:
        'Pass the phone and find the Mafia.',
  ),
];