import 'package:flutter/foundation.dart';

/// A single-domain change notifier. Listeners are called when
/// any mutation occurs in the corresponding repository.
class DomainNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Broadcasts data-mutation events per domain.
/// Screens and controllers subscribe to the domains they care about
/// and auto-reload when data changes — no manual refresh wiring needed.
class DataChangeNotifier {
  final languages = DomainNotifier();
  final terms = DomainNotifier();
  final texts = DomainNotifier();
  final collections = DomainNotifier();
  final reviewCards = DomainNotifier();

  /// Notify all domains at once (e.g. after backup restore).
  void notifyAll() {
    languages.notify();
    terms.notify();
    texts.notify();
    collections.notify();
    reviewCards.notify();
  }
}
