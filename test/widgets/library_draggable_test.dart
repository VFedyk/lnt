import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/collection.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/theme/app_theme.dart';
import 'package:language_nerd_tools/presentation/widgets/library/library_grid_content.dart';
import 'package:language_nerd_tools/presentation/widgets/library/library_list_content.dart';

void main() {
  final folders = [
    for (var i = 0; i < 2; i++)
      Collection(id: 'c$i', languageId: 'l', name: 'Folder $i'),
  ];
  final texts = [
    for (var i = 0; i < 30; i++)
      TextDocument(id: 't$i', languageId: 'l', title: 'Text $i', content: 'x'),
  ];

  late List<(Object, Collection?)> drops;
  late List<TextDocument> opened;
  late List<TextDocument> textOptions;
  late List<Collection> folderOptions;

  void reset() {
    drops = [];
    opened = [];
    textOptions = [];
    folderOptions = [];
  }

  Future<void> pumpScreen(WidgetTester tester, {required bool grid}) async {
    reset();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final Widget content = grid
        ? LibraryGridContent(
            l10n: l10n,
            collections: folders,
            texts: texts,
            unknownCounts: const {},
            bookProgress: const {},
            isInsideCollection: false,
            onOpenCollection: (_) {},
            onShowCollectionOptions: folderOptions.add,
            onOpenText: opened.add,
            onShowTextOptions: textOptions.add,
            onDrop: (item, target) => drops.add((item, target)),
          )
        : LibraryListContent(
            language: Language(id: 'l', name: 'English', languageCode: 'en'),
            l10n: l10n,
            collections: folders,
            texts: texts,
            unknownCounts: const {},
            bookProgress: const {},
            isInsideCollection: false,
            onOpenCollection: (_) {},
            onEditCollection: (_) {},
            onDeleteCollection: (_) {},
            onOpenText: opened.add,
            onReviewText: (_) {},
            onSetCover: (_) {},
            onEditText: (_) {},
            onDeleteText: (_) {},
            onDrop: (item, target) => drops.add((item, target)),
          );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.light(),
        home: Scaffold(body: content),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset center(WidgetTester tester, String title) =>
      tester.getCenter(find.text(title).first);

  double scrollOffset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

  Future<void> moveTo(WidgetTester tester, TestGesture g, Offset to) async {
    // Move in several steps so the drag target registers hover.
    for (var i = 1; i <= 5; i++) {
      await g.moveTo(to);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (final grid in [true, false]) {
    final name = grid ? 'grid' : 'list';

    group(name, () {
      testWidgets('touch swipe scrolls and does not drag', (tester) async {
        await pumpScreen(tester, grid: grid);
        final before = scrollOffset(tester);
        final g = await tester.startGesture(center(tester, 'Text 0'));
        for (var i = 0; i < 5; i++) {
          await g.moveBy(const Offset(0, -40));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await tester.pumpAndSettle();
        expect(scrollOffset(tester), greaterThan(before));
        expect(drops, isEmpty);
      });

      testWidgets('touch long-press then move drops onto folder', (
        tester,
      ) async {
        await pumpScreen(tester, grid: grid);
        final folderPos = center(tester, 'Folder 0');
        final g = await tester.startGesture(center(tester, 'Text 0'));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await moveTo(tester, g, folderPos);
        await g.up();
        await tester.pumpAndSettle();
        expect(drops.length, 1);
        expect(drops.first.$1, texts[0]);
        expect(drops.first.$2, folders[0]);
      });

      testWidgets('touch tap opens the text', (tester) async {
        await pumpScreen(tester, grid: grid);
        await tester.tap(find.text('Text 0').first);
        await tester.pumpAndSettle();
        expect(opened, [texts[0]]);
      });

      testWidgets('mouse press and move drags immediately', (tester) async {
        await pumpScreen(tester, grid: grid);
        final folderPos = center(tester, 'Folder 0');
        final g = await tester.startGesture(
          center(tester, 'Text 0'),
          kind: PointerDeviceKind.mouse,
        );
        await moveTo(tester, g, folderPos);
        await g.up();
        await tester.pumpAndSettle();
        expect(drops.length, 1);
        expect(drops.first.$2, folders[0]);
      });

      testWidgets('touch hold and release in place shows options (grid only)', (
        tester,
      ) async {
        await pumpScreen(tester, grid: grid);
        final g = await tester.startGesture(center(tester, 'Text 0'));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await g.up();
        await tester.pumpAndSettle();
        expect(textOptions.length, grid ? 1 : 0);
        expect(drops, isEmpty);
      });

      testWidgets('touch hold on a folder and release opens its options', (
        tester,
      ) async {
        await pumpScreen(tester, grid: grid);
        final g = await tester.startGesture(center(tester, 'Folder 0'));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await g.up();
        await tester.pumpAndSettle();
        expect(folderOptions.length, grid ? 1 : 0);
        expect(drops, isEmpty);
      });
    });
  }

  testWidgets('grid: mouse right-click opens text options', (tester) async {
    await pumpScreen(tester, grid: true);
    final g = await tester.startGesture(
      center(tester, 'Text 0'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await g.up();
    await tester.pumpAndSettle();
    expect(textOptions, [texts[0]]);
    expect(drops, isEmpty);
  });
}
