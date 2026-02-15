import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/language.dart';

class ReaderLanguagePickerDialog extends StatelessWidget {
  final AppLocalizations l10n;
  final List<Language> languages;

  const ReaderLanguagePickerDialog({
    super.key,
    required this.l10n,
    required this.languages,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.assignForeignLanguage),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages
            .map(
              (lang) => ListTile(
                leading: const Icon(Icons.language),
                title: Text(lang.name),
                onTap: () => Navigator.pop(context, lang),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
