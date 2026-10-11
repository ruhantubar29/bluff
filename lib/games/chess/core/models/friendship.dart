/// A friend on the player's roster.
///
/// Local-first: friends are stored on this device. [presence] reflects what
/// the active connection layer actually reports — it is never simulated. When
/// no backend is connected everything is [PresenceStatus.unknown] and the UI
/// says so honestly.
enum PresenceStatus {
  /// Reachable and not in a game.
  online,

  /// Currently playing a game.
  inGame,

  /// Signed in previously but not connected now.
  offline,

  /// We have no connection that could tell us (backend not connected).
  unknown,
}

extension PresenceLabel on PresenceStatus {
  String get label {
    switch (this) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.inGame:
        return 'In game';
      case PresenceStatus.offline:
        return 'Offline';
      case PresenceStatus.unknown:
        return 'Unknown';
    }
  }

  bool get isLive => this == PresenceStatus.online || this == PresenceStatus.inGame;
}

class ChessFriend {
  const ChessFriend({
    required this.id,
    required this.username,
    required this.displayName,
    required this.addedAt,
    this.avatarEmoji,
    this.avatarColor = 0xffC62828,
    this.presence = PresenceStatus.unknown,
    this.presenceNote,
  });

  final String id;
  final String username;
  final String displayName;
  final DateTime addedAt;
  final String? avatarEmoji;
  final int avatarColor;

  /// Live presence as reported by the connection layer.
  final PresenceStatus presence;

  /// Optional context, e.g. "Playing Blitz" when [presence] is inGame.
  final String? presenceNote;

  ChessFriend copyWith({
    PresenceStatus? presence,
    String? presenceNote,
  }) =>
      ChessFriend(
        id: id,
        username: username,
        displayName: displayName,
        addedAt: addedAt,
        avatarEmoji: avatarEmoji,
        avatarColor: avatarColor,
        presence: presence ?? this.presence,
        presenceNote: presenceNote,
      );

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'addedAt': addedAt.millisecondsSinceEpoch,
        'avatarEmoji': avatarEmoji,
        'avatarColor': avatarColor,
        // Presence is connection state, not persisted.
      };

  factory ChessFriend.fromJson(Map<String, dynamic> json) => ChessFriend(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Friend',
        addedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['addedAt'] as num?)?.toInt() ?? 0,
        ),
        avatarEmoji: json['avatarEmoji'] as String?,
        avatarColor: (json['avatarColor'] as num?)?.toInt() ?? 0xffC62828,
      );
}
