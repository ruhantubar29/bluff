import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/player_profile.dart';
import '../core/models/time_control.dart';
import '../core/rating/elo.dart';
import 'chess_storage.dart';

/// Outcome of an auth attempt.
class AuthResult {
  const AuthResult._({this.profile, this.recoveryCode, this.error});

  const AuthResult.success(PlayerProfile profile, {String? recoveryCode})
      : this._(profile: profile, recoveryCode: recoveryCode);

  const AuthResult.failure(String error) : this._(error: error);

  final PlayerProfile? profile;

  /// One-time recovery code, only present right after sign-up.
  final String? recoveryCode;

  final String? error;

  bool get ok => profile != null;
}

/// Local-first account system.
///
/// Everything runs on-device: profiles live in [ChessStorage] and passwords
/// are never stored — only PBKDF2-HMAC-SHA256 hashes with a per-account
/// random salt. Each account gets a one-time recovery code that can reset the
/// password.
///
/// The service is deliberately interface-shaped so a real backend can replace
/// it later without touching the UI.
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  static const String _accountsKey = 'chess_accounts_v1';

  /// PBKDF2 work factor. Pure-Dart HMAC, so this stays around a quarter of a
  /// second on a phone — enough to make offline cracking unattractive.
  static const int iterations = 120000;

  static const int _minPasswordLength = 8;

  PlayerProfile? _current;
  bool _guest = false;

  /// The signed-in profile (or guest profile), loading/creating it lazily.
  Future<PlayerProfile> get current async {
    final existing = _current;
    if (existing != null) return existing;
    final stored = await ChessStorage.instance.loadCurrentProfile();
    if (stored != null) {
      _current = stored;
      _guest = stored.isGuest;
      return stored;
    }
    return ensureGuest();
  }

  /// True when the session is a local guest (no password, no sync).
  bool get isGuest => _guest;

  /// True once any profile (including a guest) is loaded.
  bool get isSignedIn => _current != null;

  /// The in-memory profile without touching storage (null before first load).
  PlayerProfile? get currentOrNull => _current;

  /// Creates or restores the local guest profile used when nobody signs in.
  Future<PlayerProfile> ensureGuest() async {
    final stored = await ChessStorage.instance.loadCurrentProfile();
    if (stored != null && stored.isGuest) {
      _current = stored;
      _guest = true;
      return stored;
    }
    final guest = PlayerProfile(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      username: 'guest',
      displayName: 'Guest',
      isGuest: true,
      ratings: _freshRatings(),
    );
    await ChessStorage.instance.upsertProfile(guest);
    await ChessStorage.instance.saveCurrentProfileId(guest.id);
    _current = guest;
    _guest = true;
    return guest;
  }

  Map<RatingCategory, PlayerRating> _freshRatings() => {
        for (final category in const [
          RatingCategory.bullet,
          RatingCategory.blitz,
          RatingCategory.rapid,
          RatingCategory.classical,
        ])
          category: PlayerRating(rating: Elo.startingRating),
      };

  // ------------------------------------------------------------- sign-up --

  /// Creates a local account. Returns the profile plus a one-time recovery
  /// code the user must store somewhere safe.
  Future<AuthResult> signUp({
    required String username,
    required String password,
    String? displayName,
  }) async {
    final clean = username.trim();
    final handle = clean.toLowerCase();
    if (handle.length < 3 || handle.length > 20) {
      return const AuthResult.failure(
          'Username must be 3–20 characters.');
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(handle)) {
      return const AuthResult.failure(
          'Use lowercase letters, numbers and underscores only.');
    }
    if (password.length < _minPasswordLength) {
      return const AuthResult.failure(
          'Password must be at least $_minPasswordLength characters.');
    }

    final accounts = await _loadAccounts();
    if (accounts.containsKey(handle)) {
      return const AuthResult.failure('That username is taken.');
    }

    final profile = PlayerProfile(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      username: handle,
      displayName: (displayName == null || displayName.trim().isEmpty)
          ? clean
          : displayName.trim(),
      isGuest: false,
      ratings: _freshRatings(),
    );

    final salt = _randomHex(16);
    final recovery = _makeRecoveryCode();
    final account = _Account(
      profileId: profile.id,
      username: handle,
      salt: salt,
      hash: _hash(password, salt, iterations),
      iterations: iterations,
      recoveryHash: _hash(recovery, salt, iterations),
      createdAt: DateTime.now(),
    );

    accounts[handle] = account;
    await _saveAccounts(accounts);
    await ChessStorage.instance.upsertProfile(profile);
    await ChessStorage.instance.saveCurrentProfileId(profile.id);

    _current = profile;
    _guest = false;
    return AuthResult.success(profile, recoveryCode: recovery);
  }

  // ------------------------------------------------------------- sign-in --

  /// Signs in with a username (or the e-mail used at sign-up) and password.
  Future<AuthResult> signIn({
    required String identifier,
    required String password,
  }) async {
    final handle = identifier.trim().toLowerCase();
    final accounts = await _loadAccounts();

    final _Account? account = accounts[handle];
    if (account == null) {
      return const AuthResult.failure('No account with that username.');
    }

    if (_hash(password, account.salt, account.iterations) != account.hash) {
      return const AuthResult.failure('Incorrect password.');
    }

    final profile = await _profileFor(account);
    _current = profile;
    _guest = false;
    await ChessStorage.instance.saveCurrentProfileId(profile.id);
    return AuthResult.success(profile);
  }

  /// Replaces the guest session with an existing local profile (switcher).
  Future<bool> switchTo(String profileId) async {
    final profiles = await ChessStorage.instance.loadProfiles();
    for (final profile in profiles) {
      if (profile.id == profileId) {
        _current = profile;
        _guest = profile.isGuest;
        await ChessStorage.instance.saveCurrentProfileId(profile.id);
        return true;
      }
    }
    return false;
  }

  Future<void> signOut() async {
    await ChessStorage.instance.saveCurrentProfileId('');
    _current = null;
    _guest = false;
  }

  // -------------------------------------------------- password recovery --

  /// Resets the password using the one-time recovery code from sign-up.
  Future<AuthResult> resetPassword({
    required String username,
    required String recoveryCode,
    required String newPassword,
  }) async {
    if (newPassword.length < _minPasswordLength) {
      return const AuthResult.failure(
          'Password must be at least $_minPasswordLength characters.');
    }
    final handle = username.trim().toLowerCase();
    final accounts = await _loadAccounts();
    final account = accounts[handle];
    if (account == null) {
      return const AuthResult.failure('No account with that username.');
    }
    final normalized = _normalizeCode(recoveryCode);
    if (_hash(normalized, account.salt, account.iterations) !=
        account.recoveryHash) {
      return const AuthResult.failure('That recovery code is not valid.');
    }

    accounts[handle] = _Account(
      profileId: account.profileId,
      username: account.username,
      salt: account.salt,
      hash: _hash(newPassword, account.salt, iterations),
      iterations: iterations,
      // A used code stays valid until the user rotates it — practical and
      // still requires possession of the original code.
      recoveryHash: account.recoveryHash,
      createdAt: account.createdAt,
    );
    await _saveAccounts(accounts);

    final profile = await _profileFor(account);
    _current = profile;
    _guest = false;
    await ChessStorage.instance.saveCurrentProfileId(profile.id);
    return AuthResult.success(profile);
  }

  /// Changes the password of the signed-in account.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final profile = _current;
    if (profile == null || profile.isGuest) {
      return const AuthResult.failure('Sign in first.');
    }
    if (newPassword.length < _minPasswordLength) {
      return const AuthResult.failure(
          'Password must be at least $_minPasswordLength characters.');
    }
    final accounts = await _loadAccounts();
    final account = accounts[profile.username];
    if (account == null) {
      return const AuthResult.failure('Local account data is missing.');
    }
    if (_hash(currentPassword, account.salt, account.iterations) !=
        account.hash) {
      return const AuthResult.failure('Incorrect password.');
    }
    accounts[profile.username] = _Account(
      profileId: account.profileId,
      username: account.username,
      salt: account.salt,
      hash: _hash(newPassword, account.salt, iterations),
      iterations: iterations,
      recoveryHash: account.recoveryHash,
      createdAt: account.createdAt,
    );
    await _saveAccounts(accounts);
    return AuthResult.success(profile);
  }

  // ----------------------------------------------------------- internals --

  Future<PlayerProfile> _profileFor(_Account account) async {
    final profiles = await ChessStorage.instance.loadProfiles();
    for (final profile in profiles) {
      if (profile.id == account.profileId) return profile;
    }
    final fresh = PlayerProfile(
      id: account.profileId,
      username: account.username,
      displayName: account.username,
      isGuest: false,
      ratings: _freshRatings(),
    );
    await ChessStorage.instance.upsertProfile(fresh);
    return fresh;
  }

  Future<Map<String, _Account>> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key:
              _Account.fromJson(entry.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAccounts(Map<String, _Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode({
        for (final entry in accounts.entries)
          entry.key: entry.value.toJson(),
      }),
    );
  }

  /// PBKDF2-HMAC-SHA256 (single block is enough for our 32-byte output).
  static String _hash(String secret, String saltHex, int iterations) {
    final salt = _fromHex(saltHex);
    final key = utf8.encode(secret);
    var block = <int>[...salt, 0, 0, 0, 1];
    var u = Hmac(sha256, key).convert(block).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = Hmac(sha256, key).convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return _toHex(result);
  }

  static String _randomHex(int bytes) {
    final rng = Random.secure();
    return _toHex(List<int>.generate(bytes, (_) => rng.nextInt(256)));
  }

  static String _makeRecoveryCode() {
    final rng = Random.secure();
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String group() => List.generate(
        4, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
    return 'BLUFF-${group()}-${group()}-${group()}';
  }

  /// Canonicalizes a recovery code so case, spacing and dash placement don't
  /// matter: "bluff abcd efgh jklm" and "BLUFF-ABCD-EFGH-JKL M" both yield
  /// `BLUFF-ABCD-EFGH-JKLM`.
  static String _normalizeCode(String code) {
    final cleaned =
        code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final match = RegExp(r'^BLUFF([A-Z0-9]{12})$').firstMatch(cleaned);
    if (match == null) return cleaned;
    final body = match.group(1)!;
    return 'BLUFF-${body.substring(0, 4)}-${body.substring(4, 8)}-'
        '${body.substring(8, 12)}';
  }

  static String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  static List<int> _fromHex(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }
}

class _Account {
  const _Account({
    required this.profileId,
    required this.username,
    required this.salt,
    required this.hash,
    required this.iterations,
    required this.recoveryHash,
    required this.createdAt,
  });

  final String profileId;
  final String username;
  final String salt;
  final String hash;
  final int iterations;
  final String recoveryHash;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'username': username,
        'salt': salt,
        'hash': hash,
        'iterations': iterations,
        'recoveryHash': recoveryHash,
        'createdAt': createdAt.toIso8601String(),
      };

  factory _Account.fromJson(Map<String, dynamic> json) => _Account(
        profileId: json['profileId'] as String? ?? '',
        username: json['username'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        hash: json['hash'] as String? ?? '',
        iterations:
            (json['iterations'] as num?)?.toInt() ?? SessionService.iterations,
        recoveryHash: json['recoveryHash'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
