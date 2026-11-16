import 'dart:math';

import '../data/countries.dart';

/// Round length in seconds, matching the reference HTML.
const int roundSeconds = 15;

/// Deck, options and scoring for one run of Guess The Flag.
///
/// Deliberately holds no timers or animation state — the screen owns those.
class GuessTheFlagLogic {
  GuessTheFlagLogic() {
    deck = List<Country>.from(countries)..shuffle(_random);
  }

  final Random _random = Random();

  /// The run, shuffled so every flag is played exactly once.
  late final List<Country> deck;

  /// Index of the flag currently on screen.
  int roundIndex = 0;

  /// Points banked this run.
  int score = 0;

  /// Consecutive correct answers.
  int streak = 0;

  /// Set once the round has been answered or timed out. The screen reads it
  /// to lock the buttons so a double tap cannot score twice.
  bool answered = false;

  /// The four answer labels for the current round, correct one included.
  List<String> options = const [];

  Country get current => deck[roundIndex];

  /// True once every flag in the deck has been played.
  bool get deckFinished => roundIndex >= deck.length;

  /// Picks 4 distinct names — the correct one plus 3 random others — and
  /// shuffles them so the answer is not always first.
  void loadRound() {
    answered = false;

    final picks = <String>[current.name];

    while (picks.length < 4) {
      final candidate = countries[_random.nextInt(countries.length)].name;

      if (!picks.contains(candidate)) {
        picks.add(candidate);
      }
    }

    picks.shuffle(_random);

    options = picks;
  }

  /// Points for a correct answer — the faster you answer, the more you get.
  int pointsFor(double timeLeft) =>
      ((timeLeft / roundSeconds) * 100).round();

  /// Moves to the next flag in the deck.
  void advance() => roundIndex++;
}
