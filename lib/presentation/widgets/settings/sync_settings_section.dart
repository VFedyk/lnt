import 'package:flutter/material.dart';

import '../../../service_locator.dart';
import '../../../utils/constants.dart';
import '../../../utils/snackbar_helpers.dart';

class SyncSettingsSection extends StatefulWidget {
  const SyncSettingsSection({super.key});

  @override
  State<SyncSettingsSection> createState() => _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends State<SyncSettingsSection> {
  final _serverUrlController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _loaded = false;
  bool _syncing = false;
  String? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final url = await settings.getSyncServerUrl();
    final nickname = await settings.getSyncNickname();
    final lastPushedAt = await settings.getSyncLastPushedAt();
    if (!mounted) return;
    setState(() {
      _serverUrlController.text = url ?? '';
      _nicknameController.text = nickname ?? '';
      _lastSyncedAt = lastPushedAt?.toLocal().toString().substring(0, 16);
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await settings.setSyncServerUrl(_serverUrlController.text);
    await settings.setSyncNickname(_nicknameController.text);
    await settings.clearSyncState();
    if (mounted) SnackbarHelpers.showSuccess(context, 'Sync settings saved');
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await syncService.sync();
      final lastPushedAt = await settings.getSyncLastPushedAt();
      if (!mounted) return;
      setState(() {
        _lastSyncedAt = lastPushedAt?.toLocal().toString().substring(0, 16);
      });
      SnackbarHelpers.showSuccess(context, 'Sync completed');
    } catch (e) {
      if (mounted) SnackbarHelpers.showError(context, 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final captionStyle = TextStyle(
      fontSize: AppConstants.fontSizeCaption,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync),
                const SizedBox(width: AppConstants.spacingS),
                Text('Sync', style: Theme.of(context).textTheme.titleMedium),
                if (_syncing) ...[
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
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.only(top: AppConstants.spacingM),
                child: CircularProgressIndicator(),
              )
            else ...[
              const SizedBox(height: AppConstants.spacingL),
              TextField(
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.1.1:3000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppConstants.spacingM),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  hintText: 'your-nickname',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_lastSyncedAt != null) ...[
                const SizedBox(height: AppConstants.spacingS),
                Text('Last synced: $_lastSyncedAt', style: captionStyle),
              ],
              const SizedBox(height: AppConstants.spacingM),
              Wrap(
                spacing: AppConstants.spacingS,
                runSpacing: AppConstants.spacingS,
                children: [
                  OutlinedButton.icon(
                    onPressed: _syncing ? null : _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _syncing ? null : _sync,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
