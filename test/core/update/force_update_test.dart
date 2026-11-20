import 'dart:io';

import 'package:bluff/core/update/force_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('isUpdateRequired', () {
    test('blocks when the recorded version is newer', () async {
      expect(
        await isUpdateRequired(fetch: () async => '{"version":"9.9.9"}'),
        isTrue,
      );
    });

    test('stays open when the versions match', () async {
      expect(
        await isUpdateRequired(fetch: () async => '{"version":"$kAppVersion"}'),
        isFalse,
      );
    });

    test('stays open when the network fails', () async {
      expect(
        await isUpdateRequired(
          fetch: () async => throw const SocketException('offline'),
        ),
        isFalse,
      );
    });

    test('stays open when there is no response at all', () async {
      expect(await isUpdateRequired(fetch: () async => null), isFalse);
    });

    test('stays open on a malformed or missing version field', () async {
      expect(await isUpdateRequired(fetch: () async => 'not json'), isFalse);
      expect(await isUpdateRequired(fetch: () async => '{}'), isFalse);
      expect(
        await isUpdateRequired(fetch: () async => '{"version":42}'),
        isFalse,
      );
      expect(
        await isUpdateRequired(fetch: () async => '{"version":""}'),
        isFalse,
      );
    });
  });

  test('kAppVersion matches the version pubspec ships', () {
    // A release that bumps pubspec but forgets the constant would leave every
    // install permanently "up to date", silently disabling the wall.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec);
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
