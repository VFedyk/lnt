import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/events/term_event.dart';

/// A single-domain change notifier. Listeners are called when
/// any mutation occurs in the corresponding repository.
class DomainNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Typed event emitter for cross-domain reactive wiring.
class EventStream<T> {
  final _controller = StreamController<T>.broadcast();
  Stream<T> get stream => _controller.stream;
  void emit(T event) => _controller.add(event);
  void close() => _controller.close();
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
  final dictionaries = DomainNotifier();
  final termSentences = DomainNotifier();
  final radicalProgress = DomainNotifier();
  final translations = DomainNotifier();

  final termEvents = EventStream<TermEvent>();

  /// Notify all domains at once (e.g. after backup restore).
  void notifyAll() {
    languages.notify();
    terms.notify();
    texts.notify();
    collections.notify();
    reviewCards.notify();
    dictionaries.notify();
    termSentences.notify();
    radicalProgress.notify();
    translations.notify();
  }
}
