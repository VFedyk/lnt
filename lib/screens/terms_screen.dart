// FILE: lib/screens/terms_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/language.dart';
import '../models/term.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import '../widgets/term_dialog.dart';

class TermsScreen extends StatefulWidget {
  final Language language;

  const TermsScreen({super.key, required this.language});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  List<Term> _terms = [];
  List<Term> _filteredTerms = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final _importService = ImportExportService();
  int? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() => _isLoading = true);
    final terms = await DatabaseService.instance.getTerms(
      languageId: widget.language.id!,
    );
    setState(() {
      _terms = terms;
      _applyFilters();
      _isLoading = false;
    });
  }

  Map<int, int> _statusCounts = {};

  void _applyFilters() {
    var filtered = _terms;

    if (_statusFilter != null) {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where(
            (t) =>
                t.text.toLowerCase().contains(query) ||
                t.translation.toLowerCase().contains(query),
          )
          .toList();
    }

    _filteredTerms = filtered;
    _updateStatusCounts();
  }

  void _updateStatusCounts() {
    _statusCounts = {};
    for (final term in _terms) {
      _statusCounts[term.status] = (_statusCounts[term.status] ?? 0) + 1;
    }
  }

  Future<void> _exportTerms(String format) async {
    try {
      await _importService.exportAndShare(_terms, format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${_terms.length} terms')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importFromCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final content = await _importService.readTextFile(file);
        final importedTerms = await _importService.importTermsFromCSV(
          content,
          widget.language.id!,
        );

        for (final term in importedTerms) {
          await DatabaseService.instance.createTerm(term);
        }

        _loadTerms();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported ${importedTerms.length} terms')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
        }
      }
    }
  }

  Future<void> _deleteTerm(Term term) async {
    await DatabaseService.instance.deleteTerm(term.id!);
    _loadTerms();
  }

  Future<void> _editTerm(Term term) async {
    final result = await showDialog<Term?>(
      context: context,
      builder: (dialogContext) => TermDialog(
        term: term,
        sentence: term.sentence,
        onLookup: (ctx, dictNum) {},
        dictionaries: const [],
        languageId: widget.language.id!,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.updateTerm(result);
      _loadTerms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terms - ${widget.language.name}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importFromCSV();
                  break;
                case 'export_csv':
                  _exportTerms('csv');
                  break;
                case 'export_anki':
                  _exportTerms('anki');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload),
                    SizedBox(width: 8),
                    Text('Import CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_anki',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export Anki'),
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
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search terms...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (_) => setState(() => _applyFilters()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('All (${_terms.length})'),
                        selected: _statusFilter == null,
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = null;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(7, (i) {
                        final status = i == 6 ? 99 : i;
                        final statusName = _getStatusName(status);
                        final count = _statusCounts[status] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('$statusName ($count)'),
                            selected: _statusFilter == status,
                            onSelected: (_) {
                              setState(() {
                                _statusFilter = status;
                                _applyFilters();
                              });
                            },
                            avatar: CircleAvatar(
                              backgroundColor: _getStatusColor(status),
                              radius: 8,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTermsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsList() {
    if (_filteredTerms.isEmpty) {
      return const Center(child: Text('No terms found'));
    }

    return ListView.builder(
      itemCount: _filteredTerms.length,
      itemBuilder: (context, index) {
        final term = _filteredTerms[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: term.statusColor,
              child: Text(
                term.status.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(term.text),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (term.translation.isNotEmpty) Text(term.translation),
                if (term.romanization.isNotEmpty)
                  Text(
                    term.romanization,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
            trailing: PopupMenuButton(
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
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editTerm(term);
                } else if (value == 'delete') {
                  _deleteTerm(term);
                }
              },
            ),
            onTap: () => _editTerm(term),
          ),
        );
      },
    );
  }

  String _getStatusName(int status) {
    switch (status) {
      case 0:
        return 'Ignored';
      case 1:
        return 'Unknown';
      case 2:
        return 'Learning 2';
      case 3:
        return 'Learning 3';
      case 4:
        return 'Learning 4';
      case 5:
        return 'Known';
      case 99:
        return 'Well Known';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.grey.shade400;
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.lightGreen.shade500;
      case 5:
        return Colors.green.shade600;
      case 99:
        return Colors.blue.shade400;
      default:
        return Colors.grey;
    }
  }
}
