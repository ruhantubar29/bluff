class ImpostorPlayer {
  final String name;

  bool isAlive;

  int score;

  ImpostorPlayer({
    required this.name,
    this.isAlive = true,
    this.score = 0,
  });

  ImpostorPlayer copyWith({
    String? name,
    bool? isAlive,
    int? score,
  }) {
    return ImpostorPlayer(
      name: name ?? this.name,
      isAlive: isAlive ?? this.isAlive,
      score: score ?? this.score,
    );
  }
}