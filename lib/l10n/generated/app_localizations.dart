import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// The app title
  ///
  /// In en, this message translates to:
  /// **'Language Nerd Tools'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @libraryTab.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTab;

  /// No description provided for @texts.
  ///
  /// In en, this message translates to:
  /// **'Texts'**
  String get texts;

  /// No description provided for @textsFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get textsFinished;

  /// No description provided for @vocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get vocabulary;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @failedToLoadData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get failedToLoadData;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @ukrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get ukrainian;

  /// No description provided for @deepLTranslation.
  ///
  /// In en, this message translates to:
  /// **'DeepL Translation'**
  String get deepLTranslation;

  /// No description provided for @deepLApiKey.
  ///
  /// In en, this message translates to:
  /// **'DeepL API Key'**
  String get deepLApiKey;

  /// No description provided for @deepLApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get your API key from deepl.com/pro-api'**
  String get deepLApiKeyHint;

  /// No description provided for @apiType.
  ///
  /// In en, this message translates to:
  /// **'API Type'**
  String get apiType;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @freeApiLimit.
  ///
  /// In en, this message translates to:
  /// **'Free API: 500,000 characters/month'**
  String get freeApiLimit;

  /// No description provided for @proApiPayPerUse.
  ///
  /// In en, this message translates to:
  /// **'Pro API: Pay per usage'**
  String get proApiPayPerUse;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get targetLanguage;

  /// No description provided for @languageForTranslations.
  ///
  /// In en, this message translates to:
  /// **'Language for translations'**
  String get languageForTranslations;

  /// No description provided for @libreTranslate.
  ///
  /// In en, this message translates to:
  /// **'LibreTranslate'**
  String get libreTranslate;

  /// No description provided for @libreTranslateHint.
  ///
  /// In en, this message translates to:
  /// **'Connect to a LibreTranslate server for translations'**
  String get libreTranslateHint;

  /// No description provided for @libreTranslateServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get libreTranslateServerUrl;

  /// No description provided for @libreTranslateApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get libreTranslateApiKey;

  /// No description provided for @libreTranslateApiKeyOptional.
  ///
  /// In en, this message translates to:
  /// **'API key is only required if the server needs authentication'**
  String get libreTranslateApiKeyOptional;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @monthlyUsage.
  ///
  /// In en, this message translates to:
  /// **'Monthly Usage'**
  String get monthlyUsage;

  /// No description provided for @couldNotLoadUsage.
  ///
  /// In en, this message translates to:
  /// **'Could not load usage. Check your API key.'**
  String get couldNotLoadUsage;

  /// No description provided for @loadingUsage.
  ///
  /// In en, this message translates to:
  /// **'Loading usage...'**
  String get loadingUsage;

  /// No description provided for @charactersRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} characters remaining'**
  String charactersRemaining(String count);

  /// No description provided for @charactersUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} / {limit} characters'**
  String charactersUsed(String used, String limit);

  /// No description provided for @noLanguagesYet.
  ///
  /// In en, this message translates to:
  /// **'No Languages Yet'**
  String get noLanguagesYet;

  /// No description provided for @addLanguageToStart.
  ///
  /// In en, this message translates to:
  /// **'Add a language to get started'**
  String get addLanguageToStart;

  /// No description provided for @addLanguage.
  ///
  /// In en, this message translates to:
  /// **'Add Language'**
  String get addLanguage;

  /// No description provided for @editLanguage.
  ///
  /// In en, this message translates to:
  /// **'Edit Language'**
  String get editLanguage;

  /// No description provided for @deleteLanguageQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Language?'**
  String get deleteLanguageQuestion;

  /// No description provided for @deleteLanguageConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will delete \"{name}\" and all associated texts, terms, and dictionaries. Continue?'**
  String deleteLanguageConfirm(String name);

  /// No description provided for @totalTerms.
  ///
  /// In en, this message translates to:
  /// **'Total Terms'**
  String get totalTerms;

  /// No description provided for @known.
  ///
  /// In en, this message translates to:
  /// **'Known'**
  String get known;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unknownWords.
  ///
  /// In en, this message translates to:
  /// **'{count} unknown words'**
  String unknownWords(int count);

  /// No description provided for @unknownCharacters.
  ///
  /// In en, this message translates to:
  /// **'{count} unknown characters'**
  String unknownCharacters(int count);

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed!'**
  String get completed;

  /// No description provided for @activityHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityHeatmap;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @textsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Texts completed'**
  String get textsCompleted;

  /// No description provided for @wordsAdded.
  ///
  /// In en, this message translates to:
  /// **'Words added'**
  String get wordsAdded;

  /// No description provided for @wordsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Words reviewed'**
  String get wordsReviewed;

  /// No description provided for @noActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get noActivity;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @addText.
  ///
  /// In en, this message translates to:
  /// **'Add Text'**
  String get addText;

  /// No description provided for @importVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Import Vocabulary'**
  String get importVocabulary;

  /// No description provided for @recentlyRead.
  ///
  /// In en, this message translates to:
  /// **'Recently read'**
  String get recentlyRead;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @noTextsReadYet.
  ///
  /// In en, this message translates to:
  /// **'No texts read yet.'**
  String get noTextsReadYet;

  /// No description provided for @noTextsYetAddOne.
  ///
  /// In en, this message translates to:
  /// **'No texts yet. Add one to get started!'**
  String get noTextsYetAddOne;

  /// No description provided for @searchTexts.
  ///
  /// In en, this message translates to:
  /// **'Search texts...'**
  String get searchTexts;

  /// No description provided for @searchTerms.
  ///
  /// In en, this message translates to:
  /// **'Search terms...'**
  String get searchTerms;

  /// No description provided for @noCollectionsOrTexts.
  ///
  /// In en, this message translates to:
  /// **'No collections or texts'**
  String get noCollectionsOrTexts;

  /// No description provided for @allTextsCompleted.
  ///
  /// In en, this message translates to:
  /// **'All texts completed!'**
  String get allTextsCompleted;

  /// No description provided for @showCompletedTexts.
  ///
  /// In en, this message translates to:
  /// **'Show completed texts'**
  String get showCompletedTexts;

  /// No description provided for @hideCompletedTexts.
  ///
  /// In en, this message translates to:
  /// **'Hide completed texts'**
  String get hideCompletedTexts;

  /// No description provided for @completedHidden.
  ///
  /// In en, this message translates to:
  /// **'{count} completed hidden'**
  String completedHidden(int count);

  /// No description provided for @importFromUrl.
  ///
  /// In en, this message translates to:
  /// **'Import from URL'**
  String get importFromUrl;

  /// No description provided for @importTxt.
  ///
  /// In en, this message translates to:
  /// **'Import TXT'**
  String get importTxt;

  /// No description provided for @importEpub.
  ///
  /// In en, this message translates to:
  /// **'Import EPUB'**
  String get importEpub;

  /// No description provided for @importingEpub.
  ///
  /// In en, this message translates to:
  /// **'Importing EPUB...'**
  String get importingEpub;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importComplete;

  /// No description provided for @importFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Failed'**
  String get importFailedTitle;

  /// No description provided for @couldNotImportEpub.
  ///
  /// In en, this message translates to:
  /// **'Could not import EPUB: {error}'**
  String couldNotImportEpub(String error);

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New Collection'**
  String get newCollection;

  /// No description provided for @editCollection.
  ///
  /// In en, this message translates to:
  /// **'Edit Collection'**
  String get editCollection;

  /// No description provided for @deleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete Collection?'**
  String get deleteCollection;

  /// No description provided for @deleteCollectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" and its {count} text(s)?'**
  String deleteCollectionConfirm(String name, int count);

  /// No description provided for @deleteCollectionSimple.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteCollectionSimple(String name);

  /// No description provided for @deleteText.
  ///
  /// In en, this message translates to:
  /// **'Delete Text?'**
  String get deleteText;

  /// No description provided for @deleteTextConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteTextConfirm(String title);

  /// No description provided for @editText.
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get editText;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @textContent.
  ///
  /// In en, this message translates to:
  /// **'Text Content'**
  String get textContent;

  /// No description provided for @setCover.
  ///
  /// In en, this message translates to:
  /// **'Set Cover'**
  String get setCover;

  /// No description provided for @addCover.
  ///
  /// In en, this message translates to:
  /// **'Add Cover'**
  String get addCover;

  /// No description provided for @removeCover.
  ///
  /// In en, this message translates to:
  /// **'Remove Cover'**
  String get removeCover;

  /// No description provided for @noTermsFound.
  ///
  /// In en, this message translates to:
  /// **'No terms found'**
  String get noTermsFound;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get importCsv;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exportAnki.
  ///
  /// In en, this message translates to:
  /// **'Export Anki'**
  String get exportAnki;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortByName;

  /// No description provided for @sortByDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get sortByDateAdded;

  /// No description provided for @sortByLastRead.
  ///
  /// In en, this message translates to:
  /// **'Last Read'**
  String get sortByLastRead;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @switchToListView.
  ///
  /// In en, this message translates to:
  /// **'Switch to list view'**
  String get switchToListView;

  /// No description provided for @switchToGridView.
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get switchToGridView;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @urlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/article'**
  String get urlHint;

  /// No description provided for @fetchContent.
  ///
  /// In en, this message translates to:
  /// **'Fetch content'**
  String get fetchContent;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @wordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordsCount(int count);

  /// No description provided for @charactersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String charactersCount(int count);

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get pleaseEnterUrl;

  /// No description provided for @pleaseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @totalParts.
  ///
  /// In en, this message translates to:
  /// **'Total parts'**
  String get totalParts;

  /// No description provided for @characters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get characters;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @textsTitle.
  ///
  /// In en, this message translates to:
  /// **'Texts - {languageName}'**
  String textsTitle(String languageName);

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @textCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 text} other{{count} texts}}'**
  String textCount(int count);

  /// No description provided for @unknownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unknown'**
  String unknownCount(int count);

  /// No description provided for @vocabularyTitle.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary - {languageName}'**
  String vocabularyTitle(String languageName);

  /// No description provided for @exportedTerms.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} terms'**
  String exportedTerms(int count);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @importedTerms.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} terms'**
  String importedTerms(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @statusIgnored.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get statusIgnored;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @statusLearning2.
  ///
  /// In en, this message translates to:
  /// **'Learning 2'**
  String get statusLearning2;

  /// No description provided for @statusLearning3.
  ///
  /// In en, this message translates to:
  /// **'Learning 3'**
  String get statusLearning3;

  /// No description provided for @statusLearning4.
  ///
  /// In en, this message translates to:
  /// **'Learning 4'**
  String get statusLearning4;

  /// No description provided for @statusKnown.
  ///
  /// In en, this message translates to:
  /// **'Known'**
  String get statusKnown;

  /// No description provided for @statusWellKnown.
  ///
  /// In en, this message translates to:
  /// **'Well Known'**
  String get statusWellKnown;

  /// No description provided for @addDictionariesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Dictionaries?'**
  String get addDictionariesQuestion;

  /// No description provided for @addDictionariesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Would you like to add dictionaries for {name}?'**
  String addDictionariesPrompt(String name);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @addNow.
  ///
  /// In en, this message translates to:
  /// **'Add Now'**
  String get addNow;

  /// No description provided for @dictionaryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dictionary} other{{count} dictionaries}}'**
  String dictionaryCount(int count);

  /// No description provided for @manageDictionaries.
  ///
  /// In en, this message translates to:
  /// **'Manage Dictionaries'**
  String get manageDictionaries;

  /// No description provided for @languageNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Language Name'**
  String get languageNameLabel;

  /// No description provided for @languageNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Spanish, Japanese, Chinese'**
  String get languageNameHint;

  /// No description provided for @languageCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Language Code'**
  String get languageCodeLabel;

  /// No description provided for @languageCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., en, de, uk, ja'**
  String get languageCodeHint;

  /// No description provided for @rightToLeftText.
  ///
  /// In en, this message translates to:
  /// **'Right-to-Left Text'**
  String get rightToLeftText;

  /// No description provided for @rightToLeftHint.
  ///
  /// In en, this message translates to:
  /// **'For languages like Arabic, Hebrew'**
  String get rightToLeftHint;

  /// No description provided for @showRomanization.
  ///
  /// In en, this message translates to:
  /// **'Show Romanization'**
  String get showRomanization;

  /// No description provided for @showRomanizationHint.
  ///
  /// In en, this message translates to:
  /// **'Display pronunciation guide'**
  String get showRomanizationHint;

  /// No description provided for @splitByCharacter.
  ///
  /// In en, this message translates to:
  /// **'Split by Character'**
  String get splitByCharacter;

  /// No description provided for @splitByCharacterHint.
  ///
  /// In en, this message translates to:
  /// **'For Chinese, Japanese (no spaces)'**
  String get splitByCharacterHint;

  /// No description provided for @addDictionariesAfterCreating.
  ///
  /// In en, this message translates to:
  /// **'Add dictionaries after creating the language'**
  String get addDictionariesAfterCreating;

  /// No description provided for @errorLoadingTerms.
  ///
  /// In en, this message translates to:
  /// **'Error loading terms: {error}'**
  String errorLoadingTerms(String error);

  /// No description provided for @errorLoadingLanguages.
  ///
  /// In en, this message translates to:
  /// **'Error loading languages: {error}'**
  String errorLoadingLanguages(String error);

  /// No description provided for @noDictionariesConfigured.
  ///
  /// In en, this message translates to:
  /// **'No dictionaries configured'**
  String get noDictionariesConfigured;

  /// No description provided for @lookupWord.
  ///
  /// In en, this message translates to:
  /// **'Lookup \"{word}\"'**
  String lookupWord(String word);

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel Selection'**
  String get cancelSelection;

  /// No description provided for @saveAsTerm.
  ///
  /// In en, this message translates to:
  /// **'Save as Term'**
  String get saveAsTerm;

  /// No description provided for @assignForeignLanguage.
  ///
  /// In en, this message translates to:
  /// **'Assign foreign language'**
  String get assignForeignLanguage;

  /// No description provided for @removeForeignMarking.
  ///
  /// In en, this message translates to:
  /// **'Remove foreign marking'**
  String get removeForeignMarking;

  /// No description provided for @noOtherLanguages.
  ///
  /// In en, this message translates to:
  /// **'No other languages configured'**
  String get noOtherLanguages;

  /// No description provided for @lookupInDictionary.
  ///
  /// In en, this message translates to:
  /// **'Lookup in Dictionary'**
  String get lookupInDictionary;

  /// No description provided for @pronounce.
  ///
  /// In en, this message translates to:
  /// **'Pronounce'**
  String get pronounce;

  /// No description provided for @toggleLegend.
  ///
  /// In en, this message translates to:
  /// **'Toggle Legend'**
  String get toggleLegend;

  /// No description provided for @wordList.
  ///
  /// In en, this message translates to:
  /// **'Word List'**
  String get wordList;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @markAllKnown.
  ///
  /// In en, this message translates to:
  /// **'Mark All Known'**
  String get markAllKnown;

  /// No description provided for @markedAsFinished.
  ///
  /// In en, this message translates to:
  /// **'Marked as Finished'**
  String get markedAsFinished;

  /// No description provided for @markAsFinished.
  ///
  /// In en, this message translates to:
  /// **'Mark as Finished'**
  String get markAsFinished;

  /// No description provided for @wordsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} word(s) selected. Tap + to save as term or tap search to lookup.'**
  String wordsSelected(int count);

  /// No description provided for @previewText.
  ///
  /// In en, this message translates to:
  /// **'Preview Text'**
  String get previewText;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @markAllKnownQuestion.
  ///
  /// In en, this message translates to:
  /// **'Mark All Known?'**
  String get markAllKnownQuestion;

  /// No description provided for @markAllKnownConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will mark all words in this text as \"Well Known\". Continue?'**
  String get markAllKnownConfirm;

  /// No description provided for @markAll.
  ///
  /// In en, this message translates to:
  /// **'Mark All'**
  String get markAll;

  /// No description provided for @allWordsMarkedKnown.
  ///
  /// In en, this message translates to:
  /// **'All words marked as known'**
  String get allWordsMarkedKnown;

  /// No description provided for @textMarkedFinished.
  ///
  /// In en, this message translates to:
  /// **'Text marked as finished'**
  String get textMarkedFinished;

  /// No description provided for @textMarkedInProgress.
  ///
  /// In en, this message translates to:
  /// **'Text marked as in progress'**
  String get textMarkedInProgress;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue Reading?'**
  String get continueReading;

  /// No description provided for @continueReadingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Would you like to continue with the next text?\n\n\"{title}\"'**
  String continueReadingPrompt(String title);

  /// No description provided for @termsByStatus.
  ///
  /// In en, this message translates to:
  /// **'Terms by Status'**
  String get termsByStatus;

  /// No description provided for @progressOverview.
  ///
  /// In en, this message translates to:
  /// **'Progress Overview'**
  String get progressOverview;

  /// No description provided for @percentKnown.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Known'**
  String percentKnown(String percent);

  /// No description provided for @noTermsYet.
  ///
  /// In en, this message translates to:
  /// **'No terms yet'**
  String get noTermsYet;

  /// No description provided for @learning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get learning;

  /// No description provided for @dictionariesTitle.
  ///
  /// In en, this message translates to:
  /// **'Dictionaries - {languageName}'**
  String dictionariesTitle(String languageName);

  /// No description provided for @deleteDictionary.
  ///
  /// In en, this message translates to:
  /// **'Delete Dictionary?'**
  String get deleteDictionary;

  /// No description provided for @deleteDictionaryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteDictionaryConfirm(String name);

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @noDictionariesYet.
  ///
  /// In en, this message translates to:
  /// **'No dictionaries yet'**
  String get noDictionariesYet;

  /// No description provided for @addDictionariesFor.
  ///
  /// In en, this message translates to:
  /// **'Add dictionaries for {name}'**
  String addDictionariesFor(String name);

  /// No description provided for @addDictionary.
  ///
  /// In en, this message translates to:
  /// **'Add Dictionary'**
  String get addDictionary;

  /// No description provided for @editDictionary.
  ///
  /// In en, this message translates to:
  /// **'Edit Dictionary'**
  String get editDictionary;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @dictionaryHelp.
  ///
  /// In en, this message translates to:
  /// **'Dictionary Help'**
  String get dictionaryHelp;

  /// No description provided for @howToUse.
  ///
  /// In en, this message translates to:
  /// **'How to use:'**
  String get howToUse;

  /// No description provided for @dictionaryHelpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Add dictionary URLs for this language'**
  String get dictionaryHelpStep1;

  /// No description provided for @dictionaryHelpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Use ### as placeholder for the word'**
  String get dictionaryHelpStep2;

  /// No description provided for @dictionaryHelpStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Drag to reorder dictionaries'**
  String get dictionaryHelpStep3;

  /// No description provided for @dictionaryHelpStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Toggle active/inactive'**
  String get dictionaryHelpStep4;

  /// No description provided for @exampleUrls.
  ///
  /// In en, this message translates to:
  /// **'Example URLs:'**
  String get exampleUrls;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @dictionaryName.
  ///
  /// In en, this message translates to:
  /// **'Dictionary Name'**
  String get dictionaryName;

  /// No description provided for @dictionaryNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., WordReference, Jisho'**
  String get dictionaryNameHint;

  /// No description provided for @urlTemplate.
  ///
  /// In en, this message translates to:
  /// **'URL Template'**
  String get urlTemplate;

  /// No description provided for @urlTemplateHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/dict?word=###'**
  String get urlTemplateHint;

  /// No description provided for @urlTemplateHelper.
  ///
  /// In en, this message translates to:
  /// **'Use ### as placeholder for the word'**
  String get urlTemplateHelper;

  /// No description provided for @urlMustContainPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'URL must contain ###'**
  String get urlMustContainPlaceholder;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @showInDictionaryLookupMenu.
  ///
  /// In en, this message translates to:
  /// **'Show in dictionary lookup menu'**
  String get showInDictionaryLookupMenu;

  /// No description provided for @quickTemplates.
  ///
  /// In en, this message translates to:
  /// **'Quick Templates:'**
  String get quickTemplates;

  /// No description provided for @dictionaryLookup.
  ///
  /// In en, this message translates to:
  /// **'Dictionary Lookup'**
  String get dictionaryLookup;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in Browser'**
  String get openInBrowser;

  /// No description provided for @errorLoadingPage.
  ///
  /// In en, this message translates to:
  /// **'Error loading page: {error}'**
  String errorLoadingPage(String error);

  /// No description provided for @errorOpeningBrowser.
  ///
  /// In en, this message translates to:
  /// **'Error opening browser: {error}'**
  String errorOpeningBrowser(String error);

  /// No description provided for @term.
  ///
  /// In en, this message translates to:
  /// **'Term'**
  String get term;

  /// No description provided for @useOriginal.
  ///
  /// In en, this message translates to:
  /// **'Use original: {text}'**
  String useOriginal(String text);

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original: {text}'**
  String original(String text);

  /// No description provided for @base.
  ///
  /// In en, this message translates to:
  /// **'Base: '**
  String get base;

  /// No description provided for @removeLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get removeLink;

  /// No description provided for @linkToBaseForm.
  ///
  /// In en, this message translates to:
  /// **'Link to base form...'**
  String get linkToBaseForm;

  /// No description provided for @forms.
  ///
  /// In en, this message translates to:
  /// **'Forms: {forms}'**
  String forms(String forms);

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language: '**
  String get language;

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @translateWithDeepL.
  ///
  /// In en, this message translates to:
  /// **'Translate with DeepL'**
  String get translateWithDeepL;

  /// No description provided for @translateWithLibreTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate with LibreTranslate'**
  String get translateWithLibreTranslate;

  /// No description provided for @romanizationPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Romanization / Pronunciation'**
  String get romanizationPronunciation;

  /// No description provided for @exampleSentence.
  ///
  /// In en, this message translates to:
  /// **'Example Sentence'**
  String get exampleSentence;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed. Check your API key and settings.'**
  String get translationFailed;

  /// No description provided for @languageNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Language \"{name}\" is not supported'**
  String languageNotSupported(String name);

  /// No description provided for @noDeepL.
  ///
  /// In en, this message translates to:
  /// **' (no DeepL)'**
  String get noDeepL;

  /// No description provided for @selectBaseForm.
  ///
  /// In en, this message translates to:
  /// **'Select Base Form'**
  String get selectBaseForm;

  /// No description provided for @noExistingTermsFound.
  ///
  /// In en, this message translates to:
  /// **'No existing terms found'**
  String get noExistingTermsFound;

  /// No description provided for @createNewBaseTerm.
  ///
  /// In en, this message translates to:
  /// **'Create new base term'**
  String get createNewBaseTerm;

  /// No description provided for @translationOptional.
  ///
  /// In en, this message translates to:
  /// **'Translation (optional)'**
  String get translationOptional;

  /// No description provided for @createTerm.
  ///
  /// In en, this message translates to:
  /// **'Create \"{term}\"'**
  String createTerm(String term);

  /// No description provided for @statusLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'Status Legend'**
  String get statusLegendTitle;

  /// No description provided for @databaseSection.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get databaseSection;

  /// No description provided for @databasePath.
  ///
  /// In en, this message translates to:
  /// **'Database path'**
  String get databasePath;

  /// No description provided for @openDatabaseDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open Directory'**
  String get openDatabaseDirectory;

  /// No description provided for @changeDatabase.
  ///
  /// In en, this message translates to:
  /// **'Change Database'**
  String get changeDatabase;

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get restartRequired;

  /// No description provided for @databaseChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'The database has been changed. The application will now close. Please reopen it to use the new database.'**
  String get databaseChangedMessage;

  /// No description provided for @posNoun.
  ///
  /// In en, this message translates to:
  /// **'Noun'**
  String get posNoun;

  /// No description provided for @posVerb.
  ///
  /// In en, this message translates to:
  /// **'Verb'**
  String get posVerb;

  /// No description provided for @posAdjective.
  ///
  /// In en, this message translates to:
  /// **'Adjective'**
  String get posAdjective;

  /// No description provided for @posAdverb.
  ///
  /// In en, this message translates to:
  /// **'Adverb'**
  String get posAdverb;

  /// No description provided for @posPronoun.
  ///
  /// In en, this message translates to:
  /// **'Pronoun'**
  String get posPronoun;

  /// No description provided for @posPreposition.
  ///
  /// In en, this message translates to:
  /// **'Preposition'**
  String get posPreposition;

  /// No description provided for @posConjunction.
  ///
  /// In en, this message translates to:
  /// **'Conjunction'**
  String get posConjunction;

  /// No description provided for @posInterjection.
  ///
  /// In en, this message translates to:
  /// **'Interjection'**
  String get posInterjection;

  /// No description provided for @posArticle.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get posArticle;

  /// No description provided for @posNumeral.
  ///
  /// In en, this message translates to:
  /// **'Numeral'**
  String get posNumeral;

  /// No description provided for @posParticle.
  ///
  /// In en, this message translates to:
  /// **'Particle'**
  String get posParticle;

  /// No description provided for @posOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get posOther;

  /// No description provided for @partOfSpeech.
  ///
  /// In en, this message translates to:
  /// **'Part of speech'**
  String get partOfSpeech;

  /// No description provided for @baseForm.
  ///
  /// In en, this message translates to:
  /// **'Base form'**
  String get baseForm;

  /// No description provided for @meaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get meaning;

  /// No description provided for @addTranslation.
  ///
  /// In en, this message translates to:
  /// **'Add translation'**
  String get addTranslation;

  /// No description provided for @translations.
  ///
  /// In en, this message translates to:
  /// **'Translations'**
  String get translations;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @showAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show Answer'**
  String get showAnswer;

  /// No description provided for @rateAgain.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get rateAgain;

  /// No description provided for @rateHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get rateHard;

  /// No description provided for @rateGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get rateGood;

  /// No description provided for @rateEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get rateEasy;

  /// No description provided for @noCardsDue.
  ///
  /// In en, this message translates to:
  /// **'No cards due for review'**
  String get noCardsDue;

  /// No description provided for @reviewComplete.
  ///
  /// In en, this message translates to:
  /// **'Review Complete!'**
  String get reviewComplete;

  /// No description provided for @reviewedCount.
  ///
  /// In en, this message translates to:
  /// **'Reviewed {count} cards'**
  String reviewedCount(int count);

  /// No description provided for @reviewProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String reviewProgress(int current, int total);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @unignore.
  ///
  /// In en, this message translates to:
  /// **'Unignore'**
  String get unignore;

  /// No description provided for @markWellKnown.
  ///
  /// In en, this message translates to:
  /// **'Mark as Well Known'**
  String get markWellKnown;

  /// No description provided for @flashcardReview.
  ///
  /// In en, this message translates to:
  /// **'Flashcard Review'**
  String get flashcardReview;

  /// No description provided for @flashcardReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Review due cards with spaced repetition'**
  String get flashcardReviewDescription;

  /// No description provided for @statisticsDescription.
  ///
  /// In en, this message translates to:
  /// **'View vocabulary progress and status breakdown'**
  String get statisticsDescription;

  /// No description provided for @cardsDue.
  ///
  /// In en, this message translates to:
  /// **'Cards due'**
  String get cardsDue;

  /// No description provided for @reviewedToday.
  ///
  /// In en, this message translates to:
  /// **'Reviewed today'**
  String get reviewedToday;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @backupToGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Back up to Google Drive'**
  String get backupToGoogleDrive;

  /// No description provided for @restoreFromGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google Drive'**
  String get restoreFromGoogleDrive;

  /// No description provided for @backupToICloud.
  ///
  /// In en, this message translates to:
  /// **'Back up to iCloud'**
  String get backupToICloud;

  /// No description provided for @restoreFromICloud.
  ///
  /// In en, this message translates to:
  /// **'Restore from iCloud'**
  String get restoreFromICloud;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String lastBackup(String date);

  /// No description provided for @noBackupYet.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get noBackupYet;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup completed successfully'**
  String get backupSuccess;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore completed successfully.'**
  String get restoreSuccess;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will replace all current data with the backup. This cannot be undone. Continue?'**
  String get restoreConfirmMessage;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(String error);

  /// No description provided for @noBackupFound.
  ///
  /// In en, this message translates to:
  /// **'No backup found'**
  String get noBackupFound;

  /// No description provided for @signInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled'**
  String get signInCancelled;

  /// No description provided for @typingReview.
  ///
  /// In en, this message translates to:
  /// **'Typing Review'**
  String get typingReview;

  /// No description provided for @typingSourceToTarget.
  ///
  /// In en, this message translates to:
  /// **'Source → Target'**
  String get typingSourceToTarget;

  /// No description provided for @typingTargetToSource.
  ///
  /// In en, this message translates to:
  /// **'Target → Source'**
  String get typingTargetToSource;

  /// No description provided for @typingSourceToTargetDescription.
  ///
  /// In en, this message translates to:
  /// **'Type the translation for each word'**
  String get typingSourceToTargetDescription;

  /// No description provided for @typingTargetToSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Type the word for each translation'**
  String get typingTargetToSourceDescription;

  /// No description provided for @typeYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer...'**
  String get typeYourAnswer;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrect;

  /// No description provided for @correctAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String correctAnswerWas(String answer);

  /// No description provided for @noTranslationsToReview.
  ///
  /// In en, this message translates to:
  /// **'No cards with translations to review'**
  String get noTranslationsToReview;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
