import 'dart:math' as math;

import '../models/time_control.dart';

/// Result of an Elo calculation.
class RatingChange {
  const RatingChange({
    required this.category,
    required this.ratingBefore,
    required this.ratingAfter,
    required this.expectedScore,
    required this.kFactor,
    required this.provisionalAfter,
  });

  final RatingCategory category;
  final int ratingBefore;
  final int ratingAfter;
  final double expectedScore;
  final int kFactor;

  /// Whether the player is still provisionally rated after this game.
  final bool provisionalAfter;

  int get delta => ratingAfter - ratingBefore;

  @override
  String toString() =>
      '$category: $ratingBefore → $ratingAfter (${delta >= 0 ? '+' : ''}$delta)';
}

/// Standard Elo rating maths.
///
/// * Expected score: `1 / (1 + 10^((rb - ra) / 400))`
/// * K-factor: 40 while provisional (fewer than 30 rated games), then 20,
///   dropping to 10 for elite ratings (≥ 2400) — the conventional FIDE-style
///   schedule.
/// * Players stay *provisional* for their first [provisionalGames] rated
///   games; provisional ratings are typically displayed with a `~`.
class Elo {
  Elo._();

  /// Games played before a rating stops being provisional.
  static const int provisionalGames = 30;

  /// Rating at which the K-factor tightens for established players.
  static const int eliteRating = 2400;

  static const int startingRating = 1200;

  static const int defaultKProvisional = 40;
  static const int defaultKEstablished = 20;
  static const int defaultKElite = 10;

  /// K-factor for a rating at [gamesPlayed] rated games.
  static int kFactor(int rating, int gamesPlayed) {
    if (gamesPlayed < provisionalGames) return defaultKProvisional;
    if (rating >= eliteRating) return defaultKElite;
    return defaultKEstablished;
  }

  /// Probability that [playerRating] scores at least a draw against
  /// [opponentRating].
  static double expectedScore(int playerRating, int opponentRating) {
    return 1.0 / (1.0 + math.pow(10.0, (opponentRating - playerRating) / 400.0));
  }

  /// New rating for [rating] after scoring [score] (1, 0.5, 0) against
  /// [opponentRating], having played [gamesPlayed] rated games.
  static int newRating({
    required int rating,
    required int opponentRating,
    required double score,
    required int gamesPlayed,
  }) {
    final expected = expectedScore(rating, opponentRating);
    final k = kFactor(rating, gamesPlayed);
    final delta = k * (score - expected);
    return (rating + delta).round().clamp(100, 4000);
  }

  /// Full calculation with details, for display on the result screen.
  static RatingChange calculate({
    required RatingCategory category,
    required int rating,
    required int opponentRating,
    required double score,
    required int gamesPlayed,
  }) {
    final expected = expectedScore(rating, opponentRating);
    final k = kFactor(rating, gamesPlayed);
    final after = newRating(
      rating: rating,
      opponentRating: opponentRating,
      score: score,
      gamesPlayed: gamesPlayed,
    );
    return RatingChange(
      category: category,
      ratingBefore: rating,
      ratingAfter: after,
      expectedScore: expected,
      kFactor: k,
      provisionalAfter: gamesPlayed + 1 < provisionalGames,
    );
  }

  /// Whether a rating should be displayed as provisional (`~1450`).
  static bool isProvisional(int gamesPlayed) =>
      gamesPlayed < provisionalGames;
}

/// One point in a rating history series (for the profile graph).
class RatingPoint {
  const RatingPoint({
    required this.rating,
    required this.timestamp,
    this.delta = 0,
  });

  final int rating;
  final DateTime timestamp;
  final int delta;

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'delta': delta,
      };

  factory RatingPoint.fromJson(Map<String, dynamic> json) => RatingPoint(
        rating: (json['rating'] as num).toInt(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num).toInt(),
        ),
        delta: (json['delta'] as num?)?.toInt() ?? 0,
      );
}
