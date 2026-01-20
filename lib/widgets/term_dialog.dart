import 'package:flutter/material.dart';
import '../models/term.dart';
import '../models/dictionary.dart';

class TermDialog extends StatefulWidget {
  final Term term;
  final String sentence;
  final List<Dictionary> dictionaries;
  final Function(BuildContext, Dictionary) onLookup;

  const TermDialog({
    super.key,
    required this.term,
    required this.sentence,
    required this.dictionaries,
    required this.onLookup,
  });

  @override
  State<TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<TermDialog> {
  late int _status;
  late TextEditingController _translationController;
  late TextEditingController _romanizationController;
  late TextEditingController _sentenceController;

  @override
  void initState() {
    super.initState();
    _status = widget.term.status;
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
  }

  @override
  void dispose() {
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
            child: Text(widget.term.text, style: const TextStyle(fontSize: 24)),
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
            final updatedTerm = widget.term.copyWith(
              status: _status,
              translation: _translationController.text,
              romanization: _romanizationController.text,
              sentence: _sentenceController.text,
              lastAccessed: DateTime.now(),
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
