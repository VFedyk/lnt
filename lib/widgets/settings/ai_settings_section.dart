import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart';

class AiSettingsSection extends StatelessWidget {
  final AppLocalizations l10n;
  final String provider;
  final ValueChanged<String> onProviderChanged;
  final TextEditingController apiKeyController;
  final TextEditingController modelController;
  final TextEditingController apiUrlController;
  final bool obscureApiKey;
  final VoidCallback onToggleObscureApiKey;

  const AiSettingsSection({
    super.key,
    required this.l10n,
    required this.provider,
    required this.onProviderChanged,
    required this.apiKeyController,
    required this.modelController,
    required this.apiUrlController,
    required this.obscureApiKey,
    required this.onToggleObscureApiKey,
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
                const Icon(Icons.auto_awesome),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.aiAssistant,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.aiApiKeyHint,
              style: TextStyle(
                color: AppConstants.subtitleColor,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            DropdownButtonFormField<String>(
              initialValue: provider,
              decoration: InputDecoration(
                labelText: l10n.aiProvider,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: SettingsService.aiProviderAuto,
                  child: Text(l10n.aiProviderAuto),
                ),
                DropdownMenuItem(
                  value: SettingsService.aiProviderOpenAiCompatible,
                  child: Text(l10n.aiProviderOpenAiCompatible),
                ),
                DropdownMenuItem(
                  value: SettingsService.aiProviderAnthropic,
                  child: Text(l10n.aiProviderAnthropic),
                ),
                DropdownMenuItem(
                  value: SettingsService.aiProviderOllama,
                  child: Text(l10n.aiProviderOllama),
                ),
              ],
              onChanged: (value) {
                if (value != null) onProviderChanged(value);
              },
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.aiProviderHint,
              style: TextStyle(
                color: AppConstants.subtitleColor,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            TextField(
              controller: apiKeyController,
              decoration: InputDecoration(
                labelText: l10n.aiApiKey,
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
            TextField(
              controller: modelController,
              decoration: InputDecoration(
                labelText: l10n.aiModelName,
                border: const OutlineInputBorder(),
                hintText: SettingsService.defaultAiModel,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            TextField(
              controller: apiUrlController,
              decoration: InputDecoration(
                labelText: l10n.aiApiUrl,
                border: const OutlineInputBorder(),
                hintText: SettingsService.defaultAiApiUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
