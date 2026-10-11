import 'package:flutter/material.dart';

import '../core/models/game_record.dart';
import '../core/models/player_profile.dart';
import '../core/models/time_control.dart';
import '../services/chess_storage.dart';
import '../services/session_service.dart';
import '../state/game_controller.dart';
import '../widgets/chess_theme.dart';
import 'friends_screen.dart';
import 'history_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Landing tab: identity, ratings at a glance, quick modes, recent games.
class HubHomeScreen extends StatefulWidget {
  const HubHomeScreen({
    super.key,
    required this.isActive,
    required this.onPlay,
  });

  /// True while the hub shows this page; triggers a refresh when it flips
  /// back to true (e.g. after finishing a game).
  final bool isActive;

  /// Jumps to the Play tab with the chosen mode preselected.
  final ValueChanged<ChessGameMode> onPlay;

  @override
  State<HubHomeScreen> createState() => _HubHomeScreenState();
}

class _HubHomeScreenState extends State<HubHomeScreen> {
  PlayerProfile? _profile;
  List<ChessGameRecord> _recent = const [];

  static const _categories = [
    RatingCategory.bullet,
    RatingCategory.blitz,
    RatingCategory.rapid,
    RatingCategory.classical,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HubHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load() async {
    final profile = await SessionService.instance.current;
    final games = await ChessStorage.instance.loadGames();
    games.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _recent = games.take(3).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _header(profile),
        const SizedBox(height: 18),
        if (profile != null) ...[
          const SectionTitle(title: 'Your ratings'),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final rating = profile.ratingFor(category);
                return Container(
                  width: 118,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ChessPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ChessPalette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        categoryLabel(category).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ChessText.caption,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rating.rating}',
                        style: const TextStyle(
                          color: ChessPalette.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 20),
        const SectionTitle(title: 'Play'),
        Row(
          children: [
            Expanded(
              child: _modeCard(
                icon: Icons.computer_rounded,
                title: 'vs Computer',
                subtitle: '6 levels',
                onTap: () => widget.onPlay(ChessGameMode.computer),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _modeCard(
                icon: Icons.groups_rounded,
                title: 'Pass & Play',
                subtitle: 'One device',
                onTap: () => widget.onPlay(ChessGameMode.passAndPlay),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _modeCard(
                icon: Icons.wifi_rounded,
                title: 'Online',
                subtitle: 'Server needed',
                offline: true,
                onTap: () => widget.onPlay(ChessGameMode.online),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle(title: 'Community'),
        Row(
          children: [
            Expanded(
              child: _modeCard(
                icon: Icons.group_rounded,
                title: 'Friends',
                subtitle: 'Local roster',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const FriendsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _modeCard(
                icon: Icons.leaderboard_rounded,
                title: 'Leaderboard',
                subtitle: 'This device',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const LeaderboardScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionTitle(
          title: 'Recent games',
          trailing: _recent.isEmpty
              ? null
              : InfoChip(
                  label: 'All',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HistoryScreen(localId: profile?.id),
                    ),
                  ),
                ),
        ),
        if (_recent.isEmpty)
          ChessCard(
            child: Text(
              'No games yet. Pick a mode above and play — every game is '
              'saved on this device with the full move list.',
              style: ChessText.caption.copyWith(height: 1.5),
            ),
          )
        else
          for (final record in _recent) GameRecordTile(record: record),
      ],
    );
  }

  Widget _header(PlayerProfile? profile) {
    final name = profile?.displayName;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BLUFF', style: ChessText.label),
              Text(
                name == null ? 'CHESS' : 'CHESS · $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ChessText.display.copyWith(fontSize: 26),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const ChessSettingsScreen()),
          ),
          icon: const Icon(Icons.settings_rounded,
              color: ChessPalette.textDim, size: 24),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool offline = false,
  }) {
    return ChessCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: ChessPalette.text, size: 26),
              if (offline)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: ChessPalette.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ChessText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ChessText.caption.copyWith(
              color: ChessPalette.textFaint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
