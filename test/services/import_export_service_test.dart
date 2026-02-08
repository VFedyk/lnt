import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/models/term.dart';
import 'package:language_nerd_tools/services/import_export_service.dart';

void main() {
  late ImportExportService service;

  setUp(() {
    service = ImportExportService();
  });

  List<Term> sampleTerms() => [
        Term(
          languageId: 1,
          text: 'hola',
          lowerText: 'hola',
          status: 1,
          translation: 'hello',
          romanization: '',
          sentence: 'Hola, mundo!',
        ),
        Term(
          languageId: 1,
          text: 'mundo',
          lowerText: 'mundo',
          status: 3,
          translation: 'world',
          romanization: '',
          sentence: '',
        ),
      ];

  group('exportTermsToCSV', () {
    test('produces correct header and rows', () async {
      final csv = await service.exportTermsToCSV(sampleTerms());
      final lines = csv.split('\r\n');

      expect(lines[0], 'Term,Status,Translation,Romanization,Sentence');
      expect(lines[1], contains('hola'));
      expect(lines[1], contains('hello'));
      expect(lines[2], contains('mundo'));
    });

    test('handles empty term list', () async {
      final csv = await service.exportTermsToCSV([]);
      final lines =
          csv.split('\r\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines, hasLength(1)); // header only
    });
  });

  group('importTermsFromCSV', () {
    test('parses header and data rows', () async {
      const csv = 'Term,Status,Translation,Romanization,Sentence\r\n'
          'hola,1,hello,,Hola mundo\r\n'
          'mundo,3,world,,\r\n';

      final terms = await service.importTermsFromCSV(csv, 1);
      expect(terms, hasLength(2));
      expect(terms[0].text, 'hola');
      expect(terms[0].status, 1);
      expect(terms[0].translation, 'hello');
      expect(terms[1].text, 'mundo');
      expect(terms[1].status, 3);
    });

    test('skips empty rows', () async {
      const csv = 'Term,Status\r\nhola,1\r\n\r\n\r\nmundo,2\r\n';
      final terms = await service.importTermsFromCSV(csv, 1);
      expect(terms, hasLength(2));
    });

    test('handles missing columns with defaults', () async {
      const csv = 'Term\r\nhola\r\n';
      final terms = await service.importTermsFromCSV(csv, 1);
      expect(terms, hasLength(1));
      expect(terms[0].status, 1); // default
      expect(terms[0].translation, '');
    });

    test('sets languageId on all terms', () async {
      const csv = 'Term,Status\r\nhola,1\r\nmundo,2\r\n';
      final terms = await service.importTermsFromCSV(csv, 42);
      for (final term in terms) {
        expect(term.languageId, 42);
      }
    });
  });

  group('CSV round-trip', () {
    test('export then import preserves data', () async {
      final original = sampleTerms();
      final csv = await service.exportTermsToCSV(original);
      final imported = await service.importTermsFromCSV(csv, 1);

      expect(imported, hasLength(original.length));
      for (var i = 0; i < original.length; i++) {
        expect(imported[i].text, original[i].text);
        expect(imported[i].status, original[i].status);
        expect(imported[i].translation, original[i].translation);
        expect(imported[i].romanization, original[i].romanization);
        expect(imported[i].sentence, original[i].sentence);
      }
    });
  });

  group('exportToAnki', () {
    test('produces semicolon-separated format', () async {
      final anki = await service.exportToAnki(sampleTerms());
      final lines =
          anki.split('\n').where((l) => l.trim().isNotEmpty).toList();

      expect(lines[0], contains('hola;'));
      expect(lines[0], contains('hello'));
    });

    test('includes romanization in brackets', () async {
      final terms = [
        Term(
          languageId: 1,
          text: '你好',
          lowerText: '你好',
          translation: 'hello',
          romanization: 'nǐ hǎo',
        ),
      ];

      final anki = await service.exportToAnki(terms);
      expect(anki, contains('[nǐ hǎo]'));
    });

    test('includes sentence in italics', () async {
      final anki = await service.exportToAnki(sampleTerms());
      expect(anki, contains('<i>Hola, mundo!</i>'));
    });
  });

  group('cleanTextForImport', () {
    test('normalizes whitespace', () {
      final result = service.cleanTextForImport('  hello   world  ');
      expect(result, 'hello world');
    });
  });
}
