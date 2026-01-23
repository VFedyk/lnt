import 'package:flutter/material.dart';
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
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                              'DeepL Translation',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get your API key from deepl.com/pro-api',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyController,
                          decoration: InputDecoration(
                            labelText: 'DeepL API Key',
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
                          'API Type',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Free')),
                            ButtonSegment(value: false, label: Text('Pro')),
                          ],
                          selected: {_isApiFree},
                          onSelectionChanged: (selected) {
                            setState(() => _isApiFree = selected.first);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isApiFree
                              ? "Free API: 500,000 characters/month (${_usage?.charactersRemaining} remaining)"
                              : 'Pro API: Pay per usage',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Target Language',
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
                          'Language for translations',
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
                  label: const Text('Save Settings'),
                ),
              ],
            ),
    );
  }
}
