# Architecture Review & Migration Plan — LNT (Language Nerd Tools)

## Context

You asked for an architecture review with focus on domain separation and separation of concerns, and chose to **adopt a lightweight DDD / Clean Architecture layout** as the target. This document captures the diagnosis, defines the target structure, and lays out an incremental migration path that does **not** require a stop-the-world rewrite.

The app is a shipped Flutter codebase (TestFlight, real users), single developer, with 107 passing tests in 2-3s. Migration must preserve that test suite as a safety net throughout.

**Guiding constraint: lightweight.** We adopt the *principles* (dependency rule, abstract repos at the domain edge, use cases for non-trivial flows, pure-Dart domain) but skip the heavyweight ceremony (DTO ↔ entity mappers, one use-case-class-per-CRUD-operation, separate Dart packages per bounded context, full hex/onion ritual).

---

## Current state — short diagnosis

**Working well:**
- Repository pattern is consistent ([lib/repositories/base_repository.dart](lib/repositories/base_repository.dart))
- Domain events via [`DataChangeNotifier`](lib/services/data_change_notifier.dart) — 8 domain notifiers + typed `TermEvent` stream
- Widgets are screen-scoped; `AppState` is lean; controllers don't hold `BuildContext`
- `BaseController.safeNotify()` solves the Provider post-dispose footgun

**Layering violations (the things this migration fixes):**
- [`lib/models/term.dart`](lib/models/term.dart) imports `flutter/material.dart` and `AppLocalizations` — domain depends on UI
- [`lib/services/dictionary_service.dart`](lib/services/dictionary_service.dart) imports [`lib/screens/dictionary_webview_screen.dart`](lib/screens/dictionary_webview_screen.dart) — service depends on UI
- 7 of 9 services reach for global locator getters (`db`, `settings`, `dataChanges`) instead of constructor injection
- [`lib/services/database_service.dart`](lib/services/database_service.dart) is a god factory constructing 12 repositories
- [`lib/repositories/translation_repository.dart`](lib/repositories/translation_repository.dart) is silent (no `onChange` wiring)

**Inconsistent presentation:**
- 5 of 18 screens use controllers; the rest hold business logic directly
- [`lib/screens/vocabulary_screen.dart`](lib/screens/vocabulary_screen.dart) (766 LOC) and [`lib/widgets/dashboard/dashboard_tab.dart`](lib/widgets/dashboard/dashboard_tab.dart) (664 LOC) call `db.*` directly with manual concurrency flags
- [`lib/widgets/shared/term_dialog.dart`](lib/widgets/shared/term_dialog.dart) is **1207 LOC** with direct DB access — the worst file in the repo

---

## Target architecture

```
lib/
├── domain/                          # Pure Dart. No Flutter imports. No I/O.
│   ├── entities/                    # Term, TextDocument, Language, ReviewCard, Collection, Dictionary, ...
│   ├── value_objects/               # TermStatus, PartOfSpeech (immutable, equality-by-value)
│   ├── events/                      # TermEvent (already exists), future cross-domain events
│   └── repositories/                # Abstract interfaces only — TermRepository, TextRepository, ...
│
├── application/                     # Use cases. Pure Dart. Depends only on domain/.
│   └── use_cases/
│       ├── terms/                   # CreateTerm, UpdateTermStatus, BulkImportTerms
│       ├── texts/                   # ImportText, ParseText, MarkAsRead
│       ├── review/                  # ReviewTerm, GetDueCards, SeedReviewCards
│       ├── backup/                  # CreateBackup, RestoreBackup
│       └── translation/             # TranslateTerm, ExplainWithAi
│
├── data/                            # Concrete implementations. Knows about SQLite, HTTP, files.
│   ├── repositories/                # Implements domain/repositories/* — uses sqflite
│   ├── datasources/                 # DatabaseService (connection + migrations), platform clients
│   ├── services/                    # DeepL, LibreTranslate, AiExplanation, Tts, ChineseSegmentation
│   └── notifiers/                   # DataChangeNotifier (the wiring; events live in domain/)
│
└── presentation/                    # Flutter UI. Depends on application/ and domain/, never on data/.
    ├── screens/
    ├── widgets/                     # Keep current screen-scoped subdirs
    ├── controllers/                 # ChangeNotifiers — orchestrate use cases, no DB calls
    ├── theme/                       # AppColors, app_theme.dart
    └── l10n/                        # ARB files + generated
```

### Dependency rule (the thing that makes Clean Arch worth it)

```
presentation  →  application  →  domain
       \           ↓
        →        data  →  domain
```

- `domain/` imports nothing app-specific.
- `application/` imports only `domain/`.
- `data/` imports `domain/` (to implement interfaces) but **never** `application/` or `presentation/`.
- `presentation/` imports `application/` and `domain/` but **never** `data/`.
- The service locator binds `domain/` interfaces to `data/` implementations at startup — only place where presentation indirectly touches data.

### Where this is *lightweight* (deliberate non-goals)

- **No DTO ↔ entity mappers.** Entities double as persistence records. The mapping happens in `toMap()`/`fromMap()` on the entity. (Standard Clean Arch would split these; we don't.)
- **No use-case-per-CRUD-operation.** Trivial reads (`getById`, `getAll`) stay as direct repo calls from controllers. Use cases exist only for operations with real business logic — anything that mutates state, coordinates 2+ repos, or applies invariants.
- **No separate Dart packages per bounded context.** Folders, not packages. Promote later if a domain becomes a separable product.
- **No anti-corruption layer between domains.** `TermEvent`-style events are enough decoupling at this scale.
- **No CQRS.** Same repo for reads and writes.
- **Models stay as one class** (entity + persistence). When the impedance grows, split — not before.

---

## Migration phases

The migration is **incremental**: each phase ships independently, leaves the codebase fully working and tested, and unlocks the next. Stop after any phase if priorities change — the codebase is better than before, not in an awkward middle state.

### Phase 0 — Foundation fixes (the existing Tier 1 quick wins)

**Goal:** Eliminate the layering violations that would block any migration.

1. **Move UI helpers out of [`lib/models/term.dart`](lib/models/term.dart).** Strip `flutter/material.dart` and `AppLocalizations` imports. `TermStatus.colorFor`, `localizedNameFor`, `PartOfSpeech.localizedNameFor` move to `lib/presentation/theme/term_status_ui.dart` (temporary location — they end up here in the final structure anyway). [Effort: S, risk: low]

2. **Break [`DictionaryService`](lib/services/dictionary_service.dart) → screen import.** Move `Navigator.push(... DictionaryWebViewScreen)` to `lib/presentation/utils/dictionary_navigation.dart` or the call site. Service returns URLs only. [Effort: S, risk: low]

3. **Wire [`TranslationRepository`](lib/repositories/translation_repository.dart) to a new `dataChanges.translations` `DomainNotifier`.** [Effort: S, risk: low]

4. **Move [`ReviewService`](lib/services/review_service.dart) `dataChanges.notify()` calls into the repos.** Restores the invariant "only repos notify". [Effort: S, risk: low]

5. **Inject services into [`ReaderController`](lib/controllers/reader_controller.dart)** via constructor (default to locator getters). [Effort: S, risk: low]

**Deliverable:** All current tests pass. No layering violations between models/services/screens. Reader is testable with fakes.

### Phase 1 — Carve out `domain/`

**Goal:** Establish the pure-Dart core.

1. Create `lib/domain/entities/`. Move `lib/models/*.dart` here. Verify each file: no Flutter imports, no `dart:io`, no `dart:ui`. Anything UI-bound moves to `presentation/`.
2. Create `lib/domain/value_objects/`. Extract `TermStatus` and `PartOfSpeech` from `term.dart` into immutable VO classes (`==` and `hashCode` by value, factory constructors with validation). Status integer becomes a private field; expose intent-revealing methods (`isLearning`, `isMastered`) instead of leaking the int.
3. Create `lib/domain/events/`. Move `term_event.dart` here.
4. Create `lib/domain/repositories/`. For each existing repo, define an abstract interface there: `TermRepository`, `TextRepository`, `ReviewCardRepository`, etc. The interface lists only the methods used by `application/` and `presentation/`. This is the contract.
5. Update imports across the codebase. Old `lib/models/*` and `lib/repositories/*` imports become `lib/domain/entities/*` and `lib/domain/repositories/*` (interfaces only).

**Deliverable:** `lib/domain/` compiles with `import 'package:flutter/...'` banned. Run `flutter analyze` with a custom rule or grep check to enforce. Tests pass.

### Phase 2 — Move repos to `data/`, wire interfaces to implementations

**Goal:** Establish the dependency-inversion seam.

1. Create `lib/data/repositories/`. Move existing concrete repos here. Each renames to `XRepositoryImpl` (or stays `XRepository` and the interface is `XRepositoryContract` — pick one convention; *Impl suffix is fine).
2. Each impl `implements` the matching domain interface.
3. Create `lib/data/datasources/`. Move [`database_service.dart`](lib/services/database_service.dart) here. Strip its repo-construction responsibility (see step 4).
4. Update [`lib/service_locator.dart`](lib/service_locator.dart): register **interface → impl** bindings (`sl.registerLazySingleton<TermRepository>(() => TermRepositoryImpl(...))`). `DatabaseService` becomes only the connection/migration owner.
5. Move `DeepLService`, `LibreTranslateService`, `AiExplanationService`, `TtsService`, `ChineseSegmentationService` to `lib/data/services/`. Define abstract interfaces in `lib/domain/services/` *only when* a use case needs to be testable with a fake (don't pre-emptively abstract).
6. Move [`DataChangeNotifier`](lib/services/data_change_notifier.dart) to `lib/data/notifiers/`. Events themselves live in `domain/events/` (already moved in Phase 1).

**Deliverable:** `data/` is the only layer that imports SQLite, HTTP clients, file I/O. Everything above the seam talks to interfaces. Tests pass after import rewiring.

### Phase 3 — Extract use cases for the messy operations

**Goal:** Pull business logic out of screens and controllers into named, testable use cases.

Create `lib/application/use_cases/`. Extract use cases **only where it pays off** — operations that currently sprawl across screens/controllers, coordinate multiple repos, or enforce invariants. Don't wrap trivial reads.

Concrete extraction targets (in priority order):

1. **`review/ReviewTerm`** — currently in [`ReviewService.reviewTerm()`](lib/services/review_service.dart) with FSRS + transaction + cross-domain notification. Becomes a use case that takes `(termId, rating)` and orchestrates `ReviewCardRepository`, `TermRepository`, `ReviewLogRepository`, `TermStatusLogRepository`.
2. **`texts/ImportText`** — currently smeared across [`ImportExportService`](lib/services/import_export_service.dart), [`EpubImportService`](lib/services/epub_import_service.dart), [`UrlImportService`](lib/services/url_import_service.dart), and library screen logic. Becomes one use case parameterized by source.
3. **`backup/CreateBackup` and `backup/RestoreBackup`** — currently in [`BackupService`](lib/services/backup_service.dart). Service stays as the data-layer adapter for iCloud/Drive I/O; the orchestration (transactional restore with rollback) becomes the use case.
4. **`terms/CreateTerm`, `UpdateTermStatus`, `BulkImportTerms`** — each a named class. The "creating a term seeds a review card" invariant lives here, not in the screen.
5. **`translation/TranslateTerm`** — coordinates DeepL/LibreTranslate selection from settings, falls back across providers. Currently logic spread across `term_dialog.dart` and translation services.

Use case shape (one operation per class — the lightweight DDD compromise):

```dart
class ReviewTerm {
  ReviewTerm(this._cards, this._terms, this._logs);
  final ReviewCardRepository _cards;
  final TermRepository _terms;
  final ReviewLogRepository _logs;

  Future<ReviewResult> call(int termId, Rating rating) async { ... }
}
```

Controllers gain a use case dependency, drop the direct repo calls for these flows.

**Deliverable:** ~5-8 use case classes covering the operations with real business logic. Each has a unit test. Controllers shrink. Tests pass.

### Phase 4 — Move presentation, normalize controllers

**Goal:** Complete the layout and bring controller adoption to where it pays off.

1. Move `lib/screens/`, `lib/widgets/`, `lib/controllers/`, `lib/utils/app_theme.dart`, `lib/l10n/` under `lib/presentation/`. Pure rename; imports update.
2. Add a `VocabularyController` for [`vocabulary_screen.dart`](lib/screens/vocabulary_screen.dart) and a `DashboardController` for [`dashboard_tab.dart`](lib/widgets/dashboard/dashboard_tab.dart). Replace manual `_loadInProgress`/`_pendingReload` flags with `BaseController.safeNotify()`. Controllers depend on use cases (where they exist) or repo interfaces (for trivial reads).
3. Decompose [`term_dialog.dart`](lib/widgets/shared/term_dialog.dart) (1207 LOC) into shell + `TermDialogController` (uses `terms/UpdateTermStatus`, `translation/*` use cases) + 2-3 section widgets. Same treatment for [`base_term_search_dialog.dart`](lib/widgets/shared/base_term_search_dialog.dart) (475 LOC) once the pattern is proven.
4. **Rule going forward**: a screen needs a controller when it has any of (a) >1 async data source, (b) cross-screen reactivity via `dataChanges`, (c) >300 LOC of logic. The small review screens (typing, multiple-choice, cloze) stay simple — a controller would be ceremony.
5. **Rule going forward**: global locator getters allowed at the controller boundary. Banned below it. Code-review red flag.

**Deliverable:** No `db.*`/`settings.*` access from widgets. Vocabulary and dashboard have controllers. `term_dialog` is decomposed. Tests pass.

### Phase 5 — Optional polish

Skip unless something concrete pushes you here:

- Generic `AsyncState<T>` / `Result<T>` for controllers (worthwhile only after Phase 4 reveals the duplication).
- Abstract interfaces for `TtsService` / `ChineseSegmentationService` (only when you need fakes).
- Promote a domain to its own Dart package (only if a second platform/product needs it).

---

## What stays the same

- **Provider + ChangeNotifier.** Don't migrate to Riverpod/Bloc as part of this. The state-management library is not the bottleneck; the layering is. Revisit only if a concrete pain Riverpod fixes shows up (parameterized async `family`/`autoDispose` in 5+ places).
- **`DataChangeNotifier` per-domain pattern.** It's the cleanest piece of the codebase. Keep the API; just move the file.
- **`BaseRepository` and `BaseController`.** Keep both as the shared infrastructure of their layers.
- **Models double as persistence records.** No separate DTO classes. `toMap()`/`fromMap()` stays on the entity.
- **107-test suite.** Must pass after every phase.

---

## Verification

**After every phase:**
```bash
flutter analyze    # must report no issues
flutter test       # all tests pass (add new tests in Phases 1, 3, 4)
flutter run        # smoke-test reader, vocabulary, library, term dialog, review flow
```

**Phase-specific verification:**
- **Phase 0**: existing flows unchanged; status colors render correctly in vocabulary/reader/dialog (light + dark); dictionary lookup works from reader and vocabulary.
- **Phase 1**: add a CI grep / `dart_code_metrics` rule banning Flutter imports in `lib/domain/`. Add a test that imports every domain entity and exercises basic invariants.
- **Phase 2**: in tests, register fake `TermRepository` (etc.) implementations against domain interfaces — proves the dependency inversion works.
- **Phase 3**: each new use case gets a unit test with fake repos. Test the `ReviewTerm` invariant (FSRS update + log + status change atomicity) end-to-end.
- **Phase 4**: golden tests for the decomposed `term_dialog` *before* decomposition (snapshot the current behavior, then refactor against the snapshot). Manually verify vocabulary + dashboard reactivity under term mutations.

**End-state acceptance check:**
1. `grep -r "package:flutter" lib/domain lib/application` → no matches.
2. `grep -r "import.*data/" lib/presentation` → no matches (presentation never imports data).
3. `grep -r "db\." lib/presentation/widgets` → no matches (no direct DB from widgets).
4. All 107 tests pass + new use case + golden tests.
5. Largest file in `lib/presentation/widgets/shared/` is under 500 LOC.

---

## Suggested cadence

- **Phase 0**: 2-3 days, do soon. Independent of the rest. Ships value immediately.
- **Phase 1**: 1-2 days, do after 0. Mostly mechanical moves.
- **Phase 2**: 2-3 days. The interface extraction is the thinking part; the rest is plumbing.
- **Phase 3**: 1 week, opportunistic — extract one use case per feature/bug touch, not all at once.
- **Phase 4**: 1-2 weeks, opportunistic. Vocabulary controller and `term_dialog` split are the big-ROI pieces.
- **Phase 5**: only on concrete need.

If you stop after Phase 2, you have a clean dependency-inverted core with the worst layering violations gone. That's already 80% of the win.

---

## Critical files referenced

- [lib/service_locator.dart](lib/service_locator.dart) — repo registration moves here in Phase 2
- [lib/main.dart](lib/main.dart) — only `AppState` stays at top-level after Phase 4
- [lib/models/term.dart](lib/models/term.dart) — Phase 0 strip Flutter; Phase 1 split into entity + VOs
- [lib/services/database_service.dart](lib/services/database_service.dart) — Phase 2 strips it down to connection/migrations
- [lib/services/data_change_notifier.dart](lib/services/data_change_notifier.dart) — moves in Phase 2; events split to `domain/events/` in Phase 1
- [lib/services/dictionary_service.dart](lib/services/dictionary_service.dart) — Phase 0 break screen import; Phase 2 move to `data/services/`
- [lib/services/review_service.dart](lib/services/review_service.dart) — Phase 3 most of its logic becomes the `ReviewTerm` use case
- [lib/services/backup_service.dart](lib/services/backup_service.dart) — Phase 3 orchestration extracts to use cases; service stays as iCloud/Drive adapter
- [lib/repositories/base_repository.dart](lib/repositories/base_repository.dart) — keep, move to `data/repositories/`
- [lib/repositories/translation_repository.dart](lib/repositories/translation_repository.dart) — Phase 0 add `onChange`
- [lib/controllers/reader_controller.dart](lib/controllers/reader_controller.dart) — Phase 0 constructor injection; Phase 4 depends on use cases
- [lib/screens/vocabulary_screen.dart](lib/screens/vocabulary_screen.dart) — Phase 4 gains `VocabularyController`
- [lib/widgets/dashboard/dashboard_tab.dart](lib/widgets/dashboard/dashboard_tab.dart) — Phase 4 gains `DashboardController`
- [lib/widgets/shared/term_dialog.dart](lib/widgets/shared/term_dialog.dart) — Phase 4 decomposed
