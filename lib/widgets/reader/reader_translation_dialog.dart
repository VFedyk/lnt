import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/term.dart';
import '../../utils/constants.dart';

class ReaderTranslationDialog extends StatelessWidget {
  final Term term;
  final List<Translation> translations;
  final Map<int, Translation> translationsById;
  final Map<int, Term> termsById;
  final String languageCode;
  final AppLocalizations l10n;
  final VoidCallback onEdit;
  final VoidCallback onPronounce;
  final double editIconSize;

  const ReaderTranslationDialog({
    super.key,
    required this.term,
    required this.translations,
    required this.translationsById,
    required this.termsById,
    required this.languageCode,
    required this.l10n,
    required this.onEdit,
    required this.onPronounce,
    required this.editIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 736),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      term.text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (languageCode.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.volume_up),
                      tooltip: l10n.pronounce,
                      onPressed: onPronounce,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (term.romanization.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingXS),
                Text(
                  term.romanization,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppConstants.subtitleColor,
                  ),
                ),
              ],
              const SizedBox(height: AppConstants.spacingS),
              ...translations.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppConstants.spacingXS,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.partOfSpeech != null) ...[
                        Text(
                          PartOfSpeech.localizedNameFor(t.partOfSpeech!, l10n),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppConstants.subtitleColor,
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
                      if (t.baseTranslationId != null &&
                          translationsById.containsKey(
                            t.baseTranslationId!,
                          )) ...[
                        const SizedBox(width: AppConstants.spacingS),
                        Builder(
                          builder: (context) {
                            final baseTranslation =
                                translationsById[t.baseTranslationId!]!;
                            final baseTerm = termsById[baseTranslation.termId];
                            final baseText = baseTerm != null
                                ? '${baseTerm.lowerText} (${baseTranslation.meaning})'
                                : baseTranslation.meaning;
                            return Text(
                              '\u2190 $baseText',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppConstants.subtitleColor),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingL),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit, size: editIconSize),
                  label: Text(l10n.edit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
