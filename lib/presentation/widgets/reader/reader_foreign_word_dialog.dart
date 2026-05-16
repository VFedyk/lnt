import '../../theme/term_status_ui.dart';
import 'package:flutter/material.dart';

import '../../controllers/reader_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

class ReaderForeignWordDialog extends StatelessWidget {
  final String lowerWord;
  final ForeignTermInfo info;
  final AppLocalizations l10n;
  final VoidCallback onRemove;
  final double removeIconSize;

  const ReaderForeignWordDialog({
    super.key,
    required this.lowerWord,
    required this.info,
    required this.l10n,
    required this.onRemove,
    required this.removeIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppConstants.dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lowerWord,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppConstants.spacingXS),
              Text(
                info.languageName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (info.term != null && info.term!.romanization.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingXS),
                Text(
                  info.term!.romanization,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (info.translations.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingS),
                ...info.translations.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.spacingXS,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t.partOfSpeech != null) ...[
                          Text(
                            PartOfSpeechUI.localizedNameFor(
                              t.partOfSpeech!,
                              l10n,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                          const SizedBox(width: AppConstants.spacingS),
                        ],
                        Expanded(
                          child: Text(
                            t.meaning,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (info.term != null &&
                  info.term!.translation.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  info.term!.translation,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: AppConstants.spacingL),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRemove,
                  icon: Icon(Icons.remove_circle_outline, size: removeIconSize),
                  label: Text(l10n.removeForeignMarking),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
