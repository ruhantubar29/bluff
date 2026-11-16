import 'package:bluff/games/guess_the_flag/data/countries.dart';
import 'package:bluff/games/guess_the_flag/logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuessTheFlagLogic', () {
    test('deck holds every country exactly once', () {
      final logic = GuessTheFlagLogic();

      expect(logic.deck, hasLength(countries.length));

      final codes = logic.deck.map((c) => c.code).toSet();
      expect(codes, hasLength(countries.length));

      // 193 UN members + Palestine + Vatican City + Taiwan.
      expect(countries, hasLength(196));
      // Options are drawn by name, so a duplicate would starve a round.
      expect(countries.map((c) => c.name).toSet(), hasLength(196));
    });

    test('every round offers 4 distinct names including the answer', () {
      final logic = GuessTheFlagLogic();

      while (!logic.deckFinished) {
        logic.loadRound();

        expect(logic.options, hasLength(4));
        expect(logic.options.toSet(), hasLength(4));
        expect(logic.options, contains(logic.current.name));

        logic.advance();
      }

      expect(logic.deckFinished, isTrue);
    });

    test('loadRound re-arms the double-tap lock', () {
      final logic = GuessTheFlagLogic();
      logic.loadRound();

      logic.answered = true;
      expect(logic.answered, isTrue);

      logic.loadRound();
      expect(logic.answered, isFalse);
    });

    test('points scale with the time left on the 15s clock', () {
      final logic = GuessTheFlagLogic();

      expect(logic.pointsFor(roundSeconds.toDouble()), 100);
      expect(logic.pointsFor(roundSeconds / 2), 50);
      expect(logic.pointsFor(0), 0);
    });
  });
}
