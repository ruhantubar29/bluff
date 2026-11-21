import 'dart:io';

import 'package:bluff/core/update/force_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Fresh storage per test so a wall raised in one cannot leak into the
    // next and make it pass for the wrong reason.
    SharedPreferences.setMockInitialValues({});
  });

  group('compareVersions / needsUpdate', () {
    test('a higher remote version requires the update', () {
      expect(needsUpdate('1.2.0', '1.1.0'), isTrue);
      expect(needsUpdate('2.0.0', '1.9.9'), isTrue);
      expect(needsUpdate('1.1.1', '1.1.0'), isTrue);
    });

    test('the same version does not', () {
      expect(needsUpdate('1.1.0', '1.1.0'), isFalse);
    });

    test('an older remote version does not downgrade anyone', () {
      expect(needsUpdate('1.0.0', '1.1.0'), isFalse);
      expect(needsUpdate('0.9.0', '1.0.0'), isFalse);
    });

    test('compares numerically, so 1.10.0 beats 1.9.0', () {
      // Lexicographic sorting would get this backwards and block everyone
      // on 1.9.x the moment 1.10.0 shipped.
      expect(needsUpdate('1.10.0', '1.9.0'), isTrue);
      expect(needsUpdate('1.9.0', '1.10.0'), isFalse);
    });

    test('ignores the build number after the plus', () {
      expect(needsUpdate('1.1.0+2', '1.1.0+1'), isFalse);
      expect(needsUpdate('1.1.0+1', '1.1.0+2'), isFalse);
    });

    test('unparseable values compare as equal rather than blocking', () {
      expect(needsUpdate('', '1.1.0'), isFalse);
      expect(needsUpdate('banana', '1.1.0'), isFalse);
      expect(needsUpdate('1.1.0', 'banana'), isFalse);
    });
  });

  group('checkForUpdate', () {
    test('walls and remembers when the server is ahead', () async {
      expect(
        await checkForUpdate(fetch: () async => '{"version":"9.9.9"}'),
        isTrue,
      );
      expect(await knownStaleVersion(), '9.9.9');
      expect(stillOutdated(await knownStaleVersion()), isTrue);
    });

    test('stays open and forgets when the versions match', () async {
      expect(
        await checkForUpdate(fetch: () async => '{"version":"$kAppVersion"}'),
        isFalse,
      );
      expect(await knownStaleVersion(), isNull);
    });

    test('reports "no answer" rather than "up to date" when offline', () async {
      expect(
        await checkForUpdate(
          fetch: () async => throw const SocketException('offline'),
        ),
        isNull,
      );
      expect(await checkForUpdate(fetch: () async => null), isNull);
    });

    test('reports "no answer" on a malformed or missing version', () async {
      expect(await checkForUpdate(fetch: () async => 'not json'), isNull);
      expect(await checkForUpdate(fetch: () async => '{}'), isNull);
      expect(await checkForUpdate(fetch: () async => '{"version":42}'), isNull);
      expect(await checkForUpdate(fetch: () async => '{"version":""}'), isNull);
    });
  });

  group('remembered wall', () {
    test('survives a failed check, so going offline does not unpublish it',
        () async {
      // Online: they get walled.
      expect(
        await checkForUpdate(fetch: () async => '{"version":"9.9.9"}'),
        isTrue,
      );

      // Offline: the retry gets no answer...
      expect(await checkForUpdate(fetch: () async => null), isNull);

      // ...and the wall from the earlier session is still standing.
      expect(stillOutdated(await knownStaleVersion()), isTrue);
    });

    test('survives a malformed response too', () async {
      expect(
        await checkForUpdate(fetch: () async => '{"version":"9.9.9"}'),
        isTrue,
      );
      expect(await checkForUpdate(fetch: () async => 'garbage'), isNull);
      expect(stillOutdated(await knownStaleVersion()), isTrue);
    });

    test('a later good answer can still lift it, so a rollback is not a trap',
        () async {
      expect(
        await checkForUpdate(fetch: () async => '{"version":"9.9.9"}'),
        isTrue,
      );
      expect(
        await checkForUpdate(fetch: () async => '{"version":"$kAppVersion"}'),
        isFalse,
      );
      expect(await knownStaleVersion(), isNull);
      expect(stillOutdated(await knownStaleVersion()), isFalse);
    });

    test('starts open for a player who has never been checked', () async {
      expect(await knownStaleVersion(), isNull);
      expect(stillOutdated(await knownStaleVersion()), isFalse);
    });

    test('lifts itself once the player is on the recorded version', () {
      // Installing the version we recorded is all it takes -- no server
      // round trip and no manual clearing of stored state.
      expect(stillOutdated('9.9.9'), isTrue);
      expect(stillOutdated(kAppVersion), isFalse);
      expect(stillOutdated('1.0.0'), isFalse);
      expect(stillOutdated(null), isFalse);
    });
  });

  test('kAppVersion matches the version pubspec ships', () {
    // A release that bumps pubspec but forgets the constant would leave every
    // install permanently "up to date", silently disabling the wall.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');

    final shipped = match!.group(1)!.split('+').first;
    expect(
      kAppVersion,
      shipped,
      reason: 'kAppVersion in lib/core/update/force_update.dart is out of '
          'step with version: in pubspec.yaml',
    );
  });
}
