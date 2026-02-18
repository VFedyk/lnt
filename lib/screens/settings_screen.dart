import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../service_locator.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/async_helpers.dart';
import '../utils/dialog_helpers.dart';
import '../utils/helpers.dart';
import '../utils/snackbar_helpers.dart';
import '../widgets/settings/ai_settings_section.dart';
import '../widgets/settings/app_language_section.dart';
import '../widgets/settings/backup_section.dart';
import '../widgets/settings/database_section.dart';
import '../widgets/settings/deepl_settings_section.dart';
import '../widgets/settings/deepl_usage_section.dart';
import '../widgets/settings/libretranslate_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _ltUrlController = TextEditingController();
  final _ltApiKeyController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();
  final _aiApiUrlController = TextEditingController();
  bool _obscureApiKey = true;
  bool _obscureLtApiKey = true;
  bool _obscureAiApiKey = true;
  String _aiProvider = SettingsService.aiProviderAuto;
  bool _controllersSeeded = false;

  static const _targetLanguages = {
    'EN': 'English',
    'UK': 'Ukrainian',
    'DE': 'German',
    'FR': 'French',
    'ES': 'Spanish',
    'IT': 'Italian',
    'NL': 'Dutch',
    'PL': 'Polish',
    'PT': 'Portuguese',
    'RU': 'Russian',
    'JA': 'Japanese',
    'ZH': 'Chinese',
    'KO': 'Korean',
    'BG': 'Bulgarian',
    'CS': 'Czech',
    'DA': 'Danish',
    'EL': 'Greek',
    'ET': 'Estonian',
    'FI': 'Finnish',
    'HU': 'Hungarian',
    'ID': 'Indonesian',
    'LV': 'Latvian',
    'LT': 'Lithuanian',
    'NB': 'Norwegian',
    'RO': 'Romanian',
    'SK': 'Slovak',
    'SL': 'Slovenian',
    'SV': 'Swedish',
    'TR': 'Turkish',
  };

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ltUrlController.dispose();
    _ltApiKeyController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _aiApiUrlController.dispose();
    super.dispose();
  }

  void _seedControllers(SettingsController ctrl) {
    if (!_controllersSeeded && !ctrl.isLoading) {
      _controllersSeeded = true;
      _apiKeyController.text = ctrl.initialApiKey;
      _ltUrlController.text = ctrl.initialLtUrl;
      _ltApiKeyController.text = ctrl.initialLtApiKey;
      _aiApiKeyController.text = ctrl.initialAiApiKey;
      _aiModelController.text = ctrl.initialAiModel;
      _aiApiUrlController.text = ctrl.initialAiApiUrl;
      _aiProvider = ctrl.initialAiProvider;
    }
  }

  Future<void> _saveSettings(SettingsController ctrl) async {
    await ctrl.saveSettings(
      apiKey: _apiKeyController.text,
      ltUrl: _ltUrlController.text,
      ltApiKey: _ltApiKeyController.text,
      aiApiKey: _aiApiKeyController.text,
      aiModel: _aiModelController.text,
      aiApiUrl: _aiApiUrlController.text,
      aiProvider: _aiProvider,
    );
    if (mounted) {
      SnackbarHelpers.showSuccess(
        context,
        AppLocalizations.of(context).settingsSaved,
      );
    }
  }

  Future<void> _backupToICloud(SettingsController ctrl) async {
    final l10n = AppLocalizations.of(context);
    await AsyncHelpers.run(
      context,
      operation: () => ctrl.backupToICloud(),
      successMessage: l10n.backupSuccess,
      errorMessageBuilder: (e) => l10n.backupFailed(e.toString()),
    );
  }

  Future<void> _restoreFromICloud(SettingsController ctrl) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmRestore();
    if (confirmed != true || !mounted) return;

    await AsyncHelpers.run(
      context,
      operation: () => ctrl.restoreFromICloud(),
      errorMessageBuilder: (e) => l10n.restoreFailed(e.toString()),
    );

    if (mounted) _showRestoreSuccess();
  }

  Future<bool?> _confirmRestore() {
    final l10n = AppLocalizations.of(context);
    return DialogHelpers.showDestructiveDialog(
      context,
      title: l10n.restoreConfirmTitle,
      message: l10n.restoreConfirmMessage,
      confirmText: l10n.restore,
    );
  }

  void _showRestoreSuccess() {
    final l10n = AppLocalizations.of(context);
    dataChanges.notifyAll();
    SnackbarHelpers.showSuccess(context, l10n.restoreSuccess);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openDatabaseDirectory(SettingsController ctrl) async {
    if (ctrl.dbPath == null) return;
    final dir = File(ctrl.dbPath!).parent;
    final uri = Uri.file(dir.path);
    await launchUrl(uri);
  }

  Future<void> _changeDatabase(SettingsController ctrl) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final newPath = result.files.single.path;
    if (newPath == null) return;

    await ctrl.setCustomDbPath(newPath);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.restartRequired),
        content: Text(l10n.databaseChangedMessage),
        actions: [
          TextButton(onPressed: () => exit(0), child: const Text('OK')),
        ],
      ),
    );
  }

  Color _usageColor(double usagePercent) {
    if (usagePercent > 0.9) return Theme.of(context).colorScheme.error;
    if (usagePercent > 0.7) return context.appColors.warning;
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildUsageSection(SettingsController ctrl) {
    return DeepLUsageSection(
      isLoadingUsage: ctrl.isLoadingUsage,
      usage: ctrl.usage,
      usageColor: _usageColor,
      onRetry: ctrl.loadUsage,
    );
  }

  Widget _buildDatabaseSection(SettingsController ctrl) {
    return DatabaseSection(
      l10n: AppLocalizations.of(context),
      dbPath: ctrl.dbPath ?? '',
      onOpenDatabaseDirectory: () => _openDatabaseDirectory(ctrl),
      onChangeDatabase: () => _changeDatabase(ctrl),
    );
  }

  Widget _buildBackupSection(SettingsController ctrl) {
    final l10n = AppLocalizations.of(context);
    final busy = ctrl.isBackingUp || ctrl.isRestoring;
    final backupLabel = ctrl.icloudLastBackup != null
        ? l10n.lastBackup(DateHelper.formatDateTime(ctrl.icloudLastBackup!))
        : l10n.noBackupYet;

    return BackupSection(
      l10n: l10n,
      isApplePlatform: PlatformHelper.isApple,
      busy: busy,
      iCloudBackupLabel: backupLabel,
      onBackupToICloud: () => _backupToICloud(ctrl),
      onRestoreFromICloud: () => _restoreFromICloud(ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsController()..loadSettings(),
      child: Builder(
        builder: (context) {
          final ctrl = context.watch<SettingsController>();
          _seedControllers(ctrl);

          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).settings),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            body: ctrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    children: [
                      AppLanguageSection(
                        l10n: AppLocalizations.of(context),
                        selectedLocale: context.watch<AppState>().locale,
                        onLocaleChanged: (locale) {
                          context.read<AppState>().setLocale(locale);
                        },
                      ),
                      if (PlatformHelper.isDesktop) ...[
                        const SizedBox(height: AppConstants.spacingL),
                        _buildDatabaseSection(ctrl),
                      ],
                      const SizedBox(height: AppConstants.spacingL),
                      _buildBackupSection(ctrl),
                      const SizedBox(height: AppConstants.spacingL),
                      DeepLSettingsSection(
                        l10n: AppLocalizations.of(context),
                        apiKeyController: _apiKeyController,
                        obscureApiKey: _obscureApiKey,
                        onToggleObscureApiKey: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
                        isApiFree: ctrl.isApiFree,
                        onApiTypeChanged: ctrl.setApiFree,
                        showUsage:
                            ctrl.isApiFree && _apiKeyController.text.isNotEmpty,
                        usageWidget: _buildUsageSection(ctrl),
                        targetLang: ctrl.targetLang,
                        targetLanguages: _targetLanguages,
                        onTargetLangChanged: ctrl.setTargetLang,
                      ),
                      const SizedBox(height: AppConstants.spacingL),
                      LibreTranslateSettingsSection(
                        l10n: AppLocalizations.of(context),
                        urlController: _ltUrlController,
                        apiKeyController: _ltApiKeyController,
                        obscureApiKey: _obscureLtApiKey,
                        onToggleObscureApiKey: () {
                          setState(() => _obscureLtApiKey = !_obscureLtApiKey);
                        },
                      ),
                      const SizedBox(height: AppConstants.spacingL),
                      AiSettingsSection(
                        l10n: AppLocalizations.of(context),
                        provider: _aiProvider,
                        onProviderChanged: (value) {
                          setState(() => _aiProvider = value);
                        },
                        apiKeyController: _aiApiKeyController,
                        modelController: _aiModelController,
                        apiUrlController: _aiApiUrlController,
                        obscureApiKey: _obscureAiApiKey,
                        onToggleObscureApiKey: () {
                          setState(() => _obscureAiApiKey = !_obscureAiApiKey);
                        },
                      ),
                      const SizedBox(height: AppConstants.spacingL),
                      ElevatedButton.icon(
                        onPressed: () => _saveSettings(ctrl),
                        icon: const Icon(Icons.save),
                        label: Text(AppLocalizations.of(context).saveSettings),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
