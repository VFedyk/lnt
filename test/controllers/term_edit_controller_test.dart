import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/services/ai_explanation_service.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/entities/term_sentence.dart';
import 'package:language_nerd_tools/presentation/controllers/term_edit_controller.dart';
import 'package:language_nerd_tools/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeAiService extends AiExplanationService {
  _FakeAiService({this.configured = true});

  bool configured;
  int translateCalls = 0;
  int ipaCalls = 0;
  Object? translateError;
  Object? ipaError;
  List<({String meaning, String? partOfSpeech})> translateResult = [
    (meaning: 'cat (animal)', partOfSpeech: 'noun'),
  ];
  String ipaResult = '/kæt/';
  Completer<String>? ipaCompleter;

  @override
  Future<bool> isConfigured() async => configured;

  @override
  Future<List<({String meaning, String? partOfSpeech})>> translateWord({
    required String word,
    required String contextSentence,
    required String languageName,
    String? languageCode,
  }) async {
    translateCalls++;
    if (translateError != null) throw translateError!;
    return translateResult;
  }

  @override
  Future<String> transcribeIpa({
    required String word,
    required String contextSentence,
    required String languageName,
    String? languageCode,
  }) async {
    ipaCalls++;
    if (ipaCompleter != null) return ipaCompleter!.future;
    if (ipaError != null) throw ipaError!;
    return ipaResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = await Directory.systemTemp.createTemp('lnt_term_edit');
    SharedPreferences.setMockInitialValues({
      'custom_db_path': '${dir.path}/lnt.db',
    });
    await sl.reset();
    setupServiceLocator();

    final database = await db.database;
    await database.insert('languages', {'id': 'l1', 'name': 'English'});
    await database.insert('terms', {
      'id': 't1', 'language_id': 'l1', 'text': 'cat', 'lower_text': 'cat',
      'status': 1, 'created_at': '2026-01-01T00:00:00.000Z',
      'last_accessed': '2026-01-01T00:00:00.000Z',
    });
  });

  tearDown(() async {
    await db.closeDatabase();
    await sl.reset();
    await dir.delete(recursive: true);
  });

  Future<TermEditController> makeController({
    String? termId = 't1',
    String sentence = '',
    String? sourceTextId,
    AiExplanationService? aiService,
  }) async {
    final term = termId != null
        ? (await db.terms.getById(termId))!
        : Term(languageId: 'l1', text: 'new', lowerText: 'new');
    final ctrl = TermEditController(
      term: term,
      sentence: sentence,
      sourceTextId: sourceTextId,
      languageId: 'l1',
      languageName: 'English',
      languageCode: 'en',
      aiService: aiService,
    );
    await ctrl.ready;
    return ctrl;
  }

  test('visibleSentences merges persisted rows with pending adds', () async {
    await db.termSentences.create('t1', 'Persisted one.');
    await db.termSentences.create('t1', 'Persisted two.');

    final ctrl = await makeController();
    expect(ctrl.visibleSentences.map((s) => s.text),
        ['Persisted one.', 'Persisted two.']);

    ctrl.addSentence('A new one.');
    expect(ctrl.visibleSentences.map((s) => s.text),
        ['Persisted one.', 'Persisted two.', 'A new one.']);
    ctrl.dispose();
  });

  test('visibleSentences honours edits and deletes', () async {
    final s1 = await db.termSentences.create('t1', 'Original.');
    await db.termSentences.create('t1', 'Keep me.');

    final ctrl = await makeController();
    ctrl.editSentence(s1.id!, 'Edited.');
    expect(ctrl.visibleSentences.map((s) => s.text), ['Edited.', 'Keep me.']);

    ctrl.removeSentence(s1.id!);
    expect(ctrl.visibleSentences.map((s) => s.text), ['Keep me.']);
    ctrl.dispose();
  });

  test('buildSentenceEdits produces the three buckets', () async {
    final s1 = await db.termSentences.create('t1', 'One.');
    final s2 = await db.termSentences.create('t1', 'Two.');

    final ctrl = await makeController();
    ctrl.addSentence('Added.');
    ctrl.editSentence(s1.id!, 'One edited.');
    ctrl.removeSentence(s2.id!);

    final edits = ctrl.buildSentenceEdits();
    expect(edits.added.map((e) => e.text), ['Added.']);
    expect(edits.edited, {s1.id!: 'One edited.'});
    expect(edits.deleted, [s2.id!]);
    ctrl.dispose();
  });

  test('a new term seeds the context sentence as a pending add', () async {
    final ctrl = await makeController(termId: null, sentence: 'Seed sentence.');
    expect(ctrl.visibleSentences.map((s) => s.text), ['Seed sentence.']);
    expect(
        ctrl.buildSentenceEdits().added.map((e) => e.text), ['Seed sentence.']);
    ctrl.dispose();
  });

  test('a new term seeds the context sentence with its source text id',
      () async {
    final database = await db.database;
    await database.insert('texts', {
      'id': 'txt-1', 'language_id': 'l1', 'title': 'Chapter One',
      'content': 'Seed sentence.', 'status': 0,
      'created_at': '2026-01-01T00:00:00.000Z',
      'last_read': '2026-01-01T00:00:00.000Z',
    });

    final ctrl = await makeController(
      termId: null,
      sentence: 'Seed sentence.',
      sourceTextId: 'txt-1',
    );

    expect(ctrl.buildSentenceEdits().added.single.sourceTextId, 'txt-1');
    expect(ctrl.visibleSentences.single.sourceTitle, 'Chapter One');
    ctrl.dispose();
  });

  test('isDirty is false on an untouched term', () async {
    await db.termSentences.create('t1', 'Existing.');
    final ctrl = await makeController();
    expect(ctrl.isDirty, isFalse);

    ctrl.addSentence('Now dirty.');
    expect(ctrl.isDirty, isTrue);
    ctrl.dispose();
  });

  test('TermSentenceEdits.empty is empty', () {
    expect(TermSentenceEdits.empty.isEmpty, isTrue);
  });

  test('editing ipaController flips isDirty', () async {
    final ctrl = await makeController();
    expect(ctrl.isDirty, isFalse);

    ctrl.ipaController.text = '/kæt/';
    expect(ctrl.isDirty, isTrue);
    ctrl.dispose();
  });

  test('buildSaveResult carries the trimmed ipa', () async {
    final ctrl = await makeController();
    ctrl.ipaController.text = '  /kæt/  ';

    final result = ctrl.buildSaveResult();
    expect(result.term.ipa, '/kæt/');
    ctrl.dispose();
  });

  group('AI auto-fill', () {
    test('both settings off (default): claimAutoFill returns all-false',
        () async {
      final ctrl = await makeController(aiService: _FakeAiService());
      final todo = ctrl.claimAutoFill();
      expect(todo.ipa, isFalse);
      expect(todo.translations, isFalse);
      ctrl.dispose();
    });

    test('IPA auto-fetch: on for a term without IPA, off for one with IPA',
        () async {
      SharedPreferences.setMockInitialValues({
        'ai_auto_fetch_ipa': true,
      });
      final ctrl = await makeController(aiService: _FakeAiService());
      expect(ctrl.claimAutoFill().ipa, isTrue);
      ctrl.dispose();

      final database = await db.database;
      await database.insert('terms', {
        'id': 't2', 'language_id': 'l1', 'text': 'dog', 'lower_text': 'dog',
        'status': 1, 'ipa': '/dɒg/',
        'created_at': '2026-01-01T00:00:00.000Z',
        'last_accessed': '2026-01-01T00:00:00.000Z',
      });
      SharedPreferences.setMockInitialValues({
        'ai_auto_fetch_ipa': true,
      });
      final ctrl2 =
          await makeController(termId: 't2', aiService: _FakeAiService());
      expect(ctrl2.claimAutoFill().ipa, isFalse);
      ctrl2.dispose();
    });

    test(
        'AI auto-translate: on for a term without translations, off with a '
        'translations row or a legacy translation', () async {
      SharedPreferences.setMockInitialValues({
        'ai_auto_translate': true,
      });
      final ctrl = await makeController(aiService: _FakeAiService());
      expect(ctrl.claimAutoFill().translations, isTrue);
      ctrl.dispose();

      await db.translations.replaceForTerm(
        't1',
        [Translation(termId: 't1', meaning: 'a cat')],
      );
      SharedPreferences.setMockInitialValues({
        'ai_auto_translate': true,
      });
      final ctrl2 = await makeController(aiService: _FakeAiService());
      expect(ctrl2.claimAutoFill().translations, isFalse);
      ctrl2.dispose();

      final database = await db.database;
      await database.insert('terms', {
        'id': 't3', 'language_id': 'l1', 'text': 'bird', 'lower_text': 'bird',
        'status': 1, 'translation': 'a bird',
        'created_at': '2026-01-01T00:00:00.000Z',
        'last_accessed': '2026-01-01T00:00:00.000Z',
      });
      SharedPreferences.setMockInitialValues({
        'ai_auto_translate': true,
      });
      final ctrl3 =
          await makeController(termId: 't3', aiService: _FakeAiService());
      expect(ctrl3.claimAutoFill().translations, isFalse);
      ctrl3.dispose();
    });

    test('AI not configured: both false even with both settings on',
        () async {
      SharedPreferences.setMockInitialValues({
        'ai_auto_fetch_ipa': true,
        'ai_auto_translate': true,
      });
      final ctrl =
          await makeController(aiService: _FakeAiService(configured: false));
      final todo = ctrl.claimAutoFill();
      expect(todo.ipa, isFalse);
      expect(todo.translations, isFalse);
      ctrl.dispose();
    });

    test('claimAutoFill returns all-false on its second call', () async {
      SharedPreferences.setMockInitialValues({
        'ai_auto_fetch_ipa': true,
        'ai_auto_translate': true,
      });
      final ctrl = await makeController(aiService: _FakeAiService());
      final first = ctrl.claimAutoFill();
      expect(first.ipa, isTrue);
      expect(first.translations, isTrue);

      final second = ctrl.claimAutoFill();
      expect(second.ipa, isFalse);
      expect(second.translations, isFalse);
      ctrl.dispose();
    });

    test('aiTranslateWord and fetchIpa results count as unsaved changes',
        () async {
      final ctrl = await makeController(aiService: _FakeAiService());
      expect(ctrl.isDirty, isFalse);

      await ctrl.aiTranslateWord();
      expect(ctrl.isDirty, isTrue);
      ctrl.dispose();

      final ctrl2 = await makeController(aiService: _FakeAiService());
      await ctrl2.fetchIpa();
      expect(ctrl2.isDirty, isTrue);
      ctrl2.dispose();
    });

    test(
        'fetchIpa(onlyIfEmpty: true) does not clobber user input typed while '
        'the request is in flight', () async {
      final completer = Completer<String>();
      final fake = _FakeAiService()..ipaCompleter = completer;
      final ctrl = await makeController(aiService: fake);

      final future = ctrl.fetchIpa(onlyIfEmpty: true);
      ctrl.ipaController.text = '/user-typed/';
      completer.complete('/from-ai/');
      await future;

      expect(ctrl.ipaController.text, '/user-typed/');
      ctrl.dispose();
    });

    test('fetchIpa() without onlyIfEmpty still overwrites', () async {
      final completer = Completer<String>();
      final fake = _FakeAiService()..ipaCompleter = completer;
      final ctrl = await makeController(aiService: fake);

      final future = ctrl.fetchIpa();
      ctrl.ipaController.text = '/user-typed/';
      completer.complete('/from-ai/');
      await future;

      expect(ctrl.ipaController.text, '/from-ai/');
      ctrl.dispose();
    });

    test('a new term with both settings on gets both auto-fill requests',
        () async {
      SharedPreferences.setMockInitialValues({
        'ai_auto_fetch_ipa': true,
        'ai_auto_translate': true,
      });
      final ctrl = await makeController(
        termId: null,
        aiService: _FakeAiService(),
      );
      final todo = ctrl.claimAutoFill();
      expect(todo.ipa, isTrue);
      expect(todo.translations, isTrue);
      ctrl.dispose();
    });
  });
}
