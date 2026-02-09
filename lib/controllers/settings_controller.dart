import 'package:flutter/foundation.dart';
import '../service_locator.dart';
import '../services/deepl_service.dart';
import '../services/settings_service.dart';
import '../utils/helpers.dart';

class SettingsController extends ChangeNotifier {
  bool isLoading = true;
  bool isApiFree = true;
  String targetLang = SettingsService.defaultTargetLang;
  DeepLUsage? usage;
  bool isLoadingUsage = false;
  String? dbPath;
  DateTime? icloudLastBackup;
  bool isBackingUp = false;
  bool isRestoring = false;

  // Initial values for seeding TextEditingControllers in the screen.
  String initialApiKey = '';
  String initialLtUrl = '';
  String initialLtApiKey = '';

  bool _isDisposed = false;

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadSettings() async {
    final apiKey = await settings.getDeepLApiKey();
    final isFree = await settings.isDeepLApiFree();
    final tgtLang = await settings.getDeepLTargetLang();
    final ltUrl = await settings.getLibreTranslateUrl();
    final ltApiKey = await settings.getLibreTranslateApiKey();

    String? path;
    if (PlatformHelper.isDesktop) {
      await db.database;
      path = db.currentDbPath;
    }

    final icloudBackup = await backupService.getICloudBackupDate();

    initialApiKey = apiKey ?? '';
    initialLtUrl = ltUrl ?? '';
    initialLtApiKey = ltApiKey ?? '';
    isApiFree = isFree;
    targetLang = tgtLang;
    dbPath = path;
    icloudLastBackup = icloudBackup;
    isLoading = false;
    _safeNotify();

    if (apiKey != null && apiKey.isNotEmpty) {
      await loadUsage();
    }
  }

  Future<void> loadUsage() async {
    isLoadingUsage = true;
    _safeNotify();
    final result = await deepLService.getUsage();
    usage = result;
    isLoadingUsage = false;
    _safeNotify();
  }

  Future<void> saveSettings({
    required String apiKey,
    required String ltUrl,
    required String ltApiKey,
  }) async {
    await settings.setDeepLApiKey(apiKey.trim());
    await settings.setDeepLApiFree(isApiFree);
    await settings.setDeepLTargetLang(targetLang);
    await settings.setLibreTranslateUrl(ltUrl.trim());
    await settings.setLibreTranslateApiKey(ltApiKey.trim());
  }

  /// Returns true on success.
  Future<bool> backupToICloud() async {
    isBackingUp = true;
    _safeNotify();
    try {
      await backupService.backupToICloud();
      icloudLastBackup = DateTime.now();
      isBackingUp = false;
      _safeNotify();
      return true;
    } catch (_) {
      isBackingUp = false;
      _safeNotify();
      rethrow;
    }
  }

  /// Returns true on success. Caller should confirm with user first.
  Future<bool> restoreFromICloud() async {
    isRestoring = true;
    _safeNotify();
    try {
      await backupService.restoreFromICloud();
      isRestoring = false;
      _safeNotify();
      return true;
    } catch (_) {
      isRestoring = false;
      _safeNotify();
      rethrow;
    }
  }

  Future<void> setCustomDbPath(String path) async {
    await settings.setCustomDbPath(path);
  }

  void setApiFree(bool value) {
    isApiFree = value;
    _safeNotify();
  }

  void setTargetLang(String value) {
    targetLang = value;
    _safeNotify();
  }

  static String formatNumber(int number) {
    const millionThreshold = 1000000;
    const thousandThreshold = 1000;
    if (number >= millionThreshold) {
      return '${(number / millionThreshold).toStringAsFixed(1)}M';
    } else if (number >= thousandThreshold) {
      return '${(number / thousandThreshold).toStringAsFixed(0)}K';
    }
    return number.toString();
  }
}
