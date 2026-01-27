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
  String get importFailed => 'Помилка імпорту';

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
}
