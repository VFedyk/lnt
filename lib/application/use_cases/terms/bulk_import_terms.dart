import '../../../domain/entities/term.dart';
import '../../../domain/repositories/term_repository.dart';

class BulkImportTerms {
  BulkImportTerms({required TermRepository terms}) : _terms = terms;

  final TermRepository _terms;

  Future<void> call(List<Term> terms) => _terms.bulkCreate(terms);
}
