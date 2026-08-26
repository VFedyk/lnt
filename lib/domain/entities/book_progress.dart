/// Aggregate reading progress for one continuous collection ("book").
///
/// Weighted by text length rather than chapter count, so a long chapter moves
/// the bar further than a short foreword. Built entirely in SQL — `content` is
/// never materialised in Dart (books are large).
class BookProgress {
  final String collectionId;
  final String name;
  final String? coverImage; // relative path, resolve via CoverImageHelper
  final int totalLength; // Σ LENGTH(content) over all texts, always > 0
  final int readLength; // Σ LENGTH(content) over finished texts
  final int totalTexts;
  final int finishedTexts;
  final DateTime lastRead; // MAX(texts.last_read)

  const BookProgress({
    required this.collectionId,
    required this.name,
    this.coverImage,
    required this.totalLength,
    required this.readLength,
    required this.totalTexts,
    required this.finishedTexts,
    required this.lastRead,
  });

  /// 0.0 – 1.0. `totalLength` is guaranteed non-zero by the query's HAVING clause.
  double get fraction => readLength / totalLength;

  /// Rounded percentage — a book at 99.6% renders "100%" while still appearing
  /// in the widget. Completion is decided by [isComplete] / the SQL `HAVING`,
  /// never by this rounded value.
  int get percent => (fraction * 100).round();

  bool get isComplete => readLength >= totalLength;

  factory BookProgress.fromMap(Map<String, dynamic> map) {
    return BookProgress(
      collectionId: map['collection_id'] as String,
      name: map['name'] as String,
      coverImage: map['cover_image'] as String?,
      totalLength: map['total_length'] as int,
      readLength: map['read_length'] as int? ?? 0,
      totalTexts: map['total_texts'] as int,
      finishedTexts: map['finished_texts'] as int? ?? 0,
      lastRead: DateTime.parse(map['last_read'] as String),
    );
  }
}
