import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/dictionary.dart';

abstract class _DictionaryDialogConstants {
  static const double fieldSpacing = 16.0;
  static const double switchBottomSpacing = 8.0;
  static const double tipBoxPadding = 12.0;
  static const double tipBoxRadius = 8.0;
  static const double tipIconSize = 16.0;
  static const double iconSpacing = 8.0;
  static const double stepSpacing = 8.0;
  static const double templateVerticalPadding = 4.0;
  static const double templateFontSize = 12.0;
  static const int urlFieldMaxLines = 3;
}

class DictionaryDialog extends StatefulWidget {
  final int languageId;
  final Dictionary? dictionary;

  const DictionaryDialog({super.key, required this.languageId, this.dictionary});

  @override
  State<DictionaryDialog> createState() => _DictionaryDialogState();
}

class _DictionaryDialogState extends State<DictionaryDialog> {
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
              const SizedBox(
                height: _DictionaryDialogConstants.fieldSpacing,
              ),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l10n.urlTemplate,
                  hintText: l10n.urlTemplateHint,
                  helperText: l10n.urlTemplateHelper,
                ),
                maxLines: _DictionaryDialogConstants.urlFieldMaxLines,
                validator: (v) {
                  if (v?.isEmpty == true) return l10n.required;
                  if (!v!.contains('###')) {
                    return l10n.urlMustContainPlaceholder;
                  }
                  return null;
                },
              ),
              const SizedBox(
                height: _DictionaryDialogConstants.fieldSpacing,
              ),
              SwitchListTile(
                title: Text(l10n.active),
                subtitle: Text(l10n.showInDictionaryLookupMenu),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(
                height: _DictionaryDialogConstants.switchBottomSpacing,
              ),
              Container(
                padding: const EdgeInsets.all(
                  _DictionaryDialogConstants.tipBoxPadding,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    _DictionaryDialogConstants.tipBoxRadius,
                  ),
                  border: Border.all(color: colorScheme.primary.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: _DictionaryDialogConstants.tipIconSize,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(
                          width: _DictionaryDialogConstants.iconSpacing,
                        ),
                        Text(
                          l10n.quickTemplates,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: _DictionaryDialogConstants.stepSpacing,
                    ),
                    _buildQuickTemplate(
                      'Google Translate EN-UK',
                      'https://translate.google.com/?sl=en&tl=uk&text=###&op=translate',
                    ),
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
        padding: const EdgeInsets.symmetric(
          vertical: _DictionaryDialogConstants.templateVerticalPadding,
        ),
        child: Text(
          name,
          style: TextStyle(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            fontSize: _DictionaryDialogConstants.templateFontSize,
          ),
        ),
      ),
    );
  }
}
