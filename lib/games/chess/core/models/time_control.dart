/// Chess clock time controls and categories.
library;

enum TimeCategory { bullet, blitz, rapid, classical, unlimited }

/// A time control: base time plus per-move increment.
///
/// [initial] is the starting time for each player and [increment] is
/// added after every move that player makes.
class TimeControl {
  const TimeControl({
    required this.initial,
    required this.increment,
    required this.category,
    this.label,
  });

  final Duration initial;
  final Duration increment;
  final TimeCategory category;

  /// Human readable name (e.g. "3 + 2"). Derived from [initial]/[increment]
  /// when null.
  final String? label;

  static const TimeControl unlimited = TimeControl(
    initial: Duration(days: 36500),
    increment: Duration.zero,
    category: TimeCategory.unlimited,
    label: 'Unlimited',
  );

  /// All presets required by the product spec.
  static const List<TimeControl> presets = [
    TimeControl(
      initial: Duration(minutes: 1),
      increment: Duration.zero,
      category: TimeCategory.bullet,
      label: '1 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 1),
      increment: Duration(seconds: 1),
      category: TimeCategory.bullet,
      label: '1 + 1',
    ),
    TimeControl(
      initial: Duration(minutes: 2),
      increment: Duration(seconds: 1),
      category: TimeCategory.bullet,
      label: '2 + 1',
    ),
    TimeControl(
      initial: Duration(minutes: 3),
      increment: Duration.zero,
      category: TimeCategory.blitz,
      label: '3 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 3),
      increment: Duration(seconds: 2),
      category: TimeCategory.blitz,
      label: '3 + 2',
    ),
    TimeControl(
      initial: Duration(minutes: 5),
      increment: Duration.zero,
      category: TimeCategory.blitz,
      label: '5 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 5),
      increment: Duration(seconds: 3),
      category: TimeCategory.blitz,
      label: '5 + 3',
    ),
    TimeControl(
      initial: Duration(minutes: 10),
      increment: Duration.zero,
      category: TimeCategory.rapid,
      label: '10 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 10),
      increment: Duration(seconds: 5),
      category: TimeCategory.rapid,
      label: '10 + 5',
    ),
    TimeControl(
      initial: Duration(minutes: 15),
      increment: Duration(seconds: 10),
      category: TimeCategory.rapid,
      label: '15 + 10',
    ),
    TimeControl(
      initial: Duration(minutes: 30),
      increment: Duration.zero,
      category: TimeCategory.classical,
      label: '30 + 0',
    ),
  ];

  /// Preset whose label matches, used when restoring saved games.
  static TimeControl? byLabel(String label) {
    for (final tc in presets) {
      if (tc.displayLabel == label) return tc;
    }
    return null;
  }

  String get displayLabel {
    if (label != null) return label!;
    final base = initial.inSeconds;
    final inc = increment.inSeconds;
    return '$base + $inc';
  }

  String get categoryName {
    switch (category) {
      case TimeCategory.bullet:
        return 'Bullet';
      case TimeCategory.blitz:
        return 'Blitz';
      case TimeCategory.rapid:
        return 'Rapid';
      case TimeCategory.classical:
        return 'Classical';
      case TimeCategory.unlimited:
        return 'Unlimited';
    }
  }

  /// Rating category this control plays for.
  RatingCategory get ratingCategory {
    switch (category) {
      case TimeCategory.bullet:
        return RatingCategory.bullet;
      case TimeCategory.blitz:
        return RatingCategory.blitz;
      case TimeCategory.rapid:
        return RatingCategory.rapid;
      case TimeCategory.classical:
        return RatingCategory.classical;
      case TimeCategory.unlimited:
        return RatingCategory.classical;
    }
  }

  bool get hasClock => category != TimeCategory.unlimited;

  @override
  bool operator ==(Object other) =>
      other is TimeControl &&
      other.initial == initial &&
      other.increment == increment;

  @override
  int get hashCode => Object.hash(initial, increment);
}

/// Rating categories a player can hold a rating in.
enum RatingCategory {
  bullet('Bullet'),
  blitz('Blitz'),
  rapid('Rapid'),
  classical('Classical'),
  puzzle('Puzzle');

  const RatingCategory(this.displayName);

  final String displayName;
}
