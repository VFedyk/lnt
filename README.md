# FLTR - Foreign Language Text Reader (Flutter)

A complete Flutter implementation of the Foreign Language Text Reader application for mobile platforms (Android & iOS).

## Features

- ✅ **Multi-language Support** - Manage multiple languages with custom dictionary configurations
- ✅ **Interactive Reading** - Tap words to look up in web dictionaries
- ✅ **Vocabulary Tracking** - 7 status levels (Ignored, Unknown, Learning 1-4, Known, Well Known)
- ✅ **Color-coded Highlighting** - Visual progress tracking while reading
- ✅ **Import/Export** - CSV and Anki flashcard format support
- ✅ **Text Library** - Organize and manage your reading materials
- ✅ **Statistics** - Track learning progress per language
- ✅ **RTL Support** - Right-to-left text support for languages like Arabic, Hebrew
- ✅ **Offline Storage** - All data stored locally using SQLite

## Quick Start

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (included with Flutter)
- Android Studio / Xcode for mobile development

### Installation

1. **Create a new Flutter project:**

   ```bash
   flutter create fltr_flutter
   cd fltr_flutter
   ```

2. **Copy the project structure:**

   ```
   lib/
   ├── main.dart
   ├── models/
   │   ├── language.dart
   │   ├── text_document.dart
   │   └── term.dart
   ├── screens/
   │   ├── home_screen.dart
   │   ├── languages_screen.dart
   │   ├── texts_screen.dart
   │   ├── reader_screen.dart
   │   ├── terms_screen.dart
   │   └── statistics_screen.dart
   ├── widgets/
   │   ├── term_dialog.dart
   │   └── status_legend.dart
   ├── services/
   │   ├── database_service.dart
   │   ├── import_export_service.dart
   │   ├── dictionary_service.dart
   │   └── text_parser_service.dart
   └── utils/
       ├── constants.dart
       └── helpers.dart
   ```

3. **Update `pubspec.yaml`:**

   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     provider: ^6.1.1
     sqflite: ^2.3.0
     path: ^1.8.3
     path_provider: ^2.1.1
     shared_preferences: ^2.2.2
     file_picker: ^6.1.1
     csv: ^6.0.0
     share_plus: ^7.2.1
     url_launcher: ^6.2.2
     cupertino_icons: ^1.0.6
     intl: ^0.19.0
     collection: ^1.18.0
   ```

4. **Install dependencies:**

   ```bash
   flutter pub get
   ```

5. **Run the app:**
   ```bash
   flutter run
   ```

## Usage Guide

### Adding a Language

1. Navigate to the Languages tab
2. Tap the + button
3. Enter language name and dictionary URL(s)
4. Use `###` as placeholder for the word in dictionary URLs
5. Example: `https://www.wordreference.com/es/en/translation.asp?spen=###`

### Importing Text

**Option 1: Manual Entry**

1. Go to Texts tab
2. Tap + button
3. Enter title and paste text content

**Option 2: File Import**

1. Go to Texts tab
2. Tap the upload icon
3. Select a .txt file

### Reading Text

1. Select a text from the Texts screen
2. Tap any word to:
   - Look it up in dictionary
   - Add/edit vocabulary entry
   - Set status level (1-5, Ignored, Well Known)
   - Add translation and notes

### Managing Vocabulary

1. Go to Terms tab
2. Filter by status level
3. Search for specific terms
4. Edit or delete terms
5. Export to CSV or Anki format

### Importing/Exporting Terms

**Export:**

1. Go to Terms screen
2. Tap menu (⋮) → Export CSV or Export Anki
3. Share file via email, cloud storage, etc.

**Import:**

1. Prepare CSV with format: `Term,Status,Translation,Romanization,Sentence`
2. Go to Terms screen
3. Tap menu (⋮) → Import CSV
4. Select your CSV file

## Dictionary URL Examples

| Language | Dictionary URL                                                           |
| -------- | ------------------------------------------------------------------------ |
| Spanish  | `https://www.wordreference.com/es/en/translation.asp?spen=###`           |
| French   | `https://www.wordreference.com/fren/###`                                 |
| German   | `https://dict.leo.org/german-english/###`                                |
| Japanese | `https://jisho.org/search/###`                                           |
| Chinese  | `https://www.mdbg.net/chinese/dictionary?page=worddict&wdrst=0&wdqb=###` |
| Korean   | `https://ko.dict.naver.com/#/search?query=###`                           |
| Italian  | `https://www.wordreference.com/iten/###`                                 |

## Status Levels Explained

| Status          | Color       | Meaning             |
| --------------- | ----------- | ------------------- |
| 0 - Ignored     | Gray        | Word to skip/ignore |
| 1 - Unknown     | Red         | Just encountered    |
| 2 - Learning 2  | Orange      | Seen a few times    |
| 3 - Learning 3  | Yellow      | Getting familiar    |
| 4 - Learning 4  | Light Green | Almost known        |
| 5 - Known       | Green       | Well understood     |
| 99 - Well Known | Blue        | Fully mastered      |

## Database Schema

### Languages Table

- id, name, dict_url1, dict_url2, dict_url3
- right_to_left, show_romanization
- regexp_word_characters, regexp_split_sentences

### Texts Table

- id, language_id, title, content
- source_uri, created_at, last_read, position

### Terms Table

- id, language_id, text, lower_text
- status, translation, romanization, sentence
- created_at, last_accessed

## Advanced Features

### Custom Word Parsing

Languages can define custom regular expressions for:

- Word character patterns
- Sentence splitting rules
- Character substitutions

### Bulk Operations

- Mark all words in a text as known
- Bulk status updates for selected terms
- Export filtered terms

### Reading Position

The app remembers your reading position in each text.

## Troubleshooting

### Issue: Dictionary lookup not working

**Solution:** Ensure the dictionary URL contains `###` placeholder and you're connected to the internet.

### Issue: CSV import fails

**Solution:** Check CSV format. First line should be headers: `Term,Status,Translation,Romanization,Sentence`

### Issue: Words not highlighting

**Solution:** Ensure words are saved in the vocabulary database. The reader only highlights known terms.

## Development

### Building for Release

**Android:**

```bash
flutter build apk --release
```

**iOS:**

```bash
flutter build ios --release
```

### Running Tests

```bash
flutter test
```

### Code Structure

- **Models**: Data classes for Language, Term, TextDocument
- **Services**: Business logic and data operations
- **Screens**: Main UI screens
- **Widgets**: Reusable UI components

## Contributing

This is a conversion of the original Java FLTR application to Flutter. Contributions are welcome!

### Areas for Enhancement

- [ ] Text-to-speech integration
- [ ] Spaced repetition flashcard system
- [ ] Cloud synchronization
- [ ] More dictionary API integrations
- [ ] Advanced statistics and charts
- [ ] Dark mode theme
- [ ] Custom font support

## Credits

Original FLTR application: https://github.com/hapepo23/foreign-language-text-reader

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:

- Original FLTR: https://github.com/hapepo23/foreign-language-text-reader/issues
- Flutter implementation: Create an issue in your repository

---

**Happy Language Learning! 📚🌍**
