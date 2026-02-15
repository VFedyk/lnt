import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class ReaderMarkAllKnownDialog extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onConfirm;

  const ReaderMarkAllKnownDialog({
    super.key,
    required this.l10n,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.markAllKnownQuestion),
      content: Text(l10n.markAllKnownConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: onConfirm, child: Text(l10n.markAll)),
      ],
    );
  }
}
