import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Handles cover image path storage and resolution.
///
/// On iOS/macOS, the app sandbox path changes between launches.
/// This helper stores relative paths and resolves them at runtime.
class CoverImageHelper {
  static late String _basePath;

  static Future<void> initialize() async {
    _basePath = (await getApplicationDocumentsDirectory()).path;
  }

  /// Convert an absolute path to a relative path for database storage.
  static String toRelative(String absolutePath) {
    if (absolutePath.startsWith(_basePath)) {
      return absolutePath.substring(_basePath.length + 1);
    }
    return absolutePath;
  }

  /// Resolve a stored path to an absolute path for display.
  /// Handles both new relative paths and legacy absolute paths.
  static String? resolve(String? path) {
    if (path == null || path.isEmpty) return null;

    // Already relative — prepend base path
    if (!path.startsWith('/')) {
      return '$_basePath/$path';
    }

    // Absolute path — check if it still works
    if (File(path).existsSync()) return path;

    // Broken absolute path (sandbox UUID changed) — extract relative part
    final coversIdx = path.indexOf('/covers/');
    if (coversIdx != -1) {
      return '$_basePath${path.substring(coversIdx)}';
    }

    return path;
  }
}
