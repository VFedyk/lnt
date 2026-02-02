import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/text_document.dart';
import '../utils/constants.dart';

abstract class _AddTextDialogConstants {
  static const int contentMaxLines = 10;
}

class AddTextDialog extends StatefulWidget {
  final int languageId;
  final int? collectionId;

  const AddTextDialog({
    super.key,
    required this.languageId,
    this.collectionId,
  });

  @override
  State<AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<AddTextDialog> {
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addText),
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
              const SizedBox(height: AppConstants.spacingL),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.textContent,
                  alignLabelWithHint: true,
                ),
                maxLines: _AddTextDialogConstants.contentMaxLines,
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
              final text = TextDocument(
                languageId: widget.languageId,
                collectionId: widget.collectionId,
                title: _titleController.text,
                content: _contentController.text,
              );
              Navigator.pop(context, text);
            }
          },
          child: Text(l10n.add),
        ),
      ],
    );
  }
}
