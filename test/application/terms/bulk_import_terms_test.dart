import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/application/use_cases/terms/bulk_import_terms.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/repositories/term_repository.dart';

class MockTermRepository extends Mock implements TermRepository {}
class _FakeTerm extends Fake implements Term {}

void main() {
  late MockTermRepository mockTerms;
  late BulkImportTerms useCase;

  setUpAll(() {
    registerFallbackValue(_FakeTerm());
  });

  setUp(() {
    mockTerms = MockTermRepository();
    useCase = BulkImportTerms(terms: mockTerms);
    when(() => mockTerms.bulkCreate(any())).thenAnswer((_) async {});
  });

  test('delegates to TermRepository.bulkCreate with the provided list', () async {
    final terms = [
      Term(languageId: 'lang-1', text: 'one', lowerText: 'one'),
      Term(languageId: 'lang-1', text: 'two', lowerText: 'two'),
    ];

    await useCase(terms);

    verify(() => mockTerms.bulkCreate(terms)).called(1);
  });

  test('calls bulkCreate exactly once even for a large list', () async {
    final terms = List.generate(
      100,
      (i) => Term(languageId: 'lang-1', text: 'w$i', lowerText: 'w$i'),
    );

    await useCase(terms);

    verify(() => mockTerms.bulkCreate(any())).called(1);
  });

  test('calls bulkCreate with an empty list when given no terms', () async {
    await useCase([]);
    verify(() => mockTerms.bulkCreate([])).called(1);
  });
}
