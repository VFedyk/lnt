import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../services/database_service.dart';
import 'dictionaries_screen.dart';

class LanguagesScreen extends StatefulWidget {
  final VoidCallback? onLanguagesChanged;

  const LanguagesScreen({super.key, this.onLanguagesChanged});

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
    final languages = await DatabaseService.instance.getLanguages();
    setState(() {
      _languages = languages;
      _isLoading = false;
    });

    // Notify parent that languages changed
    widget.onLanguagesChanged?.call();
  }

  Future<void> _addOrEditLanguage([Language? language]) async {
    final result = await showDialog<Language>(
      context: context,
      builder: (context) => _LanguageDialog(language: language),
    );

    if (result != null) {
      if (language == null) {
        final langId = await DatabaseService.instance.createLanguage(result);
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
        await DatabaseService.instance.updateLanguage(result);
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
    final dicts = await DatabaseService.instance.getDictionaries(
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteLanguage(language.id!);
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
                  Icon(Icons.language, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(l10n.noLanguagesYet),
                  const SizedBox(height: 8),
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
                    horizontal: 16,
                    vertical: 8,
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
                          color: Colors.red,
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

class _LanguageDialog extends StatefulWidget {
  final Language? language;

  const _LanguageDialog({this.language});

  @override
  State<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<_LanguageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late bool _rightToLeft;
  late bool _showRomanization;
  late bool _splitByCharacter;

  @override
  void initState() {
    super.initState();
    final lang = widget.language;
    _nameController = TextEditingController(text: lang?.name ?? '');
    _rightToLeft = lang?.rightToLeft ?? false;
    _showRomanization = lang?.showRomanization ?? false;
    _splitByCharacter = lang?.splitByCharacter ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.language == null ? l10n.addLanguage : l10n.editLanguage),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.languageNameLabel,
                  hintText: l10n.languageNameHint,
                ),
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.rightToLeftText),
                subtitle: Text(l10n.rightToLeftHint),
                value: _rightToLeft,
                onChanged: (v) => setState(() => _rightToLeft = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(l10n.showRomanization),
                subtitle: Text(l10n.showRomanizationHint),
                value: _showRomanization,
                onChanged: (v) => setState(() => _showRomanization = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(l10n.splitByCharacter),
                subtitle: Text(l10n.splitByCharacterHint),
                value: _splitByCharacter,
                onChanged: (v) => setState(() => _splitByCharacter = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.addDictionariesAfterCreating,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final lang = Language(
                id: widget.language?.id,
                name: _nameController.text.trim(),
                rightToLeft: _rightToLeft,
                showRomanization: _showRomanization,
                splitByCharacter: _splitByCharacter,
              );
              Navigator.pop(context, lang);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
