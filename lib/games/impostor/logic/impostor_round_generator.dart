import 'dart:math';

import '../models/impostor_player.dart';
import '../models/impostor_round.dart';
import '../models/impostor_settings.dart';
import 'word_deck.dart';

class ImpostorRoundGenerator {
  ImpostorRoundGenerator._();

  static final ImpostorRoundGenerator instance =
      ImpostorRoundGenerator._();

  final Random _random = Random();

  int _maximumImpostors(int players) {
    if (players >= 16) {
      return 6;
    }

    if (players >= 13) {
      return 5;
    }

    if (players >= 10) {
      return 4;
    }

    if (players >= 7) {
      return 3;
    }

    if (players >= 5) {
      return 2;
    }

    return 1;
  }

  Future<ImpostorRound> generate({
    required ImpostorSettings settings,
    required List<ImpostorPlayer> players,
  }) async {
    if (players.length != settings.playerCount) {
      throw ArgumentError(
        'Player count does not match settings.',
      );
    }

    if (players.length <
        ImpostorSettings.minPlayers) {
      throw ArgumentError(
        'There must be at least '
        '${ImpostorSettings.minPlayers} players.',
      );
    }

    if (players.length >
        ImpostorSettings.maxPlayers) {
      throw ArgumentError(
        'There cannot be more than '
        '${ImpostorSettings.maxPlayers} players.',
      );
    }

    if (settings.categories.isEmpty) {
      throw ArgumentError(
        'At least one category must be selected.',
      );
    }

    final maximumImpostors =
        _maximumImpostors(players.length);

    if (settings.impostorCount < 1) {
      throw ArgumentError(
        'Impostor maximum must be at least 1.',
      );
    }

    if (settings.impostorCount >
        maximumImpostors) {
      throw ArgumentError(
        'Too many impostors for this number of players.',
      );
    }

    final actualImpostorCount =
        settings.randomImpostorCount
            ? _random.nextInt(
                players.length + 1,
              )
            : settings.impostorCount;

    final category =
        settings.categories[
          _random.nextInt(
            settings.categories.length,
          )
        ];

    final word =
        await ImpostorWordDeck.instance.next(
      language: settings.language,
      category: category,
    );

    final indexes = List<int>.generate(
      players.length,
      (index) => index,
    )..shuffle(_random);

    final impostorIndexes = indexes
        .take(actualImpostorCount)
        .toSet();

    final List<int> startingPlayerCandidates;

    if (settings.hintsEnabled) {
      startingPlayerCandidates =
          List<int>.generate(
        players.length,
        (index) => index,
      );
    } else {
      startingPlayerCandidates =
          List<int>.generate(
        players.length,
        (index) => index,
      )
              .where(
                (index) =>
                    !impostorIndexes.contains(
                  index,
                ),
              )
              .toList();
    }

    final startingPlayerIndex =
        startingPlayerCandidates[
          _random.nextInt(
            startingPlayerCandidates.length,
          )
        ];

    return ImpostorRound(
      players: players,
      category: category,
      secretWord: word.word,
      hint: settings.hintsEnabled
          ? word.hint
          : null,
      impostorIndexes: impostorIndexes,
      randomImpostorCount:
          settings.randomImpostorCount,
      startingPlayerIndex:
          startingPlayerIndex,
    );
  }
}