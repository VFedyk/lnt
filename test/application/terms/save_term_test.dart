import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/application/use_cases/terms/save_term.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/entities/term_sentence.dart';
import 'package:language_nerd_tools/domain/repositories/term_repository.dart';
import 'package:language_nerd_tools/domain/repositories/term_sentence_repository.dart';
import 'package:language_nerd_tools/domain/repositories/translation_repository.dart';

class MockTermRepository extends Mock implements TermRepository {}
class MockTranslationRepository extends Mock implements TranslationRepository {}
class MockTermSentenceRepository extends Mock implements TermSentenceRepository {}
class _FakeTerm extends Fake implements Term {}
class _FakeTranslation extends Fake implements Translation {}

Term _makeTerm({String? id}) =>
    Term(id: id, languageId: 'lang-1', text: 'hello', lowerText: 'hello');

void main() {
  late MockTermRepository mockTerms;
  late MockTranslationRepository mockTranslations;
  late MockTermSentenceRepository mockSentences;
  late SaveTerm useCase;

  setUpAll(() {
    registerFallbackValue(_FakeTerm());
    registerFallbackValue(_FakeTranslation());
  });

  setUp(() {
    mockTerms = MockTermRepository();
    mockTranslations = MockTranslationRepository();
    mockSentences = MockTermSentenceRepository();
    useCase = SaveTerm(
      terms: mockTerms,
      translations: mockTranslations,
      sentences: mockSentences,
    );

    when(() => mockTranslations.replaceForTerm(any(), any())).thenAnswer((_) async {});
    when(() => mockSentences.create(any(), any())).thenAnswer(
      (i) async => TermSentence(
        termId: i.positionalArguments[0] as String,
        sentence: i.positionalArguments[1] as String,
        createdAt: DateTime.now(),
      ),
    );
    when(() => mockSentences.update(any(), any())).thenAnswer((_) async {});
    when(() => mockSentences.delete(any())).thenAnswer((_) async {});
  });

  group('create path (isNew: true)', () {
    test('calls create then replaceForTerm with the new id', () async {
      const newId = 'new-uuid-123';
      final term = _makeTerm();
      final translations = [Translation(termId: '', meaning: 'world')];

      when(() => mockTerms.create(any())).thenAnswer((_) async => newId);

      final result = await useCase(term, translations, isNew: true);

      verify(() => mockTerms.create(any())).called(1);
      verify(() => mockTranslations.replaceForTerm(newId, translations)).called(1);
      expect(result, newId);
    });

    test('returns the id from create', () async {
      const id = 'abc-456';
      when(() => mockTerms.create(any())).thenAnswer((_) async => id);

      final result = await useCase(_makeTerm(), [], isNew: true);

      expect(result, id);
    });

    test('does not call update', () async {
      when(() => mockTerms.create(any())).thenAnswer((_) async => 'x');

      await useCase(_makeTerm(), [], isNew: true);

      verifyNever(() => mockTerms.update(any()));
    });
  });

  group('update path (isNew: false)', () {
    test('calls update then replaceForTerm with existing id', () async {
      const existingId = 'existing-99';
      final term = _makeTerm(id: existingId);
      final translations = [Translation(termId: existingId, meaning: 'hi')];

      when(() => mockTerms.update(any())).thenAnswer((_) async => 1);

      final result = await useCase(term, translations, isNew: false);

      verify(() => mockTerms.update(any())).called(1);
      verify(() => mockTranslations.replaceForTerm(existingId, translations)).called(1);
      expect(result, existingId);
    });

    test('does not call create', () async {
      final term = _makeTerm(id: 'some-id');
      when(() => mockTerms.update(any())).thenAnswer((_) async => 1);

      await useCase(term, [], isNew: false);

      verifyNever(() => mockTerms.create(any()));
    });
  });

  group('sentence edits', () {
    test('applied against the new id on the create path', () async {
      const newId = 'fresh-id';
      when(() => mockTerms.create(any())).thenAnswer((_) async => newId);

      await useCase(
        _makeTerm(),
        [],
        isNew: true,
        sentences: const TermSentenceEdits(added: ['A new sentence.']),
      );

      verify(() => mockSentences.create(newId, 'A new sentence.')).called(1);
    });

    test('applied against the existing id, in delete/edit/add order', () async {
      const id = 'existing-1';
      when(() => mockTerms.update(any())).thenAnswer((_) async => 1);

      await useCase(
        _makeTerm(id: id),
        [],
        isNew: false,
        sentences: const TermSentenceEdits(
          added: ['added'],
          edited: {'s-edit': 'changed'},
          deleted: ['s-del'],
        ),
      );

      verify(() => mockSentences.delete('s-del')).called(1);
      verify(() => mockSentences.update('s-edit', 'changed')).called(1);
      verify(() => mockSentences.create(id, 'added')).called(1);
    });

    test('TermSentenceEdits.empty writes nothing', () async {
      when(() => mockTerms.create(any())).thenAnswer((_) async => 'x');

      await useCase(_makeTerm(), [], isNew: true);

      verifyNever(() => mockSentences.create(any(), any()));
      verifyNever(() => mockSentences.update(any(), any()));
      verifyNever(() => mockSentences.delete(any()));
    });
  });
}
