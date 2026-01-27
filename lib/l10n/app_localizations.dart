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
/// import 'l10n/app_localizations.dart';
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

  /// No description provided for @texts.
  ///
  /// In en, this message translates to:
  /// **'Texts'**
  String get texts;

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

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import Failed'**
  String get importFailed;

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
