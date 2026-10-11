import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineImpostorPlayer {
  const OnlineImpostorPlayer({
    required this.uid,
    required this.name,
    required this.isAlive,
    required this.score,
    required this.ready,
  });

  final String uid;
  final String name;
  final bool isAlive;
  final int score;
  final bool ready;

  factory OnlineImpostorPlayer.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    return OnlineImpostorPlayer(
      uid: uid,
      name: data['displayName'] as String? ?? 'Player',
      isAlive: data['isAlive'] != false,
      score: (data['score'] as num?)?.toInt() ?? 0,
      ready: data['ready'] == true,
    );
  }
}

class OnlineImpostorRound {
  const OnlineImpostorRound({
    required this.roomCode,
    required this.roundNumber,
    required this.phase,
    required this.players,
    required this.startingPlayerId,
  });

  final String roomCode;
  final int roundNumber;
  final String phase;
  final List<OnlineImpostorPlayer> players;
  final String? startingPlayerId;

  factory OnlineImpostorRound.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (data == null) {
      throw Exception('Room data could not be loaded.');
    }

    final rawPlayers =
        Map<String, dynamic>.from(
      data['players'] ?? {},
    );

    final players = rawPlayers.entries.map((entry) {
      return OnlineImpostorPlayer.fromMap(
        entry.key,
        Map<String, dynamic>.from(entry.value),
      );
    }).toList();

    return OnlineImpostorRound(
      roomCode: data['roomCode'] as String? ?? '',
      roundNumber:
          (data['roundNumber'] as num?)?.toInt() ?? 0,
      phase: data['status'] as String? ?? 'waiting',
      players: players,
      startingPlayerId:
          data['startingPlayerId'] as String?,
    );
  }
}