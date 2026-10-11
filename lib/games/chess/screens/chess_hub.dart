import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../state/game_controller.dart';
import '../widgets/chess_theme.dart';
import 'history_screen.dart';
import 'hub_home_screen.dart';
import 'play_screen.dart';
import 'profile_screen.dart';
import 'puzzle_screen.dart';

/// Tabs of the persistent chess shell.
enum HubTab { home, play, puzzles, history, profile }

/// The chess platform shell: a persistent navigation container (bottom bar
/// on phones, rail on desktop) holding Home, Play, History and Profile.
///
/// Each Bluff entry point opens this hub with its tab/mode preselected:
/// singleplayer → vs Computer, pass & play → Pass & Play, multiplayer →
/// Online (which explains the server requirement honestly).
class ChessHub extends StatefulWidget {
  const ChessHub({
    super.key,
    this.initialTab = HubTab.home,
    this.initialMode,
  });

  /// Convenience entry: singleplayer → vs Computer.
  const ChessHub.vsComputer({Key? key})
      : this(
          key: key,
          initialTab: HubTab.play,
          initialMode: ChessGameMode.computer,
        );

  /// Convenience entry: pass & play → shared-device game.
  const ChessHub.passAndPlay({Key? key})
      : this(
          key: key,
          initialTab: HubTab.play,
          initialMode: ChessGameMode.passAndPlay,
        );

  /// Convenience entry: multiplayer → Online (honest server notice).
  const ChessHub.online({Key? key})
      : this(
          key: key,
          initialTab: HubTab.play,
          initialMode: ChessGameMode.online,
        );

  final HubTab initialTab;
  final ChessGameMode? initialMode;

  @override
  State<ChessHub> createState() => _ChessHubState();
}

class _ChessHubState extends State<ChessHub> {
  late HubTab _tab;
  ChessGameMode? _playMode;

  /// False until persisted settings are restored, so preferences (themes,
  /// default time control, sounds) never flash their defaults.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _playMode = widget.initialMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await ChessSettingsService.instance.load();
    } catch (_) {
      // Missing or corrupt prefs: the in-memory defaults already apply.
    }
    if (mounted) setState(() => _ready = true);
  }

  void _goToPlay(ChessGameMode mode) {
    setState(() {
      _playMode = mode;
      _tab = HubTab.play;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: ChessPalette.background,
        body: Center(
          child: CircularProgressIndicator(color: ChessPalette.accent),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    final pages = [
      HubHomeScreen(isActive: _tab == HubTab.home, onPlay: _goToPlay),
      PlayScreen(initialMode: _playMode),
      PuzzleScreen(isActive: _tab == HubTab.puzzles),
      HistoryScreen(isActive: _tab == HubTab.history),
      ProfileScreen(isActive: _tab == HubTab.profile),
    ];

    final body = IndexedStack(index: _tab.index, children: pages);

    return Scaffold(
      backgroundColor: ChessPalette.background,
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  _rail(extended: width >= 1180),
                  const SizedBox(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 64,
              backgroundColor: ChessPalette.surface,
              indicatorColor: ChessPalette.accentSoft,
              selectedIndex: _tab.index,
              onDestinationSelected: (i) =>
                  setState(() => _tab = HubTab.values[i]),
              destinations: _destinations,
            ),
    );
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.play_circle_outline_rounded),
      selectedIcon: Icon(Icons.play_circle_rounded),
      label: 'Play',
    ),
    NavigationDestination(
      icon: Icon(Icons.extension_outlined),
      selectedIcon: Icon(Icons.extension_rounded),
      label: 'Puzzles',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_rounded),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  Widget _rail({required bool extended}) {
    return Container(
      color: ChessPalette.surface,
      child: NavigationRail(
        extended: extended,
        backgroundColor: ChessPalette.surface,
        selectedIndex: _tab.index,
        onDestinationSelected: (i) =>
            setState(() => _tab = HubTab.values[i]),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ChessPalette.accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                '♞',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
          ),
        ),
        labelType: extended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        groupAlignment: -0.9,
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Home'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.play_circle_outline_rounded),
            selectedIcon: Icon(Icons.play_circle_rounded),
            label: Text('Play'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension_rounded),
            label: Text('Puzzles'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: Text('History'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: Text('Profile'),
          ),
        ],
      ),
    );
  }
}
