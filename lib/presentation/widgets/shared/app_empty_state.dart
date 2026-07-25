import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

/// A reusable empty state widget used across the app
///
/// Displays a centered column with:
/// - Large icon
/// - Title text
/// - Optional subtitle text
/// - Optional action button(s)
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double iconSize;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? action;
  final List<Widget>? actions;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.iconSize = 80.0,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.action,
    this.actions,
  }) : assert(
          action == null || actions == null,
          'Cannot provide both action and actions',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTitleStyle = theme.textTheme.headlineSmall;
    final defaultSubtitleStyle = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

    // Scrollable so a tall footer (e.g. the reread suggestion) cannot overflow
    // on a short screen; Center keeps the usual look when it fits.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              title,
              style: titleStyle ?? defaultTitleStyle,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppConstants.spacingS),
              Text(
                subtitle!,
                style: subtitleStyle ?? defaultSubtitleStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null || actions != null) ...[
              const SizedBox(height: AppConstants.spacingL),
              ?action,
              if (action == null && actions != null) ...actions!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A reusable completion state widget for review screens
///
/// Displays a celebration icon with review count and done button
class ReviewCompletionState extends StatelessWidget {
  final int reviewedCount;
  final VoidCallback onDone;
  final String completionMessage;
  final String reviewedCountMessage;
  final String doneLabel;

  /// Rendered below the done button — used for the reread suggestion, which
  /// collapses to nothing when there is no good candidate.
  final Widget? footer;

  const ReviewCompletionState({
    super.key,
    required this.reviewedCount,
    required this.onDone,
    required this.completionMessage,
    required this.reviewedCountMessage,
    required this.doneLabel,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.celebration,
      iconSize: 80.0,
      iconColor: Theme.of(context).colorScheme.primary,
      title: completionMessage,
      subtitle: reviewedCountMessage,
      actions: [
        ElevatedButton.icon(
          onPressed: onDone,
          icon: const Icon(Icons.done),
          label: Text(doneLabel),
        ),
        ?footer,
      ],
    );
  }
}

/// A reusable error state widget
///
/// Displays an error icon with message and retry button
class AppErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    required this.title,
    required this.onRetry,
    required this.retryLabel,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      iconSize: AppConstants.errorIconSize,
      iconColor: Theme.of(context).colorScheme.error,
      title: title,
      subtitle: message,
      action: ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(retryLabel),
      ),
    );
  }
}
