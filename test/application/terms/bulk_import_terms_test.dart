import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/application/use_cases/terms/bulk_import_terms.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/entities/term_sentence.dart';
import 'package:language_nerd_tools/domain/repositories/term_repository.dart';
import 'package:language_nerd_tools/domain/repositories/term_sentence_repository.dart';

class MockTermRepository extends Mock implements TermRepository {}

class MockTermSentenceRepository extends Mock
    implements TermSentenceRepository {}

class _FakeTerm extends Fake implements Term {}

void main() {
  late MockTermRepository mockTerms;
  late MockTermSentenceRepository mockSentences;
  late BulkImportTerms useCase;

  setUpAll(() {
    registerFallbackValue(_FakeTerm());
  });

  setUp(() {
    mockTerms = MockTermRepository();
    mockSentences = MockTermSentenceRepository();
    useCase = BulkImportTerms(terms: mockTerms, sentences: mockSentences);
    when(() => mockTerms.bulkCreate(any())).thenAnswer((_) async {});
    when(() => mockSentences.create(any(), any())).thenAnswer(
      (i) async => TermSentence(
        termId: i.positionalArguments[0] as String,
        sentence: i.positionalArguments[1] as String,
        createdAt: DateTime.now(),
      ),
    );
  });

  test('creates terms with assigned ids and no legacy sentence', () async {
    final terms = [
      Term(languageId: 'lang-1', text: 'one', lowerText: 'one'),
      Term(languageId: 'lang-1', text: 'two', lowerText: 'two'),
    ];

    await useCase(terms);

    final captured = verify(() => mockTerms.bulkCreate(captureAny()))
        .captured
        .single as List<Term>;
    expect(captured, hasLength(2));
    expect(captured.every((t) => t.id != null), isTrue);
    expect(captured.every((t) => t.sentence.isEmpty), isTrue);
  });

  test('creates a term_sentences row for each term carrying a sentence',
      () async {
    final terms = [
      Term(languageId: 'l', text: 'a', lowerText: 'a', sentence: 'A sentence.'),
      Term(languageId: 'l', text: 'b', lowerText: 'b'),
    ];

    await useCase(terms);

    final captured = verify(() => mockTerms.bulkCreate(captureAny()))
        .captured
        .single as List<Term>;
    verify(() => mockSentences.create(captured[0].id!, 'A sentence.')).called(1);
    verifyNever(() => mockSentences.create(captured[1].id!, any()));
  });

  test('does nothing when given no terms', () async {
    await useCase([]);
    verifyNever(() => mockTerms.bulkCreate(any()));
    verifyNever(() => mockSentences.create(any(), any()));
  });
}
