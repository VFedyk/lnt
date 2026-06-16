import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/utils/helpers.dart';

void main() {
  group('DateHelper.formatRelativeFuture', () {
    final now = DateTime.now();

    test('past or now reads as "Due now"', () {
      expect(DateHelper.formatRelativeFuture(now.subtract(const Duration(days: 1))),
          'Due now');
      expect(DateHelper.formatRelativeFuture(now.subtract(const Duration(minutes: 5))),
          'Due now');
    });

    test('future dates read forward, never "Just now"', () {
      expect(DateHelper.formatRelativeFuture(now.add(const Duration(days: 3, hours: 1))),
          'in 3 days');
      expect(DateHelper.formatRelativeFuture(now.add(const Duration(days: 1, hours: 1))),
          'in 1 day');
      expect(DateHelper.formatRelativeFuture(now.add(const Duration(hours: 2, minutes: 1))),
          'in 2 hours');
    });
  });
}
