import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// The version this build reports itself as.
///
/// Must match `version:` in pubspec.yaml (minus the `+build` number) —
/// `test/core/update/force_update_test.dart` fails if the two drift, so a
/// release cannot ship with a stale version string.
const String kAppVersion = '1.1.0';

/// The newest published version, read at launch.
///
/// Served by GitHub Pages from `docs/latest.json`, so cutting a release and
/// updating that one file is the whole update procedure — no server, no API
/// token and no rate limit to hit on every app start.
const String kLatestVersionUrl =
    'https://ruhantubar29.github.io/bluff/latest.json';

/// Where the update button takes the player.
///
/// Kept in step with `APK_NAME` in `docs/script.js`: GitHub resolves
/// `/releases/latest/download/<name>` to the asset on the newest published
/// release, so the landing page and the in-app button both always point at
/// the current APK.
const String kDownloadUrl =
    'https://github.com/ruhantubar29/bluff/releases/latest/download/BLUFF.apk';

/// How long to wait before asking the server again after a failed check.
///
/// The check runs until it gets an answer, so a player who was offline when
/// an update shipped is walled the moment they come back online rather than
/// only on their next cold start.
const Duration kUpdateRetryInterval = Duration(seconds: 15);

/// The version that previously proved this install outdated, or null.
///
/// Read before any network so an offline launch still shows the wall to
/// someone we already know is stale.
Future<String?> knownStaleVersion() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_staleKey);
}

/// Whether [version] is still newer than this build.
///
/// Self-resolves once the player has updated, so the stored value never
/// needs clearing by hand after a successful install.
bool stillOutdated(String? version) =>
    version != null && needsUpdate(version, kAppVersion);

/// Compares two dotted versions numerically so 1.10.0 beats 1.9.0.
///
/// Returns a negative number when [a] is older, zero when they match and a
/// positive number when [a] is newer. A version that cannot be parsed at all
/// compares as equal, so malformed data on either side can never lock
/// anyone out.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  if (pa == null || pb == null) return 0;
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Splits `1.2.0+7` into `[1, 2, 0]`, ignoring the build number, or returns
/// null when any part is not a number.
List<int>? _parts(String v) {
  final core = v.split('+').first.trim();
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final piece in core.split('.')) {
    final n = int.tryParse(piece.trim());
    if (n == null) return null;
    parts.add(n);
  }
  return parts;
}

/// Whether the recorded version is newer than the one installed.
bool needsUpdate(String remoteVersion, String localVersion) =>
    compareVersions(remoteVersion, localVersion) > 0;

/// Asks the server which version is newest and records the answer.
///
/// Returns true when this build is outdated, false when it is current, and
/// **null when the server could not be reached or answered with something
/// unreadable**. Null is deliberately distinct from false: a failed check
/// must never be mistaken for "you are up to date", because that would drop
/// a remembered wall the moment a stale player goes offline. The caller
/// keeps whatever it already decided and should try again later.
///
/// Only a real answer updates the stored verdict, so a broken response can
/// neither raise nor clear a wall.
Future<bool?> checkForUpdate({Future<String?> Function()? fetch}) async {
  try {
    final raw = await (fetch ?? _fetchLatest)();
    if (raw == null) return null;

    String? remote;
    final decoded = jsonDecode(raw);
    final value = decoded is Map ? decoded['version'] : null;
    if (value is String && value.isNotEmpty) remote = value;
    if (remote == null) return null;

    final prefs = await SharedPreferences.getInstance();
    if (needsUpdate(remote, kAppVersion)) {
      await prefs.setString(_staleKey, remote);
      return true;
    }
    await prefs.remove(_staleKey);
    return false;
  } catch (_) {
    // Unreachable, unreadable, or storage refused. Never raised to the
    // caller: a failed check is "no answer", not "you are up to date".
    return null;
  }
}

const String _staleKey = 'update_required_for';

Future<String?> _fetchLatest() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(Uri.parse(kLatestVersionUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;
    return await utf8.decoder.bind(response).join();
  } finally {
    client.close(force: true);
  }
}
