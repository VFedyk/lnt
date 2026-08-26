import 'package:flutter/material.dart';

import '../../../domain/entities/book_progress.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';
import 'cover_thumbnail.dart';

class BookProgressCard extends StatelessWidget {
  final List<BookProgress> books;
  final ValueChanged<BookProgress> onOpenBook;

  const BookProgressCard({super.key, required this.books, required this.onOpenBook});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.readingProgress, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacingM),
            if (books.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Text(l10n.noBooksInProgress),
              )
            else
              ...books.map(
                (book) => _BookListTile(book: book, l10n: l10n, onTap: () => onOpenBook(book)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookListTile extends StatelessWidget {
  final BookProgress book;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _BookListTile({required this.book, required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CoverThumbnail(coverImage: book.coverImage, fallbackIcon: Icons.menu_book),
      title: Text(book.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.bookProgressChapters(book.finishedTexts, book.totalTexts),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: book.fraction,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
        ],
      ),
      trailing: Text(
        '${book.percent}%',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      onTap: onTap,
    );
  }
}
