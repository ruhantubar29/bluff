import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../games/impostor/models/impostor_player.dart';

class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();

  static const _playersKey = 'impostor_players';
  static const _playerCountKey = 'impostor_player_count';
  static const _categoriesKey = 'impostor_categories';
  static const _impostorCountKey = 'impostor_count';
  static const _randomImpostorCountKey =
      'impostor_random_count';
  static const _hintsEnabledKey = 'impostor_hints_enabled';
  static const _languageKey = 'impostor_language';

  static const _wordDeckStateKey =
      'impostor_word_deck_state';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??=
        await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------------------
  // PLAYERS
  // ---------------------------------------------------------------------------

  Future<void> savePlayers(
  List<ImpostorPlayer> players,
) async {
  final prefs = await _prefs;

  final data = players
      .map(
        (player) => {
          'name': player.name,
          'isAlive': player.isAlive,
          'score': player.score,
        },
      )
      .toList();

  await prefs.setString(
    _playersKey,
    jsonEncode(data),
  );

  await prefs.setInt(
    _playerCountKey,
    players.length,
  );
}

  Future<List<ImpostorPlayer>?> loadPlayers() async {
  final prefs = await _prefs;

  final raw = prefs.getString(_playersKey);

  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      return null;
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => ImpostorPlayer(
            name: item['name']?.toString() ?? '',
            isAlive: item['isAlive'] as bool? ?? true,
            score: item['score'] is num
                ? (item['score'] as num).toInt()
                : 0,
          ),
        )
        .toList();
  } catch (_) {
    return null;
  }
}

  // ---------------------------------------------------------------------------
  // IMPOSTOR SETUP
  // ---------------------------------------------------------------------------

  Future<void> saveImpostorSettings({
    required int playerCount,
    required int impostorCount,
    required List<String> categories,
    required bool randomImpostorCount,
    required bool hintsEnabled,
    required String languageCode,
  }) async {
    final prefs = await _prefs;

    await Future.wait([
      prefs.setInt(
        _playerCountKey,
        playerCount,
      ),
      prefs.setInt(
        _impostorCountKey,
        impostorCount,
      ),
      prefs.setStringList(
        _categoriesKey,
        categories,
      ),
      prefs.setBool(
        _randomImpostorCountKey,
        randomImpostorCount,
      ),
      prefs.setBool(
        _hintsEnabledKey,
        hintsEnabled,
      ),
      prefs.setString(
        _languageKey,
        languageCode,
      ),
    ]);
  }

  Future<int?> loadPlayerCount() async {
    final prefs = await _prefs;
    return prefs.getInt(_playerCountKey);
  }

  Future<int?> loadImpostorCount() async {
    final prefs = await _prefs;
    return prefs.getInt(_impostorCountKey);
  }

  Future<List<String>?> loadCategories() async {
    final prefs = await _prefs;

    final categories =
        prefs.getStringList(_categoriesKey);

    if (categories == null) {
      return null;
    }

    return List<String>.from(categories);
  }

  Future<bool?> loadRandomImpostorCount() async {
    final prefs = await _prefs;
    return prefs.getBool(
      _randomImpostorCountKey,
    );
  }

  Future<bool?> loadHintsEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_hintsEnabledKey);
  }

  Future<String?> loadLanguageCode() async {
    final prefs = await _prefs;
    return prefs.getString(_languageKey);
  }

  // ---------------------------------------------------------------------------
  // WORD DECK
  // ---------------------------------------------------------------------------

  Future<void> saveWordDeckState({
    required Map<String, List<int>> wordQueues,
    required Map<String, Set<int>> usedHintIndexes,
  }) async {
    final prefs = await _prefs;

    final encodedQueues =
        <String, List<int>>{};

    for (final entry in wordQueues.entries) {
      encodedQueues[entry.key] =
          List<int>.from(entry.value);
    }

    final encodedHints =
        <String, List<int>>{};

    for (final entry in usedHintIndexes.entries) {
      encodedHints[entry.key] =
          entry.value.toList();
    }

    final state = {
      'wordQueues': encodedQueues,
      'usedHintIndexes': encodedHints,
    };

    await prefs.setString(
      _wordDeckStateKey,
      jsonEncode(state),
    );
  }

  Future<Map<String, dynamic>?> loadWordDeckState()
      async {
    final prefs = await _prefs;

    final raw =
        prefs.getString(_wordDeckStateKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(
        decoded,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearWordDeckState() async {
    final prefs = await _prefs;

    await prefs.remove(_wordDeckStateKey);
  }
}