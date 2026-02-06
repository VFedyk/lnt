import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/deepl_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

abstract class _SettingsScreenConstants {
  static const double errorIconSize = 20.0;
  static const double progressBarHeight = 8.0;
  static const double usageWarningThreshold = 0.7;
  static const double usageCriticalThreshold = 0.9;
  // percent formatting: use 100 and 1 literals directly
  static const int millionThreshold = 1000000;
  static const int thousandThreshold = 1000;
  static const int numberDecimalPlacesMillion = 1;
  static const int numberDecimalPlacesThousand = 0;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _isApiFree = true;
  bool _isLoading = true;
  bool _obscureApiKey = true;
  String _targetLang = SettingsService.defaultTargetLang;
  DeepLUsage? _usage;
  bool _isLoadingUsage = false;
  String? _dbPath;

  // LibreTranslate
  final _ltUrlController = TextEditingController();
  final _ltApiKeyController = TextEditingController();
  bool _obscureLtApiKey = true;

  static bool get _isDesktop => PlatformHelper.isDesktop;

  // Supported DeepL target languages
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
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await SettingsService.instance.getDeepLApiKey();
    final isFree = await SettingsService.instance.isDeepLApiFree();
    final targetLang = await SettingsService.instance.getDeepLTargetLang();

    // LibreTranslate settings
    final ltUrl = await SettingsService.instance.getLibreTranslateUrl();
    final ltApiKey = await SettingsService.instance.getLibreTranslateApiKey();

    // Load DB path on desktop
    String? dbPath;
    if (_isDesktop) {
      await DatabaseService.instance.database; // ensure initialized
      dbPath = DatabaseService.instance.currentDbPath;
    }

    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _isApiFree = isFree;
        _targetLang = targetLang;
        _ltUrlController.text = ltUrl ?? '';
        _ltApiKeyController.text = ltApiKey ?? '';
        _dbPath = dbPath;
        _isLoading = false;
      });
    }

    // Load usage if API key is set
    if (apiKey != null && apiKey.isNotEmpty) {
      _loadUsage();
    }
  }

  Future<void> _loadUsage() async {
    setState(() => _isLoadingUsage = true);
    final usage = await DeepLService.instance.getUsage();
    if (mounted) {
      setState(() {
        _usage = usage;
        _isLoadingUsage = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await SettingsService.instance.setDeepLApiKey(
      _apiKeyController.text.trim(),
    );
    await SettingsService.instance.setDeepLApiFree(_isApiFree);
    await SettingsService.instance.setDeepLTargetLang(_targetLang);
    await SettingsService.instance.setLibreTranslateUrl(
      _ltUrlController.text.trim(),
    );
    await SettingsService.instance.setLibreTranslateApiKey(
      _ltApiKeyController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)));
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ltUrlController.dispose();
    _ltApiKeyController.dispose();
    super.dispose();
  }

  Color _usageColor(double usagePercent) {
    if (usagePercent > _SettingsScreenConstants.usageCriticalThreshold) {
      return Theme.of(context).colorScheme.error;
    } else if (usagePercent > _SettingsScreenConstants.usageWarningThreshold) {
      return AppConstants.warningColor;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildUsageSection() {
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingL),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: _isLoadingUsage
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
            : _usage == null
                ? Row(
                    children: [
                      Icon(Icons.error_outline,
                           color: Theme.of(context).colorScheme.error,
                           size: _SettingsScreenConstants.errorIconSize),
                      const SizedBox(width: AppConstants.spacingS),
                      Expanded(
                        child: Text(AppLocalizations.of(context).couldNotLoadUsage),
                      ),
                      TextButton(
                        onPressed: _loadUsage,
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
                            '${(_usage!.usagePercent * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _usageColor(_usage!.usagePercent),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                        child: LinearProgressIndicator(
                          value: _usage!.usagePercent,
                          minHeight: _SettingsScreenConstants.progressBarHeight,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _usageColor(_usage!.usagePercent),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      Text(
                        AppLocalizations.of(context).charactersUsed(
                          _formatNumber(_usage!.characterCount),
                          _formatNumber(_usage!.characterLimit),
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: AppConstants.fontSizeCaption,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context).charactersRemaining(
                          _formatNumber(_usage!.charactersRemaining),
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

  Widget _buildDatabaseSection() {
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
                Text(
                  l10n.databaseSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              l10n.databasePath,
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
                _dbPath ?? '',
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
                  onPressed: _openDatabaseDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.openDatabaseDirectory),
                ),
                OutlinedButton.icon(
                  onPressed: _changeDatabase,
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

  Future<void> _openDatabaseDirectory() async {
    if (_dbPath == null) return;
    final dir = File(_dbPath!).parent;
    final uri = Uri.file(dir.path);
    await launchUrl(uri);
  }

  Future<void> _changeDatabase() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final newPath = result.files.single.path;
    if (newPath == null) return;

    await SettingsService.instance.setCustomDbPath(newPath);

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

  String _formatNumber(int number) {
    if (number >= _SettingsScreenConstants.millionThreshold) {
      return '${(number / _SettingsScreenConstants.millionThreshold).toStringAsFixed(_SettingsScreenConstants.numberDecimalPlacesMillion)}M';
    } else if (number >= _SettingsScreenConstants.thousandThreshold) {
      return '${(number / _SettingsScreenConstants.thousandThreshold).toStringAsFixed(_SettingsScreenConstants.numberDecimalPlacesThousand)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
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
                  _buildDatabaseSection(),
                ],
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
                                _obscureApiKey
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureApiKey = !_obscureApiKey,
                                );
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
                          selected: {_isApiFree},
                          onSelectionChanged: (selected) {
                            setState(() => _isApiFree = selected.first);
                          },
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        Text(
                          _isApiFree
                              ? AppLocalizations.of(context).freeApiLimit
                              : AppLocalizations.of(context).proApiPayPerUse,
                          style: TextStyle(
                            color: AppConstants.subtitleColor,
                            fontSize: AppConstants.fontSizeCaption,
                          ),
                        ),
                        // Usage display for free plan
                        if (_isApiFree && _apiKeyController.text.isNotEmpty)
                          _buildUsageSection(),
                        const SizedBox(height: AppConstants.spacingL),
                        Text(
                          AppLocalizations.of(context).targetLanguage,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        DropdownButtonFormField<String>(
                          initialValue: _targetLang,
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
                            if (value != null) {
                              setState(() => _targetLang = value);
                            }
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
                                _obscureLtApiKey
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureLtApiKey = !_obscureLtApiKey,
                                );
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
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: Text(AppLocalizations.of(context).saveSettings),
                ),
              ],
            ),
    );
  }
}
