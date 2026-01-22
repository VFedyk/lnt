import 'package:flutter/material.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../services/database_service.dart';

class TermDialog extends StatefulWidget {
  final Term term;
  final String sentence;
  final List<Dictionary> dictionaries;
  final Function(BuildContext, Dictionary) onLookup;
  final int languageId;

  const TermDialog({
    super.key,
    required this.term,
    required this.sentence,
    required this.dictionaries,
    required this.onLookup,
    required this.languageId,
  });

  @override
  State<TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<TermDialog> {
  late int _status;
  late TextEditingController _termController;
  late TextEditingController _translationController;
  late TextEditingController _romanizationController;
  late TextEditingController _sentenceController;

  // Base term linking
  int? _baseTermId;
  Term? _baseTerm;
  List<Term> _linkedTerms = [];

  @override
  void initState() {
    super.initState();
    _status = widget.term.status;
    _termController = TextEditingController(text: widget.term.lowerText);
    _translationController = TextEditingController(
      text: widget.term.translation,
    );
    _romanizationController = TextEditingController(
      text: widget.term.romanization,
    );
    _sentenceController = TextEditingController(
      text: widget.term.sentence.isEmpty
          ? widget.sentence
          : widget.term.sentence,
    );
    _baseTermId = widget.term.baseTermId;
    _loadBaseTermAndLinkedTerms();
  }

  Future<void> _loadBaseTermAndLinkedTerms() async {
    // Load base term if this term is linked to one
    if (_baseTermId != null) {
      final baseTerm = await DatabaseService.instance.getTerm(_baseTermId!);
      if (mounted) {
        setState(() => _baseTerm = baseTerm);
      }
    }
    // Load linked terms if this term IS a base term (has an id)
    if (widget.term.id != null) {
      final linked = await DatabaseService.instance.getLinkedTerms(widget.term.id!);
      if (mounted) {
        setState(() => _linkedTerms = linked);
      }
    }
  }

  Future<void> _selectBaseTerm() async {
    final selectedTerm = await showDialog<Term>(
      context: context,
      builder: (context) => _BaseTermSearchDialog(
        languageId: widget.languageId,
        excludeTermId: widget.term.id,
      ),
    );
    if (selectedTerm != null && mounted) {
      setState(() {
        _baseTermId = selectedTerm.id;
        _baseTerm = selectedTerm;
      });
    }
  }

  void _removeBaseTerm() {
    setState(() {
      _baseTermId = null;
      _baseTerm = null;
    });
  }

  Widget _buildBaseTermSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show base term if linked
        if (_baseTerm != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Base: ',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    _baseTerm!.lowerText,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _removeBaseTerm,
                  tooltip: 'Remove link',
                ),
              ],
            ),
          )
        else
          // Show button to link to base term
          OutlinedButton.icon(
            onPressed: _selectBaseTerm,
            icon: const Icon(Icons.add_link, size: 18),
            label: const Text('Link to base form...'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade300),
            ),
          ),

        // Show linked terms if this is a base term
        if (_linkedTerms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Forms: ${_linkedTerms.map((t) => t.lowerText).join(", ")}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _termController.dispose();
    _translationController.dispose();
    _romanizationController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.term.lowerText,
                  style: const TextStyle(fontSize: 24),
                ),
                if (widget.term.text != widget.term.lowerText)
                  Text(
                    'Original: ${widget.term.text}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (widget.dictionaries.isNotEmpty)
            PopupMenuButton<Dictionary>(
              icon: const Icon(Icons.search),
              tooltip: 'Lookup in Dictionary',
              onSelected: (dict) {
                widget.onLookup(context, dict);
              },
              itemBuilder: (context) => widget.dictionaries
                  .map(
                    (dict) =>
                        PopupMenuItem(value: dict, child: Text(dict.name)),
                  )
                  .toList(),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Term field (editable)
            TextField(
              controller: _termController,
              decoration: InputDecoration(
                labelText: 'Term',
                border: const OutlineInputBorder(),
                suffixIcon: widget.term.text != widget.term.lowerText
                    ? IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: 'Use original: ${widget.term.text}',
                        onPressed: () {
                          _termController.text = widget.term.text;
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // Base term linking
            _buildBaseTermSection(),
            const SizedBox(height: 12),

            // Status selector
            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(0, 'Ignored', Colors.grey.shade400),
                _buildStatusChip(1, 'Unknown', Colors.red.shade400),
                _buildStatusChip(2, 'Learning 2', Colors.orange.shade400),
                _buildStatusChip(3, 'Learning 3', Colors.yellow.shade700),
                _buildStatusChip(4, 'Learning 4', Colors.lightGreen.shade500),
                _buildStatusChip(5, 'Known', Colors.green.shade600),
                _buildStatusChip(99, 'Well Known', Colors.blue.shade400),
              ],
            ),
            const SizedBox(height: 16),

            // Translation field
            TextField(
              controller: _translationController,
              decoration: const InputDecoration(
                labelText: 'Translation',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Romanization field
            TextField(
              controller: _romanizationController,
              decoration: const InputDecoration(
                labelText: 'Romanization / Pronunciation',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Sentence field
            TextField(
              controller: _sentenceController,
              decoration: const InputDecoration(
                labelText: 'Example Sentence',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.term.id != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final editedTerm = _termController.text.trim().toLowerCase();
            final updatedTerm = widget.term.copyWith(
              text: editedTerm,
              lowerText: editedTerm,
              status: _status,
              translation: _translationController.text,
              romanization: _romanizationController.text,
              sentence: _sentenceController.text,
              lastAccessed: DateTime.now(),
              baseTermId: _baseTermId,
              clearBaseTermId: _baseTermId == null && widget.term.baseTermId != null,
            );
            Navigator.pop(context, updatedTerm);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildStatusChip(int status, String label, Color color) {
    final isSelected = _status == status;
    final isIgnored = status == 0;
    final isWellKnown = status == 99;

    // For ignored and well-known when not selected, show as plain text
    if ((isIgnored || isWellKnown) && !isSelected) {
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isIgnored ? Colors.grey.shade600 : Colors.blue.shade700,
            fontSize: 12,
          ),
        ),
        selected: false,
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: isIgnored ? Colors.grey.shade400 : Colors.blue.shade300,
          width: 1,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _status = status);
          }
        },
      );
    }

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.2),
      onSelected: (selected) {
        if (selected) {
          setState(() => _status = status);
        }
      },
      avatar: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

/// Dialog to search and select a base term
class _BaseTermSearchDialog extends StatefulWidget {
  final int languageId;
  final int? excludeTermId;

  const _BaseTermSearchDialog({
    required this.languageId,
    this.excludeTermId,
  });

  @override
  State<_BaseTermSearchDialog> createState() => _BaseTermSearchDialogState();
}

class _BaseTermSearchDialogState extends State<_BaseTermSearchDialog> {
  final _searchController = TextEditingController();
  final _translationController = TextEditingController();
  List<Term> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    final results = await DatabaseService.instance.searchTerms(
      widget.languageId,
      query.trim(),
    );

    if (mounted) {
      setState(() {
        _searchResults = results
            .where((t) => t.id != widget.excludeTermId)
            .toList();
        _isSearching = false;
      });
    }
  }

  Future<void> _createNewBaseTerm() async {
    final termText = _searchController.text.trim().toLowerCase();
    if (termText.isEmpty) return;

    final newTerm = Term(
      languageId: widget.languageId,
      text: termText,
      lowerText: termText,
      status: 1,
      translation: _translationController.text.trim(),
    );

    final id = await DatabaseService.instance.createTerm(newTerm);
    final createdTerm = newTerm.copyWith(id: id);

    if (mounted) {
      Navigator.pop(context, createdTerm);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Base Form'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search terms...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'No terms found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _translationController,
                      decoration: const InputDecoration(
                        labelText: 'Translation (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _createNewBaseTerm,
                      icon: const Icon(Icons.add),
                      label: Text('Create "${_searchController.text.trim().toLowerCase()}"'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final term = _searchResults[index];
                    return ListTile(
                      title: Text(term.lowerText),
                      subtitle: term.translation.isNotEmpty
                          ? Text(
                              term.translation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      leading: CircleAvatar(
                        backgroundColor: term.statusColor,
                        radius: 12,
                      ),
                      onTap: () => Navigator.pop(context, term),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
