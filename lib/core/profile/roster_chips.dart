import 'package:flutter/material.dart';

import 'player_roster.dart';

/// "From your players" quick-fill row shared by every pass-and-play roster
/// screen (Who Am I, Impostor, Mafia) — Splash remembers the recurring crew
/// so no game asks for the same names twice.
///
/// Renders nothing while the roster is empty or still loading.
class RosterChips extends StatefulWidget {
  const RosterChips({
    super.key,
    required this.onPick,
    this.max = 8,
  });

  /// Called with the tapped roster name.
  final ValueChanged<String> onPick;

  /// Roster names shown before truncating — the crew you actually play with
  /// fits on two lines.
  final int max;

  @override
  State<RosterChips> createState() => _RosterChipsState();
}

class _RosterChipsState extends State<RosterChips> {
  @override
  void initState() {
    super.initState();
    PlayerRoster.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final roster = PlayerRoster.instance.players;
    if (roster.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'From your players',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final player in roster.take(widget.max))
                ActionChip(
                  avatar: Text(
                    player.name.isEmpty
                        ? '?'
                        : player.name.substring(0, 1),
                    style: const TextStyle(fontSize: 14),
                  ),
                  label: Text(player.name),
                  onPressed: () => widget.onPick(player.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
