import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../service_locator.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

abstract class _SettingsScreenConstants {
  static const double usageBarHeight = 8.0;
  static const double usageErrorIconSize = 20.0;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _ltUrlController = TextEditingController();
  final _ltApiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _obscureLtApiKey = true;
  bool _controllersSeeded = false;

  static bool get _isDesktop => PlatformHelper.isDesktop;

  static const _targetLanguages = {
    'EN': 'English',
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
    'UK': 'Ukrainian',
  };

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ltUrlController.dispose();
    _ltApiKeyController.dispose();
    super.dispose();
  }

  void _seedControllers(SettingsController ctrl) {
    if (!_controllersSeeded && !ctrl.isLoading) {
      _controllersSeeded = true;
      _apiKeyController.text = ctrl.initialApiKey;
      _ltUrlController.text = ctrl.initialLtUrl;
      _ltApiKeyController.text = ctrl.initialLtApiKey;
    }
  }

  Future<void> _saveSettings(SettingsController ctrl) async {
    await ctrl.saveSettings(
      apiKey: _apiKeyController.text,
      ltUrl: _ltUrlController.text,
      ltApiKey: _ltApiKeyController.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
      );
    }
  }

  Future<void> _backupToICloud(SettingsController ctrl) async {
    try {
      await ctrl.backupToICloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).backupSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).backupFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _restoreFromICloud(SettingsController ctrl) async {
    final confirmed = await _confirmRestore();
    if (confirmed != true) return;
    try {
      await ctrl.restoreFromICloud();
      if (mounted) _showRestoreSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).restoreFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<bool?> _confirmRestore() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.restore),
          ),
        ],
      ),
    );
  }

  void _showRestoreSuccess() {
    final l10n = AppLocalizations.of(context);
    dataChanges.notifyAll();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.restoreSuccess)),
    );
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
          TextButton(
            onPressed: () => exit(0),
            child: const Text('OK'),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingL),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: ctrl.isLoadingUsage
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: AppConstants.progressIndicatorSizeS,
                    height: AppConstants.progressIndicatorSizeS,
                    child: const CircularProgressIndicator(
                      strokeWidth: AppConstants.progressStrokeWidth,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Text(AppLocalizations.of(context).loadingUsage),
                ],
              )
            : ctrl.usage == null
                ? Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: _SettingsScreenConstants.usageErrorIconSize),
                      const SizedBox(width: AppConstants.spacingS),
                      Expanded(
                        child: Text(AppLocalizations.of(context).couldNotLoadUsage),
                      ),
                      TextButton(
                        onPressed: ctrl.loadUsage,
                        child: Text(AppLocalizations.of(context).retry),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).monthlyUsage,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${(ctrl.usage!.usagePercent * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _usageColor(ctrl.usage!.usagePercent),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                        child: LinearProgressIndicator(
                          value: ctrl.usage!.usagePercent,
                          minHeight: _SettingsScreenConstants.usageBarHeight,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _usageColor(ctrl.usage!.usagePercent),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      Text(
                        AppLocalizations.of(context).charactersUsed(
                          SettingsController.formatNumber(ctrl.usage!.characterCount),
                          SettingsController.formatNumber(ctrl.usage!.characterLimit),
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: AppConstants.fontSizeCaption,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context).charactersRemaining(
                          SettingsController.formatNumber(ctrl.usage!.charactersRemaining),
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: AppConstants.fontSizeCaption,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDatabaseSection(SettingsController ctrl) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage),
                const SizedBox(width: AppConstants.spacingS),
                Text(l10n.databaseSection, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(l10n.databasePath, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppConstants.spacingS),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: SelectableText(
                ctrl.dbPath ?? '',
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingS,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openDatabaseDirectory(ctrl),
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.openDatabaseDirectory),
                ),
                OutlinedButton.icon(
                  onPressed: () => _changeDatabase(ctrl),
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(l10n.changeDatabase),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection(SettingsController ctrl) {
    final l10n = AppLocalizations.of(context);
    final dateHelper = DateHelper.formatDateTime;
    final busy = ctrl.isBackingUp || ctrl.isRestoring;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud),
                const SizedBox(width: AppConstants.spacingS),
                Text(l10n.backupRestore, style: Theme.of(context).textTheme.titleMedium),
                if (busy) ...[
                  const SizedBox(width: AppConstants.spacingM),
                  SizedBox(
                    width: AppConstants.progressIndicatorSizeS,
                    height: AppConstants.progressIndicatorSizeS,
                    child: const CircularProgressIndicator(
                      strokeWidth: AppConstants.progressStrokeWidth,
                    ),
                  ),
                ],
              ],
            ),
            if (PlatformHelper.isApple) ...[
              const SizedBox(height: AppConstants.spacingL),
              Text('iCloud', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppConstants.spacingXS),
              Text(
                ctrl.icloudLastBackup != null
                    ? l10n.lastBackup(dateHelper(ctrl.icloudLastBackup!))
                    : l10n.noBackupYet,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Wrap(
                spacing: AppConstants.spacingS,
                runSpacing: AppConstants.spacingS,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _backupToICloud(ctrl),
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(l10n.backupToICloud),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _restoreFromICloud(ctrl),
                    icon: const Icon(Icons.cloud_download),
                    label: Text(l10n.restoreFromICloud),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsController()..loadSettings(),
      child: Builder(builder: (context) {
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
                    // App Language Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.language),
                                const SizedBox(width: AppConstants.spacingS),
                                Text(
                                  AppLocalizations.of(context).appLanguage,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingL),
                            SegmentedButton<Locale>(
                              segments: [
                                ButtonSegment(
                                  value: const Locale('en'),
                                  label: Text(AppLocalizations.of(context).english),
                                ),
                                ButtonSegment(
                                  value: const Locale('uk'),
                                  label: Text(AppLocalizations.of(context).ukrainian),
                                ),
                              ],
                              selected: {context.watch<AppState>().locale},
                              onSelectionChanged: (selected) {
                                context.read<AppState>().setLocale(selected.first);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isDesktop) ...[
                      const SizedBox(height: AppConstants.spacingL),
                      _buildDatabaseSection(ctrl),
                    ],
                    const SizedBox(height: AppConstants.spacingL),
                    _buildBackupSection(ctrl),
                    const SizedBox(height: AppConstants.spacingL),
                    // DeepL API Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.translate),
                                const SizedBox(width: AppConstants.spacingS),
                                Text(
                                  AppLocalizations.of(context).deepLTranslation,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            Text(
                              AppLocalizations.of(context).deepLApiKeyHint,
                              style: TextStyle(
                                color: AppConstants.subtitleColor,
                                fontSize: AppConstants.fontSizeCaption,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingL),
                            TextField(
                              controller: _apiKeyController,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).deepLApiKey,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureApiKey = !_obscureApiKey);
                                  },
                                ),
                              ),
                              obscureText: _obscureApiKey,
                            ),
                            const SizedBox(height: AppConstants.spacingL),
                            Text(
                              AppLocalizations.of(context).apiType,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(value: true, label: Text(AppLocalizations.of(context).free)),
                                ButtonSegment(value: false, label: Text(AppLocalizations.of(context).pro)),
                              ],
                              selected: {ctrl.isApiFree},
                              onSelectionChanged: (selected) {
                                ctrl.setApiFree(selected.first);
                              },
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            Text(
                              ctrl.isApiFree
                                  ? AppLocalizations.of(context).freeApiLimit
                                  : AppLocalizations.of(context).proApiPayPerUse,
                              style: TextStyle(
                                color: AppConstants.subtitleColor,
                                fontSize: AppConstants.fontSizeCaption,
                              ),
                            ),
                            if (ctrl.isApiFree && _apiKeyController.text.isNotEmpty)
                              _buildUsageSection(ctrl),
                            const SizedBox(height: AppConstants.spacingL),
                            Text(
                              AppLocalizations.of(context).targetLanguage,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            DropdownButtonFormField<String>(
                              initialValue: ctrl.targetLang,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: AppConstants.spacingM,
                                  vertical: AppConstants.spacingS,
                                ),
                              ),
                              items: _targetLanguages.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) ctrl.setTargetLang(value);
                              },
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            Text(
                              AppLocalizations.of(context).languageForTranslations,
                              style: TextStyle(
                                color: AppConstants.subtitleColor,
                                fontSize: AppConstants.fontSizeCaption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingL),
                    // LibreTranslate Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.g_translate),
                                const SizedBox(width: AppConstants.spacingS),
                                Text(
                                  AppLocalizations.of(context).libreTranslate,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            Text(
                              AppLocalizations.of(context).libreTranslateHint,
                              style: TextStyle(
                                color: AppConstants.subtitleColor,
                                fontSize: AppConstants.fontSizeCaption,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingL),
                            TextField(
                              controller: _ltUrlController,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).libreTranslateServerUrl,
                                border: const OutlineInputBorder(),
                                hintText: 'https://libretranslate.com',
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingL),
                            TextField(
                              controller: _ltApiKeyController,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).libreTranslateApiKey,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureLtApiKey ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureLtApiKey = !_obscureLtApiKey);
                                  },
                                ),
                              ),
                              obscureText: _obscureLtApiKey,
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            Text(
                              AppLocalizations.of(context).libreTranslateApiKeyOptional,
                              style: TextStyle(
                                color: AppConstants.subtitleColor,
                                fontSize: AppConstants.fontSizeCaption,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      }),
    );
  }
}
