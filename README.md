# FLTR - Foreign Language Text Reader (Flutter)

A Flutter implementation of the Foreign Language Text Reader application for learning languages through reading.

## Requirements

- Flutter SDK ^3.10.7
- Dart SDK ^3.10.7

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/VFedyk/fltr-exp-1
   cd fltr_flutter
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

## Build

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

## Features

- Import texts from URL, TXT, or EPUB (with cover extraction)
- Organize texts in collections with grid/list views
- Track vocabulary with status levels (Unknown → Known)
- Link word forms to base terms
- Color-coded reader with multi-word selection
- DeepL translation integration
- Character-based language support (Chinese, Japanese)
- Export vocabulary to CSV or Anki

## Gratitude and recognition

- FLTR
- LingQ
