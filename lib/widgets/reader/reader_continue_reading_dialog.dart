import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class ReaderContinueReadingDialog extends StatelessWidget {
  final AppLocalizations l10n;
  final String nextTitle;

  const ReaderContinueReadingDialog({
    super.key,
    required this.l10n,
    required this.nextTitle,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.continueReading),
      content: Text(l10n.continueReadingPrompt(nextTitle)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.no),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.yes),
        ),
      ],
    );
  }
}
