import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/entities/term_sentence.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:language_nerd_tools/domain/value_objects/term_status.dart';
import 'package:language_nerd_tools/presentation/controllers/reader_controller.dart';
import 'package:language_nerd_tools/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returning from a review must repaint the page: FSRS has moved the statuses
/// of words in this text, and the reader colours words by status.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  ReaderController? controller;
  final language = Language(id: 'lang-1', name: 'English', languageCode: 'en');

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = await Directory.systemTemp.createTemp('lnt_reader');
    SharedPreferences.setMockInitialValues({
      'custom_db_path': '${dir.path}/lnt.db',
    });

    await sl.reset();
    setupServiceLocator();

    final database = await db.database;
    await database.insert('languages', {'id': 'lang-1', 'name': 'English'});
    await database.insert('texts', {
      'id': 'x1',
      'language_id': 'lang-1',
      'title': 'Chapter 1',
      'content': 'alpha beta',
      'created_at': '2026-01-01T00:00:00.000Z',
      'last_read': '2026-01-01T00:00:00.000Z',
    });
    for (final word in ['alpha', 'beta']) {
      await database.insert('terms', {
        'id': word,
        'language_id': 'lang-1',
        'text': word,
        'lower_text': word,
        'status': TermStatus.unknown,
        'created_at': '2026-01-01T00:00:00.000Z',
        'last_accessed': '2026-01-01T00:00:00.000Z',
      });
    }
  });

  tearDown(() async {
    // loadTermsAndParse warms the word index fire-and-forget; let it land before
    // the database goes away, or it reopens under the next test's settings.
    await controller?.indexWarmup;
    controller = null;
    await db.closeDatabase();
    await sl.reset();
    await dir.delete(recursive: true);
  });

  int statusOf(ReaderController ctrl, String word) => ctrl.wordTokens
      .firstWhere((t) => t.isWord && t.text == word)
      .term!
      .status;

  test('refreshTermStatuses repaints statuses changed by a review', () async {
    final ctrl = ReaderController(
      text: TextDocument(
        id: 'x1',
        languageId: 'lang-1',
        title: 'Chapter 1',
        content: 'alpha beta',
      ),
      language: language,
    );
    controller = ctrl;
    await ctrl.loadTermsAndParse();

    expect(statusOf(ctrl, 'alpha'), TermStatus.unknown);
    expect(ctrl.termCounts[TermStatus.unknown], 2);

    // Stand in for what a review session writes.
    final database = await db.database;
    await database.update(
      'terms',
      {'status': TermStatus.known},
      where: 'id = ?',
      whereArgs: ['alpha'],
    );

    var notified = 0;
    ctrl.addListener(() => notified++);
    await ctrl.refreshTermStatuses();

    expect(statusOf(ctrl, 'alpha'), TermStatus.known);
    expect(statusOf(ctrl, 'beta'), TermStatus.unknown);
    // The legend counts move with them.
    expect(ctrl.termCounts[TermStatus.known], 1);
    expect(ctrl.termCounts[TermStatus.unknown], 1);
    expect(notified, greaterThan(0));

    ctrl.dispose();
  });

  test('refreshTermStatuses does not re-parse the text', () async {
    final ctrl = ReaderController(
      text: TextDocument(
        id: 'x1',
        languageId: 'lang-1',
        title: 'Chapter 1',
        content: 'alpha beta',
      ),
      language: language,
    );
    controller = ctrl;
    await ctrl.loadTermsAndParse();

    final tokenCount = ctrl.wordTokens.length;
    final paragraphCount = ctrl.paragraphs.length;

    await ctrl.refreshTermStatuses();

    expect(ctrl.wordTokens.length, tokenCount);
    expect(ctrl.paragraphs.length, paragraphCount);

    ctrl.dispose();
  });

  group('sentence counts', () {
    ReaderController build(String content) {
      final ctrl = ReaderController(
        text: TextDocument(
          id: 'x1',
          languageId: 'lang-1',
          title: 'Chapter 1',
          content: content,
        ),
        language: language,
      );
      controller = ctrl;
      return ctrl;
    }

    test('loadTermsAndParse populates sentenceCounts', () async {
      await db.termSentences.create('alpha', 'One.');
      await db.termSentences.create('alpha', 'Two.');
      final ctrl = build('alpha beta');
      await ctrl.loadTermsAndParse();

      expect(ctrl.sentenceCounts, {'alpha': 2});
      ctrl.dispose();
    });

    test('handleTermSaved tracks added and deleted sentences', () async {
      final ctrl = build('alpha beta');
      await ctrl.loadTermsAndParse();
      final alpha = ctrl.termsMap['alpha']!;

      await ctrl.handleTermSaved(
        alpha,
        const [],
        isNew: false,
        sentences: const TermSentenceEdits(
          added: [(text: 'Alpha one.', sourceTextId: null)],
        ),
      );
      expect(ctrl.sentenceCounts['alpha'], 1);

      final saved = await db.termSentences.getByTermId('alpha');
      await ctrl.handleTermSaved(
        alpha,
        const [],
        isNew: false,
        sentences: TermSentenceEdits(deleted: [saved.single.id!]),
      );
      expect(ctrl.sentenceCounts.containsKey('alpha'), isFalse);
      ctrl.dispose();
    });

    test('mineSentenceForTerm: mined, duplicate, noSentence', () async {
      final ctrl = build('alpha beta. Gamma delta.');
      await ctrl.loadTermsAndParse();
      final alpha = ctrl.termsMap['alpha']!;

      expect(await ctrl.mineSentenceForTerm(alpha, 0), MineSentenceResult.mined);
      expect(ctrl.sentenceCounts['alpha'], 1);

      expect(
        await ctrl.mineSentenceForTerm(alpha, 0),
        MineSentenceResult.duplicate,
      );
      expect(ctrl.sentenceCounts['alpha'], 1);

      expect(
        await ctrl.mineSentenceForTerm(alpha, 9999),
        MineSentenceResult.noSentence,
      );
      expect(ctrl.sentenceCounts['alpha'], 1);
      ctrl.dispose();
    });

    test('foreign word carries sentenceCount', () async {
      final database = await db.database;
      await database.insert('languages', {'id': 'lang-2', 'name': 'German'});
      await database.insert('terms', {
        'id': 'gamma',
        'language_id': 'lang-2',
        'text': 'gamma',
        'lower_text': 'gamma',
        'status': TermStatus.unknown,
        'created_at': '2026-01-01T00:00:00.000Z',
        'last_accessed': '2026-01-01T00:00:00.000Z',
      });
      await db.termSentences.create('gamma', 'Gamma ist hier.');
      await db.termSentences.create('gamma', 'Noch ein Gamma.');
      await db.textForeignWords.saveWords('x1', 'lang-2', {'gamma': 'gamma'});

      final ctrl = build('alpha gamma');
      await ctrl.loadTermsAndParse();

      expect(ctrl.otherLanguageTerms['gamma']?.sentenceCount, 2);
      ctrl.dispose();
    });
  });
}
