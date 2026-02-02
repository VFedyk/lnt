import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/text_document.dart';

class EditTextDialog extends StatefulWidget {
  final TextDocument text;

  const EditTextDialog({super.key, required this.text});

  @override
  State<EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  static const double _spacing = 16.0;
  static const int _contentMaxLines = 10;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.text.title);
    _contentController = TextEditingController(text: widget.text.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editText),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.title),
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
              ),
              const SizedBox(height: _spacing),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.textContent,
                  alignLabelWithHint: true,
                ),
                maxLines: _contentMaxLines,
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
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
              final updatedText = widget.text.copyWith(
                title: _titleController.text,
                content: _contentController.text,
              );
              Navigator.pop(context, updatedText);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
