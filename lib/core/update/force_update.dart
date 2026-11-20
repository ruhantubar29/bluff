import 'dart:convert';
import 'dart:io';

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

/// Whether the player is on an older version than the one just released.
bool needsUpdate(String remoteVersion, String localVersion) =>
    compareVersions(remoteVersion, localVersion) > 0;

/// Checks whether this install is too old to keep running.
///
/// Fails open on purpose: offline, slow, or a malformed response must never
/// lock a player out of a build that may well be the newest one they can get.
/// A genuine mismatch is the only thing that blocks.
Future<bool> isUpdateRequired({Future<String?> Function()? fetch}) async {
  try {
    final raw = await (fetch ?? _fetchLatest)();
    if (raw == null) return false;
    final decoded = jsonDecode(raw);
    final remote = decoded is Map ? decoded['version'] : null;
    if (remote is! String || remote.isEmpty) return false;
    return needsUpdate(remote, kAppVersion);
  } catch (_) {
    return false;
  }
}

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
