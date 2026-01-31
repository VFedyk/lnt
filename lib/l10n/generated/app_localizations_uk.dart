// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Language Nerd Tools';

  @override
  String get home => 'Головна';

  @override
  String get texts => 'Тексти';

  @override
  String get vocabulary => 'Словник';

  @override
  String get stats => 'Статистика';

  @override
  String get languages => 'Мови';

  @override
  String get settings => 'Налаштування';

  @override
  String get cancel => 'Скасувати';

  @override
  String get save => 'Зберегти';

  @override
  String get delete => 'Видалити';

  @override
  String get edit => 'Редагувати';

  @override
  String get add => 'Додати';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Повторити';

  @override
  String get create => 'Створити';

  @override
  String get import => 'Імпорт';

  @override
  String get export => 'Експорт';

  @override
  String get close => 'Закрити';

  @override
  String get yes => 'Так';

  @override
  String get no => 'Ні';

  @override
  String get search => 'Пошук';

  @override
  String get loading => 'Завантаження...';

  @override
  String get error => 'Помилка';

  @override
  String get success => 'Успіх';

  @override
  String get warning => 'Попередження';

  @override
  String get confirm => 'Підтвердити';

  @override
  String get appLanguage => 'Мова застосунку';

  @override
  String get english => 'Англійська';

  @override
  String get ukrainian => 'Українська';

  @override
  String get deepLTranslation => 'Переклад DeepL';

  @override
  String get deepLApiKey => 'API ключ DeepL';

  @override
  String get deepLApiKeyHint => 'Отримайте API ключ на deepl.com/pro-api';

  @override
  String get apiType => 'Тип API';

  @override
  String get free => 'Безкоштовний';

  @override
  String get pro => 'Pro';

  @override
  String get freeApiLimit => 'Безкоштовний API: 500 000 символів/місяць';

  @override
  String get proApiPayPerUse => 'Pro API: Оплата за використання';

  @override
  String get targetLanguage => 'Цільова мова';

  @override
  String get languageForTranslations => 'Мова для перекладів';

  @override
  String get saveSettings => 'Зберегти налаштування';

  @override
  String get settingsSaved => 'Налаштування збережено';

  @override
  String get monthlyUsage => 'Місячне використання';

  @override
  String get couldNotLoadUsage => 'Не вдалося завантажити. Перевірте API ключ.';

  @override
  String get loadingUsage => 'Завантаження використання...';

  @override
  String charactersRemaining(String count) {
    return '$count символів залишилось';
  }

  @override
  String charactersUsed(String used, String limit) {
    return '$used / $limit символів';
  }

  @override
  String get noLanguagesYet => 'Мов ще немає';

  @override
  String get addLanguageToStart => 'Додайте мову, щоб почати';

  @override
  String get addLanguage => 'Додати мову';

  @override
  String get editLanguage => 'Редагувати мову';

  @override
  String get deleteLanguageQuestion => 'Видалити мову?';

  @override
  String deleteLanguageConfirm(String name) {
    return 'Це видалить \"$name\" та всі пов\'язані тексти, терміни та словники. Продовжити?';
  }

  @override
  String get totalTerms => 'Всього термінів';

  @override
  String get known => 'Відомі';

  @override
  String get unknown => 'Невідомі';

  @override
  String unknownWords(int count) {
    return '$count невідомих слів';
  }

  @override
  String unknownCharacters(int count) {
    return '$count невідомих символів';
  }

  @override
  String get completed => 'Завершено!';

  @override
  String get quickActions => 'Швидкі дії';

  @override
  String get addText => 'Додати текст';

  @override
  String get importVocabulary => 'Імпортувати словник';

  @override
  String get recentlyRead => 'Нещодавно прочитане';

  @override
  String get recentlyAdded => 'Нещодавно додане';

  @override
  String get noTextsReadYet => 'Ще не прочитано жодного тексту.';

  @override
  String get noTextsYetAddOne => 'Текстів ще немає. Додайте один, щоб почати!';

  @override
  String get searchTexts => 'Пошук текстів...';

  @override
  String get searchTerms => 'Пошук термінів...';

  @override
  String get noCollectionsOrTexts => 'Немає колекцій чи текстів';

  @override
  String get allTextsCompleted => 'Всі тексти завершено!';

  @override
  String get showCompletedTexts => 'Показати завершені тексти';

  @override
  String get hideCompletedTexts => 'Сховати завершені тексти';

  @override
  String completedHidden(int count) {
    return '$count завершених сховано';
  }

  @override
  String get importFromUrl => 'Імпорт з URL';

  @override
  String get importTxt => 'Імпорт TXT';

  @override
  String get importEpub => 'Імпорт EPUB';

  @override
  String get importingEpub => 'Імпорт EPUB...';

  @override
  String get importComplete => 'Імпорт завершено';

  @override
  String importFailed(String error) {
    return 'Помилка імпорту: $error';
  }

  @override
  String couldNotImportEpub(String error) {
    return 'Не вдалося імпортувати EPUB: $error';
  }

  @override
  String get newCollection => 'Нова колекція';

  @override
  String get editCollection => 'Редагувати колекцію';

  @override
  String get deleteCollection => 'Видалити колекцію?';

  @override
  String deleteCollectionConfirm(String name, int count) {
    return 'Видалити \"$name\" та $count текст(ів)?';
  }

  @override
  String deleteCollectionSimple(String name) {
    return 'Видалити \"$name\"?';
  }

  @override
  String get deleteText => 'Видалити текст?';

  @override
  String deleteTextConfirm(String title) {
    return 'Видалити \"$title\"?';
  }

  @override
  String get editText => 'Редагувати текст';

  @override
  String get title => 'Назва';

  @override
  String get textContent => 'Вміст тексту';

  @override
  String get setCover => 'Встановити обкладинку';

  @override
  String get addCover => 'Додати обкладинку';

  @override
  String get removeCover => 'Видалити обкладинку';

  @override
  String get noTermsFound => 'Термінів не знайдено';

  @override
  String get importCsv => 'Імпорт CSV';

  @override
  String get exportCsv => 'Експорт CSV';

  @override
  String get exportAnki => 'Експорт Anki';

  @override
  String get name => 'Назва';

  @override
  String get description => 'Опис';

  @override
  String get descriptionOptional => 'Опис (необов\'язково)';

  @override
  String get required => 'Обов\'язково';

  @override
  String get sortByName => 'За назвою';

  @override
  String get sortByDateAdded => 'За датою додавання';

  @override
  String get sortByLastRead => 'За останнім читанням';

  @override
  String get listView => 'Список';

  @override
  String get gridView => 'Сітка';

  @override
  String get switchToListView => 'Перейти до списку';

  @override
  String get switchToGridView => 'Перейти до сітки';

  @override
  String get url => 'URL';

  @override
  String get urlHint => 'https://example.com/article';

  @override
  String get fetchContent => 'Завантажити вміст';

  @override
  String get preview => 'Попередній перегляд';

  @override
  String wordsCount(int count) {
    return '$count слів';
  }

  @override
  String charactersCount(int count) {
    return '$count символів';
  }

  @override
  String get pleaseEnterUrl => 'Введіть URL';

  @override
  String get pleaseEnterTitle => 'Введіть назву';

  @override
  String get book => 'Книга';

  @override
  String get author => 'Автор';

  @override
  String get chapters => 'Розділи';

  @override
  String get totalParts => 'Всього частин';

  @override
  String get characters => 'Символів';

  @override
  String get notes => 'Примітки';

  @override
  String textsTitle(String languageName) {
    return 'Тексти - $languageName';
  }

  @override
  String get sort => 'Сортувати';

  @override
  String textCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count текстів',
      few: '$count тексти',
      one: '1 текст',
    );
    return '$_temp0';
  }

  @override
  String unknownCount(int count) {
    return '$count невідомих';
  }

  @override
  String vocabularyTitle(String languageName) {
    return 'Словник - $languageName';
  }

  @override
  String exportedTerms(int count) {
    return 'Експортовано $count термінів';
  }

  @override
  String exportFailed(String error) {
    return 'Помилка експорту: $error';
  }

  @override
  String importedTerms(int count) {
    return 'Імпортовано $count термінів';
  }

  @override
  String get all => 'Всі';

  @override
  String get statusIgnored => 'Ігноровані';

  @override
  String get statusUnknown => 'Невідомі';

  @override
  String get statusLearning2 => 'Вивчення 2';

  @override
  String get statusLearning3 => 'Вивчення 3';

  @override
  String get statusLearning4 => 'Вивчення 4';

  @override
  String get statusKnown => 'Відомі';

  @override
  String get statusWellKnown => 'Добре відомі';

  @override
  String get addDictionariesQuestion => 'Додати словники?';

  @override
  String addDictionariesPrompt(String name) {
    return 'Бажаєте додати словники для $name?';
  }

  @override
  String get later => 'Пізніше';

  @override
  String get addNow => 'Додати зараз';

  @override
  String dictionaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count словників',
      few: '$count словники',
      one: '1 словник',
    );
    return '$_temp0';
  }

  @override
  String get manageDictionaries => 'Керувати словниками';

  @override
  String get languageNameLabel => 'Назва мови';

  @override
  String get languageNameHint => 'напр., Іспанська, Японська, Китайська';

  @override
  String get rightToLeftText => 'Текст справа наліво';

  @override
  String get rightToLeftHint => 'Для мов як Арабська, Іврит';

  @override
  String get showRomanization => 'Показувати романізацію';

  @override
  String get showRomanizationHint => 'Відображати вимову';

  @override
  String get splitByCharacter => 'Розділяти за символами';

  @override
  String get splitByCharacterHint => 'Для Китайської, Японської (без пробілів)';

  @override
  String get addDictionariesAfterCreating =>
      'Додайте словники після створення мови';

  @override
  String errorLoadingTerms(String error) {
    return 'Помилка завантаження термінів: $error';
  }

  @override
  String errorLoadingLanguages(String error) {
    return 'Помилка завантаження мов: $error';
  }

  @override
  String get noDictionariesConfigured => 'Словники не налаштовані';

  @override
  String lookupWord(String word) {
    return 'Шукати \"$word\"';
  }

  @override
  String get cancelSelection => 'Скасувати вибір';

  @override
  String get saveAsTerm => 'Зберегти як термін';

  @override
  String get lookupInDictionary => 'Шукати у словнику';

  @override
  String get toggleLegend => 'Легенда';

  @override
  String get wordList => 'Список слів';

  @override
  String get fontSize => 'Розмір шрифту';

  @override
  String get markAllKnown => 'Позначити все відомим';

  @override
  String get markedAsFinished => 'Позначено як завершене';

  @override
  String get markAsFinished => 'Позначити як завершене';

  @override
  String wordsSelected(int count) {
    return 'Вибрано $count слів. Натисніть + для збереження або пошук для перегляду.';
  }

  @override
  String get previewText => 'Попередній перегляд';

  @override
  String get done => 'Готово';

  @override
  String get markAllKnownQuestion => 'Позначити все відомим?';

  @override
  String get markAllKnownConfirm =>
      'Це позначить усі слова в цьому тексті як \"Добре відомі\". Продовжити?';

  @override
  String get markAll => 'Позначити все';

  @override
  String get allWordsMarkedKnown => 'Усі слова позначено як відомі';

  @override
  String get textMarkedFinished => 'Текст позначено як завершений';

  @override
  String get textMarkedInProgress => 'Текст позначено як незавершений';

  @override
  String get continueReading => 'Продовжити читання?';

  @override
  String continueReadingPrompt(String title) {
    return 'Бажаєте продовжити з наступним текстом?\n\n\"$title\"';
  }

  @override
  String get termsByStatus => 'Терміни за статусом';

  @override
  String get progressOverview => 'Огляд прогресу';

  @override
  String percentKnown(String percent) {
    return '$percent% відомо';
  }

  @override
  String get noTermsYet => 'Ще немає термінів';

  @override
  String get learning => 'Вивчення';

  @override
  String dictionariesTitle(String languageName) {
    return 'Словники - $languageName';
  }

  @override
  String get deleteDictionary => 'Видалити словник?';

  @override
  String deleteDictionaryConfirm(String name) {
    return 'Видалити \"$name\"?';
  }

  @override
  String get deactivate => 'Деактивувати';

  @override
  String get activate => 'Активувати';

  @override
  String get noDictionariesYet => 'Словників ще немає';

  @override
  String addDictionariesFor(String name) {
    return 'Додайте словники для $name';
  }

  @override
  String get addDictionary => 'Додати словник';

  @override
  String get editDictionary => 'Редагувати словник';

  @override
  String get help => 'Допомога';

  @override
  String get dictionaryHelp => 'Довідка словників';

  @override
  String get howToUse => 'Як використовувати:';

  @override
  String get dictionaryHelpStep1 => '1. Додайте URL словників для цієї мови';

  @override
  String get dictionaryHelpStep2 =>
      '2. Використовуйте ### як заповнювач для слова';

  @override
  String get dictionaryHelpStep3 => '3. Перетягуйте для зміни порядку';

  @override
  String get dictionaryHelpStep4 => '4. Перемикайте активний/неактивний';

  @override
  String get exampleUrls => 'Приклади URL:';

  @override
  String get gotIt => 'Зрозуміло';

  @override
  String get dictionaryName => 'Назва словника';

  @override
  String get dictionaryNameHint => 'напр., WordReference, Jisho';

  @override
  String get urlTemplate => 'Шаблон URL';

  @override
  String get urlTemplateHint => 'https://example.com/dict?word=###';

  @override
  String get urlTemplateHelper => 'Використовуйте ### як заповнювач для слова';

  @override
  String get urlMustContainPlaceholder => 'URL повинен містити ###';

  @override
  String get active => 'Активний';

  @override
  String get showInDictionaryLookupMenu => 'Показувати в меню пошуку';

  @override
  String get quickTemplates => 'Швидкі шаблони:';

  @override
  String get dictionaryLookup => 'Пошук у словнику';

  @override
  String get reload => 'Оновити';

  @override
  String get back => 'Назад';

  @override
  String get forward => 'Вперед';

  @override
  String get openInBrowser => 'Відкрити в браузері';

  @override
  String errorLoadingPage(String error) {
    return 'Помилка завантаження сторінки: $error';
  }

  @override
  String errorOpeningBrowser(String error) {
    return 'Помилка відкриття браузера: $error';
  }

  @override
  String get term => 'Термін';

  @override
  String useOriginal(String text) {
    return 'Використати оригінал: $text';
  }

  @override
  String original(String text) {
    return 'Оригінал: $text';
  }

  @override
  String get base => 'Базова форма: ';

  @override
  String get removeLink => 'Видалити зв\'язок';

  @override
  String get linkToBaseForm => 'Зв\'язати з базовою формою...';

  @override
  String forms(String forms) {
    return 'Форми: $forms';
  }

  @override
  String get status => 'Статус';

  @override
  String get language => 'Мова: ';

  @override
  String get translation => 'Переклад';

  @override
  String get translateWithDeepL => 'Перекласти з DeepL';

  @override
  String get romanizationPronunciation => 'Романізація / Вимова';

  @override
  String get exampleSentence => 'Приклад речення';

  @override
  String get translationFailed => 'Помилка перекладу. Перевірте API ключ.';

  @override
  String languageNotSupported(String name) {
    return 'Мова \"$name\" не підтримується DeepL';
  }

  @override
  String get noDeepL => ' (без DeepL)';

  @override
  String get selectBaseForm => 'Обрати базову форму';

  @override
  String get noExistingTermsFound => 'Існуючих термінів не знайдено';

  @override
  String get createNewBaseTerm => 'Створити новий базовий термін';

  @override
  String get translationOptional => 'Переклад (необов\'язково)';

  @override
  String createTerm(String term) {
    return 'Створити \"$term\"';
  }

  @override
  String get statusLegendTitle => 'Легенда статусів';
}
