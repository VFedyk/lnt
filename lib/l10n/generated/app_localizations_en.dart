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
  String get libraryTab => 'Library';

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
  String get libreTranslate => 'LibreTranslate';

  @override
  String get libreTranslateHint =>
      'Connect to a LibreTranslate server for translations';

  @override
  String get libreTranslateServerUrl => 'Server URL';

  @override
  String get libreTranslateApiKey => 'API Key';

  @override
  String get libreTranslateApiKeyOptional =>
      'API key is only required if the server needs authentication';

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
  String get activityHeatmap => 'Activity';

  @override
  String get less => 'Less';

  @override
  String get more => 'More';

  @override
  String get textsCompleted => 'Texts completed';

  @override
  String get wordsAdded => 'Words added';

  @override
  String get wordsReviewed => 'Words reviewed';

  @override
  String get noActivity => 'No activity';

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
  String get importFailedTitle => 'Import Failed';

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
  String charactersCount(int count) {
    return '$count characters';
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

  @override
  String textsTitle(String languageName) {
    return 'Texts - $languageName';
  }

  @override
  String get sort => 'Sort';

  @override
  String textCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texts',
      one: '1 text',
    );
    return '$_temp0';
  }

  @override
  String unknownCount(int count) {
    return '$count unknown';
  }

  @override
  String vocabularyTitle(String languageName) {
    return 'Vocabulary - $languageName';
  }

  @override
  String exportedTerms(int count) {
    return 'Exported $count terms';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String importedTerms(int count) {
    return 'Imported $count terms';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get all => 'All';

  @override
  String get statusIgnored => 'Ignored';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get statusLearning2 => 'Learning 2';

  @override
  String get statusLearning3 => 'Learning 3';

  @override
  String get statusLearning4 => 'Learning 4';

  @override
  String get statusKnown => 'Known';

  @override
  String get statusWellKnown => 'Well Known';

  @override
  String get addDictionariesQuestion => 'Add Dictionaries?';

  @override
  String addDictionariesPrompt(String name) {
    return 'Would you like to add dictionaries for $name?';
  }

  @override
  String get later => 'Later';

  @override
  String get addNow => 'Add Now';

  @override
  String dictionaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dictionaries',
      one: '1 dictionary',
    );
    return '$_temp0';
  }

  @override
  String get manageDictionaries => 'Manage Dictionaries';

  @override
  String get languageNameLabel => 'Language Name';

  @override
  String get languageNameHint => 'e.g., Spanish, Japanese, Chinese';

  @override
  String get languageCodeLabel => 'Language Code';

  @override
  String get languageCodeHint => 'e.g., en, de, uk, ja';

  @override
  String get rightToLeftText => 'Right-to-Left Text';

  @override
  String get rightToLeftHint => 'For languages like Arabic, Hebrew';

  @override
  String get showRomanization => 'Show Romanization';

  @override
  String get showRomanizationHint => 'Display pronunciation guide';

  @override
  String get splitByCharacter => 'Split by Character';

  @override
  String get splitByCharacterHint => 'For Chinese, Japanese (no spaces)';

  @override
  String get addDictionariesAfterCreating =>
      'Add dictionaries after creating the language';

  @override
  String errorLoadingTerms(String error) {
    return 'Error loading terms: $error';
  }

  @override
  String errorLoadingLanguages(String error) {
    return 'Error loading languages: $error';
  }

  @override
  String get noDictionariesConfigured => 'No dictionaries configured';

  @override
  String lookupWord(String word) {
    return 'Lookup \"$word\"';
  }

  @override
  String get cancelSelection => 'Cancel Selection';

  @override
  String get saveAsTerm => 'Save as Term';

  @override
  String get assignForeignLanguage => 'Assign foreign language';

  @override
  String get removeForeignMarking => 'Remove foreign marking';

  @override
  String get noOtherLanguages => 'No other languages configured';

  @override
  String get lookupInDictionary => 'Lookup in Dictionary';

  @override
  String get toggleLegend => 'Toggle Legend';

  @override
  String get wordList => 'Word List';

  @override
  String get fontSize => 'Font Size';

  @override
  String get markAllKnown => 'Mark All Known';

  @override
  String get markedAsFinished => 'Marked as Finished';

  @override
  String get markAsFinished => 'Mark as Finished';

  @override
  String wordsSelected(int count) {
    return '$count word(s) selected. Tap + to save as term or tap search to lookup.';
  }

  @override
  String get previewText => 'Preview Text';

  @override
  String get done => 'Done';

  @override
  String get markAllKnownQuestion => 'Mark All Known?';

  @override
  String get markAllKnownConfirm =>
      'This will mark all words in this text as \"Well Known\". Continue?';

  @override
  String get markAll => 'Mark All';

  @override
  String get allWordsMarkedKnown => 'All words marked as known';

  @override
  String get textMarkedFinished => 'Text marked as finished';

  @override
  String get textMarkedInProgress => 'Text marked as in progress';

  @override
  String get continueReading => 'Continue Reading?';

  @override
  String continueReadingPrompt(String title) {
    return 'Would you like to continue with the next text?\n\n\"$title\"';
  }

  @override
  String get termsByStatus => 'Terms by Status';

  @override
  String get progressOverview => 'Progress Overview';

  @override
  String percentKnown(String percent) {
    return '$percent% Known';
  }

  @override
  String get noTermsYet => 'No terms yet';

  @override
  String get learning => 'Learning';

  @override
  String dictionariesTitle(String languageName) {
    return 'Dictionaries - $languageName';
  }

  @override
  String get deleteDictionary => 'Delete Dictionary?';

  @override
  String deleteDictionaryConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deactivate => 'Deactivate';

  @override
  String get activate => 'Activate';

  @override
  String get noDictionariesYet => 'No dictionaries yet';

  @override
  String addDictionariesFor(String name) {
    return 'Add dictionaries for $name';
  }

  @override
  String get addDictionary => 'Add Dictionary';

  @override
  String get editDictionary => 'Edit Dictionary';

  @override
  String get help => 'Help';

  @override
  String get dictionaryHelp => 'Dictionary Help';

  @override
  String get howToUse => 'How to use:';

  @override
  String get dictionaryHelpStep1 => '1. Add dictionary URLs for this language';

  @override
  String get dictionaryHelpStep2 => '2. Use ### as placeholder for the word';

  @override
  String get dictionaryHelpStep3 => '3. Drag to reorder dictionaries';

  @override
  String get dictionaryHelpStep4 => '4. Toggle active/inactive';

  @override
  String get exampleUrls => 'Example URLs:';

  @override
  String get gotIt => 'Got it';

  @override
  String get dictionaryName => 'Dictionary Name';

  @override
  String get dictionaryNameHint => 'e.g., WordReference, Jisho';

  @override
  String get urlTemplate => 'URL Template';

  @override
  String get urlTemplateHint => 'https://example.com/dict?word=###';

  @override
  String get urlTemplateHelper => 'Use ### as placeholder for the word';

  @override
  String get urlMustContainPlaceholder => 'URL must contain ###';

  @override
  String get active => 'Active';

  @override
  String get showInDictionaryLookupMenu => 'Show in dictionary lookup menu';

  @override
  String get quickTemplates => 'Quick Templates:';

  @override
  String get dictionaryLookup => 'Dictionary Lookup';

  @override
  String get reload => 'Reload';

  @override
  String get back => 'Back';

  @override
  String get forward => 'Forward';

  @override
  String get openInBrowser => 'Open in Browser';

  @override
  String errorLoadingPage(String error) {
    return 'Error loading page: $error';
  }

  @override
  String errorOpeningBrowser(String error) {
    return 'Error opening browser: $error';
  }

  @override
  String get term => 'Term';

  @override
  String useOriginal(String text) {
    return 'Use original: $text';
  }

  @override
  String original(String text) {
    return 'Original: $text';
  }

  @override
  String get base => 'Base: ';

  @override
  String get removeLink => 'Remove link';

  @override
  String get linkToBaseForm => 'Link to base form...';

  @override
  String forms(String forms) {
    return 'Forms: $forms';
  }

  @override
  String get status => 'Status';

  @override
  String get language => 'Language: ';

  @override
  String get translation => 'Translation';

  @override
  String get translate => 'Translate';

  @override
  String get translateWithDeepL => 'Translate with DeepL';

  @override
  String get translateWithLibreTranslate => 'Translate with LibreTranslate';

  @override
  String get romanizationPronunciation => 'Romanization / Pronunciation';

  @override
  String get exampleSentence => 'Example Sentence';

  @override
  String get translationFailed =>
      'Translation failed. Check your API key and settings.';

  @override
  String languageNotSupported(String name) {
    return 'Language \"$name\" is not supported';
  }

  @override
  String get noDeepL => ' (no DeepL)';

  @override
  String get selectBaseForm => 'Select Base Form';

  @override
  String get noExistingTermsFound => 'No existing terms found';

  @override
  String get createNewBaseTerm => 'Create new base term';

  @override
  String get translationOptional => 'Translation (optional)';

  @override
  String createTerm(String term) {
    return 'Create \"$term\"';
  }

  @override
  String get statusLegendTitle => 'Status Legend';

  @override
  String get databaseSection => 'Database';

  @override
  String get databasePath => 'Database path';

  @override
  String get openDatabaseDirectory => 'Open Directory';

  @override
  String get changeDatabase => 'Change Database';

  @override
  String get restartRequired => 'Restart Required';

  @override
  String get databaseChangedMessage =>
      'The database has been changed. The application will now close. Please reopen it to use the new database.';

  @override
  String get posNoun => 'Noun';

  @override
  String get posVerb => 'Verb';

  @override
  String get posAdjective => 'Adjective';

  @override
  String get posAdverb => 'Adverb';

  @override
  String get posPronoun => 'Pronoun';

  @override
  String get posPreposition => 'Preposition';

  @override
  String get posConjunction => 'Conjunction';

  @override
  String get posInterjection => 'Interjection';

  @override
  String get posArticle => 'Article';

  @override
  String get posNumeral => 'Numeral';

  @override
  String get posParticle => 'Particle';

  @override
  String get posOther => 'Other';

  @override
  String get partOfSpeech => 'Part of speech';

  @override
  String get baseForm => 'Base form';

  @override
  String get meaning => 'Meaning';

  @override
  String get addTranslation => 'Add translation';

  @override
  String get translations => 'Translations';

  @override
  String get review => 'Review';

  @override
  String get showAnswer => 'Show Answer';

  @override
  String get rateAgain => 'Again';

  @override
  String get rateHard => 'Hard';

  @override
  String get rateGood => 'Good';

  @override
  String get rateEasy => 'Easy';

  @override
  String get noCardsDue => 'No cards due for review';

  @override
  String get reviewComplete => 'Review Complete!';

  @override
  String reviewedCount(int count) {
    return 'Reviewed $count cards';
  }

  @override
  String reviewProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get ignore => 'Ignore';

  @override
  String get unignore => 'Unignore';

  @override
  String get markWellKnown => 'Mark as Well Known';

  @override
  String get flashcardReview => 'Flashcard Review';

  @override
  String get flashcardReviewDescription =>
      'Review due cards with spaced repetition';

  @override
  String get statisticsDescription =>
      'View vocabulary progress and status breakdown';

  @override
  String get cardsDue => 'Cards due';

  @override
  String get reviewedToday => 'Reviewed today';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get backupToGoogleDrive => 'Back up to Google Drive';

  @override
  String get restoreFromGoogleDrive => 'Restore from Google Drive';

  @override
  String get backupToICloud => 'Back up to iCloud';

  @override
  String get restoreFromICloud => 'Restore from iCloud';

  @override
  String lastBackup(String date) {
    return 'Last backup: $date';
  }

  @override
  String get noBackupYet => 'No backup yet';

  @override
  String get backupSuccess => 'Backup completed successfully';

  @override
  String get restoreSuccess => 'Restore completed successfully.';

  @override
  String get restoreConfirmTitle => 'Restore Backup?';

  @override
  String get restoreConfirmMessage =>
      'This will replace all current data with the backup. This cannot be undone. Continue?';

  @override
  String get restore => 'Restore';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get noBackupFound => 'No backup found';

  @override
  String get signInCancelled => 'Sign-in was cancelled';
}
