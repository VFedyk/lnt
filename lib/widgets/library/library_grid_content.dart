import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/collection.dart';
import '../../models/text_document.dart';
import '../../utils/constants.dart';
import '../book_cover.dart';

abstract class _LibraryGridContentConstants {
  static const double maxCrossAxisExtent = 140.0;
  static const double childAspectRatio = 0.45;
}

class LibraryGridContent extends StatelessWidget {
  final AppLocalizations l10n;
  final List<Collection> collections;
  final List<TextDocument> texts;
  final Map<int, int> unknownCounts;
  final ValueChanged<Collection> onOpenCollection;
  final ValueChanged<Collection> onShowCollectionOptions;
  final ValueChanged<TextDocument> onOpenText;
  final ValueChanged<TextDocument> onShowTextOptions;

  const LibraryGridContent({
    super.key,
    required this.l10n,
    required this.collections,
    required this.texts,
    required this.unknownCounts,
    required this.onOpenCollection,
    required this.onShowCollectionOptions,
    required this.onOpenText,
    required this.onShowTextOptions,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_GridItem>[
      ...collections.map((c) => _GridItem(collection: c)),
      ...texts.map((t) => _GridItem(text: t)),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _LibraryGridContentConstants.maxCrossAxisExtent,
        childAspectRatio: _LibraryGridContentConstants.childAspectRatio,
        crossAxisSpacing: AppConstants.spacingL,
        mainAxisSpacing: AppConstants.spacingL,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item.collection != null) {
          final collection = item.collection!;
          return BookCover(
            title: collection.name,
            subtitle: collection.description.isNotEmpty
                ? collection.description
                : null,
            imagePath: collection.coverImage,
            isFolder: true,
            onTap: () => onOpenCollection(collection),
            onLongPress: () => onShowCollectionOptions(collection),
          );
        }

        final text = item.text!;
        final unknownCount = unknownCounts[text.id] ?? 0;
        final unknownLabel = l10n.unknownCount(unknownCount);

        return BookCover(
          title: text.title,
          subtitle: text.status == TextStatus.finished
              ? l10n.completed
              : unknownLabel,
          imagePath: text.coverImage,
          isCompleted: text.status == TextStatus.finished,
          onTap: () => onOpenText(text),
          onLongPress: () => onShowTextOptions(text),
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
