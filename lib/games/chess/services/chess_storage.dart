import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/challenge.dart';
import '../core/models/friendship.dart';
import '../core/models/game_record.dart';
import '../core/models/player_profile.dart';
import '../core/models/puzzle.dart';
import 'settings_service.dart';

/// Local-first persistence for the chess platform.
///
/// Everything the platform remembers lives on-device in SharedPreferences:
/// profiles, ratings, game history, friends, challenges and puzzle attempts.
/// The online layer never writes here directly — it goes through the
/// controllers, so swapping in a real backend later is a contained change.
class ChessStorage {
  ChessStorage._();

  static final ChessStorage instance = ChessStorage._();

  static const _profilesKey = 'chess_profiles_v1';
  static const _currentProfileKey = 'chess_current_profile_v1';
  static const _gamesKey = 'chess_games_v1';
  static const _friendsKey = 'chess_friends_v1';
  static const _challengesKey = 'chess_challenges_v1';
  static const _puzzleAttemptsKey = 'chess_puzzle_attempts_v1';
  static const _lastDailyPuzzleKey = 'chess_daily_puzzle_v1';
  static const _seenIdsKey = 'chess_seen_puzzles_v1';
  static const _hasOnboardedKey = 'chess_onboarded_v1';

  /// Newest games kept before older ones are pruned.
  static const int maxStoredGames = 300;

  /// Puzzle attempts kept for history/streaks.
  static const int maxPuzzleAttempts = 200;

  /// Not memoized on purpose: `SharedPreferences.getInstance()` caches
  /// internally, and skipping a local copy keeps storage in sync with
  /// `setMockInitialValues` in tests.
  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  Future<String?> _read(String key) async => (await _p).getString(key);

  Future<void> _write(String key, String value) async =>
      (await _p).setString(key, value);

  // ------------------------------------------------------------------ profile

  Future<List<PlayerProfile>> loadProfiles() async {
    final raw = await _read(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => PlayerProfile.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfiles(List<PlayerProfile> profiles) async {
    await _write(
      _profilesKey,
      jsonEncode([for (final p in profiles) p.toJson()]),
    );
  }

  Future<String?> loadCurrentProfileId() async {
    final prefs = await _p;
    return prefs.getString(_currentProfileKey);
  }

  Future<void> saveCurrentProfileId(String id) async {
    final prefs = await _p;
    await prefs.setString(_currentProfileKey, id);
  }

  /// Convenience: the active profile, or null when nobody has signed in yet.
  Future<PlayerProfile?> loadCurrentProfile() async {
    final id = await loadCurrentProfileId();
    if (id == null) return null;
    final profiles = await loadProfiles();
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> upsertProfile(PlayerProfile profile) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await saveProfiles(profiles);
  }

  // -------------------------------------------------------------------- games

  Future<List<ChessGameRecord>> loadGames() async {
    final raw = await _read(_gamesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final games = <ChessGameRecord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          games
              .add(ChessGameRecord.fromJson(item.cast<String, dynamic>()));
        } catch (_) {
          // Skip a corrupt record rather than losing the whole history.
        }
      }
      return games;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveGames(List<ChessGameRecord> games) async {
    final trimmed =
        games.length > maxStoredGames ? games.sublist(0, maxStoredGames) : games;
    await _write(_gamesKey, jsonEncode([for (final g in trimmed) g.toJson()]));
  }

  /// Appends a finished game (newest first) and prunes the tail.
  Future<void> addGame(ChessGameRecord game) async {
    final games = await loadGames();
    games.insert(0, game);
    await saveGames(games);
  }

  Future<void> deleteGame(String id) async {
    final games = await loadGames();
    games.removeWhere((g) => g.id == id);
    await saveGames(games);
  }

  Future<void> clearGames() async => saveGames(const []);

  // ------------------------------------------------------------------ friends

  Future<List<ChessFriend>> loadFriends() async {
    final raw = await _read(_friendsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => ChessFriend.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFriends(List<ChessFriend> friends) async {
    await _write(_friendsKey, jsonEncode([for (final f in friends) f.toJson()]));
  }

  // --------------------------------------------------------------- challenges

  Future<List<ChessChallenge>> loadChallenges() async {
    final raw = await _read(_challengesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => ChessChallenge.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChallenges(List<ChessChallenge> challenges) async {
    await _write(
      _challengesKey,
      jsonEncode([for (final c in challenges) c.toJson()]),
    );
  }

  // ------------------------------------------------------------------- puzzles

  Future<List<PuzzleAttempt>> loadPuzzleAttempts() async {
    final raw = await _read(_puzzleAttemptsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => PuzzleAttempt.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addPuzzleAttempt(PuzzleAttempt attempt) async {
    final attempts = await loadPuzzleAttempts();
    attempts.insert(0, attempt);
    if (attempts.length > maxPuzzleAttempts) {
      attempts.removeRange(maxPuzzleAttempts, attempts.length);
    }
    await _write(
      _puzzleAttemptsKey,
      jsonEncode([for (final a in attempts) a.toJson()]),
    );
  }

  /// Puzzle ids already attempted (used to avoid repeats in a session).
  Future<Set<String>> loadSeenPuzzleIds() async {
    final prefs = await _p;
    return (prefs.getStringList(_seenIdsKey) ?? const []).toSet();
  }

  Future<void> saveSeenPuzzleIds(Set<String> ids) async {
    final prefs = await _p;
    await prefs.setStringList(_seenIdsKey, ids.toList());
  }

  Future<void> markDailyPuzzle(String id) async {
    final prefs = await _p;
    await prefs.setString(_lastDailyPuzzleKey, id);
  }

  Future<String?> loadDailyPuzzleId() async {
    final prefs = await _p;
    return prefs.getString(_lastDailyPuzzleKey);
  }

  // ------------------------------------------------------------------ session

  Future<bool> loadHasOnboarded() async {
    final prefs = await _p;
    return prefs.getBool(_hasOnboardedKey) ?? false;
  }

  Future<void> saveHasOnboarded(bool value) async {
    final prefs = await _p;
    await prefs.setBool(_hasOnboardedKey, value);
  }

  /// Wipes every chess-owned key (account removal / factory reset).
  Future<void> wipeAll() async {
    final prefs = await _p;
    await Future.wait([
      prefs.remove(_profilesKey),
      prefs.remove(_currentProfileKey),
      prefs.remove(_gamesKey),
      prefs.remove(_friendsKey),
      prefs.remove(_challengesKey),
      prefs.remove(_puzzleAttemptsKey),
      prefs.remove(_lastDailyPuzzleKey),
      prefs.remove(_seenIdsKey),
      prefs.remove(_hasOnboardedKey),
      prefs.remove('chess_settings_v1'),
    ]);
  }

  /// Exports everything as JSON (user data portability).
  Future<Map<String, dynamic>> exportData() async => {
        'profiles': [for (final p in await loadProfiles()) p.toJson()],
        'games': [for (final g in await loadGames()) g.toJson()],
        'friends': [for (final f in await loadFriends()) f.toJson()],
        'challenges': [for (final c in await loadChallenges()) c.toJson()],
        'puzzleAttempts': [
          for (final a in await loadPuzzleAttempts()) a.toJson(),
        ],
        'settings': ChessSettingsService.instance.settings.toJson(),
      };
}
