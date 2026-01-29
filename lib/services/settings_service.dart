import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._init();
  SettingsService._init();

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
