import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

class DeepLSettingsSection extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController apiKeyController;
  final bool obscureApiKey;
  final VoidCallback onToggleObscureApiKey;
  final bool isApiFree;
  final ValueChanged<bool> onApiTypeChanged;
  final bool showUsage;
  final Widget? usageWidget;

  const DeepLSettingsSection({
    super.key,
    required this.l10n,
    required this.apiKeyController,
    required this.obscureApiKey,
    required this.onToggleObscureApiKey,
    required this.isApiFree,
    required this.onApiTypeChanged,
    required this.showUsage,
    required this.usageWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.deepLTranslation,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.deepLApiKeyHint,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            TextField(
              controller: apiKeyController,
              decoration: InputDecoration(
                labelText: l10n.deepLApiKey,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: onToggleObscureApiKey,
                ),
              ),
              obscureText: obscureApiKey,
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(l10n.apiType, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppConstants.spacingS),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.free)),
                ButtonSegment(value: false, label: Text(l10n.pro)),
              ],
              selected: {isApiFree},
              onSelectionChanged: (selected) {
                onApiTypeChanged(selected.first);
              },
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              isApiFree ? l10n.freeApiLimit : l10n.proApiPayPerUse,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            if (showUsage && usageWidget != null) usageWidget!,
          ],
        ),
      ),
    );
  }
}
