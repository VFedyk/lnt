import '../service_locator.dart';
import '../data/services/deepl_service.dart';
import '../services/settings_service.dart';
import '../utils/helpers.dart';
import 'base_controller.dart';

class SettingsController extends BaseController {
  bool isLoading = true;
  bool isApiFree = true;
  String targetLang = SettingsService.defaultTargetLang;
  DeepLUsage? usage;
  bool isLoadingUsage = false;
  String? dbPath;
  /// Date of the backup file currently in iCloud (remote metadata).
  DateTime? icloudRemoteDate;
  /// Date this device last created a backup (stored locally).
  DateTime? icloudLocalDate;
  bool isCheckingBackup = false;
  bool isBackingUp = false;
  bool isRestoring = false;
  double? restoreProgress;
  DateTime? lastRestoreDate;

  // Initial values for seeding TextEditingControllers in the screen.
  String initialApiKey = '';
  String initialLtUrl = '';
  String initialLtApiKey = '';
  String initialAiApiKey = '';
  String initialAiModel = SettingsService.defaultAiModel;
  String initialAiApiUrl = SettingsService.defaultAiApiUrl;
  String initialAiProvider = SettingsService.aiProviderAuto;

  Future<void> loadSettings() async {
    final apiKey = await settings.getDeepLApiKey();
    final isFree = await settings.isDeepLApiFree();
    final tgtLang = await settings.getTargetLang();
    final ltUrl = await settings.getLibreTranslateUrl();
    final ltApiKey = await settings.getLibreTranslateApiKey();
    final aiApiKey = await settings.getAiApiKey();
    final aiModel = await settings.getAiModel();
    final aiApiUrl = await settings.getAiApiUrl();
    final aiProvider = await settings.getAiProvider();

    String? path;
    if (PlatformHelper.isDesktop) {
      await db.database;
      path = db.currentDbPath;
    }

    final icloudRemote = await backupService.getICloudBackupDate();
    final icloudLocal = await settings.getICloudLastBackup();
    final lastRestore = await settings.getLastRestore();

    initialApiKey = apiKey ?? '';
    initialLtUrl = ltUrl ?? '';
    initialLtApiKey = ltApiKey ?? '';
    initialAiApiKey = aiApiKey ?? '';
    initialAiModel = aiModel;
    initialAiApiUrl = aiApiUrl;
    initialAiProvider = aiProvider;
    isApiFree = isFree;
    targetLang = tgtLang;
    dbPath = path;
    icloudRemoteDate = icloudRemote;
    icloudLocalDate = icloudLocal;
    lastRestoreDate = lastRestore;
    isLoading = false;
    safeNotify();

    if (apiKey != null && apiKey.isNotEmpty) {
      await loadUsage();
    }
  }

  Future<void> loadUsage() async {
    isLoadingUsage = true;
    safeNotify();
    final result = await deepLService.getUsage();
    usage = result;
    isLoadingUsage = false;
    safeNotify();
  }

  Future<void> saveSettings({
    required String apiKey,
    required String ltUrl,
    required String ltApiKey,
    required String aiApiKey,
    required String aiModel,
    required String aiApiUrl,
    required String aiProvider,
  }) async {
    await settings.setDeepLApiKey(apiKey.trim());
    await settings.setDeepLApiFree(isApiFree);
    await settings.setTargetLang(targetLang);
    await settings.setLibreTranslateUrl(ltUrl.trim());
    await settings.setLibreTranslateApiKey(ltApiKey.trim());
    await settings.setAiApiKey(aiApiKey.trim());
    await settings.setAiModel(aiModel.trim());
    await settings.setAiApiUrl(aiApiUrl.trim());
    await settings.setAiProvider(aiProvider.trim());
  }

  /// Returns true on success.
  Future<bool> backupToICloud() async {
    isBackingUp = true;
    safeNotify();
    try {
      await backupService.backupToICloud();
      final now = DateTime.now();
      icloudRemoteDate = now;
      icloudLocalDate = now;
      await settings.setICloudLastBackup(now);
      isBackingUp = false;
      safeNotify();
      return true;
    } catch (_) {
      isBackingUp = false;
      safeNotify();
      rethrow;
    }
  }

  /// Returns true on success. Caller should confirm with user first.
  Future<bool> restoreFromICloud() async {
    isRestoring = true;
    restoreProgress = null;
    safeNotify();
    try {
      await backupService.restoreFromICloud(
        onProgress: (p) {
          restoreProgress = p;
          safeNotify();
        },
      );
      final now = DateTime.now();
      lastRestoreDate = now;
      await settings.setLastRestore(now);
      isRestoring = false;
      restoreProgress = null;
      safeNotify();
      return true;
    } catch (_) {
      isRestoring = false;
      restoreProgress = null;
      safeNotify();
      rethrow;
    }
  }

  Future<void> recheckICloudBackup() async {
    isCheckingBackup = true;
    safeNotify();
    try {
      icloudRemoteDate = await backupService.getICloudBackupDate();
    } finally {
      isCheckingBackup = false;
      safeNotify();
    }
  }

  Future<void> setCustomDbPath(String path) async {
    await settings.setCustomDbPath(path);
  }

  void setApiFree(bool value) {
    isApiFree = value;
    safeNotify();
  }

  void setTargetLang(String value) {
    targetLang = value;
    safeNotify();
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
