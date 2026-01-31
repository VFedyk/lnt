// FILE: lib/screens/dictionaries_screen.dart
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/dictionary.dart';
import '../services/database_service.dart';

class _DictionariesScreenConstants {
  static const double listPadding = 16.0;
  static const double cardBottomMargin = 8.0;
  static const double iconSpacing = 8.0;
  static const double subtitleFontSize = 12.0;
  static const double emptyIconSize = 64.0;
  static const double emptyTextSpacing = 16.0;
  static const double emptySubtextSpacing = 8.0;
  static const double helpSectionSpacing = 16.0;
  static const double helpStepSpacing = 8.0;
  static const double exampleUrlFontSize = 12.0;
  static const double dialogFieldSpacing = 16.0;
  static const double switchBottomSpacing = 8.0;
  static const double tipBoxPadding = 12.0;
  static const double tipBoxRadius = 8.0;
  static const double tipIconSize = 16.0;
  static const double templateVerticalPadding = 4.0;
  static const double templateFontSize = 12.0;
  static const int urlMaxLines = 1;
  static const int urlFieldMaxLines = 3;
}

class DictionariesScreen extends StatefulWidget {
  final Language language;

  const DictionariesScreen({super.key, required this.language});

  @override
  State<DictionariesScreen> createState() => _DictionariesScreenState();
}

class _DictionariesScreenState extends State<DictionariesScreen> {
  List<Dictionary> _dictionaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    setState(() => _isLoading = true);
    final dicts = await DatabaseService.instance.getDictionaries(
      languageId: widget.language.id!,
    );
    setState(() {
      _dictionaries = dicts;
      _isLoading = false;
    });
  }

  Future<void> _addOrEditDictionary([Dictionary? dictionary]) async {
    final result = await showDialog<Dictionary>(
      context: context,
      builder: (context) => _DictionaryDialog(
        languageId: widget.language.id!,
        dictionary: dictionary,
      ),
    );

    if (result != null) {
      if (dictionary == null) {
        await DatabaseService.instance.createDictionary(result);
      } else {
        await DatabaseService.instance.updateDictionary(result);
      }
      _loadDictionaries();
    }
  }

  Future<void> _deleteDictionary(Dictionary dictionary) async {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteDictionary),
        content: Text(l10n.deleteDictionaryConfirm(dictionary.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteDictionary(dictionary.id!);
      _loadDictionaries();
    }
  }

  Future<void> _toggleActive(Dictionary dictionary) async {
    final updated = dictionary.copyWith(isActive: !dictionary.isActive);
    await DatabaseService.instance.updateDictionary(updated);
    _loadDictionaries();
  }

  Future<void> _reorderDictionaries(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _dictionaries.removeAt(oldIndex);
      _dictionaries.insert(newIndex, item);
    });

    await DatabaseService.instance.reorderDictionaries(_dictionaries);
    _loadDictionaries();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dictionariesTitle(widget.language.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.help,
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dictionaries.isEmpty
          ? _buildEmptyState()
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(_DictionariesScreenConstants.listPadding),
              itemCount: _dictionaries.length,
              onReorder: _reorderDictionaries,
              itemBuilder: (context, index) {
                final dict = _dictionaries[index];
                return Card(
                  key: ValueKey(dict.id),
                  margin: const EdgeInsets.only(bottom: _DictionariesScreenConstants.cardBottomMargin),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_handle, color: colorScheme.outline),
                        const SizedBox(width: _DictionariesScreenConstants.iconSpacing),
                        CircleAvatar(
                          backgroundColor: dict.isActive
                              ? colorScheme.primary
                              : colorScheme.outline,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(color: colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      dict.name,
                      style: TextStyle(
                        decoration: dict.isActive
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      dict.url,
                      maxLines: _DictionariesScreenConstants.urlMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: _DictionariesScreenConstants.subtitleFontSize, color: colorScheme.onSurfaceVariant),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _addOrEditDictionary(dict);
                            break;
                          case 'toggle':
                            _toggleActive(dict);
                            break;
                          case 'delete':
                            _deleteDictionary(dict);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit),
                              const SizedBox(width: _DictionariesScreenConstants.iconSpacing),
                              Text(l10n.edit),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                dict.isActive
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              const SizedBox(width: _DictionariesScreenConstants.iconSpacing),
                              Text(
                                dict.isActive ? l10n.deactivate : l10n.activate,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: colorScheme.error),
                              const SizedBox(width: _DictionariesScreenConstants.iconSpacing),
                              Text(
                                l10n.delete,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditDictionary(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book, size: _DictionariesScreenConstants.emptyIconSize, color: colorScheme.outline),
          const SizedBox(height: _DictionariesScreenConstants.emptyTextSpacing),
          Text(l10n.noDictionariesYet),
          const SizedBox(height: _DictionariesScreenConstants.emptySubtextSpacing),
          Text(
            l10n.addDictionariesFor(widget.language.name),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: _DictionariesScreenConstants.emptyTextSpacing),
          ElevatedButton.icon(
            onPressed: () => _addOrEditDictionary(),
            icon: const Icon(Icons.add),
            label: Text(l10n.addDictionary),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dictionaryHelp),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.howToUse,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: _DictionariesScreenConstants.helpStepSpacing),
              Text(l10n.dictionaryHelpStep1),
              Text(l10n.dictionaryHelpStep2),
              Text(l10n.dictionaryHelpStep3),
              Text(l10n.dictionaryHelpStep4),
              const SizedBox(height: _DictionariesScreenConstants.helpSectionSpacing),
              Text(
                l10n.exampleUrls,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: _DictionariesScreenConstants.helpStepSpacing),
              const Text(
                'WordReference:\nhttps://www.wordreference.com/es/en/translation.asp?spen=###',
                style: TextStyle(fontSize: _DictionariesScreenConstants.exampleUrlFontSize),
              ),
              const SizedBox(height: _DictionariesScreenConstants.helpStepSpacing),
              const Text(
                'Jisho (Japanese):\nhttps://jisho.org/search/###',
                style: TextStyle(fontSize: _DictionariesScreenConstants.exampleUrlFontSize),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }
}

class _DictionaryDialog extends StatefulWidget {
  final int languageId;
  final Dictionary? dictionary;

  const _DictionaryDialog({required this.languageId, this.dictionary});

  @override
  State<_DictionaryDialog> createState() => _DictionaryDialogState();
}

class _DictionaryDialogState extends State<_DictionaryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final dict = widget.dictionary;
    _nameController = TextEditingController(text: dict?.name ?? '');
    _urlController = TextEditingController(text: dict?.url ?? '');
    _isActive = dict?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        widget.dictionary == null ? l10n.addDictionary : l10n.editDictionary,
      ),
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
                  labelText: l10n.dictionaryName,
                  hintText: l10n.dictionaryNameHint,
                ),
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
              ),
              const SizedBox(height: _DictionariesScreenConstants.dialogFieldSpacing),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l10n.urlTemplate,
                  hintText: l10n.urlTemplateHint,
                  helperText: l10n.urlTemplateHelper,
                ),
                maxLines: _DictionariesScreenConstants.urlFieldMaxLines,
                validator: (v) {
                  if (v?.isEmpty == true) return l10n.required;
                  if (!v!.contains('###')) {
                    return l10n.urlMustContainPlaceholder;
                  }

                  return null;
                },
              ),
              const SizedBox(height: _DictionariesScreenConstants.dialogFieldSpacing),
              SwitchListTile(
                title: Text(l10n.active),
                subtitle: Text(l10n.showInDictionaryLookupMenu),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: _DictionariesScreenConstants.switchBottomSpacing),
              Container(
                padding: const EdgeInsets.all(_DictionariesScreenConstants.tipBoxPadding),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(_DictionariesScreenConstants.tipBoxRadius),
                  border: Border.all(color: colorScheme.primary.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: _DictionariesScreenConstants.tipIconSize,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: _DictionariesScreenConstants.iconSpacing),
                        Text(
                          l10n.quickTemplates,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildQuickTemplate(
                      'WordReference ES-EN',
                      'https://www.wordreference.com/es/en/translation.asp?spen=###',
                    ),
                    _buildQuickTemplate(
                      'Jisho (Japanese)',
                      'https://jisho.org/search/###',
                    ),
                    _buildQuickTemplate(
                      'MDBG (Chinese)',
                      'https://www.mdbg.net/chinese/dictionary?page=worddict&wdrst=0&wdqb=###',
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
              final dict = Dictionary(
                id: widget.dictionary?.id,
                languageId: widget.languageId,
                name: _nameController.text,
                url: _urlController.text,
                sortOrder: widget.dictionary?.sortOrder ?? 0,
                isActive: _isActive,
              );
              Navigator.pop(context, dict);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _buildQuickTemplate(String name, String url) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        setState(() {
          if (_nameController.text.isEmpty) {
            _nameController.text = name;
          }
          _urlController.text = url;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _DictionariesScreenConstants.templateVerticalPadding),
        child: Text(
          name,
          style: TextStyle(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            fontSize: _DictionariesScreenConstants.templateFontSize,
          ),
        ),
      ),
    );
  }
}
