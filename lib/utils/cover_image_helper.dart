import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
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

  static Future<Directory> _coversDir() async {
    final dir = Directory(p.join(_basePath, 'covers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies a picked file into `<documents>/covers/` and returns the absolute path.
  static Future<String> importFile(String sourcePath) async {
    final dir = await _coversDir();
    final name =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final newPath = p.join(dir.path, name);
    await File(sourcePath).copy(newPath);
    return newPath;
  }

  /// Writes image bytes into `<documents>/covers/` and returns the absolute path.
  /// [extension] is given without a leading dot.
  static Future<String> saveBytes(Uint8List bytes, String extension) async {
    final dir = await _coversDir();
    final newPath =
        p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.$extension');
    await File(newPath).writeAsBytes(bytes);
    return newPath;
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
