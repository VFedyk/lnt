import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/dictionary.dart';
import 'package:language_nerd_tools/domain/repositories/dictionary_repository.dart';
import 'package:language_nerd_tools/services/dictionary_service.dart';
import 'package:language_nerd_tools/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements DictionaryRepository {
  final List<Dictionary> all;
  _FakeRepo(this.all);

  @override
  Future<List<Dictionary>> getAll(
      {String? languageId, bool activeOnly = false}) async {
    return all
        .where((d) =>
            (languageId == null || d.languageId == languageId) &&
            (!activeOnly || d.isActive))
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late DictionaryService service;
  final stored = [
    Dictionary(id: 'd1', languageId: 'l1', name: 'A', url: 'https://a/###'),
    Dictionary(id: 'd2', languageId: 'l1', name: 'B', url: 'https://b/###'),
    Dictionary(
        id: 'd3',
        languageId: 'l1',
        name: 'Off',
        url: 'https://c/###',
        isActive: false),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = DictionaryService(
      dictionaries: _FakeRepo(stored),
      settingsService: SettingsService(),
    );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test('$platform: system entry first, stored order kept', () async {
      debugDefaultTargetPlatformOverride = platform;
      final result = await service.getActiveDictionaries('l1');
      expect(result.first.isSystem, isTrue);
      expect(result.first.languageId, 'l1');
      expect(result.skip(1).map((d) => d.id), ['d1', 'd2']);
    });
  }

  test('no system entry when the switch is off', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await SettingsService().setSystemDictionaryEnabled('l1', false);
    final result = await service.getActiveDictionaries('l1');
    expect(result.any((d) => d.isSystem), isFalse);
    expect(result.map((d) => d.id), ['d1', 'd2']);
  });

  test('no system entry on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final result = await service.getActiveDictionaries('l1');
    expect(result.any((d) => d.isSystem), isFalse);
  });

  test('no system entry on the host platform', () async {
    final result = await service.getActiveDictionaries('l1');
    expect(result.any((d) => d.isSystem), isFalse);
  });

  test('getAllDictionaries never contains the system entry', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final result = await service.getAllDictionaries('l1');
    expect(result.any((d) => d.isSystem), isFalse);
    expect(result.length, 3);
  });
}
