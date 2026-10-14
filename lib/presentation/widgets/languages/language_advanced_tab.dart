import 'package:flutter/material.dart';
import '../../../domain/value_objects/text_parsing_defaults.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

/// The Advanced tab of `LanguageEditScreen`: editable word / sentence regexes.
/// Controllers are owned by the screen so values survive tab switches.
class LanguageAdvancedTab extends StatelessWidget {
  final TextEditingController wordController;
  final TextEditingController sentenceController;
  final bool splitByCharacter;

  const LanguageAdvancedTab({
    super.key,
    required this.wordController,
    required this.sentenceController,
    required this.splitByCharacter,
  });

  /// Null when [value] is acceptable. Empty means "use the default".
  static String? validatePattern(AppLocalizations l10n, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    try {
      if (RegExp(v, unicode: true).hasMatch('')) return l10n.regexMatchesEmpty;
    } on FormatException catch (e) {
      return l10n.invalidRegex(e.message);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      children: [
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
                  l10n.advancedPatternsWarning,
                  style: TextStyle(
                    fontSize: 13.0,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingL),
        _PatternField(
          controller: wordController,
          label: l10n.wordPatternLabel,
          hint: splitByCharacter
              ? l10n.wordPatternIgnoredForCharSplit
              : l10n.wordPatternHint,
          defaultValue: TextParsingDefaults.wordPattern,
          enabled: !splitByCharacter,
        ),
        const SizedBox(height: AppConstants.spacingL),
        _PatternField(
          controller: sentenceController,
          label: l10n.sentencePatternLabel,
          hint: l10n.sentencePatternHint,
          defaultValue: TextParsingDefaults.sentencePattern,
          enabled: true,
        ),
      ],
    );
  }
}

class _PatternField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String defaultValue;
  final bool enabled;

  const _PatternField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.defaultValue,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isDefault = value.text == defaultValue;
        return TextFormField(
          controller: controller,
          enabled: enabled,
          minLines: 1,
          maxLines: null,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: label,
            helperText: hint,
            helperMaxLines: 3,
            suffixIcon: IconButton(
              icon: const Icon(Icons.restore),
              tooltip: l10n.resetToDefault,
              onPressed: enabled && !isDefault
                  ? () => controller.text = defaultValue
                  : null,
            ),
          ),
          validator: enabled
              ? (v) => LanguageAdvancedTab.validatePattern(l10n, v)
              : null,
        );
      },
    );
  }
}
