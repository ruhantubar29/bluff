import 'package:bluff/core/reviews/review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The prompt must fire on the Nth recorded game, once ever, and must never
/// throw when the platform has no review flow (test environment doesn't).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReviewService.instance.resetForTesting();
  });

  test('stays silent below the game threshold', () async {
    final prefs = await SharedPreferences.getInstance();

    for (var i = 0;
        i < ReviewService.gamesBeforeAsk - 1;
        i++) {
      await ReviewService.instance.maybeAskAfterGame();
    }

    expect(
      prefs.getBool(ReviewService.askedKey),
      isNull,
    );
    expect(
      prefs.getInt(ReviewService.gamesSinceAskKey),
      ReviewService.gamesBeforeAsk - 1,
    );
  });

  test('asks exactly once, then never again', () async {
    final prefs = await SharedPreferences.getInstance();

    for (var i = 0; i < ReviewService.gamesBeforeAsk + 3; i++) {
      await ReviewService.instance.maybeAskAfterGame();
    }

    expect(
      prefs.getBool(ReviewService.askedKey),
      isTrue,
    );
    // After the ask the counter stops moving — one prompt, ever.
    expect(
      prefs.getInt(ReviewService.gamesSinceAskKey),
      ReviewService.gamesBeforeAsk,
    );

    // A fresh boot stays quiet too.
    ReviewService.instance.resetForTesting();
    await ReviewService.instance.maybeAskAfterGame();
    expect(
      prefs.getInt(ReviewService.gamesSinceAskKey),
      ReviewService.gamesBeforeAsk,
    );
  });

  test('never throws in an environment without a review flow',
      () async {
    for (var i = 0; i < ReviewService.gamesBeforeAsk; i++) {
      await ReviewService.instance.maybeAskAfterGame();
    }
    // Reaching this line without an exception is the assertion.
  });
}
