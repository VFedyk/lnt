import 'package:flutter/foundation.dart';

/// Base controller for all ChangeNotifier-based controllers
///
/// Provides safe notification pattern that prevents calling notifyListeners()
/// after the controller has been disposed. This prevents "!_debugDisposed"
/// assertion errors in async operations.
abstract class BaseController extends ChangeNotifier {
  bool _isDisposed = false;

  /// Whether this controller has been disposed
  bool get isDisposed => _isDisposed;

  /// Safely notifies listeners only if the controller hasn't been disposed
  ///
  /// Use this instead of calling notifyListeners() directly to prevent
  /// errors in async operations that complete after dispose().
  @protected
  void safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
