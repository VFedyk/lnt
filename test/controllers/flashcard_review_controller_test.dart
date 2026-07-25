import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/value_objects/review_scope.dart';
import 'package:language_nerd_tools/domain/value_objects/term_status.dart';
import 'package:language_nerd_tools/presentation/controllers/flashcard_review_controller.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/models/review_session_spec.dart';
import 'package:language_nerd_tools/presentation/screens/flashcard_review_screen.dart';
import 'package:language_nerd_tools/presentation/theme/app_theme.dart';
import 'package:language_nerd_tools/domain/entities/review_card.dart';
import 'package:language_nerd_tools/service_locator.dart';
import 'package:language_nerd_tools/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stands in for the real service so a write failure can be injected.
class _ThrowingReviewService implements ReviewService {
  @override
  Future<({ReviewCardRecord updatedCard, int newStatus})> reviewTerm(
    ReviewCardRecord record,
    fsrs.Rating rating, {
    bool notify = true,
  }) async =>
      throw StateError('write failed');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Drives a whole text-scoped flashcard session against a real database, the
/// way the reader entry point does. Guards the rating loop: a throw inside
/// rateCard leaves the phase stuck on `rating` and every later tap is silently
/// swallowed by the re-entry guard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = await Directory.systemTemp.createTemp('lnt_ctrl');
    SharedPreferences.setMockInitialValues({
      'custom_db_path': '${dir.path}/lnt.db',
      'new_cards_per_day': 0,
    });

    await sl.reset();
    setupServiceLocator();

    final database = await db.database;
    await database.insert('languages', {'id': 'lang-1', 'name': 'English'});
    await database.insert('texts', {
      'id': 'x1',
      'language_id': 'lang-1',
      'title': 'Chapter 1',
      'content': 'alpha beta gamma',
      'created_at': '2026-01-01T00:00:00.000Z',
      'last_read': '2026-01-01T00:00:00.000Z',
    });
    for (final word in ['alpha', 'beta', 'gamma']) {
      await database.insert('terms', {
        'id': word,
        'language_id': 'lang-1',
        'text': word,
        'lower_text': word,
        'status': TermStatus.learning2,
        'created_at': '2026-01-01T00:00:00.000Z',
        'last_accessed': '2026-01-01T00:00:00.000Z',
      });
      await database.insert('text_words', {
        'text_id': 'x1',
        'lower_text': word,
        'occurrences': 1,
        'first_position': 0,
      });
    }
  });

  tearDown(() async {
    await db.closeDatabase();
    await sl.reset();
    await dir.delete(recursive: true);
  });

  Future<FlashcardReviewController> start({required bool graded}) async {
    final controller = FlashcardReviewController(
      spec: ReviewSessionSpec(
        language: Language(id: 'lang-1', name: 'English', languageCode: 'en'),
        scope: ReviewScope(textId: 'x1', includeNotDue: !graded),
        graded: graded,
        sourceTextId: 'x1',
        sourceTextTitle: 'Chapter 1',
      ),
    );
    // Let loadDueCards (seeding + queries) settle.
    for (var i = 0; i < 50; i++) {
      if (controller.phase != ReviewPhase.loading &&
          controller.phase != ReviewPhase.seeding) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return controller;
  }

  test('a graded text-scoped session advances through every card', () async {
    final controller = await start(graded: true);
    expect(controller.phase, ReviewPhase.question);
    expect(controller.dueItems.length, 3);

    for (var i = 0; i < 3; i++) {
      expect(controller.currentIndex, i);
      controller.revealAnswer();
      expect(controller.phase, ReviewPhase.revealed);
      await controller.rateCard(fsrs.Rating.good);
      // The phase must never be left on `rating` — that state silently
      // swallows every subsequent tap.
      expect(controller.phase, isNot(ReviewPhase.rating));
    }

    expect(controller.phase, ReviewPhase.done);
    expect(controller.reviewedCount, 3);
  });

  test('a failed write never strands the phase on rating', () async {
    final controller = await start(graded: true);
    controller.revealAnswer();

    sl.unregister<ReviewService>();
    sl.registerSingleton<ReviewService>(_ThrowingReviewService());
    await controller.rateCard(fsrs.Rating.good);

    // Still rateable: the phase must fall back to `revealed`, not `rating`,
    // or every later tap and keystroke is swallowed by the re-entry guard.
    expect(controller.phase, ReviewPhase.revealed);
    expect(controller.currentIndex, 0);
  });

  test('a practice text-scoped session advances and writes nothing', () async {
    final controller = await start(graded: false);
    expect(controller.phase, ReviewPhase.question);

    final before = await db.reviewCards.getByTermId('alpha');

    controller.revealAnswer();
    await controller.rateCard(fsrs.Rating.again);

    expect(controller.phase, ReviewPhase.question);
    expect(controller.currentIndex, 1);
    expect(controller.outcome.failedTermIds, {'alpha'});

    final after = await db.reviewCards.getByTermId('alpha');
    expect(after!.nextDue, before!.nextDue);
    expect(await db.reviewLogs.getByTermId('alpha'), isEmpty);
  });

  testWidgets('the rating buttons advance a text-scoped flashcard session',
      (tester) async {
    final spec = ReviewSessionSpec(
      language: Language(id: 'lang-1', name: 'English', languageCode: 'en'),
      scope: const ReviewScope(textId: 'x1'),
      graded: true,
      sourceTextId: 'x1',
      sourceTextTitle: 'Chapter 1',
    );

    // Real sqflite I/O only progresses inside runAsync; pumpAndSettle is
    // unusable here because the loading spinner never settles.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FlashcardReviewScreen(spec: spec),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);

    // Reveal the answer.
    await tester.tap(find.text(l10n.showAnswer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.rateGood), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text(l10n.rateGood));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Card 2 of 3 must now be showing: the reveal buttons are gone again.
    expect(find.text(l10n.rateGood), findsNothing);
    expect(find.text('2 of 3'), findsOneWidget);

    // Rate the remaining two and land on the completion screen.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(l10n.showAnswer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.rateGood));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();

    expect(find.text(l10n.reviewComplete), findsOneWidget);
  });
}
