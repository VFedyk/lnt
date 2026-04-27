import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/dictionary.dart';

class ReaderDictionaryPickerDialog extends StatelessWidget {
  final AppLocalizations l10n;
  final String selectedWords;
  final List<Dictionary> dictionaries;

  const ReaderDictionaryPickerDialog({
    super.key,
    required this.l10n,
    required this.selectedWords,
    required this.dictionaries,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.lookupWord(selectedWords)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: dictionaries
            .map(
              (dict) => ListTile(
                leading: const Icon(Icons.book),
                title: Text(dict.name),
                onTap: () => Navigator.pop(context, dict),
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
