import 'package:flutter/material.dart';

/// Utility class for common dialog patterns
class DialogHelpers {
  /// Shows a confirmation dialog with title, message, and cancel/confirm buttons
  ///
  /// Returns `true` if user confirms, `false` if canceled, or `null` if dismissed
  ///
  /// Example:
  /// ```dart
  /// final confirmed = await DialogHelpers.showConfirmationDialog(
  ///   context,
  ///   title: l10n.deleteConfirmation,
  ///   message: l10n.deleteWarning,
  ///   isDestructive: true,
  /// );
  /// if (confirmed == true) {
  ///   // Perform delete
  /// }
  /// ```
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? cancelText,
    String? confirmText,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText ?? localizations.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  )
                : null,
            child: Text(confirmText ?? localizations.okButtonLabel),
          ),
        ],
      ),
    );
  }

  /// Shows a destructive confirmation dialog (delete, remove, etc.)
  ///
  /// Convenience wrapper around [showConfirmationDialog] with isDestructive=true
  static Future<bool?> showDestructiveDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? cancelText,
    String? confirmText,
  }) {
    return showConfirmationDialog(
      context,
      title: title,
      message: message,
      cancelText: cancelText,
      confirmText: confirmText,
      isDestructive: true,
    );
  }
}
