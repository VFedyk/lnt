import 'package:flutter/material.dart';
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
          final shouldAddDict = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Dictionaries?'),
              content: Text(
                'Would you like to add dictionaries for ${result.name}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Add Now'),
                ),
              ],
            ),
          );

          if (shouldAddDict == true) {
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Language?'),
        content: Text(
          'This will delete "${language.name}" and all associated texts, terms, and dictionaries. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Languages')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _languages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.language, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No languages yet'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditLanguage(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Language'),
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
                        return Text(
                          '$count ${count == 1 ? 'dictionary' : 'dictionaries'}',
                        );
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.book),
                          onPressed: () => _manageDictionaries(lang),
                          tooltip: 'Manage Dictionaries',
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
    return AlertDialog(
      title: Text(widget.language == null ? 'Add Language' : 'Edit Language'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Language Name',
                  hintText: 'e.g., Spanish, Japanese, Chinese',
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Right-to-Left Text'),
                subtitle: const Text('For languages like Arabic, Hebrew'),
                value: _rightToLeft,
                onChanged: (v) => setState(() => _rightToLeft = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Show Romanization'),
                subtitle: const Text('Display pronunciation guide'),
                value: _showRomanization,
                onChanged: (v) => setState(() => _showRomanization = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Split by Character'),
                subtitle: const Text('For Chinese, Japanese (no spaces)'),
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
                        'Add dictionaries after creating the language',
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
          child: const Text('Cancel'),
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
          child: const Text('Save'),
        ),
      ],
    );
  }
}
