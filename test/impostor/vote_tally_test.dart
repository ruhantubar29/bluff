import 'package:bluff/games/impostor/logic/vote_tally.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accusationIsTied', () {
    test('a tie across the last slot is a draw', () {
      // Two players locked on 2 votes, only one accusation to give.
      expect(
        accusationIsTied(votesDescending: [2, 2, 0], slots: 1),
        isTrue,
      );
    });

    test('everyone on zero votes is a draw', () {
      expect(
        accusationIsTied(votesDescending: [0, 0, 0, 0], slots: 1),
        isTrue,
      );
    });

    test('a clear leader is not a draw', () {
      expect(
        accusationIsTied(votesDescending: [3, 1, 0], slots: 1),
        isFalse,
      );
    });

    test('a tie entirely inside the accusation is not a draw', () {
      // Both tied players get a slot, so the order between them is moot.
      expect(
        accusationIsTied(votesDescending: [3, 3, 1], slots: 2),
        isFalse,
      );
    });

    test('a tie entirely outside the accusation is not a draw', () {
      expect(
        accusationIsTied(votesDescending: [3, 1, 1], slots: 1),
        isFalse,
      );
    });

    test('no slots or no players left over cannot tie', () {
      expect(
        accusationIsTied(votesDescending: [2, 2], slots: 0),
        isFalse,
      );
      expect(
        accusationIsTied(votesDescending: [2, 2], slots: 2),
        isFalse,
      );
    });
  });
}
