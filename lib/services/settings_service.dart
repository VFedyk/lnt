import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService();

  static const String _deepLApiKeyKey = 'deepl_api_key';
  static const String _deepLApiTypeKey = 'deepl_api_type'; // 'free' or 'pro'
  static const String _deepLTargetLangKey = 'deepl_target_lang';
  static const String defaultTargetLang = 'EN';

  // Window size persistence
  static const String _windowWidthKey = 'window_width';
  static const String _windowHeightKey = 'window_height';
  static const String _windowMaximizedKey = 'window_maximized';
  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 720;

  // LibreTranslate settings
  static const String _libreTranslateUrlKey = 'libretranslate_url';
  static const String _libreTranslateApiKeyKey = 'libretranslate_api_key';
  static const String defaultLibreTranslateUrl = 'https://libretranslate.com';

  // Custom database path
  static const String _customDbPathKey = 'custom_db_path';

  // Backup timestamps
  static const String _googleDriveLastBackupKey = 'google_drive_last_backup';
  static const String _icloudLastBackupKey = 'icloud_last_backup';

  Future<String?> getDeepLApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deepLApiKeyKey);
  }

  Future<void> setDeepLApiKey(String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_deepLApiKeyKey);
    } else {
      await prefs.setString(_deepLApiKeyKey, apiKey);
    }
  }

  Future<bool> isDeepLApiFree() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deepLApiTypeKey) != 'pro';
  }

  Future<void> setDeepLApiFree(bool isFree) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deepLApiTypeKey, isFree ? 'free' : 'pro');
  }

  Future<bool> hasDeepLApiKey() async {
    final key = await getDeepLApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<String> getDeepLTargetLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deepLTargetLangKey) ?? defaultTargetLang;
  }

  Future<void> setDeepLTargetLang(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deepLTargetLangKey, langCode);
  }

  // Window size persistence

  Future<double> getWindowWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_windowWidthKey) ?? defaultWindowWidth;
  }

  Future<double> getWindowHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_windowHeightKey) ?? defaultWindowHeight;
  }

  Future<bool> getWindowMaximized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_windowMaximizedKey) ?? false;
  }

  // LibreTranslate settings

  Future<String?> getLibreTranslateUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_libreTranslateUrlKey) ?? defaultLibreTranslateUrl;
  }

  Future<void> setLibreTranslateUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_libreTranslateUrlKey);
    } else {
      await prefs.setString(_libreTranslateUrlKey, url);
    }
  }

  Future<String?> getLibreTranslateApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_libreTranslateApiKeyKey);
  }

  Future<void> setLibreTranslateApiKey(String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_libreTranslateApiKeyKey);
    } else {
      await prefs.setString(_libreTranslateApiKeyKey, apiKey);
    }
  }

  Future<bool> hasLibreTranslateApiKey() async {
    final key = await getLibreTranslateApiKey();
    return key != null && key.isNotEmpty;
  }

  // Custom database path

  Future<String?> getCustomDbPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customDbPathKey);
  }

  Future<void> setCustomDbPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_customDbPathKey);
    } else {
      await prefs.setString(_customDbPathKey, path);
    }
  }

  // Backup timestamps

  Future<DateTime?> getGoogleDriveLastBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_googleDriveLastBackupKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setGoogleDriveLastBackup(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _googleDriveLastBackupKey,
      date.millisecondsSinceEpoch,
    );
  }

  Future<DateTime?> getICloudLastBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_icloudLastBackupKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setICloudLastBackup(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_icloudLastBackupKey, date.millisecondsSinceEpoch);
  }

  Future<void> saveWindowState({
    required double width,
    required double height,
    required bool isMaximized,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowWidthKey, width);
    await prefs.setDouble(_windowHeightKey, height);
    await prefs.setBool(_windowMaximizedKey, isMaximized);
  }
}
