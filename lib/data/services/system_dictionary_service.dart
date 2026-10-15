import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the operating system's own dictionary UI (iOS, iPadOS, macOS).
/// No definition data is ever read; the OS shows its own sheet or popover.
class SystemDictionaryService {
  static const MethodChannel _channel = MethodChannel('lnt/system_dictionary');

  /// Uses [defaultTargetPlatform] rather than `PlatformHelper` so tests can
  /// override it; the `kIsWeb` guard is needed because on web it reports the
  /// browser's OS.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Throws [PlatformException] / [MissingPluginException] on failure.
  Future<void> lookUp(String word) =>
      _channel.invokeMethod<void>('lookUp', word.trim());
}
