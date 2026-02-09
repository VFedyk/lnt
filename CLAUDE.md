# CLAUDE.md — LNT (Language Nerd Tools)

## Project overview

Flutter language learning app: import texts (URL, TXT, EPUB), track vocabulary with spaced repetition (FSRS), review via flashcards, translate with DeepL/LibreTranslate. Backup/restore via iCloud and Google Drive.

## Tech stack

- **Flutter** (stable channel), Dart SDK ^3.10.7
- **State management**: Provider + ChangeNotifier (`AppState` in `main.dart`, screen-level controllers in `lib/controllers/`)
- **Database**: SQLite via `sqflite` (+ `sqflite_common_ffi` for Linux/Windows)
- **DI / Service locator**: `get_it` — registered in `lib/service_locator.dart`
- **Architecture**: Repository pattern → Services (via get_it) → Screens/Widgets
- **Localization**: ARB files (`app_en.arb`, `app_uk.arb`) → `flutter gen-l10n`
- **Platforms**: iOS, macOS, Android, Linux, Windows, Web

## Project structure

```
lib/
├── main.dart              # Entry point, AppState provider
├── service_locator.dart   # get_it registrations + convenience getters
├── models/                # Data models (Term, TextDocument, Language, etc.)
├── repositories/          # DB access layer (BaseRepository pattern)
├── services/              # Business logic (registered via get_it)
├── controllers/           # Screen-level ChangeNotifier controllers
├── screens/               # Full-page UI screens (thin UI layer)
├── widgets/               # Reusable UI components and dialogs
├── utils/                 # Helpers, constants, CoverImageHelper
└── l10n/                  # Localization (ARB files + generated)
```

## Common commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Run linter (must pass with no issues)
flutter gen-l10n             # Regenerate localization after editing .arb files
flutter build ipa            # Build iOS for TestFlight
flutter build macos          # Build macOS
```

## Key conventions

- **Service locator**: `setupServiceLocator()` in `main.dart` registers all services. Access via top-level getters: `db`, `settings`, `backupService`, `reviewService`, `deepLService`, `libreTranslateService`
- **Repository pattern**: `db.terms.getAll()` etc.
- Repositories use lazy `() => database` callback — DB can be closed and reopened
- **Localization**: Always add strings to both `app_en.arb` and `app_uk.arb`, then run `flutter gen-l10n`
- **Cover images**: stored as relative paths (`covers/<name>.jpg`) in documents dir, resolved at runtime by `CoverImageHelper`
- **Backup**: zip archive containing `lnt.db` + `covers/` directory
- **iCloud container**: `iCloud.lnt-db-backup`
- **Google Drive**: hidden app data folder (`appDataFolder`)
- **Google Sign-In v7**: singleton `GoogleSignIn.instance`, must call `initialize()` once before `authenticate()`

## Architecture notes

- `AppState.dataVersion` increments after backup restore → `HomeScreen` uses `ValueKey(dataVersion)` to force full rebuild
- `PlatformHelper.isApple` / `PlatformHelper.isDesktop` guards platform-specific features
- Database migrations in `database_migrations.dart` with version numbering
- EPUB parsing via `epub_pro` package (camelCase API)
- **Screen controllers**: `SettingsController`, `LibraryController`, `ReaderController` — each extends `ChangeNotifier`, provided via `ChangeNotifierProvider` at screen level. Controllers own state and business logic; screens are thin UI layers that orchestrate dialogs/navigation. Controllers use `_isDisposed` + `_safeNotify()` for async safety (no `BuildContext` dependency).

## Testing

- Tests live in `test/services/` — run with `flutter test`
- Pure-logic services are tested (text parser, review service, import/export, EPUB import, backup archive format)
- Widget tests are not yet comprehensive (default `widget_test.dart` is a leftover)

## CI/CD

- **GitHub Actions**: `.github/workflows/ci.yml` — runs `flutter analyze` and `flutter test` on push/PR to main; only triggers on changes to `lib/`, `test/`, platform dirs, or `pubspec.*`
- Xcode Cloud: `ios/ci_scripts/ci_post_clone.sh` and `macos/ci_scripts/ci_post_clone.sh`
- macOS ephemeral xcfilelists must be committed (excluded from gitignore via negation pattern)

## Lint rules

- Base: `package:flutter_lints/flutter.yaml`
- `flutter analyze` must report no issues before committing
