import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Splash-style App Store / Play Store review prompt.
///
/// Splash only asks after the player has demonstrably enjoyed the app — so
/// this fires on the Nth recorded game, once ever, and silently does nothing
/// when the platform has no review flow (emulator, desktop, CI).
class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  static const String askedKey = 'bluff.review.asked';
  static const String gamesSinceAskKey = 'bluff.review.games_since_ask';

  /// Games played before the prompt — enough to have formed an opinion,
  /// few enough that it still feels earned.
  static const int gamesBeforeAsk = 3;

  bool _asked = false;
  int _gamesSinceAsk = 0;
  bool _loaded = false;
  bool _inFlight = false;

  /// Test-only: forget in-memory state so each test boots from scratch.
  @visibleForTesting
  void resetForTesting() {
    _asked = false;
    _gamesSinceAsk = 0;
    _loaded = false;
    _inFlight = false;
  }

  @visibleForTesting
  Future<void> loadForTesting() => _load();

  Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _asked = prefs.getBool(askedKey) ?? false;
    _gamesSinceAsk = prefs.getInt(gamesSinceAskKey) ?? 0;
    _loaded = true;
  }

  /// Counts one recorded game and prompts when the threshold is reached.
  /// Safe to call from anywhere; never throws, never blocks.
  Future<void> maybeAskAfterGame() async {
    if (_inFlight) return;

    try {
      await _load();
      if (_asked) return;

      _inFlight = true;
      _gamesSinceAsk += 1;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(gamesSinceAskKey, _gamesSinceAsk);

      if (_gamesSinceAsk < gamesBeforeAsk) return;

      // One ask, ever — being nagged twice is worse than never asking.
      _asked = true;
      await prefs.setBool(askedKey, true);

      if (await InAppReview.instance.isAvailable()) {
        await InAppReview.instance.requestReview();
      }
    } catch (_) {
      // Review flow unavailable — the game just finished, keep it that way.
    } finally {
      _inFlight = false;
    }
  }
}
