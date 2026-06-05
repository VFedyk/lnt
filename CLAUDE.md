# CLAUDE.md — LNT (Language Nerd Tools)

## Project overview

Flutter language learning app: import texts (URL, TXT, EPUB), track vocabulary with spaced repetition (FSRS), review via flashcards, translate with DeepL/LibreTranslate. Backup/restore via iCloud and Google Drive.

## Tech stack

- **Flutter** (stable channel), Dart SDK ^3.10.7
- **State management**: Provider + ChangeNotifier (`AppState` in `main.dart`, screen-level controllers in `lib/presentation/controllers/`)
- **Database**: SQLite via `sqflite` (+ `sqflite_common_ffi` for Linux/Windows)
- **DI / Service locator**: `get_it` — registered in `lib/service_locator.dart`
- **Architecture**: Lightweight Clean Architecture — `domain/` (pure Dart) → `data/` (SQLite/HTTP) → `application/` (use cases) → `services/` (business logic) → `presentation/` (controllers + screens + widgets). Dependency inversion via abstract interfaces in `domain/repositories/`.
- **Localization**: ARB files (`app_en.arb`, `app_uk.arb`) → `flutter gen-l10n`
- **Platforms**: iOS, macOS, Android, Linux, Windows, Web

## Project structure

```
lib/
├── main.dart              # Entry point, AppState provider
├── service_locator.dart   # get_it registrations + convenience getters
├── domain/                # Pure Dart — no Flutter, no I/O
│   ├── entities/          # Term, TextDocument, Language, ReviewCard, Collection, Dictionary, …
│   ├── value_objects/     # TermStatus, PartOfSpeech (immutable, equality-by-value)
│   ├── events/            # TermEvent (sealed class + subtypes)
│   └── repositories/      # Abstract interfaces: TermRepository, TextRepository, … (12 interfaces)
├── data/                  # Concrete implementations — knows about SQLite, HTTP, files
│   ├── repositories/      # XRepositoryImpl classes (implement domain interfaces); BaseRepository
│   ├── datasources/       # DatabaseService (connection + migrations), database_migrations.dart
│   ├── services/          # DeepLService, LibreTranslateService, TtsService, ChineseSegmentationService, AiExplanationService
│   └── notifiers/         # DataChangeNotifier, DomainNotifier, EventStream
├── application/           # Use cases — named, injectable, testable operations
│   └── use_cases/
│       ├── review/        # ReviewTerm (FSRS scheduling + repo writes)
│       ├── terms/         # SaveTerm (create/update term + translations), BulkImportTerms
│       └── translation/   # TranslateTerm (DeepL/LibreTranslate selection)
├── services/              # Business logic: ReviewService, BackupService, ImportExportService, EpubImportService, UrlImportService, TextParserService, DictionaryService, SettingsService, LoggerService, IsolateParser
├── presentation/          # All UI — thin screens, reusable widgets, controllers, theme
│   ├── controllers/       # ChangeNotifier controllers (one per screen or complex dialog)
│   │                      #   BaseController, LibraryController, VocabularyController,
│   │                      #   DashboardController, ReaderController, SettingsController,
│   │                      #   FlashcardReviewController, TermDialogController,
│   │                      #   BaseTermSearchDialogController
│   ├── screens/           # Full-page UI screens (thin UI layer)
│   ├── widgets/           # UI components organized by screen
│   │   ├── shared/        # Used by 2+ screens (app_empty_state, term_dialog, review_progress_*,
│   │   │                  #   animated_counter, translation_mixin, base_term_search_dialog,
│   │   │                  #   handwriting_canvas, hanzi_writer_widget, review_options_grid)
│   │   ├── dashboard/     # dashboard_tab.dart only (activity_heatmap, dashboard_charts)
│   │   ├── statistics/    # statistics_screen.dart only (status_history_chart)
│   │   ├── dictionaries/  # dictionaries_screen.dart only
│   │   ├── languages/     # languages_screen.dart only
│   │   ├── library/       # library_screen.dart only (dialogs + grid/list/search/status + book_cover)
│   │   ├── reader/        # reader_screen.dart only (dialogs, reader_content, paragraph_rich_text, …)
│   │   ├── review/        # review_screen.dart only (exercise_card, review_stats_section)
│   │   └── settings/      # settings_screen.dart only (section widgets)
│   ├── theme/             # AppTheme, AppColors extension, TermStatusUI, PartOfSpeechUI
│   └── models/            # chart_data.dart (view models for charts)
├── utils/                 # Helpers, constants, CoverImageHelper, language_utils, radicals
└── l10n/                  # Localization (ARB files + generated)
```

### Key screens

- **home_screen.dart** — shell with 5 tabs via `HomeTab` enum: dashboard, texts (library), terms (vocabulary), review, languages
- **vocabulary_screen.dart** — browse and manage all terms
- **statistics_screen.dart** — learning analytics with status history charts
- **review_screen.dart** — entry point for review; links to exercise-specific screens:
  - **flashcard_review_screen.dart** — flip-card review
  - **multiple_choice_review_screen.dart** — multiple choice
  - **cloze_review_screen.dart** — fill-in-the-blank (`ClozeMode`: easy / advanced)
  - **typing_review_screen.dart** — typed answer (`TypingDirection`: sourceToTarget / targetToSource)
  - **stroke_review_screen.dart** — handwriting practice with canvas
- **radical_practice_screen.dart** / **radical_writing_screen.dart** — Kangxi radical learning (214 radicals)

## Common commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Run linter (must pass with no issues)
flutter gen-l10n             # Regenerate localization after editing .arb files
flutter build ipa            # Build iOS for TestFlight
flutter build macos          # Build macOS
```

## Key conventions

- **Service locator**: `setupServiceLocator()` in `main.dart` registers all services. Access via top-level getters: `db`, `settings`, `backupService`, `reviewService`, `deepLService`, `libreTranslateService`, `ttsService`, `chineseSegService`, `dataChanges`. Use case getters: `reviewTerm`, `saveTerm`, `bulkImportTerms`, `translateTerm`.
- **Repository pattern**: `db.terms.getAll()` etc. `db` is a `DatabaseService` facade that exposes all repos typed to their domain interfaces. Each repo also registered individually: `sl<TermRepository>()`.
- Repositories use lazy `() => database` callback — DB can be closed and reopened. Concrete impls are `XRepositoryImpl` in `lib/data/repositories/`; domain interfaces are in `lib/domain/repositories/`.
- **Dependency inversion**: `DatabaseService` accepts `SettingsService` and `DataChangeNotifier` via constructor — no `service_locator.dart` import inside `lib/data/`.
- **Reactive data layer**: `DataChangeNotifier` (`lib/data/notifiers/`) holds per-domain `DomainNotifier` instances (`dataChanges.terms`, `.texts`, `.languages`, `.collections`, `.reviewCards`, `.dictionaries`, `.termSentences`, `.radicalProgress`, `.translations`). Repositories call `notifyChange()` after mutations; screens/controllers `addListener` on relevant domains and auto-reload. Use `dataChanges.notifyAll()` for bulk invalidation (e.g. backup restore).
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
- **AppColors extension** (`lib/presentation/theme/app_theme.dart`): Access via `context.appColors` for semantic colors:
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
- Database migrations in `lib/data/datasources/database_migrations.dart` with version numbering
- EPUB parsing via `epub_pro` package (camelCase API)
- **Screen controllers** (`lib/presentation/controllers/`): `SettingsController`, `LibraryController`, `VocabularyController`, `DashboardController`, `ReaderController`, `FlashcardReviewController`, plus `TermDialogController` and `BaseTermSearchDialogController` for complex dialogs. Each extends `BaseController` (which extends `ChangeNotifier`), provided via `ChangeNotifierProvider`. Controllers own all state and db access; screens/widgets are thin UI layers. `BaseController.safeNotify()` prevents post-dispose notification errors. Controllers never hold `BuildContext` — dialog-showing and SnackBars stay in the widget layer.
- **SettingsController backup state**: tracks `icloudRemoteDate` (date of file in iCloud), `icloudLocalDate` (last backup from this device), `lastRestoreDate`, `isCheckingBackup`. Call `recheckICloudBackup()` to refresh the remote date.
- **Use cases** (`lib/application/use_cases/`): `ReviewTerm` (owns FSRS scheduler, writes review log + card + term status), `SaveTerm` (create/update term + replaceForTerm in one call), `BulkImportTerms`, `TranslateTerm` (provider selection + language-code mapping). `ReviewService` delegates to `ReviewTerm` and is injected via constructor. Use case getters in `service_locator.dart`: `reviewTerm`, `saveTerm`, `bulkImportTerms`, `translateTerm`.
- **TtsService** (`ttsService`): text-to-speech via `flutter_tts`; access via `ttsService` getter.
- **ChineseSegmentationService** (`chineseSegService`): word tokenization via `jieba_flutter` for Chinese texts.
- **AiExplanationService**: AI-powered word/phrase explanations; supports OpenAI, Anthropic, and Ollama backends. Not registered as a singleton — instantiated where needed. Settings managed via `ai_settings_section.dart`.
- **Radicals** (`lib/utils/radicals.dart`): `Radical` class + `kRadicals` constant with all 214 Kangxi radicals. Progress tracked via `RadicalProgressRepositoryImpl` and `dataChanges.radicalProgress`.

## Sync layer

Sync with `lnt-server` (sibling project at `../lnt-server`) is split across four services in `lib/services/`:

| File | Responsibility |
|---|---|
| `sync_service.dart` | Orchestrator: `sync()` / `fullSync()`; creates API clients; drives pull → push pipeline |
| `sync_image_service.dart` | Image upload (push) and download/register (pull); `prefetchImageRefs`, `syncCoverImages`, `resolveCoverImageId` |
| `sync_push_service.dart` | Collects local DB rows into `EventInput` batches: `collect{Languages,Collections,Texts,Terms,ReviewLogs,StatusLogs}` |
| `sync_pull_service.dart` | Applies remote events to local DB: `applyEvent`, `validatePayload` |

### SyncApi (`lib/data/services/sync_api.dart`)

- `SyncApi(baseUrl)` — unauthenticated; use **only** for `resolveUser()`.
- `SyncApi.withToken(baseUrl, token)` — authenticated; adds `Authorization: Bearer <token>` to all requests.

`resolveUser()` returns `(String userId, String token)`. The token is persisted in `SettingsService` under `sync_token` and passed to `SyncApi.withToken` on every subsequent sync. Clearing the token (via `clearSyncState()` or changing nickname) forces a fresh resolve.

All calls except `pushEvents` retry up to 3× on transient network errors with exponential backoff. `pushEvents` has a timeout but **no retry** — retrying a push would duplicate events server-side.

### Pull phase (pagination-aware)

1. Loop `api.pullEvents(userId, since: cursor, limit: 1000)` until `events` is empty.
2. Before applying each page: `imageService.prefetchImageRefs` downloads all referenced cover images in parallel (concurrency 4) into `imageRefCache`.
3. Apply each event via `pullService.applyEvent`; catch exceptions per-event so one bad event doesn't abort the whole pull.
4. Advance cursor to `events.last.seq`; persist `latestSeq` when done.

`applyEvent` uses `ConflictAlgorithm.replace` for LWW domains (`language/collection/text/term/review_card`) and `ConflictAlgorithm.ignore` for append-only logs (`review_log/term_status_log`). The `term` domain wraps delete-old-translations + insert-new-translations in a **sqflite transaction** to prevent partial writes leaving a term with no translations.

### Push phase

1. `imageService.syncCoverImages`: SHA-256-hash unsynced cover images, batch-check server, upload missing in parallel (concurrency 4), persist `sync_hash`.
2. `pushService.collect*`: query local tables filtered by `lastPushedAt`.
3. Push in batches of 200 via `api.pushEvents`.

### Settings keys (SharedPreferences)

| Key | Purpose |
|---|---|
| `sync_server_url` | Base URL of lnt-server |
| `sync_nickname` | User's nickname |
| `sync_user_id` | UUID from server (cached after first resolve) |
| `sync_token` | Bearer token (cached after first resolve; cleared with sync state) |
| `sync_device_id` | Stable per-install UUID |
| `sync_last_pulled_seq` | Server seq cursor for next pull |
| `sync_last_pushed_at` | Milliseconds epoch; used to filter push queries |

### Error UX (`sync_settings_section.dart`)

`_syncErrorMessage(e)` maps to user-readable strings:
- `SyncApiException` → `"Server error (N): …"` (shows HTTP status)
- `SocketException` / `TimeoutException` → `"Network error — check your connection and server URL"`
- Everything else → `"Sync failed: $e"`

## Testing

- **Command**: `flutter test` — runs all 151 tests in ~2-3 seconds
- **Expected output**: `All tests passed!` with no failures or errors
- **Verification**: Use exit code pattern to avoid parsing verbose output:
  ```bash
  flutter test > /dev/null 2>&1 && echo "✅ All tests passed!" || echo "❌ Some tests failed"
  ```
- **Test coverage**:
  - `test/application/` — Use cases: ReviewTerm (FSRS + repo writes), SaveTerm, BulkImportTerms, TranslateTerm
  - `test/services/` — Pure-logic services (text parser, review service, import/export, EPUB import, backup archive format, data change notifier, Chinese segmentation)
  - `test/repositories/` — BaseRepository pattern (reactive notifications, LIKE escaping)
  - `test/controllers/` — Screen controllers (LibraryController listener lifecycle and CRUD delegation)
  - `test/services/sync_service_test.dart` — Sync layer: `validatePayload` (all domains), `applyEvent` (LWW replace, ignore-duplicate, term atomicity), collectors with timestamp windowing; uses `sqflite_common_ffi` in-memory DB with full v21 schema
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
