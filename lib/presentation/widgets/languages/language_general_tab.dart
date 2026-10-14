import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';
import '../../../utils/language_utils.dart';
import 'language_presets.dart';

/// The General tab of `LanguageEditScreen`: preset, romanization and the
/// character-splitting switches. All state lives in the screen.
class LanguageGeneralTab extends StatelessWidget {
  final LangPreset? selectedPreset;
  final bool showRomanization;
  final bool splitByCharacter;
  final bool useWordSegmentation;
  final ValueChanged<LangPreset?> onPresetChanged;
  final ValueChanged<bool> onRomanizationChanged;
  final ValueChanged<bool> onSplitByCharacterChanged;
  final ValueChanged<bool> onWordSegmentationChanged;

  const LanguageGeneralTab({
    super.key,
    required this.selectedPreset,
    required this.showRomanization,
    required this.splitByCharacter,
    required this.useWordSegmentation,
    required this.onPresetChanged,
    required this.onRomanizationChanged,
    required this.onSplitByCharacterChanged,
    required this.onWordSegmentationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final isCJK = selectedPreset?.splitByCharacter ?? false;
    final sortedPresets = [...kLangPresets]
      ..sort((a, b) => langSortKey(localizedLangName(l10n, a.code), locale)
          .compareTo(langSortKey(localizedLangName(l10n, b.code), locale)));

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      children: [
        DropdownButtonFormField<LangPreset>(
          initialValue: selectedPreset,
          decoration: InputDecoration(labelText: l10n.languageNameLabel),
          isExpanded: true,
          items: sortedPresets.map((preset) {
            final flag = preset.flagEmoji;
            return DropdownMenuItem<LangPreset>(
              value: preset,
              child: Text(
                  '${flag.isNotEmpty ? '$flag ' : ''}${localizedLangName(l10n, preset.code)}'),
            );
          }).toList(),
          onChanged: onPresetChanged,
          validator: (v) => v == null ? l10n.required : null,
        ),
        const SizedBox(height: AppConstants.spacingL),
        SwitchListTile(
          title: Text(l10n.showRomanization),
          subtitle: Text(l10n.showRomanizationHint),
          value: showRomanization,
          onChanged: onRomanizationChanged,
          contentPadding: EdgeInsets.zero,
        ),
        if (isCJK) ...[
          SwitchListTile(
            title: Text(l10n.splitByCharacter),
            subtitle: Text(l10n.splitByCharacterHint),
            value: splitByCharacter,
            onChanged: onSplitByCharacterChanged,
            contentPadding: EdgeInsets.zero,
          ),
          if (splitByCharacter)
            SwitchListTile(
              title: Text(l10n.wordSegmentation),
              subtitle: Text(l10n.wordSegmentationHint),
              value: useWordSegmentation,
              onChanged: onWordSegmentationChanged,
              contentPadding: EdgeInsets.zero,
            ),
        ],
        const SizedBox(height: AppConstants.spacingS),
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 20.0, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  l10n.addDictionariesAfterCreating,
                  style: TextStyle(
                    fontSize: 13.0,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
