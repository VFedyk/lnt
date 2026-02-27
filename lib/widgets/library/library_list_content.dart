import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/collection.dart';
import '../../models/language.dart';
import '../../models/text_document.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

abstract class _LibraryListContentConstants {
  static const double finishedBackgroundAlpha = 0.2;
  static const double draggingOpacity = 0.4;
  static const double feedbackOpacity = 0.85;
  static const double feedbackElevation = 8.0;
  static const double feedbackWidth = 280.0;
  static const double parentZoneHeight = 40.0;
  static const double parentZoneBorderWidth = 2.0;
}

class LibraryListContent extends StatelessWidget {
  final Language language;
  final AppLocalizations l10n;
  final List<Collection> collections;
  final List<TextDocument> texts;
  final Map<int, int> unknownCounts;
  final bool isInsideCollection;
  final ValueChanged<Collection> onOpenCollection;
  final ValueChanged<Collection> onEditCollection;
  final ValueChanged<Collection> onDeleteCollection;
  final ValueChanged<TextDocument> onOpenText;
  final ValueChanged<TextDocument> onSetCover;
  final ValueChanged<TextDocument> onEditText;
  final ValueChanged<TextDocument> onDeleteText;
  // target=null → drop on parent zone; target=Collection → drop into folder
  final void Function(Object item, Collection? target) onDrop;

  const LibraryListContent({
    super.key,
    required this.language,
    required this.l10n,
    required this.collections,
    required this.texts,
    required this.unknownCounts,
    required this.isInsideCollection,
    required this.onOpenCollection,
    required this.onEditCollection,
    required this.onDeleteCollection,
    required this.onOpenText,
    required this.onSetCover,
    required this.onEditText,
    required this.onDeleteText,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (isInsideCollection)
          _ParentDropZone(l10n: l10n, onDrop: onDrop),
        ...collections.map(
          (collection) => _FolderListItem(
            collection: collection,
            l10n: l10n,
            onOpen: () => onOpenCollection(collection),
            onEdit: () => onEditCollection(collection),
            onDelete: () => onDeleteCollection(collection),
            onDrop: (item) => onDrop(item, collection),
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

          return _TextListItem(
            text: text,
            l10n: l10n,
            totalLabel: totalLabel,
            unknownLabel: unknownLabel,
            unknownCount: unknownCount,
            onOpen: () => onOpenText(text),
            onSetCover: () => onSetCover(text),
            onEdit: () => onEditText(text),
            onDelete: () => onDeleteText(text),
          );
        }),
      ],
    );
  }
}

// ── Parent drop zone ──────────────────────────────────────────────────────────

class _ParentDropZone extends StatelessWidget {
  final AppLocalizations l10n;
  final void Function(Object item, Collection? target) onDrop;

  const _ParentDropZone({required this.l10n, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<Object>(
      onAcceptWithDetails: (details) => onDrop(details.data, null),
      builder: (context, candidateItems, _) {
        final isHovering = candidateItems.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _LibraryListContentConstants.parentZoneHeight,
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingL,
            vertical: AppConstants.spacingXS,
          ),
          decoration: BoxDecoration(
            color: isHovering
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppConstants.spacingS),
            border: Border.all(
              color: isHovering
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isHovering
                  ? _LibraryListContentConstants.parentZoneBorderWidth
                  : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.drive_file_move_outlined,
                size: 16,
                color: isHovering
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                l10n.moveToParentFolder,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: isHovering
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight:
                      isHovering ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Folder list item ──────────────────────────────────────────────────────────

class _FolderListItem extends StatelessWidget {
  final Collection collection;
  final AppLocalizations l10n;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Object> onDrop;

  const _FolderListItem({
    required this.collection,
    required this.l10n,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final card = Card(
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
              onEdit();
            } else if (value == _ListAction.delete) {
              onDelete();
            }
          },
        ),
        onTap: onOpen,
      ),
    );

    // Drag feedback: compact card shown while dragging
    final feedback = Material(
      elevation: _LibraryListContentConstants.feedbackElevation,
      borderRadius: BorderRadius.circular(AppConstants.spacingS),
      child: Opacity(
        opacity: _LibraryListContentConstants.feedbackOpacity,
        child: SizedBox(
          width: _LibraryListContentConstants.feedbackWidth,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.folder)),
            title: Text(
              collection.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => details.data != collection,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidateItems, _) {
        final isHovering = candidateItems.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: isHovering
              ? BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary,
                    width: _LibraryListContentConstants.parentZoneBorderWidth,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppConstants.spacingS + 4),
                )
              : null,
          child: Draggable<Object>(
            data: collection,
            feedback: feedback,
            childWhenDragging: Opacity(
              opacity: _LibraryListContentConstants.draggingOpacity,
              child: card,
            ),
            child: card,
          ),
        );
      },
    );
  }
}

// ── Text list item ────────────────────────────────────────────────────────────

class _TextListItem extends StatelessWidget {
  final TextDocument text;
  final AppLocalizations l10n;
  final String totalLabel;
  final String unknownLabel;
  final int unknownCount;
  final VoidCallback onOpen;
  final VoidCallback onSetCover;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TextListItem({
    required this.text,
    required this.l10n,
    required this.totalLabel,
    required this.unknownLabel,
    required this.unknownCount,
    required this.onOpen,
    required this.onSetCover,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingXS,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: text.status == TextStatus.finished
              ? context.appColors.success.withValues(
                  alpha: _LibraryListContentConstants.finishedBackgroundAlpha,
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
              onSetCover();
            } else if (value == _ListAction.edit) {
              onEdit();
            } else if (value == _ListAction.delete) {
              onDelete();
            }
          },
        ),
        onTap: onOpen,
      ),
    );

    final feedback = Material(
      elevation: _LibraryListContentConstants.feedbackElevation,
      borderRadius: BorderRadius.circular(AppConstants.spacingS),
      child: Opacity(
        opacity: _LibraryListContentConstants.feedbackOpacity,
        child: SizedBox(
          width: _LibraryListContentConstants.feedbackWidth,
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                text.status == TextStatus.finished
                    ? Icons.check
                    : Icons.article,
              ),
            ),
            title: Text(text.title, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );

    return Draggable<Object>(
      data: text,
      feedback: feedback,
      childWhenDragging: Opacity(
        opacity: _LibraryListContentConstants.draggingOpacity,
        child: card,
      ),
      child: card,
    );
  }
}

enum _ListAction { cover, edit, delete }
