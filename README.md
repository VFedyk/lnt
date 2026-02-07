# LNT - Language Nerd Tools

Yet another language learning application

## Features

- Import texts from URL, TXT, or EPUB (with cover extraction)
- Track vocabulary with status levels (Unknown → Known)
- Review vocabulary through flashcards (should be more tools for review in the future)
- Link word forms to base terms
- Color-coded reader with multi-word selection
- DeepL/LibreTranslate translation integration
- Character-based language support (Chinese, Japanese)
- Export vocabulary to CSV or Anki


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
