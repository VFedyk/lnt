import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../utils/constants.dart';

abstract class _LanguageDialogConstants {
  static const double infoIconSize = 20.0;
  static const double infoFontSize = 13.0;
}

class LanguageDialog extends StatefulWidget {
  final Language? language;

  const LanguageDialog({super.key, this.language});

  @override
  State<LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<LanguageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late bool _rightToLeft;
  late bool _showRomanization;
  late bool _splitByCharacter;

  @override
  void initState() {
    super.initState();
    final lang = widget.language;
    _nameController = TextEditingController(text: lang?.name ?? '');
    _codeController = TextEditingController(text: lang?.languageCode ?? '');
    _rightToLeft = lang?.rightToLeft ?? false;
    _showRomanization = lang?.showRomanization ?? false;
    _splitByCharacter = lang?.splitByCharacter ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.language == null ? l10n.addLanguage : l10n.editLanguage),
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
                  labelText: l10n.languageNameLabel,
                  hintText: l10n.languageNameHint,
                ),
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
                autofocus: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: l10n.languageCodeLabel,
                  hintText: l10n.languageCodeHint,
                ),
                validator: (v) => v?.trim().isEmpty == true ? l10n.required : null,
              ),
              const SizedBox(height: AppConstants.spacingL),
              SwitchListTile(
                title: Text(l10n.rightToLeftText),
                subtitle: Text(l10n.rightToLeftHint),
                value: _rightToLeft,
                onChanged: (v) => setState(() => _rightToLeft = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(l10n.showRomanization),
                subtitle: Text(l10n.showRomanizationHint),
                value: _showRomanization,
                onChanged: (v) => setState(() => _showRomanization = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(l10n.splitByCharacter),
                subtitle: Text(l10n.splitByCharacterHint),
                value: _splitByCharacter,
                onChanged: (v) => setState(() => _splitByCharacter = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppConstants.spacingS),
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: _LanguageDialogConstants.infoIconSize,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        l10n.addDictionariesAfterCreating,
                        style: TextStyle(
                          fontSize: _LanguageDialogConstants.infoFontSize,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
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
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final lang = Language(
                id: widget.language?.id,
                name: _nameController.text.trim(),
                languageCode: _codeController.text.trim().toLowerCase(),
                rightToLeft: _rightToLeft,
                showRomanization: _showRomanization,
                splitByCharacter: _splitByCharacter,
              );
              Navigator.pop(context, lang);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
