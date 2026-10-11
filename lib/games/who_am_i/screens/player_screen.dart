import 'package:flutter/material.dart';

import '../../../core/profile/player_roster.dart';
import '../../../core/profile/roster_chips.dart';

class PlayerScreen extends StatefulWidget {
  final List<String> players;

  const PlayerScreen({
    super.key,
    required this.players,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();

    controllers = List.generate(
      widget.players.length,
      (index) => TextEditingController(
        text: widget.players[index],
      ),
    );

    // Roster loads asynchronously on first use (saved players chips).
    PlayerRoster.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void done() {
    final players = controllers
        .map((controller) => controller.text.trim())
        .toList();

    // Don't allow empty player names.
    if (players.any((name) => name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name for every player.'),
        ),
      );
      return;
    }

    // Remember the crew so next game starts pre-filled.
    PlayerRoster.instance.recordGame(players);

    Navigator.pop(context, players);
  }

  /// Taps on a saved roster name drop it into the first empty slot.
  void fillFromRoster(String name) {
    for (final controller in controllers) {
      if (controller.text.trim().isEmpty) {
        controller.text = name;
        setState(() {});
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Players',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Enter player names',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            RosterChips(onPick: fillFromRoster),

            const SizedBox(height: 25),

            Expanded(
              child: ListView.separated(
                itemCount: controllers.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return TextField(
                    controller: controllers[index],
                    onChanged: (_) => setState(() {}),
                    textCapitalization:
                        TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Player ${index + 1}',
                      hintText: 'Enter name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: done,
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
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