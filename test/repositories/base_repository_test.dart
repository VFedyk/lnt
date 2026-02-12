import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/repositories/base_repository.dart';
import 'package:language_nerd_tools/services/data_change_notifier.dart';

/// Minimal concrete subclass for testing BaseRepository behavior.
class _TestRepository extends BaseRepository {
  _TestRepository(super.getDatabase, {super.onChange});

  /// Exposes notifyChange() for testing.
  void doMutation() => notifyChange();
}

void main() {
  group('BaseRepository', () {
    test('notifyChange() fires the onChange DomainNotifier', () {
      final domainNotifier = DomainNotifier();
      int callCount = 0;
      domainNotifier.addListener(() => callCount++);

      final repo = _TestRepository(
        () => throw UnimplementedError('DB not needed for this test'),
        onChange: domainNotifier,
      );

      repo.doMutation();
      expect(callCount, 1);

      repo.doMutation();
      expect(callCount, 2);
    });

    test('notifyChange() does nothing when onChange is null', () {
      final repo = _TestRepository(
        () => throw UnimplementedError('DB not needed for this test'),
      );

      // Should not throw
      repo.doMutation();
    });

    test('multiple repositories can share the same DomainNotifier', () {
      final domainNotifier = DomainNotifier();
      int callCount = 0;
      domainNotifier.addListener(() => callCount++);

      final repoA = _TestRepository(
        () => throw UnimplementedError(),
        onChange: domainNotifier,
      );
      final repoB = _TestRepository(
        () => throw UnimplementedError(),
        onChange: domainNotifier,
      );

      repoA.doMutation();
      repoB.doMutation();

      expect(callCount, 2);
    });
  });

  group('escapeLike', () {
    test('escapes percent sign', () {
      expect(BaseRepository.escapeLike('100%'), r'100\%');
    });

    test('escapes underscore', () {
      expect(BaseRepository.escapeLike('foo_bar'), r'foo\_bar');
    });

    test('escapes backslash', () {
      expect(BaseRepository.escapeLike(r'a\b'), r'a\\b');
    });

    test('escapes all special characters together', () {
      expect(BaseRepository.escapeLike(r'a%b_c\d'), r'a\%b\_c\\d');
    });

    test('returns unchanged string when no special characters', () {
      expect(BaseRepository.escapeLike('hello'), 'hello');
    });
  });
}
