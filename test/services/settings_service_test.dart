import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:language_nerd_tools/services/settings_service.dart';

void main() {
  late SettingsService settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
  });

  group('bookProgressLimit', () {
    test('returns default when nothing is stored', () async {
      expect(
        await settings.getBookProgressLimit(),
        SettingsService.defaultBookProgressLimit,
      );
    });

    test('round-trips a valid value', () async {
      await settings.setBookProgressLimit(10);
      expect(await settings.getBookProgressLimit(), 10);
    });

    test('clamps on write above the max', () async {
      await settings.setBookProgressLimit(100);
      expect(
        await settings.getBookProgressLimit(),
        SettingsService.maxBookProgressLimit,
      );
    });

    test('clamps on write below the min', () async {
      await settings.setBookProgressLimit(0);
      expect(
        await settings.getBookProgressLimit(),
        SettingsService.minBookProgressLimit,
      );
    });

    test('clamps on read for an out-of-range stored value', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_book_progress_limit': 99,
      });
      expect(
        await settings.getBookProgressLimit(),
        SettingsService.maxBookProgressLimit,
      );
    });
  });
}
