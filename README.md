# LNT - Language Nerd Tools

<img width="1840" height="1196" alt="image" src="https://github.com/user-attachments/assets/261a8d77-37f3-4ac8-9d05-4b7c620be2d8" />

## Why LNT?

Most language learning apps make one of two tradeoffs: they're either
**flashcard-first** (great for drilling, poor for reading real content) or
**reading-first** (great for immersion, but vocabulary review is an afterthought).
LNT treats both as first-class citizens in a single offline, open-source app.

|                                                   | Anki   | LingQ | Memrise | **LNT**    |
| ------------------------------------------------- | ------ | ----- | ------- | ---------- |
| Import any text / EPUB / URL                      | —      | ✓     | —       | ✓          |
| Color-coded reader by vocab level                 | —      | ✓     | —       | ✓          |
| FSRS spaced repetition                            | plugin | —     | —       | ✓ built-in |
| Multiple review modes (MC, cloze, typing, stroke) | —      | —     | —       | ✓          |
| Chinese stroke & radical practice                 | —      | —     | —       | ✓          |
| AI-powered word explanations                      | —      | —     | —       | ✓          |
| 100% local, no account required                   | ✓      | —     | —       | ✓          |
| Open source & self-hostable                       | ✓      | —     | —       | ✓          |
| Export to Anki / CSV                              | ✓      | —     | —       | ✓          |

**LNT is for language learners who:**

- Want to study from real content (articles, books, podcasts) — not pre-made decks
- Care about owning their data and not paying a subscription
- Are serious about Chinese (stroke order, radical practice, jieba segmentation)
- Want FSRS scheduling without wrestling with Anki plugins

## Features

- Color-coded reader with multi-word selection
- Import texts from web, plain text, or EPUB files
- Track vocabulary with ability to export (CSV or Anki)
- Review vocabulary through flashcards (with help of FSRS algorithm)
- DeepL/LibreTranslate translation services integration

## Development guide

### Requirements

- Flutter SDK ^3.10.7
- Dart SDK ^3.10.7

### Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/VFedyk/lnt
   cd lnt
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the application:

   ```bash
   # For macOS
   flutter run -d macos

   # For iOS (simulator or device)
   flutter run -d ios

   # For Android (emulator or device)
   flutter run -d android

   # For Chrome (web)
   flutter run -d chrome
   ```

### Build

```bash
# Build for macOS
flutter build macos

# Build for iOS
flutter build ios

# Build APK for Android
flutter build apk

# Build for web
flutter build web
```

## Gratitude and recognition

- FLTR
- LingQ
- Anki
- Memrise
