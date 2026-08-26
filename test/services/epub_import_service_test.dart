import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:language_nerd_tools/data/datasources/database_service.dart';
import 'package:language_nerd_tools/data/notifiers/data_change_notifier.dart';
import 'package:language_nerd_tools/domain/entities/collection.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:language_nerd_tools/domain/repositories/collection_repository.dart';
import 'package:language_nerd_tools/domain/repositories/text_repository.dart';
import 'package:language_nerd_tools/services/epub_import_service.dart';
import 'package:language_nerd_tools/utils/cover_image_helper.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

class MockCollectionRepository extends Mock implements CollectionRepository {}

class MockTextRepository extends Mock implements TextRepository {}

class _FakeCollection extends Fake implements Collection {}

class _FakeTextDocumentList extends Fake implements List<TextDocument> {}

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String path;
  _FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Builds minimal, valid EPUB bytes with a single short chapter (and,
/// optionally, a cover image file so `_extractCoverImage` has something to find).
Uint8List _buildMinimalEpub({bool withCoverImage = false}) {
  final archive = Archive();

  final containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
  archive.addFile(ArchiveFile(
      'META-INF/container.xml', containerXml.length, containerXml.codeUnits));

  final manifestImage = withCoverImage
      ? '<item id="cover-image" href="cover.jpg" media-type="image/jpeg"/>'
      : '';

  final contentOpf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">test-book</dc:identifier>
    <dc:title>Test Book</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="chapter1" href="chapter1.html" media-type="application/xhtml+xml"/>
    $manifestImage
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
  </spine>
</package>''';
  archive.addFile(
      ArchiveFile('OEBPS/content.opf', contentOpf.length, contentOpf.codeUnits));

  final tocNcx = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="test-book"/></head>
  <docTitle><text>Test Book</text></docTitle>
  <navMap>
    <navPoint id="chapter1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.html"/>
    </navPoint>
  </navMap>
</ncx>''';
  archive.addFile(ArchiveFile('OEBPS/toc.ncx', tocNcx.length, tocNcx.codeUnits));

  final chapterHtml = '''<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body><h1>Chapter 1</h1><p>Hello world, this is a short test chapter.</p></body>
</html>''';
  archive.addFile(
      ArchiveFile('OEBPS/chapter1.html', chapterHtml.length, chapterHtml.codeUnits));

  if (withCoverImage) {
    final coverBytes = List<int>.filled(16, 1);
    archive.addFile(ArchiveFile('OEBPS/cover.jpg', coverBytes.length, coverBytes));
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  late EpubImportService service;

  setUp(() {
    service = EpubImportService();
  });

  group('importEpub — isContinuous', () {
    final sl = GetIt.instance;
    late MockDatabaseService mockDb;
    late MockCollectionRepository mockCollections;
    late MockTextRepository mockTexts;

    setUpAll(() {
      registerFallbackValue(_FakeCollection());
      registerFallbackValue(_FakeTextDocumentList());
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        Directory.systemTemp.createTempSync('lnt_epub_test').path,
      );
    });

    setUp(() async {
      await sl.reset();
      await CoverImageHelper.initialize();

      mockDb = MockDatabaseService();
      mockCollections = MockCollectionRepository();
      mockTexts = MockTextRepository();

      when(() => mockDb.collections).thenReturn(mockCollections);
      when(() => mockDb.texts).thenReturn(mockTexts);
      when(() => mockCollections.create(any())).thenAnswer((_) async => 'collection-1');
      when(() => mockCollections.update(any())).thenAnswer((_) async => 1);
      when(() => mockTexts.batchCreate(any())).thenAnswer((_) async {});

      sl.registerSingleton<DataChangeNotifier>(DataChangeNotifier());
      sl.registerSingleton<DatabaseService>(mockDb);
    });

    tearDown(() async {
      await sl.reset();
    });

    test('the created collection is marked as a book', () async {
      final epubBytes = _buildMinimalEpub();

      await service.importEpub(epubBytes: epubBytes, languageId: 'lang-1');

      final created = verify(() => mockCollections.create(captureAny()))
          .captured
          .single as Collection;
      expect(created.isContinuous, isTrue);
    });

    test('isContinuous survives the cover-image copyWith/update round trip', () async {
      final epubBytes = _buildMinimalEpub(withCoverImage: true);

      await service.importEpub(epubBytes: epubBytes, languageId: 'lang-1');

      final created = verify(() => mockCollections.create(captureAny()))
          .captured
          .single as Collection;
      expect(created.isContinuous, isTrue);

      final updated = verify(() => mockCollections.update(captureAny()))
          .captured
          .single as Collection;
      expect(updated.coverImage, isNotNull);
      expect(updated.isContinuous, isTrue);
    });
  });

  group('htmlToPlainText', () {
    test('strips basic HTML tags', () {
      expect(
        service.htmlToPlainText('<p>Hello <b>world</b></p>'),
        'Hello world',
      );
    });

    test('converts block elements to newlines', () {
      final result = service.htmlToPlainText('<p>First</p><p>Second</p>');
      expect(result, contains('First'));
      expect(result, contains('Second'));
      expect(result, contains('\n'));
    });

    test('converts br to newline', () {
      expect(service.htmlToPlainText('Hello<br>World'), 'Hello\nWorld');
      expect(service.htmlToPlainText('Hello<br/>World'), 'Hello\nWorld');
      expect(service.htmlToPlainText('Hello<br />World'), 'Hello\nWorld');
    });

    test('removes script tags and content', () {
      final result = service.htmlToPlainText(
        '<p>Text</p><script>alert("x")</script><p>More</p>',
      );
      expect(result, isNot(contains('alert')));
      expect(result, contains('Text'));
      expect(result, contains('More'));
    });

    test('removes style tags and content', () {
      final result = service.htmlToPlainText(
        '<style>.foo { color: red; }</style><p>Content</p>',
      );
      expect(result, isNot(contains('color')));
      expect(result, 'Content');
    });

    test('returns empty for empty input', () {
      expect(service.htmlToPlainText(''), '');
    });

    test('decodes HTML entities', () {
      expect(
        service.htmlToPlainText('<p>Tom &amp; Jerry</p>'),
        'Tom & Jerry',
      );
    });
  });

  group('decodeHtmlEntities', () {
    test('decodes named entities', () {
      expect(service.decodeHtmlEntities('&amp;'), '&');
      expect(service.decodeHtmlEntities('&lt;'), '<');
      expect(service.decodeHtmlEntities('&gt;'), '>');
      expect(service.decodeHtmlEntities('&quot;'), '"');
      expect(service.decodeHtmlEntities('&nbsp;'), ' ');
      expect(service.decodeHtmlEntities('&mdash;'), '—');
    });

    test('decodes numeric entities', () {
      expect(service.decodeHtmlEntities('&#65;'), 'A');
      expect(service.decodeHtmlEntities('&#123;'), '{');
    });

    test('decodes hex entities', () {
      expect(service.decodeHtmlEntities('&#x41;'), 'A');
      expect(service.decodeHtmlEntities('&#x7B;'), '{');
    });

    test('preserves text without entities', () {
      expect(service.decodeHtmlEntities('Hello world'), 'Hello world');
    });

    test('handles multiple entities in one string', () {
      expect(
        service.decodeHtmlEntities('A &amp; B &lt; C'),
        'A & B < C',
      );
    });
  });

  group('processChapter', () {
    test('returns single part for short content', () {
      final parts = service.processChapter(
        title: 'Chapter 1',
        content: 'Short chapter content.',
        chapterIndex: 0,
      );
      expect(parts, hasLength(1));
      expect(parts[0].title, 'Chapter 1');
      expect(parts[0].partNumber, 0);
      expect(parts[0].totalParts, 1);
    });

    test('splits long content into multiple parts', () {
      final longContent =
          List.generate(200, (i) => 'This is sentence number $i. ').join();

      final parts = service.processChapter(
        title: 'Long Chapter',
        content: longContent,
        chapterIndex: 0,
      );

      expect(parts.length, greaterThan(1));
      for (final part in parts) {
        expect(part.title, startsWith('Long Chapter (Part'));
        expect(part.totalParts, parts.length);
      }
    });

    test('split parts do not exceed max length significantly', () {
      final longContent =
          List.generate(200, (i) => 'Sentence $i is here. ').join();

      final parts = service.processChapter(
        title: 'Test',
        content: longContent,
        chapterIndex: 0,
      );

      for (final part in parts) {
        expect(
          part.content.length,
          lessThan(EpubImportService.maxChapterLength + 100),
        );
      }
    });
  });

  group('findSplitPoint', () {
    test('splits at sentence boundary', () {
      const text =
          'First sentence. Second sentence. Third sentence. Fourth.';
      final point = service.findSplitPoint(text, 35);
      // Should split after "Second sentence. "
      expect(text.substring(0, point).trim(), endsWith('.'));
    });

    test('falls back to paragraph break', () {
      final text = '${'A' * 20}\n\n${'B' * 20}';
      final point = service.findSplitPoint(text, 30);
      expect(point, 22); // after \n\n
    });

    test('falls back to space as last resort', () {
      final text = 'word ' * 20; // no sentence enders, no newlines
      final point = service.findSplitPoint(text, 30);
      expect(text[point - 1], ' ');
    });
  });

  group('cleanContent', () {
    test('normalizes multiple spaces to one', () {
      expect(service.cleanContent('hello   world'), 'hello world');
    });

    test('collapses excessive newlines', () {
      expect(service.cleanContent('a\n\n\n\nb'), 'a\n\nb');
    });

    test('trims leading and trailing whitespace', () {
      expect(service.cleanContent('  hello  '), 'hello');
    });
  });
}
