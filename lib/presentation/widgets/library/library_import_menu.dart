import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

enum LibraryImportAction { url, txt, epub }

class LibraryImportMenu extends StatelessWidget {
  final AppLocalizations l10n;
  final ValueChanged<LibraryImportAction> onSelected;

  const LibraryImportMenu({
    super.key,
    required this.l10n,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LibraryImportAction>(
      icon: const Icon(Icons.file_upload),
      tooltip: l10n.import,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: LibraryImportAction.url,
          child: Row(
            children: [
              const Icon(Icons.link),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importFromUrl),
            ],
          ),
        ),
        PopupMenuItem(
          value: LibraryImportAction.txt,
          child: Row(
            children: [
              const Icon(Icons.text_snippet),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importTxt),
            ],
          ),
        ),
        PopupMenuItem(
          value: LibraryImportAction.epub,
          child: Row(
            children: [
              const Icon(Icons.book),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importEpub),
            ],
          ),
        ),
      ],
    );
  }
}
