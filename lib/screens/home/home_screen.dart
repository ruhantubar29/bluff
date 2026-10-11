import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../multiplayer/multiplayer_screen.dart';
import '../singleplayer/singleplayer_screen.dart';
import '../pass_and_play/pass_and_play_screen.dart';
import 'profile/profile_screen.dart';
import 'settings/settings_screen.dart';
import '../../core/profile/avatars.dart';
import '../../core/profile/profile_repository.dart';
import 'bluff_id_prompt.dart';

const _dark = Color(0xff09090E);
const _red = Color(0xffC62828);
const _highlight = Color(0xffFFD166);

const String _favoritesKey = 'bluff.favorite_games';
const String _recentGamesKey = 'bluff.recent_games';

enum _PlayMode { singleplayer, multiplayer, passAndPlay }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  _PlayMode _selectedMode = _PlayMode.singleplayer;

  final ScrollController _scrollController = ScrollController();

  double _scrollOffset = 0;

  final List<String> _favoriteGameTitles = <String>[];

  final Set<String> _favoriteGames = <String>{};

  List<String> _recentGameTitles = <String>[];

  late final AnimationController _flagController;

  Timer? _bluffIdPromptTimer;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _flagController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _loadGamePreferences();

    // Subscription window: about a second after home first appears, pop
    // the one-time Bluff ID offer over it (skipped when signed in or
    // already dismissed — see BluffIdPrompt).
    _bluffIdPromptTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      unawaited(BluffIdPrompt.maybeShow(context));
    });
  }

  Future<void> _loadGamePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final favorites = prefs.getStringList(_favoritesKey) ?? <String>[];

    final recent = prefs.getStringList(_recentGamesKey) ?? <String>[];

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
      _scrollOffset = _scrollController.offset;
    });
  }

  Future<void> _toggleFavorite(String gameTitle) async {
    setState(() {
      if (_favoriteGames.contains(gameTitle)) {
        _favoriteGames.remove(gameTitle);

        _favoriteGameTitles.remove(gameTitle);
      } else {
        _favoriteGames.add(gameTitle);

        _favoriteGameTitles.add(gameTitle);
      }
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_favoritesKey, _favoriteGameTitles);
  }

  Future<void> _markRecent(String gameTitle) async {
    if (_favoriteGames.contains(gameTitle)) {
      return;
    }

    setState(() {
      _recentGameTitles.remove(gameTitle);

      _recentGameTitles.insert(0, gameTitle);
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_recentGamesKey, _recentGameTitles);
  }

  @override
  void dispose() {
    _bluffIdPromptTimer?.cancel();

    _scrollController.removeListener(_onScroll);

    _scrollController.dispose();
    _flagController.dispose();

    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
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

  Future<void> _openGameFromMode(String gameTitle) async {
    await _markRecent(gameTitle);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _dark,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 76)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModeSelector(),

                          const SizedBox(height: 24),

                          Text(
                            _modeTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _modeDescription,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),

                  if (_selectedMode == _PlayMode.singleplayer)
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: SingleplayerScreen(
                        favoriteGames: _favoriteGames,
                        onFavoriteToggle: _toggleFavorite,
                        onGameOpened: _openGameFromMode,
                      ),
                    )
                  else if (_selectedMode == _PlayMode.passAndPlay)
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: PassAndPlayScreen(
                        favoriteGames: _favoriteGames,
                        onFavoriteToggle: _toggleFavorite,
                        onGameOpened: _openGameFromMode,
                      ),
                    )
                  else
                    const SliverFillRemaining(
                      hasScrollBody: true,
                      child: MultiplayerScreen(),
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

  Widget _buildFloatingHeader() {
    final movement = (_scrollOffset / 110.0).clamp(0.0, 1.0);

    final sideOpacity = (1.0 - movement).clamp(0.0, 1.0);

    final screenWidth = MediaQuery.sizeOf(context).width;

    final logoWidth = _logoWidth(context);

    const startLeft = 20.0;

    final centeredLeft = (screenWidth - logoWidth) / 2;

    final logoLeft = startLeft + (centeredLeft - startLeft) * movement;

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
                painter: _HeaderBackgroundPainter(scrollProgress: movement),
              ),
            ),

            Positioned(
              left: logoLeft,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: _flagController,
                  builder: (context, child) {
                    return _buildLogo(_flagController.value);
                  },
                ),
              ),
            ),

            Positioned(
              right: 16,
              top: 17,
              child: IgnorePointer(
                ignoring: sideOpacity < 0.05,
                child: Opacity(
                  opacity: sideOpacity,
                  child: _buildActionButtons(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _logoWidth(BuildContext context) {
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
      textDirection: TextDirection.ltr,
    )..layout();

    return painter.width + 3 + 30;
  }

  Widget _buildLogo(double flagTime) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BLUFF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 0.9,
          ),
        ),

        const SizedBox(width: 3),

        Transform.translate(
          offset: const Offset(0, -5),
          child: SizedBox(
            width: 30,
            height: 21,
            child: CustomPaint(painter: _BangladeshFlagPainter(time: flagTime)),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _profileBubble(),
          Container(
            width: 1,
            height: 22,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          _gearButton(),
        ],
      ),
    );
  }

  /// Settings gear beside the profile bubble (Splash keeps both up here).
  Widget _gearButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: _openSettings,
        child: const SizedBox(
          width: 38,
          height: 36,
          child: Center(
            child: Icon(
              Icons.settings_rounded,
              size: 21,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  /// Splash-style profile bubble in the home header. Shows the avatar and a
  /// red dot until the player backs the account up. Opens the full Profile
  /// screen directly — no half-height sheet in between.
  Widget _profileBubble() {
    final profile = ProfileRepository.instance.profile;
    final signedIn = profile?.isSignedIn ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: _openProfile,
        child: SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _highlight.withValues(alpha: 0.16),
                    border: Border.all(
                      color: signedIn ? const Color(0xFF32D74B) : _highlight,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: AvatarView(
                      index: profile?.avatarIndex ?? 0,
                      size: 26,
                      photoPath: profile?.avatarPhotoPath,
                    ),
                  ),
                ),
                if (!signedIn)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _red,
                        border: Border.all(color: Colors.black, width: 1.5),
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

  Widget _buildModeSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _modeButton(mode: _PlayMode.singleplayer, label: 'SINGLEPLAYER'),

          _modeButton(mode: _PlayMode.multiplayer, label: 'MULTIPLAYER'),

          _modeButton(mode: _PlayMode.passAndPlay, label: 'PASS & PLAY'),
        ],
      ),
    );
  }

  Widget _modeButton({required _PlayMode mode, required String label}) {
    final selected = _selectedMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMode = mode;
            _scrollOffset = 0;
          });

          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _red : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBackgroundPainter extends CustomPainter {
  final double scrollProgress;

  const _HeaderBackgroundPainter({required this.scrollProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _dark.withValues(alpha: 0.97),
          _dark.withValues(alpha: 0.72),
          _dark.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, paint);

    final fogPaint = Paint()
      ..color = _red.withValues(alpha: 0.018 + scrollProgress * 0.018)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

    canvas.drawCircle(
      Offset(size.width * 0.48, size.height * 0.35),
      size.width * 0.42,
      fogPaint,
    );
  }

  @override
  bool shouldRepaint(_HeaderBackgroundPainter oldDelegate) {
    return oldDelegate.scrollProgress != scrollProgress;
  }
}

class _BangladeshFlagPainter extends CustomPainter {
  final double time;

  const _BangladeshFlagPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xff006A4E);

    const red = Color(0xffF42A41);

    const samples = 100;

    final phase = time * math.pi * 2;

    canvas.save();

    final flagPath = Path();

    for (int i = 0; i <= samples; i++) {
      final t = i / samples;

      final x = size.width * t;

      final wave = _wave(t, phase);

      if (i == 0) {
        flagPath.moveTo(x, wave);
      } else {
        flagPath.lineTo(x, wave);
      }
    }

    for (int i = samples; i >= 0; i--) {
      final t = i / samples;

      final x = size.width * t;

      final wave = _wave(t, phase);

      flagPath.lineTo(x, size.height + wave);
    }

    flagPath.close();

    canvas.clipPath(flagPath);

    final greenPaint = Paint()
      ..color = green
      ..isAntiAlias = true;

    canvas.drawRect(Offset.zero & size, greenPaint);

    const circleT = 0.48;

    final circleWave = _wave(circleT, phase);

    final circleCenter = Offset(
      size.width * circleT,
      size.height * 0.50 + circleWave * 0.72,
    );

    final circlePaint = Paint()
      ..color = red
      ..isAntiAlias = true;

    canvas.drawCircle(circleCenter, size.height * 0.30, circlePaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'BD',
        style: TextStyle(
          color: Colors.white,
          fontSize: 4.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        circleCenter.dx - textPainter.width / 2,
        circleCenter.dy - textPainter.height / 2,
      ),
    );

    canvas.restore();
  }

  double _wave(double t, double phase) {
    final envelope = math.sin(t * math.pi);

    final primary = math.sin(t * math.pi * 2.2 + phase);

    final secondary = math.sin(t * math.pi * 4.0 + phase * 1.35);

    return envelope * (primary * 1.15 + secondary * 0.30);
  }

  @override
  bool shouldRepaint(_BangladeshFlagPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
