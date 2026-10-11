/// The single identity model for a Bluff player.
///
/// Mirrors Splash Party's profile: created locally during onboarding with no
/// account required, then upgraded in place when the player signs in.
class Profile {
  const Profile({
    this.name = '',
    this.avatarIndex = 0,
    this.avatarPhotoPath,
    this.gender = PlayerGender.ratherNotSay,
    this.ageBand = AgeBand.unknown,
    this.group = PlayGroup.friends,
    this.source = HearSource.other,
    this.notificationsEnabled = false,
    this.languageCode = 'en',
    this.createdAt = 0,
    this.uid,
    this.isSignedIn = false,
    this.isMigrated = false,
  });

  final String name;
  final int avatarIndex;

  /// Local path to the player's own gallery photo, when they chose one
  /// instead of a character avatar. Device-specific: a profile restored on
  /// another device falls back to [avatarIndex] (the file won't exist there).
  final String? avatarPhotoPath;
  final PlayerGender gender;
  final AgeBand ageBand;
  final PlayGroup group;
  final HearSource source;
  final bool notificationsEnabled;
  final String languageCode;
  final int createdAt;

  /// Firebase uid. Null until the anonymous session is created.
  final String? uid;
  final bool isSignedIn;

  /// True once local data has been pushed to the cloud account.
  final bool isMigrated;

  bool get hasName => name.trim().isNotEmpty;

  Profile copyWith({
    String? name,
    int? avatarIndex,
    String? avatarPhotoPath,
    bool clearAvatarPhoto = false,
    PlayerGender? gender,
    AgeBand? ageBand,
    PlayGroup? group,
    HearSource? source,
    bool? notificationsEnabled,
    String? languageCode,
    int? createdAt,
    String? uid,
    bool clearUid = false,
    bool? isSignedIn,
    bool? isMigrated,
  }) {
    return Profile(
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      avatarPhotoPath: clearAvatarPhoto
          ? null
          : (avatarPhotoPath ?? this.avatarPhotoPath),
      gender: gender ?? this.gender,
      ageBand: ageBand ?? this.ageBand,
      group: group ?? this.group,
      source: source ?? this.source,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      languageCode: languageCode ?? this.languageCode,
      createdAt: createdAt ?? this.createdAt,
      uid: clearUid ? null : (uid ?? this.uid),
      isSignedIn: isSignedIn ?? this.isSignedIn,
      isMigrated: isMigrated ?? this.isMigrated,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatarIndex': avatarIndex,
    'avatarPhotoPath': avatarPhotoPath,
    'gender': gender.id,
    'ageBand': ageBand.id,
    'group': group.id,
    'source': source.id,
    'notificationsEnabled': notificationsEnabled,
    'languageCode': languageCode,
    'createdAt': createdAt,
    'uid': uid,
    'isSignedIn': isSignedIn,
    'isMigrated': isMigrated,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      name: json['name'] as String? ?? '',
      avatarIndex: json['avatarIndex'] as int? ?? 0,
      avatarPhotoPath: json['avatarPhotoPath'] as String?,
      gender: PlayerGender.fromId(json['gender'] as String?),
      ageBand: AgeBand.fromId(json['ageBand'] as String?),
      group: PlayGroup.fromId(json['group'] as String?),
      source: HearSource.fromId(json['source'] as String?),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      languageCode: json['languageCode'] as String? ?? 'en',
      createdAt: json['createdAt'] as int? ?? 0,
      uid: json['uid'] as String?,
      isSignedIn: json['isSignedIn'] as bool? ?? false,
      isMigrated: json['isMigrated'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'Profile(name: $name, uid: $uid, '
      'isSignedIn: $isSignedIn)';
}

enum PlayerGender {
  male('male'),
  female('female'),
  nonbinary('nonbinary'),
  ratherNotSay('rather_not_say');

  const PlayerGender(this.id);
  final String id;

  static PlayerGender fromId(String? id) => PlayerGender.values.firstWhere(
    (value) => value.id == id,
    orElse: () => PlayerGender.ratherNotSay,
  );
}

enum AgeBand {
  under13('under13'),
  age13_17('13_17'),
  age18_20('18_20'),
  age21plus('21_plus'),
  unknown('unknown');

  const AgeBand(this.id);
  final String id;

  /// Unknown ids (including the retired pre-release bands
  /// `18_24` / `25_34` / `35_44` / `45_plus`) fall back to
  /// [unknown] instead of throwing.
  static AgeBand fromId(String? id) => AgeBand.values.firstWhere(
    (value) => value.id == id,
    orElse: () => AgeBand.unknown,
  );
}

enum PlayGroup {
  friends('friends'),
  family('family'),
  partner('partner'),
  colleagues('colleagues');

  const PlayGroup(this.id);
  final String id;

  static PlayGroup fromId(String? id) => PlayGroup.values.firstWhere(
    (value) => value.id == id,
    orElse: () => PlayGroup.friends,
  );
}

enum HearSource {
  store('store'),
  friends('friends'),
  socialMedia('social_media'),
  other('other');

  const HearSource(this.id);
  final String id;

  static HearSource fromId(String? id) => HearSource.values.firstWhere(
    (value) => value.id == id,
    orElse: () => HearSource.other,
  );
}

/// Where the app should land after the splash/bootstrap step. Language
/// selection is the first onboarding step, not a screen of its own.
enum AppStartState { loading, onboarding, main }
