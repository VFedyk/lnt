import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/collection.dart';
import '../../models/language.dart';
import '../../models/text_document.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

class LibraryListContent extends StatelessWidget {
  final Language language;
  final AppLocalizations l10n;
  final List<Collection> collections;
  final List<TextDocument> texts;
  final Map<int, int> unknownCounts;
  final ValueChanged<Collection> onOpenCollection;
  final ValueChanged<Collection> onEditCollection;
  final ValueChanged<Collection> onDeleteCollection;
  final ValueChanged<TextDocument> onOpenText;
  final ValueChanged<TextDocument> onSetCover;
  final ValueChanged<TextDocument> onEditText;
  final ValueChanged<TextDocument> onDeleteText;
  final double finishedBackgroundAlpha;

  const LibraryListContent({
    super.key,
    required this.language,
    required this.l10n,
    required this.collections,
    required this.texts,
    required this.unknownCounts,
    required this.onOpenCollection,
    required this.onEditCollection,
    required this.onDeleteCollection,
    required this.onOpenText,
    required this.onSetCover,
    required this.onEditText,
    required this.onDeleteText,
    required this.finishedBackgroundAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ...collections.map(
          (collection) => Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingXS,
            ),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.folder)),
              title: Tooltip(
                message: collection.name,
                child: Text(collection.name, overflow: TextOverflow.ellipsis),
              ),
              subtitle: collection.description.isNotEmpty
                  ? Text(collection.description)
                  : null,
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ListAction.edit,
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _ListAction.delete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.delete),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == _ListAction.edit) {
                    onEditCollection(collection);
                  } else if (value == _ListAction.delete) {
                    onDeleteCollection(collection);
                  }
                },
              ),
              onTap: () => onOpenCollection(collection),
            ),
          ),
        ),
        ...texts.map((text) {
          final unknownCount = unknownCounts[text.id] ?? 0;
          final totalLabel = language.splitByCharacter
              ? l10n.charactersCount(text.characterCount)
              : l10n.wordsCount(text.wordCount);
          final unknownLabel = language.splitByCharacter
              ? l10n.unknownCharacters(unknownCount)
              : l10n.unknownWords(unknownCount);

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingXS,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: text.status == TextStatus.finished
                    ? context.appColors.success.withValues(
                        alpha: finishedBackgroundAlpha,
                      )
                    : null,
                child: Icon(
                  text.status == TextStatus.finished
                      ? Icons.check
                      : Icons.article,
                  color: text.status == TextStatus.finished
                      ? context.appColors.success
                      : null,
                ),
              ),
              title: Tooltip(
                message: text.title,
                child: Text(text.title, overflow: TextOverflow.ellipsis),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(totalLabel),
                  Text(
                    unknownLabel,
                    style: TextStyle(
                      color: unknownCount > 0
                          ? context.appColors.warning
                          : context.appColors.success,
                      fontSize: AppConstants.fontSizeCaption,
                      fontWeight: unknownCount == 0 ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ListAction.cover,
                    child: Row(
                      children: [
                        const Icon(Icons.image),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.setCover),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _ListAction.edit,
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _ListAction.delete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.delete),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == _ListAction.cover) {
                    onSetCover(text);
                  } else if (value == _ListAction.edit) {
                    onEditText(text);
                  } else if (value == _ListAction.delete) {
                    onDeleteText(text);
                  }
                },
              ),
              onTap: () => onOpenText(text),
            ),
          );
        }),
      ],
    );
  }
}

enum _ListAction { cover, edit, delete }
