# FLTR - Foreign Language Text Reader (Flutter)

A Flutter implementation of the Foreign Language Text Reader application for learning languages through reading.

## Requirements

- Flutter SDK ^3.10.7
- Dart SDK ^3.10.7

## Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
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

- Import texts (TXT and EPUB formats)
- Track vocabulary with status levels (Unknown, Learning, Known, Well Known)
- Dictionary lookup integration
- Statistics and progress tracking
- Support for character-based languages (Chinese, Japanese)
- Export vocabulary to CSV or Anki format
