import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/controllers/library_controller.dart';
import 'package:language_nerd_tools/models/language.dart';
import 'package:language_nerd_tools/models/text_document.dart';
import 'package:language_nerd_tools/repositories/collection_repository.dart';
import 'package:language_nerd_tools/repositories/term_repository.dart';
import 'package:language_nerd_tools/repositories/text_repository.dart';
import 'package:language_nerd_tools/services/data_change_notifier.dart';
import 'package:language_nerd_tools/services/database_service.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

class MockTextRepository extends Mock implements TextRepository {}

class MockCollectionRepository extends Mock implements CollectionRepository {}

class MockTermRepository extends Mock implements TermRepository {}

class _FakeTextDocument extends Fake implements TextDocument {}

/// Pump microtasks so fire-and-forget futures (like loadData) can complete.
Future<void> pumpMicrotasks([int count = 5]) async {
  for (var i = 0; i < count; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final sl = GetIt.instance;

  late DataChangeNotifier changes;
  late MockDatabaseService mockDb;
  late MockTextRepository mockTexts;
  late MockCollectionRepository mockCollections;
  late MockTermRepository mockTerms;

  Language testLanguage() => Language(
        id: 1,
        name: 'English',
        languageCode: 'en',
      );

  setUpAll(() {
    registerFallbackValue(_FakeTextDocument());
  });

  setUp(() async {
    await sl.reset();

    changes = DataChangeNotifier();
    mockDb = MockDatabaseService();
    mockTexts = MockTextRepository();
    mockCollections = MockCollectionRepository();
    mockTerms = MockTermRepository();

    when(() => mockDb.texts).thenReturn(mockTexts);
    when(() => mockDb.collections).thenReturn(mockCollections);
    when(() => mockDb.terms).thenReturn(mockTerms);

    // Stub repository methods called by loadData()
    when(() => mockCollections.getAll(
          languageId: any(named: 'languageId'),
          parentId: any(named: 'parentId'),
        )).thenAnswer((_) async => []);
    when(() => mockTexts.getAll(languageId: any(named: 'languageId')))
        .thenAnswer((_) async => []);
    when(() => mockTerms.getMapByLanguage(any()))
        .thenAnswer((_) async => {});

    sl.registerSingleton<DataChangeNotifier>(changes);
    sl.registerSingleton<DatabaseService>(mockDb);
  });

  tearDown(() async {
    // Let any pending async work finish before resetting
    await pumpMicrotasks();
    await sl.reset();
  });

  group('listener lifecycle', () {
    test('constructor adds listeners to texts and collections', () async {
      final controller = LibraryController(language: testLanguage());
      addTearDown(controller.dispose);

      changes.texts.notify();
      await pumpMicrotasks();

      verify(() => mockTexts.getAll(languageId: 1)).called(1);
    });

    test('dispose removes listeners', () async {
      final controller = LibraryController(language: testLanguage());
      controller.dispose();

      // After dispose, notifications should not trigger loadData
      changes.texts.notify();
      changes.collections.notify();
      await pumpMicrotasks();

      verifyNever(
          () => mockTexts.getAll(languageId: any(named: 'languageId')));
    });

    test('text domain notification triggers loadData', () async {
      final controller = LibraryController(language: testLanguage());
      addTearDown(controller.dispose);

      changes.texts.notify();
      await pumpMicrotasks();

      verify(() => mockCollections.getAll(
            languageId: 1,
            parentId: null,
          )).called(1);
      verify(() => mockTexts.getAll(languageId: 1)).called(1);
    });

    test('collection domain notification triggers loadData', () async {
      final controller = LibraryController(language: testLanguage());
      addTearDown(controller.dispose);

      changes.collections.notify();
      await pumpMicrotasks();

      verify(() => mockCollections.getAll(
            languageId: 1,
            parentId: null,
          )).called(1);
      verify(() => mockTexts.getAll(languageId: 1)).called(1);
    });

    test('unrelated domain notification does not trigger loadData', () async {
      final controller = LibraryController(language: testLanguage());
      addTearDown(controller.dispose);

      changes.terms.notify();
      changes.reviewCards.notify();
      changes.languages.notify();
      await pumpMicrotasks();

      verifyNever(
          () => mockTexts.getAll(languageId: any(named: 'languageId')));
    });
  });

  group('CRUD methods delegate to repositories', () {
    test('createText delegates to repository', () async {
      when(() => mockTexts.create(any())).thenAnswer((_) async => 1);

      final controller = LibraryController(language: testLanguage());
      addTearDown(controller.dispose);

      final doc = TextDocument(
        languageId: 1,
        title: 'Test',
        content: 'Hello',
      );
      await controller.createText(doc);

      verify(() => mockTexts.create(any())).called(1);
    });

    test('deleteText delegates to repository', () async {
      when(() => mockTexts.delete(any())).thenAnswer((_) async => 1);

      final controller = LibraryController(language: testLanguage());
      addTearDown(controller.dispose);

      await controller.deleteText(42);

      verify(() => mockTexts.delete(42)).called(1);
    });
  });
}
