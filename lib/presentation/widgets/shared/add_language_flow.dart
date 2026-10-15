import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/language.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../main.dart';
import '../../../service_locator.dart';
import '../../../utils/dialog_helpers.dart';
import '../../../utils/language_utils.dart';
import '../../../utils/snackbar_helpers.dart';
import '../../screens/dictionaries_screen.dart';
import '../../screens/language_edit_screen.dart';
import '../languages/language_presets.dart';
import 'language_quick_picker.dart';

/// Saves [draft] via [createLanguage], selects it, shows the success snackbar
/// and — unless [isFirstLanguage] — offers to add dictionaries.
Future<Language?> createAndSelectLanguage(
  BuildContext context,
  Language draft, {
  required bool isFirstLanguage,
}) async {
  final l10n = AppLocalizations.of(context);
  final appState = context.read<AppState>();
  final Language saved;
  try {
    saved = await createLanguage(draft);
  } catch (e) {
    if (context.mounted) {
      SnackbarHelpers.showError(context, l10n.errorAddingLanguage(e.toString()));
    }
    return null;
  }
  await appState.setSelectedLanguage(saved.id);
  if (!context.mounted) return saved;
  SnackbarHelpers.showSuccess(context, l10n.languageAdded(saved.name));

  if (!isFirstLanguage) {
    final shouldAddDict = await DialogHelpers.showConfirmationDialog(
      context,
      title: l10n.addDictionariesQuestion,
      message: l10n.addDictionariesPrompt(saved.name),
      cancelText: l10n.later,
      confirmText: l10n.addNow,
    );
    if (shouldAddDict == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DictionariesScreen(language: saved)),
      );
    }
  }
  return saved;
}

/// Pushes `LanguageEditScreen()` and, if it pops a language, runs
/// [createAndSelectLanguage].
Future<Language?> openCustomLanguageForm(
  BuildContext context, {
  required bool isFirstLanguage,
}) async {
  final result = await Navigator.push<Language>(
    context,
    MaterialPageRoute(builder: (_) => const LanguageEditScreen()),
  );
  if (result == null || !context.mounted) return null;
  return createAndSelectLanguage(
    context,
    result,
    isFirstLanguage: isFirstLanguage,
  );
}

/// What the add-language sheet was dismissed with.
sealed class _SheetResult {}

class _PresetChosen extends _SheetResult {
  final LangPreset preset;
  _PresetChosen(this.preset);
}

class _CustomChosen extends _SheetResult {}

/// Modal bottom sheet hosting [LanguageQuickPicker]. A preset tap creates the
/// language; "Custom settings…" closes the sheet and opens the full form.
Future<Language?> showAddLanguageSheet(
  BuildContext context, {
  required Set<String> existingCodes,
}) async {
  final result = await showModalBottomSheet<_SheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: LanguageQuickPicker(
          existingCodes: existingCodes,
          onPresetSelected: (p) async =>
              Navigator.pop(sheetContext, _PresetChosen(p)),
          onCustomSettings: () => Navigator.pop(sheetContext, _CustomChosen()),
        ),
      ),
    ),
  );
  if (result == null || !context.mounted) return null;
  final isFirst = existingCodes.isEmpty;
  switch (result) {
    case _PresetChosen(:final preset):
      final name = localizedLangName(AppLocalizations.of(context), preset.code);
      return createAndSelectLanguage(
        context,
        preset.toLanguage(name),
        isFirstLanguage: isFirst,
      );
    case _CustomChosen():
      return openCustomLanguageForm(context, isFirstLanguage: isFirst);
  }
}
