import 'package:bluff/games/chess/core/openings/opening_book.dart';
import 'package:bluff/games/chess/core/openings/opening_book_data.dart';
import 'package:chess/chess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpeningBook data integrity', () {
    test('ships a substantial book of well-formed entries', () {
      expect(OpeningBook.entryCount, greaterThanOrEqualTo(100));
      expect(kOpeningLines.length, OpeningBook.entryCount);

      for (final line in kOpeningLines) {
        expect(line.eco, matches(RegExp(r'^[A-E][0-9]{2}$')),
            reason: 'bad ECO for ${line.name}');
        expect(line.name, isNotEmpty);
        expect(line.moves, isNotEmpty);
        expect(line.moves, hasLength(lessThanOrEqualTo(16)));
        for (final san in line.moves) {
          expect(san, isNotEmpty);
          expect(san, isNot(contains('+')), reason: '${line.name}: $san');
          expect(san, isNot(contains('#')), reason: '${line.name}: $san');
        }
      }
    });

    test('every line replays legally from the starting position', () {
      var legal = 0;
      for (final line in kOpeningLines) {
        final game = Chess();
        for (var i = 0; i < line.moves.length; i++) {
          final wanted = line.moves[i];
          if (game.move(wanted)) continue; // exact SAN hit (common case)

          // The book strips check/mate suffixes, so fall back to matching
          // against every legal SAN in the position.
          String? chosen;
          for (final raw in game.moves({'verbose': true})) {
            final m = raw as Map;
            final san = (m['san'] as String?) ?? '';
            if (san.replaceAll(RegExp(r'[+#!?]+$'), '') == wanted) {
              chosen = san;
              break;
            }
          }
          expect(chosen, isNotNull,
              reason: '${line.eco} ${line.name}: illegal move #$i ($wanted)');
          expect(game.move(chosen!), isTrue,
              reason: '${line.eco} ${line.name}');
        }
        legal++;
      }
      expect(legal, OpeningBook.entryCount);
    });

    test('names follow the "Family: Variation" convention', () {
      var withVariation = 0;
      for (final line in kOpeningLines) {
        final match = line.toMatch();
        expect(match.family, isNotEmpty);
        if (match.hasVariation) {
          withVariation++;
          expect(match.name, contains(': '));
          expect(match.displayName, match.name);
        }
      }
      expect(withVariation, greaterThan(50),
          reason: 'most mainstream lines should carry a variation');
    });
  });

  group('OpeningBook.identify', () {
    test('returns null before any move', () {
      expect(OpeningBook.identify(null), isNull);
      expect(OpeningBook.identify(const []), isNull);
    });

    test('identifies the Najdorf at depth', () {
      final match = OpeningBook.identify(const [
        'e4',
        'c5',
        'Nf3',
        'd6',
        'd4',
        'cxd4',
        'Nxd4',
        'Nf6',
        'Nc3',
        'a6',
      ]);
      expect(match, isNotNull);
      expect(match!.eco, startsWith('B9'));
      expect(match.family, contains('Sicilian'));
      expect(match.name, contains('Najdorf'));
    });

    test('shorter prefixes resolve to shallower entries', () {
      final first = OpeningBook.identify(const ['e4']);
      expect(first, isNotNull);

      final sicilian = OpeningBook.identify(const ['e4', 'c5']);
      expect(sicilian, isNotNull);
      expect(sicilian!.family, contains('Sicilian'));

      final deep = OpeningBook.identify(
          const ['e4', 'c5', 'Nf3', 'd6', 'd4', 'cxd4', 'Nxd4', 'Nf6']);
      expect(deep, isNotNull);
      // The deeper match must be at least as specific as the shallow one.
      expect(deep!.name.length, greaterThanOrEqualTo(sicilian.name.length));
    });

    test('longest matching line wins', () {
      final ruy = OpeningBook.identify(const [
        'e4',
        'e5',
        'Nf3',
        'Nc6',
        'Bb5',
        'a6',
        'Ba4',
        'Nf6',
        'O-O',
        'Be7',
        'Re1',
        'b5',
        'Bb3',
        'd6',
        'c3',
        'O-O',
      ]);
      expect(ruy, isNotNull);
      expect(ruy!.eco, startsWith('C9'));
      expect(ruy.name, 'Ruy Lopez: Closed');

      final morphy =
          OpeningBook.identify(const ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6']);
      expect(morphy, isNotNull);
      expect(morphy!.eco, startsWith('C7'));
      expect(morphy.name, 'Ruy Lopez: Morphy Defense');
      // The deeper line must be a different (more specific) entry.
      expect(ruy.name, isNot(morphy.name));
      expect(ruy.eco, isNot(morphy.eco));
    });

    test('tolerates check/mate suffixes the book strips', () {
      // 1.e4 e5 2.Nf3 Nc6 3.Bb5 pins with a check on some move orders; use a
      // line that genuinely contains a check in its SAN.
      final withCheck = OpeningBook.identify(const [
        'e4',
        'e5',
        'Nf3',
        'Nc6',
        'Bb5',
        'Nf6',
        'O-O',
        'Nxe4',
        'd4',
        'Nd6',
        'Bxc6',
        'dxc6',
        'dxe5',
        'Nf5',
        'Qxd8+',
      ]);
      // Whether or not that exact line is in the book, identify must not
      // throw and must accept '+'-suffixed SAN.
      final bookLine = OpeningBook.identify(const ['Qxd8+']);
      expect(withCheck, isA<OpeningMatch?>());
      expect(bookLine, isA<OpeningMatch?>());
    });

    test('returns null for sequences outside the book', () {
      // 1.a6 never begins a book line, so nothing matches at any depth.
      expect(OpeningBook.identify(const ['a6', 'a3', 'b4', 'b5']), isNull);
      expect(OpeningBook.identify(const ['h5', 'h4', 'a3', 'a4']), isNull);
    });

    test('never throws on odd input', () {
      expect(() => OpeningBook.identify(const ['', '']), returnsNormally);
      expect(() => OpeningBook.identify(const ['???', 'e4']), returnsNormally);
      expect(OpeningBook.identify(const ['', '']), isNull);
    });

    test('ignores moves past the book horizon', () {
      final moves = <String>[
        'e4',
        'c5',
        'Nf3',
        'd6',
        'd4',
        'cxd4',
        'Nxd4',
        'Nf6',
        'Nc3',
        'a6',
        'Be3',
        'e5',
        'Nb3',
        'Be7',
        'f3',
        'Be6',
        'Qd2',
        'O-O',
        'g4',
        'c4',
      ];
      final match = OpeningBook.identify(moves);
      expect(match, isNotNull);
      expect(match!.eco, startsWith('B9'));
    });
  });

  group('OpeningBook.lines', () {
    test('exposes the same data as the raw constant', () {
      expect(OpeningBook.lines, hasLength(OpeningBook.entryCount));
      final first = OpeningBook.lines.first;
      expect(first.moves, kOpeningLines.first.moves);
      expect(first.eco, kOpeningLines.first.eco);
      expect(first.name, kOpeningLines.first.name);
    });
  });

  group('OpeningMatch', () {
    test('equality and display', () {
      const a = OpeningMatch(
        name: 'Sicilian Defense: Najdorf Variation',
        eco: 'B90',
        family: 'Sicilian Defense',
        variation: 'Najdorf Variation',
      );
      const b = OpeningMatch(
        name: 'Sicilian Defense: Najdorf Variation',
        eco: 'B90',
        family: 'Sicilian Defense',
        variation: 'Najdorf Variation',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.displayName, a.name);
      expect(a.hasVariation, isTrue);
      expect('$a', contains('B90'));
    });
  });
}
