import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/collection.dart';
import '../models/term.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import '../services/epub_import_service.dart';
import '../services/text_parser_service.dart';
import 'reader_screen.dart';

class TextsScreen extends StatefulWidget {
  final Language language;

  const TextsScreen({super.key, required this.language});

  @override
  State<TextsScreen> createState() => _TextsScreenState();
}

class _TextsScreenState extends State<TextsScreen> {
  List<TextDocument> _texts = [];
  List<Collection> _collections = [];
  Collection? _currentCollection;
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final _importService = ImportExportService();
  final _textParser = TextParserService();
  Map<int, int> _unknownCounts = {}; // textId -> unknown word count

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final collections = await DatabaseService.instance.getCollections(
      languageId: widget.language.id!,
      parentId: _currentCollection?.id,
    );

    final texts = await DatabaseService.instance.getTexts(
      languageId: widget.language.id!,
    );

    // Load terms map for unknown word calculation
    final termsMap = await DatabaseService.instance.getTermsMap(
      widget.language.id!,
    );

    // Filter texts by current collection
    final filteredTexts = _currentCollection == null
        ? texts.where((t) => t.collectionId == null).toList()
        : texts.where((t) => t.collectionId == _currentCollection!.id).toList();

    // Calculate unknown counts for each text
    final unknownCounts = <int, int>{};
    for (final text in filteredTexts) {
      unknownCounts[text.id!] = _calculateUnknownCount(text, termsMap);
    }

    setState(() {
      _collections = collections;
      _texts = filteredTexts;
      _unknownCounts = unknownCounts;
      _isLoading = false;
    });
  }

  int _calculateUnknownCount(TextDocument text, Map<String, Term> termsMap) {
    final words = _textParser.splitIntoWords(text.content, widget.language);
    int unknownCount = 0;

    final seenWords = <String>{};
    for (final word in words) {
      final normalized = word.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      final term = termsMap[normalized];
      // Count as unknown if no term exists or status is 1 (Unknown)
      if (term == null || term.status == 1) {
        unknownCount++;
      }
    }

    return unknownCount;
  }

  Future<void> _recalculateUnknownCountForText(TextDocument text) async {
    final termsMap = await DatabaseService.instance.getTermsMap(
      widget.language.id!,
    );
    final newCount = _calculateUnknownCount(text, termsMap);
    setState(() {
      _unknownCounts[text.id!] = newCount;
    });
  }

  Future<void> _openCollection(Collection collection) async {
    setState(() => _currentCollection = collection);
    await _loadData();
  }

  Future<void> _goBack() async {
    if (_currentCollection != null) {
      if (_currentCollection!.parentId != null) {
        final parent = await DatabaseService.instance.getCollection(
          _currentCollection!.parentId!,
        );
        setState(() => _currentCollection = parent);
      } else {
        setState(() => _currentCollection = null);
      }
      await _loadData();
    }
  }

  Future<void> _addCollection() async {
    final result = await showDialog<Collection>(
      context: context,
      builder: (context) => _CollectionDialog(
        languageId: widget.language.id!,
        parentId: _currentCollection?.id,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.createCollection(result);
      _loadData();
    }
  }

  Future<void> _addText() async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => _AddTextDialog(
        languageId: widget.language.id!,
        collectionId: _currentCollection?.id,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.createText(result);
      _loadData();
    }
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final content = await _importService.readTextFile(File(file.path!));

      final text = TextDocument(
        languageId: widget.language.id!,
        collectionId: _currentCollection?.id,
        title: file.name.replaceAll('.txt', ''),
        content: _importService.cleanTextForImport(content),
      );

      await DatabaseService.instance.createText(text);
      _loadData();
    }
  }

  Future<void> _importFromEpub() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Importing EPUB...')),
          ],
        ),
      ),
    );

    try {
      final epubService = EpubImportService();
      final importResult = await epubService.importEpub(
        epubBytes: file.bytes!,
        languageId: widget.language.id!,
        parentCollectionId: _currentCollection?.id,
      );

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Book: ${importResult.bookTitle}'),
              if (importResult.author != null)
                Text('Author: ${importResult.author}'),
              Text('Chapters: ${importResult.totalChapters}'),
              if (importResult.totalParts > importResult.totalChapters)
                Text('Total parts: ${importResult.totalParts}'),
              Text('Characters: ${importResult.totalCharacters}'),
              if (importResult.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...importResult.warnings.take(3).map((w) => Text('• $w')),
                if (importResult.warnings.length > 3)
                  Text('... and ${importResult.warnings.length - 3} more'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _loadData();
    } catch (e) {
      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Failed'),
          content: Text('Could not import EPUB: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteText(TextDocument text) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Text?'),
        content: Text('Delete "${text.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteText(text.id!);
      _loadData();
    }
  }

  Future<void> _deleteCollection(Collection collection) async {
    final textCount = await DatabaseService.instance.getTextCountInCollection(
      collection.id!,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text(
          textCount > 0
              ? 'Delete "${collection.name}" and its $textCount text(s)?'
              : 'Delete "${collection.name}"?',
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
      await DatabaseService.instance.deleteCollection(collection.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Texts - ${widget.language.name}'),
            if (_currentCollection != null)
              Text(
                _currentCollection!.name,
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        leading: _currentCollection != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'New Collection',
            onPressed: _addCollection,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import',
            onSelected: (value) {
              switch (value) {
                case 'txt':
                  _importFromFile();
                  break;
                case 'epub':
                  _importFromEpub();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'txt',
                child: Row(
                  children: [
                    Icon(Icons.text_snippet),
                    SizedBox(width: 8),
                    Text('Import TXT'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'epub',
                child: Row(
                  children: [
                    Icon(Icons.book),
                    SizedBox(width: 8),
                    Text('Import EPUB'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search texts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContentList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addText,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContentList() {
    final query = _searchController.text.toLowerCase();
    final filteredTexts = query.isEmpty
        ? _texts
        : _texts.where((t) => t.title.toLowerCase().contains(query)).toList();

    if (_collections.isEmpty && filteredTexts.isEmpty) {
      return const Center(child: Text('No collections or texts'));
    }

    return ListView(
      children: [
        // Collections first
        ..._collections.map(
          (collection) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.folder)),
              title: Text(collection.name),
              subtitle: collection.description.isNotEmpty
                  ? Text(collection.description)
                  : null,
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteCollection(collection);
                  }
                },
              ),
              onTap: () => _openCollection(collection),
            ),
          ),
        ),

        // Then texts
        ...filteredTexts.map(
          (text) {
            final unknownCount = _unknownCounts[text.id] ?? 0;
            final totalLabel = text.getCountLabel(widget.language.splitByCharacter);
            final unknownLabel = widget.language.splitByCharacter
                ? '$unknownCount unknown characters'
                : '$unknownCount unknown words';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.article)),
                title: Text(text.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(totalLabel),
                    Text(
                      unknownLabel,
                      style: TextStyle(
                        color: unknownCount > 0 ? Colors.orange : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteText(text),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReaderScreen(text: text, language: widget.language),
                    ),
                  ).then((_) => _recalculateUnknownCountForText(text));
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CollectionDialog extends StatefulWidget {
  final int languageId;
  final int? parentId;

  const _CollectionDialog({required this.languageId, this.parentId});

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Collection'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
          ],
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
              final collection = Collection(
                languageId: widget.languageId,
                parentId: widget.parentId,
                name: _nameController.text,
                description: _descriptionController.text,
              );
              Navigator.pop(context, collection);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _AddTextDialog extends StatefulWidget {
  final int languageId;
  final int? collectionId;

  const _AddTextDialog({required this.languageId, this.collectionId});

  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Text'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Text Content',
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
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
              final text = TextDocument(
                languageId: widget.languageId,
                collectionId: widget.collectionId,
                title: _titleController.text,
                content: _contentController.text,
              );
              Navigator.pop(context, text);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
