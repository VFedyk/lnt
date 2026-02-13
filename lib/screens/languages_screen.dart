import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../service_locator.dart';
import '../utils/constants.dart';
import '../widgets/language_dialog.dart';
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
    setState(() => _isLoading = true);
    final languages = await db.languages.getAll();
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
        // After creating language, prompt to add dictionaries
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          final shouldAddDict = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.addDictionariesQuestion),
              content: Text(l10n.addDictionariesPrompt(result.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.later),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.addNow),
                ),
              ],
            ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLanguageQuestion),
        content: Text(l10n.deleteLanguageConfirm(language.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.language, size: AppConstants.emptyStateIconSize, color: Colors.grey[400]),
                  const SizedBox(height: AppConstants.spacingL),
                  Text(l10n.noLanguagesYet),
                  const SizedBox(height: AppConstants.spacingS),
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditLanguage(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addLanguage),
                  ),
                ],
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
