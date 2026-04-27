import 'package:flutter/material.dart';
import '../presentation/theme/app_theme.dart';

/// Utility class for showing consistent SnackBar messages
class SnackbarHelpers {
  /// Shows a success message (green background)
  ///
  /// Example:
  /// ```dart
  /// SnackbarHelpers.showSuccess(context, l10n.savedSuccessfully);
  /// ```
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    final appColors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: appColors.onSuccess),
        ),
        backgroundColor: appColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows an error message (red background)
  ///
  /// Example:
  /// ```dart
  /// SnackbarHelpers.showError(context, e.toString());
  /// ```
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onError),
        ),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows an info message (default Material theme)
  ///
  /// Example:
  /// ```dart
  /// SnackbarHelpers.showInfo(context, l10n.noChanges);
  /// ```
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows a warning message (orange background)
  ///
  /// Example:
  /// ```dart
  /// SnackbarHelpers.showWarning(context, l10n.lowStorage);
  /// ```
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    final appColors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: appColors.onWarning),
        ),
        backgroundColor: appColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
