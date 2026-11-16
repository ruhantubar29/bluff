import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Character art is looked up as `character_<n>.png` — see
/// `_characterAsset` in the impostor game and `avatarAssetFor` in
/// `avatars.dart`. A file whose name differs only by case resolves on
/// Windows, where it was almost certainly checked, but not on Android or
/// iOS, where the lookup fails and the UI silently falls back to the 🎭
/// placeholder. This pins the names to what the code actually asks for.
void main() {
  test('character art filenames match the lowercase name the code requests',
      () {
    final names = Directory('assets/images/characters')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();

    expect(names, isNotEmpty, reason: 'no character art was found on disk');

    final offenders =
        names.where((n) => !RegExp(r'^character_\d+\.png$').hasMatch(n));

    expect(
      offenders,
      isEmpty,
      reason: 'Image.asset is given character_<n>.png in lowercase, so every '
          'file must match exactly. Offending names: '
          '${offenders.join(', ')}',
    );
  });
}
