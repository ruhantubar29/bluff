import 'package:flutter/material.dart';

import '../../../core/profile/player_roster.dart';
import '../../../core/profile/roster_chips.dart';
import 'role_screen.dart';

class MafiaScreen extends StatefulWidget {
  const MafiaScreen({super.key});

  @override
  State<MafiaScreen> createState() => _MafiaScreenState();
}

class _MafiaScreenState extends State<MafiaScreen> {
  final List<String> players = [];

  final TextEditingController playerController =
      TextEditingController();

  void addPlayer() {
    final name = playerController.text.trim();

    if (name.isEmpty) return;

    if (players.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Player already exists.'),
        ),
      );
      return;
    }

    setState(() {
      players.add(name);
      playerController.clear();
    });
  }

  void removePlayer(int index) {
    setState(() {
      players.removeAt(index);
    });
  }

  /// Roster chip tap: fills the input if empty, otherwise appends.
  void pickFromRoster(String name) {
    if (players.contains(name)) return;
    setState(() {
      players.add(name);
      playerController.clear();
    });
  }

  void next() {
    if (players.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'At least 4 players are required.',
          ),
        ),
      );
      return;
    }

    // Remember the crew for next time.
    PlayerRoster.instance.recordGame(players);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MafiaRoleScreen(
          players: List<String>.from(players),
        ),
      ),
    );
  }

  @override
  void dispose() {
    playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mafia',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              const Text(
                'PLAYERS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Add everyone who is playing.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: playerController,
                      textInputAction:
                          TextInputAction.done,
                      onSubmitted: (_) => addPlayer(),
                      decoration: const InputDecoration(
                        hintText: 'Player name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  SizedBox(
                    height: 56,
                    width: 56,
                    child: ElevatedButton(
                      onPressed: addPlayer,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              RosterChips(onPick: pickFromRoster),

              const SizedBox(height: 20),

              Expanded(
                child: players.isEmpty
                    ? Center(
                        child: Text(
                          'No players added yet.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: players.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                              side: BorderSide(
                                color:
                                    Colors.grey.shade300,
                              ),
                            ),
                            leading: CircleAvatar(
                              child: Text(
                                '${index + 1}',
                              ),
                            ),
                            title: Text(
                              players[index],
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.close,
                              ),
                              onPressed: () =>
                                  removePlayer(index),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 15),

              Text(
                '${players.length} players',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: next,
                  child: const Text(
                    'NEXT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}