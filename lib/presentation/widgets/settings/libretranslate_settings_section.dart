import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

class LibreTranslateSettingsSection extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController urlController;
  final TextEditingController apiKeyController;
  final bool obscureApiKey;
  final VoidCallback onToggleObscureApiKey;

  const LibreTranslateSettingsSection({
    super.key,
    required this.l10n,
    required this.urlController,
    required this.apiKeyController,
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
                const Icon(Icons.g_translate),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.libreTranslate,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.libreTranslateHint,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: l10n.libreTranslateServerUrl,
                border: const OutlineInputBorder(),
                hintText: AppConstants.defaultLibreTranslateUrl,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            TextField(
              controller: apiKeyController,
              decoration: InputDecoration(
                labelText: l10n.libreTranslateApiKey,
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
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.libreTranslateApiKeyOptional,
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
