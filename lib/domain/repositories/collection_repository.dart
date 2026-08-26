import '../entities/book_progress.dart';
import '../entities/collection.dart';
import '../entities/text_document.dart';

abstract class CollectionRepository {
  Future<String> create(Collection collection);
  Future<List<Collection>> getAll({String? languageId, String? parentId});
  Future<Collection?> getById(String id);
  Future<int> update(Collection collection);
  Future<void> move(String collectionId, String? parentId);
  Future<int> delete(String id);

  /// Reading progress for the language's continuous collections.
  ///
  /// [excludeCompleted] drops fully-read books (dashboard "currently reading" list);
  /// [limit] caps the result. Ordered by most recently read first.
  Future<List<BookProgress>> getBookProgress(
    String languageId, {
    int? limit,
    bool excludeCompleted = false,
  });

  /// The first text in [collectionId] that is not finished, in reading order.
  /// Falls back to the first text when every chapter is finished.
  /// Returns null for an empty collection.
  Future<TextDocument?> getNextUnfinishedText(String collectionId);
}
