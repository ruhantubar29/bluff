import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Picks a photo from the player's gallery and keeps a private copy inside
/// the app's documents directory, so the avatar survives cache clean-ups.
///
/// Everything is best-effort: on platforms without a file system (web) the
/// picker is simply not offered and [fileFor] returns null everywhere.
class AvatarPhoto {
  AvatarPhoto._();

  static const String _fileName = 'bluff_avatar_photo.jpg';

  /// Opens the gallery. Returns the stored path, or null when the player
  /// backed out (not an error).
  static Future<String?> pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    if (kIsWeb) {
      // No stable file system on the web build; fall back to letting the
      // plugin hand us a blob-backed path (session-scoped at best).
      return picked.path;
    }

    final docs = await getApplicationDocumentsDirectory();
    final target = File('${docs.path}${Platform.pathSeparator}$_fileName');
    await target.writeAsBytes(await picked.readAsBytes());
    return target.path;
  }

  /// Returns the stored photo only when it actually exists — a profile
  /// restored on another device points at a path this device never had.
  static File? fileFor(String? path) {
    if (path == null || path.isEmpty) return null;
    if (kIsWeb) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// Removes the stored photo (used when the player switches back to a
  /// character avatar).
  static Future<void> delete(String? path) async {
    final file = fileFor(path);
    if (file == null) return;
    try {
      await file.delete();
    } catch (_) {
      // Already gone — nothing to clean up.
    }
  }
}
