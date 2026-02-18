import 'package:flutter/material.dart';
import 'constants.dart';

/// Utility class for building consistent PopupMenu items
class MenuHelpers {
  /// Builds a standard PopupMenuItem with icon and text
  ///
  /// Example:
  /// ```dart
  /// PopupMenuButton<String>(
  ///   itemBuilder: (context) => [
  ///     MenuHelpers.buildMenuItem(
  ///       value: 'edit',
  ///       icon: Icons.edit,
  ///       label: l10n.edit,
  ///     ),
  ///     MenuHelpers.buildMenuItem(
  ///       value: 'delete',
  ///       icon: Icons.delete,
  ///       label: l10n.delete,
  ///       color: Theme.of(context).colorScheme.error,
  ///     ),
  ///   ],
  /// )
  /// ```
  static PopupMenuItem<T> buildMenuItem<T>({
    required T value,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: AppConstants.iconSizeS, color: color),
          const SizedBox(width: AppConstants.spacingS),
          Text(label, style: color != null ? TextStyle(color: color) : null),
        ],
      ),
    );
  }

  /// Builds a destructive PopupMenuItem (e.g., delete, remove)
  ///
  /// Uses error color from theme automatically
  ///
  /// Example:
  /// ```dart
  /// MenuHelpers.buildDestructiveMenuItem(
  ///   context: context,
  ///   value: 'delete',
  ///   icon: Icons.delete,
  ///   label: l10n.delete,
  /// )
  /// ```
  static PopupMenuItem<T> buildDestructiveMenuItem<T>({
    required BuildContext context,
    required T value,
    required IconData icon,
    required String label,
  }) {
    final errorColor = Theme.of(context).colorScheme.error;
    return buildMenuItem(
      value: value,
      icon: icon,
      label: label,
      color: errorColor,
    );
  }

  /// Builds an edit menu item with standard icon
  ///
  /// Convenience method for the common "Edit" menu item
  static PopupMenuItem<T> buildEditMenuItem<T>({
    required T value,
    required String label,
  }) {
    return buildMenuItem(
      value: value,
      icon: Icons.edit,
      label: label,
    );
  }

  /// Builds a delete menu item with standard icon and error color
  ///
  /// Convenience method for the common "Delete" menu item
  static PopupMenuItem<T> buildDeleteMenuItem<T>({
    required BuildContext context,
    required T value,
    required String label,
  }) {
    return buildDestructiveMenuItem(
      context: context,
      value: value,
      icon: Icons.delete,
      label: label,
    );
  }
}
