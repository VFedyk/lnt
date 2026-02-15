import 'package:flutter/material.dart';

import '../../controllers/settings_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/constants.dart';

class DeepLUsageSection extends StatelessWidget {
  final bool isLoadingUsage;
  final dynamic usage;
  final Color Function(double usagePercent) usageColor;
  final VoidCallback onRetry;
  final double usageBarHeight;
  final double usageErrorIconSize;

  const DeepLUsageSection({
    super.key,
    required this.isLoadingUsage,
    required this.usage,
    required this.usageColor,
    required this.onRetry,
    required this.usageBarHeight,
    required this.usageErrorIconSize,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingL),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: isLoadingUsage
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: AppConstants.progressIndicatorSizeS,
                    height: AppConstants.progressIndicatorSizeS,
                    child: const CircularProgressIndicator(
                      strokeWidth: AppConstants.progressStrokeWidth,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Text(l10n.loadingUsage),
                ],
              )
            : usage == null
            ? Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: usageErrorIconSize,
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Expanded(child: Text(l10n.couldNotLoadUsage)),
                  TextButton(onPressed: onRetry, child: Text(l10n.retry)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.monthlyUsage,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${(usage.usagePercent * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: usageColor(usage.usagePercent),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusS,
                    ),
                    child: LinearProgressIndicator(
                      value: usage.usagePercent,
                      minHeight: usageBarHeight,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        usageColor(usage.usagePercent),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    l10n.charactersUsed(
                      SettingsController.formatNumber(usage.characterCount),
                      SettingsController.formatNumber(usage.characterLimit),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: AppConstants.fontSizeCaption,
                    ),
                  ),
                  Text(
                    l10n.charactersRemaining(
                      SettingsController.formatNumber(
                        usage.charactersRemaining,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: AppConstants.fontSizeCaption,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
