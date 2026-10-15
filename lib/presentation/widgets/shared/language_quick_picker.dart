import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';
import '../../../utils/language_utils.dart';
import '../languages/language_presets.dart';

/// Search + "Popular" chips for adding a language in one tap. Holds no DB
/// access: the host decides what a tap does via [onPresetSelected].
class LanguageQuickPicker extends StatefulWidget {
  /// Language codes already added; hidden from the picker.
  final Set<String> existingCodes;
  final Future<void> Function(LangPreset) onPresetSelected;
  final VoidCallback onCustomSettings;

  const LanguageQuickPicker({
    super.key,
    required this.existingCodes,
    required this.onPresetSelected,
    required this.onCustomSettings,
  });

  @override
  State<LanguageQuickPicker> createState() => _LanguageQuickPickerState();
}

class _LanguageQuickPickerState extends State<LanguageQuickPicker> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _select(LangPreset preset) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPresetSelected(preset);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(AppLocalizations l10n, LangPreset preset) {
    final flag = preset.flagEmoji;
    final name = localizedLangName(l10n, preset.code);
    return flag.isEmpty ? name : '$flag $name';
  }

  bool _matches(AppLocalizations l10n, LangPreset preset, String query) =>
      localizedLangName(l10n, preset.code).toLowerCase().contains(query) ||
      preset.name.toLowerCase().contains(query) ||
      preset.code.toLowerCase().contains(query);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final textTheme = Theme.of(context).textTheme;
    final captionStyle = textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    final query = _query.trim().toLowerCase();
    final available = kLangPresets
        .where((p) => !widget.existingCodes.contains(p.code))
        .toList();
    final searching = query.isNotEmpty;
    final popular = [
      for (final code in kPopularLangCodes)
        ...available.where((p) => p.code == code),
    ];
    final listed = sortedLangPresets(
      l10n,
      locale,
      searching ? available.where((p) => _matches(l10n, p, query)) : available,
    );

    final children = <Widget>[
      if (!searching && popular.isNotEmpty) ...[
        Text(l10n.popularLanguages, style: captionStyle),
        const SizedBox(height: AppConstants.spacingS),
        Wrap(
          spacing: AppConstants.spacingS,
          runSpacing: AppConstants.spacingS,
          children: [
            for (final preset in popular)
              ActionChip(
                label: Text(_label(l10n, preset)),
                onPressed: _busy ? null : () => _select(preset),
              ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingL),
        if (listed.isNotEmpty) Text(l10n.allLanguages, style: captionStyle),
      ],
      if (listed.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingL),
          child: Center(child: Text(l10n.noMatchingLanguages)),
        )
      else
        for (final preset in listed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              preset.flagEmoji,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(localizedLangName(l10n, preset.code)),
            enabled: !_busy,
            onTap: () => _select(preset),
          ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchLanguages,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingL,
                ),
                children: children,
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: _busy ? null : widget.onCustomSettings,
                icon: const Icon(Icons.tune),
                label: Text(l10n.customLanguageSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
