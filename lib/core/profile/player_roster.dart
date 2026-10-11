import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_repository.dart';
import '../reviews/review_service.dart';

/// One remembered player on this device — Splash's `PlayerRosterLiveRepository`
/// equivalent: the recurring crew you play pass-and-play with, kept locally so
/// games never ask for the same names twice.
class RosterPlayer {
  const RosterPlayer({
    required this.name,
    this.avatarIndex = 0,
    this.timesPlayed = 0,
    this.createdAt = 0,
  });

  final String name;
  final int avatarIndex;
  final int timesPlayed;
  final int createdAt;

  RosterPlayer copyWith({
    String? name,
    int? avatarIndex,
    int? timesPlayed,
    int? createdAt,
  }) {
    return RosterPlayer(
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      timesPlayed: timesPlayed ?? this.timesPlayed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'avatarIndex': avatarIndex,
        'timesPlayed': timesPlayed,
        'createdAt': createdAt,
      };

  factory RosterPlayer.fromJson(Map<String, dynamic> json) {
    return RosterPlayer(
      name: json['name'] as String? ?? '',
      avatarIndex: json['avatarIndex'] as int? ?? 0,
      timesPlayed: json['timesPlayed'] as int? ?? 0,
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }
}

/// Local-first roster store with best-effort cloud sync, matching the rest of
/// the profile system: everything works offline, the account is a backup.
class PlayerRoster {
  PlayerRoster._();

  static final PlayerRoster instance = PlayerRoster._();

  static const String _prefsKey = 'bluff.roster';
  static const Duration _networkTimeout = Duration(seconds: 5);

  static const int maxPlayers = 40;

  List<RosterPlayer> _players = <RosterPlayer>[];
  bool _loaded = false;

  /// Test-only: forget in-memory state so the next call re-reads preferences.
  @visibleForTesting
  void resetForTesting() {
    _players = <RosterPlayer>[];
    _loaded = false;
  }

  List<RosterPlayer> get players => List.unmodifiable(_players);

  int get count => _players.length;

  Future<void> load() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _players = decoded
              .whereType<Map>()
              .map(
                (item) => RosterPlayer.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((player) => player.name.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // Corrupt roster: start empty rather than crash.
      }
    }

    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(
        _players.map((player) => player.toJson()).toList(),
      ),
    );

    await _pushToCloud();
  }

  /// Adds (or bumps) a player. Returns false when the roster is full or the
  /// name is blank.
  Future<bool> add({
    required String name,
    int avatarIndex = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    await load();

    final existing = _players.indexWhere(
      (player) => player.name.toLowerCase() == trimmed.toLowerCase(),
    );

    if (existing >= 0) {
      // Already known — bump them to the top instead of duplicating.
      final player = _players.removeAt(existing);
      _players.insert(
        0,
        player.copyWith(timesPlayed: player.timesPlayed + 1),
      );
      await _save();
      return true;
    }

    if (_players.length >= maxPlayers) return false;

    _players.insert(
      0,
      RosterPlayer(
        name: trimmed,
        avatarIndex: avatarIndex,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await _save();
    return true;
  }

  /// Records that these players actually played — Splash keeps a play count.
  Future<void> recordGame(List<String> names) async {
    if (names.isEmpty) return;

    await load();
    var changed = false;

    for (final name in names) {
      final index = _players.indexWhere(
        (player) => player.name.toLowerCase() == name.toLowerCase(),
      );

      if (index < 0) {
        if (_players.length >= maxPlayers) continue;
        _players.add(
          RosterPlayer(
            name: name,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        changed = true;
      } else {
        final player = _players[index];
        _players[index] = player.copyWith(
          timesPlayed: player.timesPlayed + 1,
        );
        changed = true;
      }
    }

    if (changed) await _save();

    // A game happened — the review prompt counts recorded games.
    ReviewService.instance.maybeAskAfterGame();
  }

  Future<void> remove(String name) async {
    await load();

    _players.removeWhere(
      (player) => player.name.toLowerCase() == name.toLowerCase(),
    );

    await _save();
  }

  Future<void> clear() async {
    await load();
    _players = <RosterPlayer>[];
    await _save();
  }

  /// Best-effort write of the whole roster to `users/{uid}.roster`.
  Future<void> _pushToCloud() async {
    final uid = ProfileRepository.instance.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(
            {
              'roster': _players.map((p) => p.toJson()).toList(),
            },
            SetOptions(merge: true),
          )
          .timeout(_networkTimeout);
    } catch (_) {
      // Offline — pushed again on the next change.
    }
  }

  /// Restores the roster from the account on a fresh install.
  /// Local data wins when it exists, same rule as the profile.
  Future<void> restoreIfEmpty() async {
    await load();
    if (_players.isNotEmpty) return;

    final uid = ProfileRepository.instance.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(_networkTimeout);

      final data = snapshot.data();
      final roster = data?['roster'];
      if (roster is! List) return;

      final restored = roster
          .whereType<Map>()
          .map(
            (item) => RosterPlayer.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((player) => player.name.isNotEmpty)
          .toList();

      if (restored.isEmpty) return;

      _players = restored;
      await _save();
    } catch (_) {
      // Offline or nothing to restore.
    }
  }
}
