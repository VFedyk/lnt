// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Language Nerd Tools';

  @override
  String get home => 'Home';

  @override
  String get texts => 'Texts';

  @override
  String get vocabulary => 'Vocabulary';

  @override
  String get stats => 'Stats';

  @override
  String get languages => 'Languages';

  @override
  String get settings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Retry';

  @override
  String get create => 'Create';

  @override
  String get import => 'Import';

  @override
  String get export => 'Export';

  @override
  String get close => 'Close';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get search => 'Search';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get warning => 'Warning';

  @override
  String get confirm => 'Confirm';

  @override
  String get appLanguage => 'App Language';

  @override
  String get english => 'English';

  @override
  String get ukrainian => 'Ukrainian';

  @override
  String get deepLTranslation => 'DeepL Translation';

  @override
  String get deepLApiKey => 'DeepL API Key';

  @override
  String get deepLApiKeyHint => 'Get your API key from deepl.com/pro-api';

  @override
  String get apiType => 'API Type';

  @override
  String get free => 'Free';

  @override
  String get pro => 'Pro';

  @override
  String get freeApiLimit => 'Free API: 500,000 characters/month';

  @override
  String get proApiPayPerUse => 'Pro API: Pay per usage';

  @override
  String get targetLanguage => 'Target Language';

  @override
  String get languageForTranslations => 'Language for translations';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get monthlyUsage => 'Monthly Usage';

  @override
  String get couldNotLoadUsage => 'Could not load usage. Check your API key.';

  @override
  String get loadingUsage => 'Loading usage...';

  @override
  String charactersRemaining(String count) {
    return '$count characters remaining';
  }

  @override
  String charactersUsed(String used, String limit) {
    return '$used / $limit characters';
  }

  @override
  String get noLanguagesYet => 'No Languages Yet';

  @override
  String get addLanguageToStart => 'Add a language to get started';

  @override
  String get addLanguage => 'Add Language';

  @override
  String get editLanguage => 'Edit Language';

  @override
  String get deleteLanguageQuestion => 'Delete Language?';

  @override
  String deleteLanguageConfirm(String name) {
    return 'This will delete \"$name\" and all associated texts, terms, and dictionaries. Continue?';
  }

  @override
  String get totalTerms => 'Total Terms';

  @override
  String get known => 'Known';

  @override
  String get unknown => 'Unknown';

  @override
  String unknownWords(int count) {
    return '$count unknown words';
  }

  @override
  String unknownCharacters(int count) {
    return '$count unknown characters';
  }

  @override
  String get completed => 'Completed!';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get addText => 'Add Text';

  @override
  String get importVocabulary => 'Import Vocabulary';

  @override
  String get recentlyRead => 'Recently read';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get noTextsReadYet => 'No texts read yet.';

  @override
  String get noTextsYetAddOne => 'No texts yet. Add one to get started!';

  @override
  String get searchTexts => 'Search texts...';

  @override
  String get searchTerms => 'Search terms...';

  @override
  String get noCollectionsOrTexts => 'No collections or texts';

  @override
  String get allTextsCompleted => 'All texts completed!';

  @override
  String get showCompletedTexts => 'Show completed texts';

  @override
  String get hideCompletedTexts => 'Hide completed texts';

  @override
  String completedHidden(int count) {
    return '$count completed hidden';
  }

  @override
  String get importFromUrl => 'Import from URL';

  @override
  String get importTxt => 'Import TXT';

  @override
  String get importEpub => 'Import EPUB';

  @override
  String get importingEpub => 'Importing EPUB...';

  @override
  String get importComplete => 'Import Complete';

  @override
  String get importFailed => 'Import Failed';

  @override
  String couldNotImportEpub(String error) {
    return 'Could not import EPUB: $error';
  }

  @override
  String get newCollection => 'New Collection';

  @override
  String get editCollection => 'Edit Collection';

  @override
  String get deleteCollection => 'Delete Collection?';

  @override
  String deleteCollectionConfirm(String name, int count) {
    return 'Delete \"$name\" and its $count text(s)?';
  }

  @override
  String deleteCollectionSimple(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteText => 'Delete Text?';

  @override
  String deleteTextConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get editText => 'Edit Text';

  @override
  String get title => 'Title';

  @override
  String get textContent => 'Text Content';

  @override
  String get setCover => 'Set Cover';

  @override
  String get addCover => 'Add Cover';

  @override
  String get removeCover => 'Remove Cover';

  @override
  String get noTermsFound => 'No terms found';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportAnki => 'Export Anki';

  @override
  String get name => 'Name';

  @override
  String get description => 'Description';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get required => 'Required';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByDateAdded => 'Date Added';

  @override
  String get sortByLastRead => 'Last Read';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String get switchToListView => 'Switch to list view';

  @override
  String get switchToGridView => 'Switch to grid view';

  @override
  String get url => 'URL';

  @override
  String get urlHint => 'https://example.com/article';

  @override
  String get fetchContent => 'Fetch content';

  @override
  String get preview => 'Preview';

  @override
  String wordsCount(int count) {
    return '$count words';
  }

  @override
  String get pleaseEnterUrl => 'Please enter a URL';

  @override
  String get pleaseEnterTitle => 'Please enter a title';

  @override
  String get book => 'Book';

  @override
  String get author => 'Author';

  @override
  String get chapters => 'Chapters';

  @override
  String get totalParts => 'Total parts';

  @override
  String get characters => 'Characters';

  @override
  String get notes => 'Notes';
}
