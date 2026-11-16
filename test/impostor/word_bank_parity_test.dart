import 'package:bluff/games/impostor/data/bn/word_bank.dart' as bangla;
import 'package:bluff/games/impostor/data/en/word_bank.dart' as english;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Impostor word banks', () {
    test('both languages ship the same categories in the same order', () {
      expect(bangla.WordBank.bank.keys, english.WordBank.bank.keys);
    });

    test('both languages ship the same number of words per category', () {
      bangla.WordBank.bank.forEach((category, entries) {
        expect(
          english.WordBank.bank[category]!.length,
          entries.length,
          reason: 'category "$category" is out of sync between bn and en',
        );
      });
    });

    test('every Bangla entry has a word and five hints', () {
      bangla.WordBank.bank.forEach((category, entries) {
        for (final entry in entries) {
          expect(entry.word, isNotEmpty, reason: '"$category" has an empty word');
          expect(entry.hints, hasLength(5),
              reason: '"$category/${entry.word}" must have exactly 5 hints');
          expect(entry.hints.every((hint) => hint.trim().isNotEmpty), isTrue,
              reason: '"$category/${entry.word}" has a blank hint');
        }
      });
    });

    test('every English entry has a word and five hints', () {
      english.WordBank.bank.forEach((category, entries) {
        for (final entry in entries) {
          expect(entry.word, isNotEmpty, reason: '"$category" has an empty word');
          expect(entry.hints, hasLength(5),
              reason: '"$category/${entry.word}" must have exactly 5 hints');
          expect(entry.hints.every((hint) => hint.trim().isNotEmpty), isTrue,
              reason: '"$category/${entry.word}" has a blank hint');
        }
      });
    });

    test('no word repeats inside a category', () {
      bangla.WordBank.bank.forEach((category, entries) {
        final words = entries.map((e) => e.word).toSet();
        expect(words, hasLength(entries.length),
            reason: '"$category" (bn) repeats a word');
      });

      english.WordBank.bank.forEach((category, entries) {
        final words = entries.map((e) => e.word).toSet();
        expect(words, hasLength(entries.length),
            reason: '"$category" (en) repeats a word');
      });
    });

    test('entriesFor returns the category and falls back to empty', () {
      expect(bangla.WordBank.entriesFor('Animals'), isNotEmpty);
      expect(english.WordBank.entriesFor('Anime'), isNotEmpty);
      expect(bangla.WordBank.entriesFor('Nope'), isEmpty);
      expect(english.WordBank.entriesFor('Nope'), isEmpty);
    });
  });
}
