import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/dictionary.dart';
import '../models/language.dart';
import '../service_locator.dart';
import '../utils/constants.dart';
import '../utils/dialog_helpers.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/languages/language_dialog.dart';
import 'dictionaries_screen.dart';

class LanguagesScreen extends StatefulWidget {
  const LanguagesScreen({super.key});

  @override
  State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
  List<Language> _languages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final languages = await db.languages.getAll();
    if (!mounted) return;
    setState(() {
      _languages = languages;
      _isLoading = false;
    });
  }

  Future<void> _addOrEditLanguage([Language? language]) async {
    final result = await showDialog<Language>(
      context: context,
      builder: (context) => LanguageDialog(language: language),
    );

    if (result != null) {
      if (language == null) {
        final langId = await db.languages.create(result);
        // Auto-create a Google Translate dictionary for the new language.
        final targetLang = await settings.getTargetLang();
        final sl = result.languageCode.toLowerCase();
        final tl = targetLang.toLowerCase();
        await db.dictionaries.create(
          Dictionary(
            languageId: langId,
            name: 'Google Translate ${sl.toUpperCase()}-${tl.toUpperCase()}',
            url: 'https://translate.google.com/?sl=$sl&tl=$tl&text=###&op=translate',
          ),
        );
        // After creating language, prompt to add more dictionaries
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          final shouldAddDict = await DialogHelpers.showConfirmationDialog(
            context,
            title: l10n.addDictionariesQuestion,
            message: l10n.addDictionariesPrompt(result.name),
            cancelText: l10n.later,
            confirmText: l10n.addNow,
          );

          if (shouldAddDict == true && mounted) {
            final newLang = result.copyWith(id: langId);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DictionariesScreen(language: newLang),
              ),
            );
          }
        }
      } else {
        await db.languages.update(result);
      }
      _loadLanguages();
    }
  }

  Future<void> _manageDictionaries(Language language) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DictionariesScreen(language: language)),
    );
    _loadLanguages();
  }

  Future<int> _getDictionaryCount(int languageId) async {
    final dicts = await db.dictionaries.getAll(
      languageId: languageId,
    );
    return dicts.length;
  }

  Future<void> _deleteLanguage(Language language) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await DialogHelpers.showDestructiveDialog(
      context,
      title: l10n.deleteLanguageQuestion,
      message: l10n.deleteLanguageConfirm(language.name),
      confirmText: l10n.delete,
    );

    if (confirm == true) {
      await db.languages.delete(language.id!);
      _loadLanguages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languages)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _languages.isEmpty
          ? AppEmptyState(
              icon: Icons.language,
              iconSize: AppConstants.emptyStateIconSize,
              iconColor: Colors.grey[400],
              title: l10n.noLanguagesYet,
              action: ElevatedButton.icon(
                onPressed: () => _addOrEditLanguage(),
                icon: const Icon(Icons.add),
                label: Text(l10n.addLanguage),
              ),
            )
          : ListView.builder(
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final lang = _languages[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                    vertical: AppConstants.spacingS,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(lang.name[0].toUpperCase()),
                    ),
                    title: Text(lang.name),
                    subtitle: FutureBuilder<int>(
                      future: _getDictionaryCount(lang.id!),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Text(l10n.dictionaryCount(count));
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.book),
                          onPressed: () => _manageDictionaries(lang),
                          tooltip: l10n.manageDictionaries,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _addOrEditLanguage(lang),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteLanguage(lang),
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditLanguage(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
