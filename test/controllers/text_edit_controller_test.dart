import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:language_nerd_tools/presentation/controllers/text_edit_controller.dart';
import 'package:language_nerd_tools/service_locator.dart';
import 'package:language_nerd_tools/services/settings_service.dart';
import 'package:language_nerd_tools/utils/cover_image_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String path;
  _FakePathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

TextDocument _text({String? coverImage}) => TextDocument(
      id: 't1',
      languageId: 'l1',
      title: 'Title',
      content: 'Some content',
      coverImage: coverImage,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lnt_text_edit');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    await CoverImageHelper.initialize();
    SharedPreferences.setMockInitialValues({});
    await sl.reset();
    sl.registerSingleton<SettingsService>(SettingsService());
  });

  tearDown(() async {
    await sl.reset();
    dir.deleteSync(recursive: true);
  });

  group('isDirty', () {
    test('is false initially', () {
      final c = TextEditController(text: _text(), fontSize: 18);
      expect(c.isDirty, isFalse);
      c.dispose();
    });

    test('tracks title edits', () {
      final c = TextEditController(text: _text(), fontSize: 18);
      c.titleController.text = 'Other';
      expect(c.isDirty, isTrue);
      c.dispose();
    });

    test('tracks content edits and returns to clean when reverted', () {
      final c = TextEditController(text: _text(), fontSize: 18);
      c.contentController.text = 'Changed';
      expect(c.isDirty, isTrue);
      c.contentController.text = 'Some content';
      expect(c.isDirty, isFalse);
      c.dispose();
    });

    test('tracks setting a cover', () {
      final c = TextEditController(text: _text(), fontSize: 18);
      c.setCoverImagePath('${dir.path}/covers/new.jpg');
      expect(c.isDirty, isTrue);
      c.dispose();
    });

    test('tracks clearing an existing cover', () {
      final c = TextEditController(
        text: _text(coverImage: 'covers/old.jpg'),
        fontSize: 18,
      );
      expect(c.isDirty, isFalse);
      c.clearCover();
      expect(c.isDirty, isTrue);
      c.dispose();
    });
  });

  group('buildResult', () {
    test('carries the new title and content', () {
      final c = TextEditController(text: _text(), fontSize: 18);
      c.titleController.text = 'New title';
      c.contentController.text = 'New content';
      final r = c.buildResult();
      expect(r.title, 'New title');
      expect(r.content, 'New content');
      c.dispose();
    });

    test('clearing an existing cover nulls coverImage', () {
      final c = TextEditController(
        text: _text(coverImage: 'covers/old.jpg'),
        fontSize: 18,
      );
      c.clearCover();
      expect(c.buildResult().coverImage, isNull);
      c.dispose();
    });

    test('a new cover is stored as a relative path', () {
      final c = TextEditController(text: _text(), fontSize: 18);
      c.setCoverImagePath('${dir.path}/covers/new.jpg');
      expect(c.buildResult().coverImage, 'covers/new.jpg');
      c.dispose();
    });
  });

  group('fontSize', () {
    test('uses the passed value without consulting settings', () async {
      SharedPreferences.setMockInitialValues({'reader_font_size': 24.0});
      final c = TextEditController(text: _text(), fontSize: 20);
      await c.ready;
      expect(c.fontSize, 20);
      c.dispose();
    });

    test('loads the stored value when none is passed', () async {
      SharedPreferences.setMockInitialValues({'reader_font_size': 24.0});
      final c = TextEditController(text: _text());
      expect(c.fontSize, SettingsService.defaultReaderFontSize);
      await c.ready;
      expect(c.fontSize, 24);
      c.dispose();
    });
  });
}
