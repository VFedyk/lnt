import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/services/epub_import_service.dart';

void main() {
  late EpubImportService service;

  setUp(() {
    service = EpubImportService();
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
