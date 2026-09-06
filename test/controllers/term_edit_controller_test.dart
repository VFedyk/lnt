import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/entities/term_sentence.dart';
import 'package:language_nerd_tools/presentation/controllers/term_edit_controller.dart';
import 'package:language_nerd_tools/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    );
    // Let _initialize() settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
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
}
