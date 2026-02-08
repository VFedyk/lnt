import 'dart:io';
import 'dart:typed_data';
import 'package:epub_pro/epub_pro.dart';
import 'package:path_provider/path_provider.dart';
import '../models/text_document.dart';
import '../models/collection.dart';
import '../utils/cover_image_helper.dart';
import '../service_locator.dart';

/// Result of an EPUB import operation
class EpubImportResult {
  final int collectionId;
  final String bookTitle;
  final String? author;
  final String? coverImagePath;
  final int totalChapters;
  final int totalParts;
  final int totalCharacters;
  final List<String> warnings;

  EpubImportResult({
    required this.collectionId,
    required this.bookTitle,
    this.author,
    this.coverImagePath,
    required this.totalChapters,
    required this.totalParts,
    required this.totalCharacters,
    required this.warnings,
  });
}

/// Represents a processed chapter (or part of a chapter if split)
class ProcessedChapter {
  final String title;
  final String content;
  final int originalIndex;
  final int partNumber;
  final int totalParts;

  ProcessedChapter({
    required this.title,
    required this.content,
    required this.originalIndex,
    required this.partNumber,
    required this.totalParts,
  });
}

/// Service for importing EPUB files into the application
class EpubImportService {
  static const int maxChapterLength = 3000;

  /// Import an EPUB file and create a collection with chapter documents
  Future<EpubImportResult> importEpub({
    required Uint8List epubBytes,
    required int languageId,
    int? parentCollectionId,
  }) async {
    // Parse the EPUB file
    final EpubBook epubBook;
    try {
      epubBook = await EpubReader.readBook(epubBytes);
    } catch (e) {
      throw EpubImportException('Failed to parse EPUB file: $e');
    }

    final title = epubBook.title ?? 'Unknown Title';
    final author = epubBook.author;
    final warnings = <String>[];

    // Create collection for the book
    final collection = Collection(
      languageId: languageId,
      name: title,
      description: author != null ? 'By $author' : '',
      parentId: parentCollectionId,
    );

    final collectionId = await db.createCollection(collection);

    // Extract and save cover image
    final coverImagePath = await _extractCoverImage(epubBook, collectionId);
    if (coverImagePath != null) {
      // Update collection with cover image
      final updatedCollection = collection.copyWith(
        id: collectionId,
        coverImage: coverImagePath,
      );
      await db.updateCollection(updatedCollection);
    }

    try {
      // Process chapters
      final chapters = epubBook.chapters;
      if (chapters.isEmpty) {
        warnings.add('No chapters found in EPUB');
        return EpubImportResult(
          collectionId: collectionId,
          bookTitle: title,
          author: author,
          coverImagePath: coverImagePath,
          totalChapters: 0,
          totalParts: 0,
          totalCharacters: 0,
          warnings: warnings,
        );
      }

      int sortOrder = 0;
      int totalChapters = 0;
      int totalParts = 0;
      int totalCharacters = 0;
      final textsToCreate = <TextDocument>[];

      // Process each chapter (including nested subchapters)
      final sortOrderRef = _SortOrderRef(sortOrder);
      final chaptersRef = _CounterRef(totalChapters);
      final partsRef = _CounterRef(totalParts);
      final charsRef = _CounterRef(totalCharacters);

      await _processChaptersRecursively(
        chapters: chapters,
        languageId: languageId,
        collectionId: collectionId,
        sourceUri: 'epub://$title',
        coverImagePath: coverImagePath,
        textsToCreate: textsToCreate,
        sortOrderRef: sortOrderRef,
        totalChaptersRef: chaptersRef,
        totalPartsRef: partsRef,
        totalCharactersRef: charsRef,
        warnings: warnings,
      );

      // Batch insert all texts
      if (textsToCreate.isNotEmpty) {
        await db.batchCreateTexts(textsToCreate);
      }

      return EpubImportResult(
        collectionId: collectionId,
        bookTitle: title,
        author: author,
        coverImagePath: coverImagePath,
        totalChapters: chaptersRef.value,
        totalParts: partsRef.value,
        totalCharacters: charsRef.value,
        warnings: warnings,
      );
    } catch (e) {
      // If import fails, delete the created collection
      await db.deleteCollection(collectionId);
      rethrow;
    }
  }

  /// Extract and save cover image from EPUB
  Future<String?> _extractCoverImage(EpubBook epubBook, int collectionId) async {
    try {
      // Try to find cover image in EPUB content
      final content = epubBook.content;
      if (content == null || content.images.isEmpty) {
        return null;
      }

      final images = content.images;
      EpubByteContentFile? coverFile;

      // Look for common cover image patterns in filenames
      for (final key in images.keys) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('cover') ||
            lowerKey.contains('title') ||
            lowerKey.contains('front')) {
          coverFile = images[key];
          break;
        }
      }

      // If still not found, just take the first image
      coverFile ??= images.values.first;

      if (coverFile.content == null) {
        return null;
      }

      // Determine file extension from filename
      String extension = 'jpg';
      final fileName = coverFile.fileName?.toLowerCase() ?? '';

      if (fileName.endsWith('.png')) {
        extension = 'png';
      } else if (fileName.endsWith('.gif')) {
        extension = 'gif';
      } else if (fileName.endsWith('.webp')) {
        extension = 'webp';
      } else if (fileName.endsWith('.jpeg')) {
        extension = 'jpeg';
      }

      // Save to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = Directory('${appDir.path}/covers');
      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }

      final coverPath = '${coverDir.path}/cover_$collectionId.$extension';
      final file = File(coverPath);
      await file.writeAsBytes(coverFile.content!);

      return CoverImageHelper.toRelative(coverPath);
    } catch (e) {
      // Cover extraction failed, but don't fail the whole import
      return null;
    }
  }

  Future<void> _processChaptersRecursively({
    required List<EpubChapter> chapters,
    required int languageId,
    required int collectionId,
    required String sourceUri,
    String? coverImagePath,
    required List<TextDocument> textsToCreate,
    required _SortOrderRef sortOrderRef,
    required _CounterRef totalChaptersRef,
    required _CounterRef totalPartsRef,
    required _CounterRef totalCharactersRef,
    required List<String> warnings,
    String titlePrefix = '',
  }) async {
    for (final chapter in chapters) {
      final chapterTitle = chapter.title ?? 'Chapter ${totalChaptersRef.value + 1}';
      final fullTitle = titlePrefix.isNotEmpty
          ? '$titlePrefix - $chapterTitle'
          : chapterTitle;

      // Extract text content from HTML
      final htmlContent = chapter.htmlContent ?? '';
      final plainText = _htmlToPlainText(htmlContent);

      if (plainText.trim().isNotEmpty) {
        totalChaptersRef.value++;

        // Process and potentially split the chapter
        final parts = _processChapter(
          title: fullTitle,
          content: plainText,
          chapterIndex: totalChaptersRef.value - 1,
        );

        if (parts.length > 1) {
          warnings.add('"$chapterTitle" was split into ${parts.length} parts');
        }

        for (final part in parts) {
          textsToCreate.add(TextDocument(
            languageId: languageId,
            collectionId: collectionId,
            title: part.title,
            content: part.content,
            sourceUri: sourceUri,
            sortOrder: sortOrderRef.value++,
            coverImage: coverImagePath,
          ));
          totalPartsRef.value++;
          totalCharactersRef.value += part.content.length;
        }
      } else if (htmlContent.isNotEmpty) {
        warnings.add('"$chapterTitle" has no text content (may contain only images)');
      }

      // Process subchapters recursively
      if (chapter.subChapters.isNotEmpty) {
        await _processChaptersRecursively(
          chapters: chapter.subChapters,
          languageId: languageId,
          collectionId: collectionId,
          sourceUri: sourceUri,
          coverImagePath: coverImagePath,
          textsToCreate: textsToCreate,
          sortOrderRef: sortOrderRef,
          totalChaptersRef: totalChaptersRef,
          totalPartsRef: totalPartsRef,
          totalCharactersRef: totalCharactersRef,
          warnings: warnings,
          titlePrefix: chapterTitle,
        );
      }
    }
  }

  /// Process a chapter and split if necessary
  List<ProcessedChapter> _processChapter({
    required String title,
    required String content,
    required int chapterIndex,
  }) {
    final cleanContent = _cleanContent(content);

    if (cleanContent.length <= maxChapterLength) {
      return [
        ProcessedChapter(
          title: title,
          content: cleanContent,
          originalIndex: chapterIndex,
          partNumber: 0,
          totalParts: 1,
        ),
      ];
    }

    // Content exceeds limit - split at sentence boundaries
    final parts = <ProcessedChapter>[];
    String remaining = cleanContent;
    int partNum = 1;

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxChapterLength) {
        parts.add(ProcessedChapter(
          title: '$title (Part $partNum)',
          content: remaining,
          originalIndex: chapterIndex,
          partNumber: partNum,
          totalParts: parts.length + 1,
        ));
        break;
      }

      // Find split point near maxChapterLength but at sentence end
      final splitPoint = _findSplitPoint(remaining, maxChapterLength);

      parts.add(ProcessedChapter(
        title: '$title (Part $partNum)',
        content: remaining.substring(0, splitPoint).trim(),
        originalIndex: chapterIndex,
        partNumber: partNum,
        totalParts: -1, // Will be updated
      ));

      remaining = remaining.substring(splitPoint).trim();
      partNum++;
    }

    // Update totalParts for all parts
    return parts
        .map((p) => ProcessedChapter(
              title: p.title,
              content: p.content,
              originalIndex: p.originalIndex,
              partNumber: p.partNumber,
              totalParts: parts.length,
            ))
        .toList();
  }

  /// Find a safe split point at a sentence boundary
  int _findSplitPoint(String text, int targetPosition) {
    // Sentence-ending punctuation patterns (includes smart quotes)
    final sentenceEnders = RegExp('[.!?]["\u2018\u2019\u201C\u201D]?\\s');

    // Search backward from target for sentence end
    final searchArea = text.substring(0, targetPosition);

    // Find all sentence endings in the search area
    final matches = sentenceEnders.allMatches(searchArea).toList();

    if (matches.isNotEmpty) {
      // Use the last sentence ending before target
      return matches.last.end;
    }

    // Fallback: look for paragraph break
    final lastParagraph = searchArea.lastIndexOf('\n\n');
    if (lastParagraph > targetPosition * 0.5) {
      return lastParagraph + 2;
    }

    // Fallback: look for any newline
    final lastNewline = searchArea.lastIndexOf('\n');
    if (lastNewline > targetPosition * 0.5) {
      return lastNewline + 1;
    }

    // Last resort: split at space near target
    final lastSpace = searchArea.lastIndexOf(' ');
    return lastSpace > 0 ? lastSpace + 1 : targetPosition;
  }

  /// Convert HTML content to plain text
  String _htmlToPlainText(String html) {
    if (html.isEmpty) return '';

    var text = html;

    // Remove script and style tags with content
    text = text.replaceAll(
      RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true),
      '',
    );

    // Convert block elements to newlines
    text = text.replaceAll(
      RegExp(r'</(p|div|h[1-6]|li|tr)>', caseSensitive: false),
      '\n',
    );
    text = text.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );

    // Add space after certain inline elements
    text = text.replaceAll(
      RegExp(r'</(td|th)>', caseSensitive: false),
      ' ',
    );

    // Remove all remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode HTML entities
    text = _decodeHtmlEntities(text);

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n[ \t]+'), '\n');
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  /// Decode common HTML entities
  String _decodeHtmlEntities(String text) {
    const entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&#39;': "'",
      '&mdash;': '—',
      '&ndash;': '–',
      '&hellip;': '…',
      '&ldquo;': '\u201C',
      '&rdquo;': '\u201D',
      '&lsquo;': '\u2018',
      '&rsquo;': '\u2019',
      '&copy;': '\u00A9',
      '&reg;': '\u00AE',
      '&trade;': '\u2122',
      '&deg;': '\u00B0',
      '&plusmn;': '\u00B1',
      '&times;': '\u00D7',
      '&divide;': '\u00F7',
      '&euro;': '\u20AC',
      '&pound;': '\u00A3',
      '&yen;': '\u00A5',
      '&cent;': '\u00A2',
    };

    var result = text;
    entities.forEach((entity, char) {
      result = result.replaceAll(entity, char);
    });

    // Handle numeric entities like &#123; and &#x7B;
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        final code = int.tryParse(m.group(1)!);
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) {
        final code = int.tryParse(m.group(1)!, radix: 16);
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      },
    );

    return result;
  }

  /// Clean and normalize content
  String _cleanContent(String content) {
    var text = content;

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }
}

/// Helper class for mutable sort order reference
class _SortOrderRef {
  int value;
  _SortOrderRef(this.value);
}

/// Helper class for mutable counter reference
class _CounterRef {
  int value;
  _CounterRef(this.value);
}

/// Exception thrown when EPUB import fails
class EpubImportException implements Exception {
  final String message;
  EpubImportException(this.message);

  @override
  String toString() => message;
}
