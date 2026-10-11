import 'package:flutter/material.dart';

import '../screens/chess_hub.dart';
import '../widgets/chess_theme.dart';
import 'bot_setup_screen.dart';
import 'puzzle_adventure_screen.dart';

/// Front door of the single-player chess folder.
///
/// The Bluff singleplayer screen opens this instead of the shared hub so the
/// two solo experiences stay separate: bot matches (full setup flow) and the
/// puzzle tower (level climb). Profile/history/settings remain one tap away
/// through the hub link in the app bar.
class SingleplayerHome extends StatelessWidget {
  const SingleplayerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChessPalette.background,
      appBar: AppBar(
        backgroundColor: ChessPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ChessPalette.text,
        elevation: 0,
        title: const Text('Singleplayer', style: ChessText.title),
        actions: [
          IconButton(
            tooltip: 'Profile & history',
            icon: const Icon(Icons.person_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChessHub(initialTab: HubTab.profile),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('CHOOSE YOUR GAME', style: ChessText.display),
            const SizedBox(height: 6),
            Text(
              'Two ways to play solo — face an engine or crack tactics.',
              style: ChessText.dim,
            ),
            const SizedBox(height: 24),
            _ModeCard(
              tag: 'VS ENGINE',
              title: 'Play with Bot',
              subtitle:
                  'Pick an opponent, your side and a clock — easy going all '
                  'the way to grandmaster strength.',
              icon: Icons.smart_toy_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BotSetupScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              tag: 'PUZZLE TOWER',
              title: 'Solve Puzzles',
              subtitle:
                  'Climb level by level up the tower — the top levels stay '
                  'hidden in the clouds until you get there.',
              icon: Icons.cloud_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PuzzleAdventureScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big tappable option card with a gradient icon tile.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChessCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ChessPalette.accent, Color(0xFF7E1717)],
              ),
              boxShadow: [
                BoxShadow(
                  color: ChessPalette.accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: ChessText.label.copyWith(
                    color: ChessPalette.gold,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(title, style: ChessText.title),
                const SizedBox(height: 6),
                Text(subtitle, style: ChessText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: ChessPalette.textFaint,
            size: 26,
          ),
        ],
      ),
    );
  }
}
