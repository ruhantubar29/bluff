import 'package:bluff/core/language/app_language.dart';
import 'package:bluff/games/would_you_rather/data/categories.dart';
import 'package:bluff/games/would_you_rather/data/questions.dart';
import 'package:bluff/games/would_you_rather/logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the bank', () {
    test('keeps its shape', () {
      final counts = <String, int>{};
      for (final question in wouldYouRatherQuestions) {
        counts[question.category] = (counts[question.category] ?? 0) + 1;
      }

      expect(wouldYouRatherQuestions, hasLength(62));
      expect(counts, <String, int>{
        'classic': 14,
        'party': 12,
        'spicy': 12,
        'taboo': 12,
        'deep': 12,
      });
    });

    test('every question points at a real category and splits in both languages',
        () {
      for (final question in wouldYouRatherQuestions) {
        expect(
          categoryById(question.category),
          isNotNull,
          reason: 'unknown category on "${question.en}"',
        );
        expect(question.en.split('|'), hasLength(2),
            reason: 'English side: "${question.en}"');
        expect(question.bn.split('|'), hasLength(2),
            reason: 'Bangla side: "${question.bn}"');
      }
    });

    test('no option is empty in either language', () {
      for (final question in wouldYouRatherQuestions) {
        for (final side in [...question.en.split('|'), ...question.bn.split('|')]) {
          expect(side.trim(), isNotEmpty, reason: question.en);
        }
      }
    });
  });

  group('WouldYouRatherGameLogic', () {
    test('spans every selected category and nothing else', () {
      final game = WouldYouRatherGameLogic(
        selectedCategoryIds: const ['classic', 'party'],
        language: AppLanguage.english,
      );

      expect(game.deckLength, 14 + 12);

      final seen = <WouldYouRatherQuestion>{};
      for (var i = 0; i < game.deckLength; i++) {
        seen.add(game.currentQuestion!);
        game.nextQuestion();
      }

      expect(seen, hasLength(game.deckLength), reason: 'a question repeated');
      expect(
        seen.every((q) => q.category == 'classic' || q.category == 'party'),
        isTrue,
        reason: 'a question from an unselected category leaked in',
      );
      expect(seen.map((q) => q.category).toSet(),
          <String>{'classic', 'party'});
    });

    test('reads the bank in the active language', () {
      final english = WouldYouRatherGameLogic(
        selectedCategoryIds: const ['classic'],
        language: AppLanguage.english,
      );
      final bangla = WouldYouRatherGameLogic(
        selectedCategoryIds: const ['classic'],
        language: AppLanguage.bangla,
      );

      final englishQuestion = english.currentQuestion!;
      expect(english.currentOptions, englishQuestion.en.split('|'));

      final banglaQuestion = bangla.currentQuestion!;
      expect(bangla.currentOptions, banglaQuestion.bn.split('|'));
    });

    test('keeps dealing past the end instead of running dry', () {
      final game = WouldYouRatherGameLogic(
        selectedCategoryIds: const ['deep'],
        language: AppLanguage.english,
      );

      for (var i = 0; i < game.deckLength * 3; i++) {
        game.nextQuestion();
        expect(game.currentQuestion, isNotNull, reason: 'deck ran out');
        expect(game.position, inInclusiveRange(1, game.deckLength));
        expect(game.hasQuestions, isTrue);
      }
    });

    test('reports nothing when no category was chosen', () {
      final game = WouldYouRatherGameLogic(
        selectedCategoryIds: const [],
        language: AppLanguage.english,
      );

      expect(game.hasQuestions, isFalse);
      expect(game.currentQuestion, isNull);
      expect(game.deckLength, 0);
      expect(game.position, 0);
    });
  });

  group('percentageFor', () {
    test('is deterministic', () {
      const sample = 'Be able to fly|Be invisible';
      expect(
        WouldYouRatherGameLogic.percentageFor(sample),
        WouldYouRatherGameLogic.percentageFor(sample),
      );
    });

    test('stays inside the range the card promises', () {
      for (final question in wouldYouRatherQuestions) {
        final percent = WouldYouRatherGameLogic.percentageFor(question.en);
        expect(percent, inInclusiveRange(26, 74), reason: question.en);
      }
    });
  });
}
