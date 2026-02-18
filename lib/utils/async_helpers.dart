// FILE: lib/utils/async_helpers.dart
import 'package:flutter/widgets.dart';
import 'snackbar_helpers.dart';

/// Helpers for running async operations with loading states and error handling.
class AsyncHelpers {
  /// Runs an async operation with loading state management for StatefulWidget.
  ///
  /// Handles:
  /// - Setting loading state before operation
  /// - Resetting loading state after operation (success or error)
  /// - Showing success message if provided
  /// - Showing error message on exception
  /// - Mounted checks to prevent errors with disposed widgets
  ///
  /// Example:
  /// ```dart
  /// await AsyncHelpers.runWithLoading(
  ///   context,
  ///   setLoadingTrue: () => setState(() => _isLoading = true),
  ///   setLoadingFalse: () => setState(() => _isLoading = false),
  ///   operation: () async {
  ///     await someAsyncWork();
  ///   },
  ///   successMessage: l10n.operationSuccess,
  ///   errorMessageBuilder: (e) => l10n.operationFailed(e.toString()),
  /// );
  /// ```
  static Future<void> runWithLoading(
    BuildContext context, {
    required VoidCallback setLoadingTrue,
    required VoidCallback setLoadingFalse,
    required Future<void> Function() operation,
    String? successMessage,
    String Function(Object)? errorMessageBuilder,
  }) async {
    setLoadingTrue();
    try {
      await operation();
      if (context.mounted && successMessage != null) {
        SnackbarHelpers.showSuccess(context, successMessage);
      }
    } catch (e) {
      if (context.mounted) {
        final message = errorMessageBuilder?.call(e) ?? e.toString();
        SnackbarHelpers.showError(context, message);
      }
      rethrow;
    } finally {
      if (context.mounted) {
        setLoadingFalse();
      }
    }
  }

  /// Runs an async operation without loading state management.
  ///
  /// Useful for operations that don't need loading indicators but still
  /// need consistent error handling and success messages.
  ///
  /// Example:
  /// ```dart
  /// await AsyncHelpers.run(
  ///   context,
  ///   operation: () async {
  ///     await db.terms.delete(termId);
  ///   },
  ///   successMessage: l10n.termDeleted,
  ///   errorMessageBuilder: (e) => '${l10n.error}: $e',
  /// );
  /// ```
  static Future<void> run(
    BuildContext context, {
    required Future<void> Function() operation,
    String? successMessage,
    String Function(Object)? errorMessageBuilder,
  }) async {
    try {
      await operation();
      if (context.mounted && successMessage != null) {
        SnackbarHelpers.showSuccess(context, successMessage);
      }
    } catch (e) {
      if (context.mounted) {
        final message = errorMessageBuilder?.call(e) ?? e.toString();
        SnackbarHelpers.showError(context, message);
      }
      rethrow;
    }
  }

  /// Runs an async operation that returns a value, with error handling.
  ///
  /// Unlike [run] and [runWithLoading], this does not show success messages
  /// (since the caller typically handles the result). Only shows errors.
  ///
  /// Returns null if the operation fails.
  ///
  /// Example:
  /// ```dart
  /// final data = await AsyncHelpers.runReturning<String>(
  ///   context,
  ///   operation: () async {
  ///     return await fetchData();
  ///   },
  ///   errorMessageBuilder: (e) => l10n.fetchFailed(e.toString()),
  /// );
  /// if (data != null) {
  ///   // Use the data
  /// }
  /// ```
  static Future<T?> runReturning<T>(
    BuildContext context, {
    required Future<T> Function() operation,
    String Function(Object)? errorMessageBuilder,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (context.mounted) {
        final message = errorMessageBuilder?.call(e) ?? e.toString();
        SnackbarHelpers.showError(context, message);
      }
      return null;
    }
  }
}
