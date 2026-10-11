import '../rating/elo.dart';
import 'time_control.dart';

/// Rating plus record for one rating category.
class PlayerRating {
  PlayerRating({
    required this.rating,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    List<RatingPoint>? history,
  }) : history = history ?? <RatingPoint>[];

  int rating;
  int gamesPlayed;
  int wins;
  int losses;
  int draws;
  final List<RatingPoint> history;

  /// True until [Elo.provisionalGames] rated games have been played.
  bool get isProvisional => Elo.isProvisional(gamesPlayed);

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  /// Applies a finished game's score (1 / 0.5 / 0) and returns the change.
  RatingChange recordGame({
    required RatingCategory category,
    required int opponentRating,
    required double score,
    DateTime? at,
  }) {
    final change = Elo.calculate(
      category: category,
      rating: rating,
      opponentRating: opponentRating,
      score: score,
      gamesPlayed: gamesPlayed,
    );
    rating = change.ratingAfter;
    gamesPlayed++;
    if (score == 1.0) {
      wins++;
    } else if (score == 0.0) {
      losses++;
    } else {
      draws++;
    }
    history.add(RatingPoint(
      rating: rating,
      timestamp: at ?? DateTime.now(),
      delta: change.delta,
    ));
    // Keep the graph bounded: last 200 points is plenty for a curve.
    if (history.length > 200) {
      history.removeRange(0, history.length - 200);
    }
    return change;
  }

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'history': [for (final p in history) p.toJson()],
      };

  factory PlayerRating.fromJson(Map<String, dynamic> json) => PlayerRating(
        rating: (json['rating'] as num?)?.toInt() ?? Elo.startingRating,
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
        history: [
          for (final p in (json['history'] as List?) ?? const [])
            RatingPoint.fromJson(p as Map<String, dynamic>),
        ],
      );
}

/// Puzzle-skill record (separate from play ratings).
class PuzzleStats {
  PuzzleStats({
    this.rating = 1200,
    this.solved = 0,
    this.attempted = 0,
    this.streak = 0,
    this.bestStreak = 0,
    List<RatingPoint>? history,
  }) : history = history ?? <RatingPoint>[];

  int rating;
  int solved;
  int attempted;
  int streak;
  int bestStreak;
  final List<RatingPoint> history;

  double get accuracy => attempted == 0 ? 0 : solved / attempted;

  void record({required bool wasSolved, required int delta, DateTime? at}) {
    attempted++;
    if (wasSolved) {
      solved++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
    }
    rating = (rating + delta).clamp(100, 4000);
    history.add(RatingPoint(
      rating: rating,
      timestamp: at ?? DateTime.now(),
      delta: delta,
    ));
    if (history.length > 200) {
      history.removeRange(0, history.length - 200);
    }
  }

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'solved': solved,
        'attempted': attempted,
        'streak': streak,
        'bestStreak': bestStreak,
        'history': [for (final p in history) p.toJson()],
      };

  factory PuzzleStats.fromJson(Map<String, dynamic> json) => PuzzleStats(
        rating: (json['rating'] as num?)?.toInt() ?? 1200,
        solved: (json['solved'] as num?)?.toInt() ?? 0,
        attempted: (json['attempted'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
        history: [
          for (final p in (json['history'] as List?) ?? const [])
            RatingPoint.fromJson(p as Map<String, dynamic>),
        ],
      );
}

/// A local player account (including guests).
class PlayerProfile {
  PlayerProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.isGuest = false,
    DateTime? createdAt,
    Map<RatingCategory, PlayerRating>? ratings,
    PuzzleStats? puzzleStats,
    this.avatarEmoji,
    this.avatarColor = 0xffC62828,
    this.statusMessage = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        ratings = ratings ?? {},
        puzzleStats = puzzleStats ?? PuzzleStats();

  final String id;
  final String username;
  final String displayName;
  final bool isGuest;
  final DateTime createdAt;

  /// Ratings per category; missing entries default to [Elo.startingRating].
  final Map<RatingCategory, PlayerRating> ratings;

  PuzzleStats puzzleStats;

  /// Optional original avatar (emoji glyph + solid colour), no artwork assets
  /// needed — keeps the identity system original and lightweight.
  final String? avatarEmoji;
  final int avatarColor;
  final String statusMessage;

  PlayerRating ratingFor(RatingCategory category) =>
      ratings.putIfAbsent(category, () => PlayerRating(rating: Elo.startingRating));

  int rating(RatingCategory category) => ratingFor(category).rating;

  /// Highest rating across categories (profile headline number).
  int get peakRating {
    var best = 0;
    for (final r in ratings.values) {
      if (r.rating > best) best = r.rating;
    }
    return best == 0 ? Elo.startingRating : best;
  }

  /// Total games across categories.
  int get totalGames {
    var total = 0;
    for (final r in ratings.values) {
      total += r.gamesPlayed;
    }
    return total;
  }

  int get totalWins {
    var total = 0;
    for (final r in ratings.values) {
      total += r.wins;
    }
    return total;
  }

  int get totalDraws {
    var total = 0;
    for (final r in ratings.values) {
      total += r.draws;
    }
    return total;
  }

  int get totalLosses {
    var total = 0;
    for (final r in ratings.values) {
      total += r.losses;
    }
    return total;
  }

  /// Two-letter monogram used when there is no avatar glyph.
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'isGuest': isGuest,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'ratings': {
          for (final e in ratings.entries) e.key.name: e.value.toJson(),
        },
        'puzzleStats': puzzleStats.toJson(),
        'avatarEmoji': avatarEmoji,
        'avatarColor': avatarColor,
        'statusMessage': statusMessage,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        id: json['id'] as String,
        username: json['username'] as String? ?? 'player',
        displayName: json['displayName'] as String? ?? 'Player',
        isGuest: json['isGuest'] as bool? ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
        ratings: {
          for (final e in ((json['ratings'] as Map?) ?? const {}).entries)
            RatingCategory.values.firstWhere(
              (c) => c.name == e.key,
              orElse: () => RatingCategory.rapid,
            ): PlayerRating.fromJson(e.value as Map<String, dynamic>),
        },
        puzzleStats: PuzzleStats.fromJson(
          (json['puzzleStats'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        avatarEmoji: json['avatarEmoji'] as String?,
        avatarColor: (json['avatarColor'] as num?)?.toInt() ?? 0xffC62828,
        statusMessage: json['statusMessage'] as String? ?? '',
      );
}
