import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/services/data_change_notifier.dart';

void main() {
  group('DomainNotifier', () {
    late DomainNotifier notifier;

    setUp(() {
      notifier = DomainNotifier();
    });

    test('notify() fires listeners', () {
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.notify();

      expect(callCount, 1);
    });

    test('notify() fires multiple listeners', () {
      int callCountA = 0;
      int callCountB = 0;
      notifier.addListener(() => callCountA++);
      notifier.addListener(() => callCountB++);

      notifier.notify();

      expect(callCountA, 1);
      expect(callCountB, 1);
    });

    test('removed listener stops receiving notifications', () {
      int callCount = 0;
      void listener() => callCount++;

      notifier.addListener(listener);
      notifier.notify();
      expect(callCount, 1);

      notifier.removeListener(listener);
      notifier.notify();
      expect(callCount, 1); // unchanged
    });

    test('adding and removing the only listener works correctly', () {
      int callCount = 0;
      void listener() => callCount++;

      notifier.addListener(listener);
      notifier.notify();
      expect(callCount, 1);

      notifier.removeListener(listener);
      notifier.notify();
      expect(callCount, 1); // no listener, no call
    });

    test('multiple notify() calls fire listeners each time', () {
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.notify();
      notifier.notify();
      notifier.notify();

      expect(callCount, 3);
    });
  });

  group('DataChangeNotifier', () {
    late DataChangeNotifier dataChanges;

    setUp(() {
      dataChanges = DataChangeNotifier();
    });

    test('notifyAll() fires all domain listeners', () {
      int languagesCalls = 0;
      int termsCalls = 0;
      int textsCalls = 0;
      int collectionsCalls = 0;
      int reviewCardsCalls = 0;

      dataChanges.languages.addListener(() => languagesCalls++);
      dataChanges.terms.addListener(() => termsCalls++);
      dataChanges.texts.addListener(() => textsCalls++);
      dataChanges.collections.addListener(() => collectionsCalls++);
      dataChanges.reviewCards.addListener(() => reviewCardsCalls++);

      dataChanges.notifyAll();

      expect(languagesCalls, 1);
      expect(termsCalls, 1);
      expect(textsCalls, 1);
      expect(collectionsCalls, 1);
      expect(reviewCardsCalls, 1);
    });

    test('individual domain notifications are independent', () {
      int termsCalls = 0;
      int textsCalls = 0;

      dataChanges.terms.addListener(() => termsCalls++);
      dataChanges.texts.addListener(() => textsCalls++);

      dataChanges.terms.notify();

      expect(termsCalls, 1);
      expect(textsCalls, 0); // unaffected
    });

    test('notifyAll() after individual notifications accumulates', () {
      int termsCalls = 0;
      dataChanges.terms.addListener(() => termsCalls++);

      dataChanges.terms.notify(); // 1
      dataChanges.notifyAll(); // 2

      expect(termsCalls, 2);
    });

    test('each domain has its own independent notifier', () {
      // Verify all domains are distinct instances
      final notifiers = {
        dataChanges.languages,
        dataChanges.terms,
        dataChanges.texts,
        dataChanges.collections,
        dataChanges.reviewCards,
      };
      expect(notifiers, hasLength(5));
    });
  });
}
