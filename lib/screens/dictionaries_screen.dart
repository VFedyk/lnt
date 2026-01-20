// FILE: lib/screens/dictionaries_screen.dart
import 'package:flutter/material.dart';
import '../models/language.dart';
import '../models/dictionary.dart';
import '../services/database_service.dart';

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dictionary?'),
        content: Text('Delete "${dictionary.name}"?'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Dictionaries - ${widget.language.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dictionaries.isEmpty
          ? _buildEmptyState()
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _dictionaries.length,
              onReorder: _reorderDictionaries,
              itemBuilder: (context, index) {
                final dict = _dictionaries[index];
                return Card(
                  key: ValueKey(dict.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_handle, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: dict.isActive
                              ? Colors.green
                              : Colors.grey,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
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
                              const SizedBox(width: 8),
                              Text(dict.isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No dictionaries yet'),
          const SizedBox(height: 8),
          Text(
            'Add dictionaries for ${widget.language.name}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _addOrEditDictionary(),
            icon: const Icon(Icons.add),
            label: const Text('Add Dictionary'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dictionary Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Add dictionary URLs for this language'),
              Text('2. Use ### as placeholder for the word'),
              Text('3. Drag to reorder dictionaries'),
              Text('4. Toggle active/inactive'),
              SizedBox(height: 16),
              Text(
                'Example URLs:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'WordReference:\nhttps://www.wordreference.com/es/en/translation.asp?spen=###',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 8),
              Text(
                'Jisho (Japanese):\nhttps://jisho.org/search/###',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
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
    return AlertDialog(
      title: Text(
        widget.dictionary == null ? 'Add Dictionary' : 'Edit Dictionary',
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
                decoration: const InputDecoration(
                  labelText: 'Dictionary Name',
                  hintText: 'e.g., WordReference, Jisho',
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL Template',
                  hintText: 'https://example.com/dict?word=###',
                  helperText: 'Use ### as placeholder for the word',
                ),
                maxLines: 3,
                validator: (v) {
                  if (v?.isEmpty == true) return 'Required';
                  if (!v!.contains('###')) return 'URL must contain ###';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Show in dictionary lookup menu'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Templates:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
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
          child: const Text('Cancel'),
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
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildQuickTemplate(String name, String url) {
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          name,
          style: TextStyle(
            color: Colors.blue.shade700,
            decoration: TextDecoration.underline,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
