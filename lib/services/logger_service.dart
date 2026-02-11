import 'dart:developer' as developer;

/// Lightweight logging wrapper around `dart:developer`.
///
/// Works with DevTools in debug mode; zero overhead in release builds.
class AppLogger {
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'LNT',
      level: 1000, // SEVERE
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warning(String message, {Object? error}) {
    developer.log(
      message,
      name: 'LNT',
      level: 900, // WARNING
      error: error,
    );
  }

  static void info(String message) {
    developer.log(message, name: 'LNT', level: 800);
  }
}
