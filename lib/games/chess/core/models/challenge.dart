import 'time_control.dart';

/// Lifecycle of a challenge.
enum ChallengeStatus {
  waiting,
  accepted,
  declined,
  cancelled,
  expired,
}

extension ChallengeStatusLabel on ChallengeStatus {
  String get label {
    switch (this) {
      case ChallengeStatus.waiting:
        return 'Waiting';
      case ChallengeStatus.accepted:
        return 'Accepted';
      case ChallengeStatus.declined:
        return 'Declined';
      case ChallengeStatus.cancelled:
        return 'Cancelled';
      case ChallengeStatus.expired:
        return 'Expired';
    }
  }

  bool get isOpen => this == ChallengeStatus.waiting;
}

/// Which side the challenger offers to take.
enum SidePreference { white, black, random }

extension SidePreferenceLabel on SidePreference {
  String get label {
    switch (this) {
      case SidePreference.white:
        return 'White';
      case SidePreference.black:
        return 'Black';
      case SidePreference.random:
        return 'Random';
    }
  }
}

/// An invitation to play: sent by one player to another with a time control.
class ChessChallenge {
  const ChessChallenge({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.timeControlLabel,
    required this.timeCategory,
    required this.createdAt,
    this.rated = true,
    this.sidePreference = SidePreference.random,
    this.status = ChallengeStatus.waiting,
    this.respondedAt,
  });

  final String id;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;

  /// Matches [TimeControl.presets] labels (or 'Unlimited').
  final String timeControlLabel;
  final TimeCategory timeCategory;
  final bool rated;
  final SidePreference sidePreference;
  final DateTime createdAt;
  final ChallengeStatus status;
  final DateTime? respondedAt;

  TimeControl? get timeControl =>
      timeControlLabel == TimeControl.unlimited.displayLabel
          ? TimeControl.unlimited
          : TimeControl.byLabel(timeControlLabel);

  ChessChallenge copyWith({ChallengeStatus? status, DateTime? respondedAt}) =>
      ChessChallenge(
        id: id,
        fromId: fromId,
        fromName: fromName,
        toId: toId,
        toName: toName,
        timeControlLabel: timeControlLabel,
        timeCategory: timeCategory,
        createdAt: createdAt,
        rated: rated,
        sidePreference: sidePreference,
        status: status ?? this.status,
        respondedAt: respondedAt ?? this.respondedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'fromName': fromName,
        'toId': toId,
        'toName': toName,
        'timeControlLabel': timeControlLabel,
        'timeCategory': timeCategory.name,
        'rated': rated,
        'sidePreference': sidePreference.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status.name,
        'respondedAt': respondedAt?.millisecondsSinceEpoch,
      };

  factory ChessChallenge.fromJson(Map<String, dynamic> json) => ChessChallenge(
        id: json['id'] as String,
        fromId: json['fromId'] as String? ?? '',
        fromName: json['fromName'] as String? ?? 'Player',
        toId: json['toId'] as String? ?? '',
        toName: json['toName'] as String? ?? 'Player',
        timeControlLabel: json['timeControlLabel'] as String? ?? '10 + 0',
        timeCategory: TimeCategory.values.firstWhere(
          (c) => c.name == json['timeCategory'],
          orElse: () => TimeCategory.rapid,
        ),
        rated: json['rated'] as bool? ?? true,
        sidePreference: SidePreference.values.firstWhere(
          (s) => s.name == json['sidePreference'],
          orElse: () => SidePreference.random,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
        status: ChallengeStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ChallengeStatus.waiting,
        ),
        respondedAt: json['respondedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (json['respondedAt'] as num).toInt(),
              ),
      );
}
