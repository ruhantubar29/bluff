import 'dart:io';

import 'package:flutter/material.dart';

import 'avatar_photo.dart';

/// Splash-style picture avatars: a curated set of the bundled chibi
/// character art, offered in this exact carousel order. (All 35 files stay
/// bundled; only these 14 are pickable.)
const List<int> kAvatarCharacters = [
  1,
  2,
  3,
  4,
  5,
  6,
  10,
  11,
  17,
  23,
  28,
  33,
  34,
  24,
];

/// How many characters the carousel offers. Never write this by hand —
/// keep [kAvatarCharacters] as the single source of truth.
final int kAvatarCount = kAvatarCharacters.length;

/// Asset path for a built-in avatar. Out-of-range indexes wrap around.
String avatarAssetFor(int index) =>
    'assets/images/characters/character_${kAvatarCharacters[index % kAvatarCount]}.png';

/// Circular avatar used everywhere a player is shown: the picked character
/// art, or the player's own gallery photo when they chose one.
///
/// The parent supplies the circle decoration/border/background — this widget
/// only fills it.
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.index,
    required this.size,
    this.photoPath,
    this.fit = BoxFit.cover,
  });

  /// Index into the built-in character art.
  final int index;

  /// Diameter of the avatar in logical pixels.
  final double size;

  /// Path to the player's own photo, if they picked one.
  final String? photoPath;

  /// How the built-in art is framed. Full-body art shown small reads better
  /// cropped from the top (face first); big previews pass [BoxFit.contain].
  final BoxFit fit;

  File? get _photoFile => AvatarPhoto.fileFor(photoPath);

  @override
  Widget build(BuildContext context) {
    final photo = _photoFile;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photo != null
            ? Image.file(
                photo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _character(),
              )
            : _character(),
      ),
    );
  }

  Widget _character() {
    return Image.asset(
      avatarAssetFor(index),
      width: size,
      height: size,
      fit: fit,
      alignment: fit == BoxFit.cover
          ? const Alignment(0, -0.55)
          : Alignment.center,
      errorBuilder: (_, _, _) =>
          const Center(child: Text('🙂', style: TextStyle(fontSize: 20))),
    );
  }
}
