import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/collection.dart';
import '../../models/text_document.dart';
import '../../utils/constants.dart';
import '../book_cover.dart';

abstract class _LibraryGridContentConstants {
  static const double maxCrossAxisExtent = 140.0;
  static const double childAspectRatio = 0.45;
  static const double draggingOpacity = 0.4;
  static const double feedbackOpacity = 0.85;
  static const double feedbackWidth = 100.0;
  static const double parentZoneHeight = 40.0;
  static const double parentZoneBorderWidth = 2.0;
}

class LibraryGridContent extends StatelessWidget {
  final AppLocalizations l10n;
  final List<Collection> collections;
  final List<TextDocument> texts;
  final Map<int, int> unknownCounts;
  final bool isInsideCollection;
  final ValueChanged<Collection> onOpenCollection;
  final ValueChanged<Collection> onShowCollectionOptions;
  final ValueChanged<TextDocument> onOpenText;
  final ValueChanged<TextDocument> onShowTextOptions;
  // target=null → drop on parent zone; target=Collection → drop into folder
  final void Function(Object item, Collection? target) onDrop;

  const LibraryGridContent({
    super.key,
    required this.l10n,
    required this.collections,
    required this.texts,
    required this.unknownCounts,
    required this.isInsideCollection,
    required this.onOpenCollection,
    required this.onShowCollectionOptions,
    required this.onOpenText,
    required this.onShowTextOptions,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_GridItem>[
      ...collections.map((c) => _GridItem(collection: c)),
      ...texts.map((t) => _GridItem(text: t)),
    ];

    return Column(
      children: [
        if (isInsideCollection)
          _ParentDropZone(l10n: l10n, onDrop: onDrop),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent:
                  _LibraryGridContentConstants.maxCrossAxisExtent,
              childAspectRatio: _LibraryGridContentConstants.childAspectRatio,
              crossAxisSpacing: AppConstants.spacingL,
              mainAxisSpacing: AppConstants.spacingL,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              if (item.collection != null) {
                final collection = item.collection!;
                final cover = BookCover(
                  title: collection.name,
                  subtitle: collection.description.isNotEmpty
                      ? collection.description
                      : null,
                  imagePath: collection.coverImage,
                  isFolder: true,
                  onTap: () => onOpenCollection(collection),
                  onLongPress: () => onShowCollectionOptions(collection),
                );

                final feedback = Opacity(
                  opacity: _LibraryGridContentConstants.feedbackOpacity,
                  child: SizedBox(
                    width: _LibraryGridContentConstants.feedbackWidth,
                    child: BookCover(
                      title: collection.name,
                      imagePath: collection.coverImage,
                      isFolder: true,
                    ),
                  ),
                );

                return DragTarget<Object>(
                  onWillAcceptWithDetails: (details) =>
                      details.data != collection,
                  onAcceptWithDetails: (details) =>
                      onDrop(details.data, collection),
                  builder: (context, candidateItems, _) {
                    final isHovering = candidateItems.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: isHovering
                          ? BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: _LibraryGridContentConstants
                                    .parentZoneBorderWidth,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppConstants.spacingS + 4,
                              ),
                            )
                          : null,
                      child: Draggable<Object>(
                        data: collection,
                        feedback: feedback,
                        childWhenDragging: Opacity(
                          opacity:
                              _LibraryGridContentConstants.draggingOpacity,
                          child: cover,
                        ),
                        child: cover,
                      ),
                    );
                  },
                );
              }

              final text = item.text!;
              final unknownCount = unknownCounts[text.id] ?? 0;
              final unknownLabel = l10n.unknownCount(unknownCount);

              final cover = BookCover(
                title: text.title,
                subtitle: text.status == TextStatus.finished
                    ? l10n.completed
                    : unknownLabel,
                imagePath: text.coverImage,
                isCompleted: text.status == TextStatus.finished,
                onTap: () => onOpenText(text),
                onLongPress: () => onShowTextOptions(text),
              );

              final feedback = Opacity(
                opacity: _LibraryGridContentConstants.feedbackOpacity,
                child: SizedBox(
                  width: _LibraryGridContentConstants.feedbackWidth,
                  child: BookCover(
                    title: text.title,
                    imagePath: text.coverImage,
                    isCompleted: text.status == TextStatus.finished,
                  ),
                ),
              );

              return Draggable<Object>(
                data: text,
                feedback: feedback,
                childWhenDragging: Opacity(
                  opacity: _LibraryGridContentConstants.draggingOpacity,
                  child: cover,
                ),
                child: cover,
              );
            },
          ),
        ),
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
          height: _LibraryGridContentConstants.parentZoneHeight,
          margin: const EdgeInsets.fromLTRB(
            AppConstants.spacingL,
            AppConstants.spacingS,
            AppConstants.spacingL,
            0,
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
                  ? _LibraryGridContentConstants.parentZoneBorderWidth
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

class _GridItem {
  final Collection? collection;
  final TextDocument? text;

  _GridItem({this.collection, this.text});
}
