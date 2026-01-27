import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/deepl_service.dart';

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

    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _isApiFree = isFree;
        _targetLang = targetLang;
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

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)));
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Widget _buildUsageSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: _isLoadingUsage
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).loadingUsage),
                ],
              )
            : _usage == null
                ? Row(
                    children: [
                      Icon(Icons.error_outline,
                           color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
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
                              color: _usage!.usagePercent > 0.9
                                  ? Theme.of(context).colorScheme.error
                                  : _usage!.usagePercent > 0.7
                                      ? Colors.orange
                                      : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _usage!.usagePercent,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _usage!.usagePercent > 0.9
                                ? Theme.of(context).colorScheme.error
                                : _usage!.usagePercent > 0.7
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).charactersUsed(
                          _formatNumber(_usage!.characterCount),
                          _formatNumber(_usage!.characterLimit),
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context).charactersRemaining(
                          _formatNumber(_usage!.charactersRemaining),
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
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
              padding: const EdgeInsets.all(16),
              children: [
                // App Language Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.language),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context).appLanguage,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                // DeepL API Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.translate),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context).deepLTranslation,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).deepLApiKeyHint,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).apiType,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        Text(
                          _isApiFree
                              ? AppLocalizations.of(context).freeApiLimit
                              : AppLocalizations.of(context).proApiPayPerUse,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        // Usage display for free plan
                        if (_isApiFree && _apiKeyController.text.isNotEmpty)
                          _buildUsageSection(),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).targetLanguage,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _targetLang,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
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
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).languageForTranslations,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
