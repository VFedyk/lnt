import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../data/services/ai_explanation_service.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart';

class AiSettingsSection extends StatefulWidget {
  final AppLocalizations l10n;
  final String provider;
  final ValueChanged<String> onProviderChanged;
  final TextEditingController apiKeyController;
  final TextEditingController modelController;
  final TextEditingController apiUrlController;
  final bool obscureApiKey;
  final VoidCallback onToggleObscureApiKey;

  const AiSettingsSection({
    super.key,
    required this.l10n,
    required this.provider,
    required this.onProviderChanged,
    required this.apiKeyController,
    required this.modelController,
    required this.apiUrlController,
    required this.obscureApiKey,
    required this.onToggleObscureApiKey,
  });

  @override
  State<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends State<AiSettingsSection> {
  List<String>? _availableModels;
  bool _isFetching = false;
  String? _fetchError;
  Timer? _fetchTimer;

  @override
  void initState() {
    super.initState();
    widget.apiKeyController.addListener(_onAuthFieldChanged);
    widget.apiUrlController.addListener(_onAuthFieldChanged);
    _scheduleFetch(immediate: true);
  }

  @override
  void didUpdateWidget(AiSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiKeyController != widget.apiKeyController ||
        oldWidget.apiUrlController != widget.apiUrlController) {
      oldWidget.apiKeyController.removeListener(_onAuthFieldChanged);
      oldWidget.apiUrlController.removeListener(_onAuthFieldChanged);
      widget.apiKeyController.addListener(_onAuthFieldChanged);
      widget.apiUrlController.addListener(_onAuthFieldChanged);
    }
    if (oldWidget.provider != widget.provider) {
      _resetModels();
      _scheduleFetch();
    }
  }

  @override
  void dispose() {
    _fetchTimer?.cancel();
    widget.apiKeyController.removeListener(_onAuthFieldChanged);
    widget.apiUrlController.removeListener(_onAuthFieldChanged);
    super.dispose();
  }

  void _onAuthFieldChanged() => _scheduleFetch();

  void _scheduleFetch({bool immediate = false}) {
    _fetchTimer?.cancel();
    _fetchTimer = Timer(
      immediate ? Duration.zero : AppConstants.animationVerySlow,
      _fetchModels,
    );
  }

  void _resetModels() {
    if (mounted) setState(() { _availableModels = null; _fetchError = null; });
  }

  bool _canFetch() {
    final apiKey = widget.apiKeyController.text.trim();
    final apiUrl = widget.apiUrlController.text.trim();
    switch (widget.provider) {
      case SettingsService.aiProviderAnthropic:
        return apiKey.isNotEmpty;
      case SettingsService.aiProviderOllama:
        return apiUrl.isNotEmpty;
      case SettingsService.aiProviderOpenAiCompatible:
        return apiKey.isNotEmpty && apiUrl.isNotEmpty;
      case SettingsService.aiProviderAuto:
      default:
        final lowerUrl = apiUrl.toLowerCase();
        if (lowerUrl.contains('localhost:11434') ||
            lowerUrl.contains('127.0.0.1:11434') ||
            lowerUrl.contains('/api/chat') ||
            lowerUrl.contains('/api/generate')) {
          return apiUrl.isNotEmpty;
        }
        return apiKey.isNotEmpty && apiUrl.isNotEmpty;
    }
  }

  Future<void> _fetchModels() async {
    if (!_canFetch()) {
      _resetModels();
      return;
    }
    if (!mounted) return;
    setState(() { _isFetching = true; _fetchError = null; });
    try {
      final models = await AiExplanationService.fetchModels(
        provider: widget.provider,
        apiKey: widget.apiKeyController.text.trim(),
        apiUrl: widget.apiUrlController.text.trim(),
      );
      if (!mounted) return;
      setState(() { _availableModels = models; _isFetching = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isFetching = false; _fetchError = e.toString(); _availableModels = null; });
    }
  }

  Widget _buildModelField(BuildContext context) {
    final l10n = widget.l10n;

    if (_isFetching) {
      return TextField(
        controller: widget.modelController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: l10n.aiModelName,
          border: const OutlineInputBorder(),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_availableModels != null && _availableModels!.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownMenu<String>(
              controller: widget.modelController,
              expandedInsets: EdgeInsets.zero,
              label: Text(l10n.aiModelName),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
              ),
              dropdownMenuEntries: _availableModels!
                  .map((m) => DropdownMenuEntry(value: m, label: m))
                  .toList(),
              onSelected: (value) {
                if (value != null) widget.modelController.text = value;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.aiRefreshModels,
            onPressed: _fetchModels,
          ),
        ],
      );
    }

    return TextField(
      controller: widget.modelController,
      decoration: InputDecoration(
        labelText: l10n.aiModelName,
        border: const OutlineInputBorder(),
        hintText: SettingsService.defaultAiModel,
        suffixIcon: _canFetch()
            ? IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: _fetchError != null
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                tooltip: l10n.aiRefreshModels,
                onPressed: _fetchModels,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.aiAssistant,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.aiApiKeyHint,
              style: TextStyle(
                color: AppConstants.subtitleColor,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            DropdownButtonFormField<String>(
              initialValue: widget.provider,
              decoration: InputDecoration(
                labelText: l10n.aiProvider,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: SettingsService.aiProviderAuto,
                  child: Text(l10n.aiProviderAuto),
                ),
                DropdownMenuItem(
                  value: SettingsService.aiProviderOpenAiCompatible,
                  child: Text(l10n.aiProviderOpenAiCompatible),
                ),
                DropdownMenuItem(
                  value: SettingsService.aiProviderAnthropic,
                  child: Text(l10n.aiProviderAnthropic),
                ),
                DropdownMenuItem(
                  value: SettingsService.aiProviderOllama,
                  child: Text(l10n.aiProviderOllama),
                ),
              ],
              onChanged: (value) {
                if (value != null) widget.onProviderChanged(value);
              },
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.aiProviderHint,
              style: TextStyle(
                color: AppConstants.subtitleColor,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            TextField(
              controller: widget.apiKeyController,
              decoration: InputDecoration(
                labelText: l10n.aiApiKey,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    widget.obscureApiKey
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: widget.onToggleObscureApiKey,
                ),
              ),
              obscureText: widget.obscureApiKey,
            ),
            const SizedBox(height: AppConstants.spacingL),
            _buildModelField(context),
            if (_fetchError != null) ...[
              const SizedBox(height: AppConstants.spacingXS),
              Text(
                _fetchError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: AppConstants.fontSizeCaption,
                ),
              ),
            ],
            const SizedBox(height: AppConstants.spacingL),
            TextField(
              controller: widget.apiUrlController,
              decoration: InputDecoration(
                labelText: l10n.aiApiUrl,
                border: const OutlineInputBorder(),
                hintText: SettingsService.defaultAiApiUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
