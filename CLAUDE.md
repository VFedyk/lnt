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
├── widgets/               # UI components organized by screen
│   ├── shared/            # Used by 2+ screens (app_empty_state, term_dialog, review_progress_*, animated_counter, translation_mixin, base_term_search_dialog)
│   ├── dashboard/         # dashboard_tab.dart only (activity_heatmap, dashboard_charts, custom_chart_tooltip)
│   ├── dictionaries/      # dictionaries_screen.dart only
│   ├── languages/         # languages_screen.dart only
│   ├── library/           # library_screen.dart only (dialogs + grid/list/search/status widgets + book_cover)
│   ├── reader/            # reader_screen.dart only (dialogs, reader_content, paragraph_rich_text, status_legend, word_list_drawer)
│   └── settings/          # settings_screen.dart only (section widgets incl. target_language_section)
├── utils/                 # Helpers, constants, CoverImageHelper, language_utils
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

- **Service locator**: `setupServiceLocator()` in `main.dart` registers all services. Access via top-level getters: `db`, `settings`, `backupService`, `reviewService`, `deepLService`, `libreTranslateService`, `dataChanges`
- **Repository pattern**: `db.terms.getAll()` etc.
- Repositories use lazy `() => database` callback — DB can be closed and reopened
- **Reactive data layer**: `DataChangeNotifier` (singleton via get_it) holds per-domain `DomainNotifier` instances (`dataChanges.terms`, `.texts`, `.languages`, `.collections`, `.reviewCards`). Repositories call `notifyChange()` after mutations; screens/controllers `addListener` on relevant domains and auto-reload. Use `dataChanges.notifyAll()` for bulk invalidation (e.g. backup restore).
- **Localization**: Always add strings to both `app_en.arb` and `app_uk.arb`, then run `flutter gen-l10n`
- **Language utilities** (`lib/utils/language_utils.dart`): `localizedLangName(l10n, isoCode)` returns a locale-aware display name; `langSortKey(s, locale)` returns a sort key that correctly orders Ukrainian special letters (Є, І, Ї, Ґ)
- **Translation provider lookups**: Use `DeepLService.deeplCode(isoCode)` and `LibreTranslateService.libreCode(isoCode)` (ISO 639-1, case-insensitive) — **not** name-based. `TranslationMixin` requires `String get languageCode` in addition to `languageName`
- **Target language**: stored via `settings.getDeepLTargetLang()` / `setDeepLTargetLang()` as uppercase DeepL code (e.g. `'EN'`, `'UK'`). Displayed and sorted via `TargetLanguageSection` on the settings screen (placed under app language, not inside the DeepL card)
- **Cover images**: stored as relative paths (`covers/<name>.jpg`) in documents dir, resolved at runtime by `CoverImageHelper`
- **Backup**: zip archive containing `lnt.db` + `covers/` directory
- **iCloud container**: `iCloud.lnt-db-backup`
- **Google Drive**: hidden app data folder (`appDataFolder`)
- **Google Sign-In v7**: singleton `GoogleSignIn.instance`, must call `initialize()` once before `authenticate()`

## UI and theming

- **Theme colors are the foundation**: Always use theme colors instead of hardcoded values for consistency across light/dark modes
- **AppColors extension** (`lib/utils/app_theme.dart`): Access via `context.appColors` for semantic colors:
  - `success` / `onSuccess` — Success states (green in light, lighter green in dark)
  - `warning` / `onWarning` — Warnings (orange in light, lighter orange in dark)
  - `streak` — Streak indicators
- **Material 3 ColorScheme**: Use `Theme.of(context).colorScheme` for standard roles:
  - `primary` / `onPrimary`, `secondary` / `onSecondary`, `tertiary` / `onTertiary`
  - `error` / `onError` — Error states
  - `surface` / `onSurface`, `background` / `onBackground`
- **SnackbarHelpers** (`lib/utils/snackbar_helpers.dart`): Use for consistent user feedback:
  - `showSuccess(context, message)` — Green background with theme-aware text
  - `showError(context, message)` — Red background with theme-aware text
  - `showWarning(context, message)` — Orange background with theme-aware text
  - `showInfo(context, message)` — Default theme colors
- **DialogHelpers** (`lib/utils/dialog_helpers.dart`): Use for consistent confirmation dialogs
- **AsyncHelpers** (`lib/utils/async_helpers.dart`): Use for async operations with error handling
- **Text overflow prevention**: Wrap text in `Expanded` widgets within `Row` layouts to prevent overflow with long translations (especially important for Ukrainian locale)

## Architecture notes

- `PlatformHelper.isApple` / `PlatformHelper.isDesktop` guards platform-specific features
- Database migrations in `database_migrations.dart` with version numbering
- EPUB parsing via `epub_pro` package (camelCase API)
- **Screen controllers**: `SettingsController`, `LibraryController`, `ReaderController` — each extends `ChangeNotifier`, provided via `ChangeNotifierProvider` at screen level. Controllers own state and business logic; screens are thin UI layers that orchestrate dialogs/navigation. Controllers use `_isDisposed` + `_safeNotify()` for async safety (no `BuildContext` dependency).

## Testing

- **Command**: `flutter test` — runs all 90 tests in ~2-3 seconds
- **Expected output**: `All tests passed!` with no failures or errors
- **Verification**: Use exit code pattern to avoid parsing verbose output:
  ```bash
  flutter test > /dev/null 2>&1 && echo "✅ All tests passed!" || echo "❌ Some tests failed"
  ```
- **Test coverage**:
  - `test/services/` — Pure-logic services (text parser, review service, import/export, EPUB import, backup archive format, data change notifier)
  - `test/repositories/` — BaseRepository pattern (reactive notifications, LIKE escaping)
  - `test/controllers/` — Screen controllers (LibraryController listener lifecycle and CRUD delegation)
  - Widget tests are not yet comprehensive (default `widget_test.dart` is a leftover)
- **Platform notes**: Tests use `sqflite_common_ffi` for in-memory SQLite on all platforms (no platform-specific setup required)
- **Running specific tests**: `flutter test test/services/review_service_test.dart`
- **CI requirement**: All tests must pass before merging (`flutter analyze` + `flutter test` in GitHub Actions)

## CI/CD

- **GitHub Actions**: `.github/workflows/ci.yml` — runs `flutter analyze` and `flutter test` on push/PR to main; only triggers on changes to `lib/`, `test/`, platform dirs, or `pubspec.*`
- Xcode Cloud: `ios/ci_scripts/ci_post_clone.sh` and `macos/ci_scripts/ci_post_clone.sh`
- macOS ephemeral xcfilelists must be committed (excluded from gitignore via negation pattern)

## Lint rules

- Base: `package:flutter_lints/flutter.yaml`
- `flutter analyze` must report no issues before committing

## Workflow rules

- After every large change, run `flutter analyze` and `flutter test` and fix all issues before finishing.
- After any considerable architectural change (new layers, new packages, changed data flow), update this file to reflect the new state.
