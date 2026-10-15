import 'package:flutter/material.dart';
import '../../data/services/system_dictionary_service.dart';
import '../../domain/entities/language.dart';
import '../../domain/value_objects/text_parsing_defaults.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../service_locator.dart';
import '../../utils/language_utils.dart';
import '../../utils/snackbar_helpers.dart';
import '../widgets/languages/language_advanced_tab.dart';
import '../widgets/languages/language_general_tab.dart';
import '../widgets/languages/language_presets.dart';

/// Full-screen editor for a [Language]; pops with the edited [Language].
class LanguageEditScreen extends StatefulWidget {
  final Language? language;

  const LanguageEditScreen({super.key, this.language});

  @override
  State<LanguageEditScreen> createState() => _LanguageEditScreenState();
}

class _LanguageEditScreenState extends State<LanguageEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TabController _tabController;
  late final TextEditingController _wordController;
  late final TextEditingController _sentenceController;
  LangPreset? _selectedPreset;
  late bool _showRomanization;
  late bool _splitByCharacter;
  late bool _useWordSegmentation;
  bool _systemDictionaryEnabled = true;

  /// The switch only applies on Apple platforms, to an existing language.
  bool get _showSystemDictionarySwitch =>
      SystemDictionaryService.isSupported && widget.language?.id != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final lang = widget.language;
    if (lang != null) {
      _selectedPreset =
          kLangPresets.where((p) => p.code == lang.languageCode).firstOrNull;
    }
    _showRomanization = lang?.showRomanization ?? false;
    _splitByCharacter =
        lang?.splitByCharacter ?? (_selectedPreset?.splitByCharacter ?? false);
    _useWordSegmentation = lang?.useWordSegmentation ??
        (_selectedPreset?.useWordSegmentation ?? false);
    _wordController = TextEditingController(
      text: TextParsingDefaults.effectiveWordPattern(
          lang?.regexpWordCharacters ?? ''),
    );
    _sentenceController = TextEditingController(
      text: TextParsingDefaults.effectiveSentencePattern(
          lang?.regexpSplitSentences ?? ''),
    );
    if (_showSystemDictionarySwitch) {
      settings.getSystemDictionaryEnabled(lang!.id!).then((v) {
        if (mounted) setState(() => _systemDictionaryEnabled = v);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wordController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  void _onPresetChanged(LangPreset? preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset != null) {
        _splitByCharacter = preset.splitByCharacter;
        _useWordSegmentation = preset.useWordSegmentation;
      }
    });
  }

  String _patternOrDefault(TextEditingController c, String fallback) {
    final v = c.text.trim();
    return v.isEmpty ? fallback : v;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      // The Form validates every tab; jump to Advanced if that is where it failed.
      final advancedError = (_splitByCharacter
              ? null
              : LanguageAdvancedTab.validatePattern(l10n, _wordController.text)) ??
          LanguageAdvancedTab.validatePattern(l10n, _sentenceController.text);
      if (advancedError != null) {
        _tabController.animateTo(1);
        SnackbarHelpers.showError(context, advancedError);
      } else {
        _tabController.animateTo(0);
      }
      return;
    }
    final preset = _selectedPreset!;
    final existing = widget.language;
    final lang = Language(
      id: existing?.id,
      name: localizedLangName(l10n, preset.code),
      languageCode: preset.code,
      rightToLeft: preset.rightToLeft,
      showRomanization: _showRomanization,
      splitByCharacter: _splitByCharacter,
      useWordSegmentation: _useWordSegmentation,
      characterSubstitutions: existing?.characterSubstitutions ?? '',
      // Ignored while splitting by character, so keep whatever is stored.
      regexpWordCharacters: _splitByCharacter
          ? (existing?.regexpWordCharacters ?? TextParsingDefaults.wordPattern)
          : _patternOrDefault(_wordController, TextParsingDefaults.wordPattern),
      regexpSplitSentences: _patternOrDefault(
          _sentenceController, TextParsingDefaults.sentencePattern),
      exceptionsSplitSentences: existing?.exceptionsSplitSentences ?? '',
    );
    if (_showSystemDictionarySwitch) {
      await settings.setSystemDictionaryEnabled(
          existing!.id!, _systemDictionaryEnabled);
    }
    if (!mounted) return;
    Navigator.pop(context, lang);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.language == null ? l10n.addLanguage : l10n.editLanguage,
        ),
        actions: [
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.languageTabGeneral),
            Tab(text: l10n.languageTabAdvanced),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            LanguageGeneralTab(
              selectedPreset: _selectedPreset,
              showRomanization: _showRomanization,
              splitByCharacter: _splitByCharacter,
              useWordSegmentation: _useWordSegmentation,
              onPresetChanged: _onPresetChanged,
              onRomanizationChanged: (v) =>
                  setState(() => _showRomanization = v),
              onSplitByCharacterChanged: (v) => setState(() {
                _splitByCharacter = v;
                if (!v) _useWordSegmentation = false;
              }),
              onWordSegmentationChanged: (v) =>
                  setState(() => _useWordSegmentation = v),
              systemDictionaryEnabled:
                  _showSystemDictionarySwitch ? _systemDictionaryEnabled : null,
              onSystemDictionaryChanged: _showSystemDictionarySwitch
                  ? (v) => setState(() => _systemDictionaryEnabled = v)
                  : null,
            ),
            LanguageAdvancedTab(
              wordController: _wordController,
              sentenceController: _sentenceController,
              splitByCharacter: _splitByCharacter,
            ),
          ],
        ),
      ),
    );
  }
}
