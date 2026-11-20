# Library Screen Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/library-screen/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling (`test/domain/entities/song_test.dart`, `test/data/repositories/drift_song_repository_test.dart`, theme-tokens feature's widget-test pattern) and `AGENTS.md` §5/§7, `COMPONENTS.md`'s closing convention ("cada componente tem um teste de widget cobrindo estados, tema escuro e semântica"). Guidelines found: `AGENTS.md`, `COMPONENTS.md`, `CLAUDE.md` Testing Rules.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Domain entity/enum (`SongOrigin`, `Song` extension, `SongRepository` interface) | unit (spot-check, exceeding the entity/config floor — mirrors theme-tokens' precedent) | Default value and one round-trip per new field; interface itself needs no test (abstract) | `test/domain/entities/*_test.dart` | `flutter test test/domain/` |
| Data (`SongMapper`, `DriftSongRepository.markRehearsed`, schema migration) | unit (`NativeDatabase.memory()`, per AD-010) | Every new branch (create/receive origin round-trip, markRehearsed success/not-found, v1→v2 migration preserves data) | `test/data/**/*_test.dart` | `flutter test test/data/` |
| Presentation shared widgets (`CantaeScaffold`, `NavPill`, `SearchField`, `SegmentedControl`, `VoicePartBadge`, `SongRow`, `EmptyState`, `PrimaryButton`/`SecondaryButton`) | widget | Per `COMPONENTS.md`: states, dark theme, accessibility semantics — for every component | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets/` |
| Presentation providers (`library_providers.dart`, `song_repository_provider.dart`) | unit (`ProviderContainer`) | Every pure function branch: search match, origin filter, each sort order, highlight selection | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers/` |
| Presentation screens (`LibraryScreen`, `ComingSoonScreen`) | widget | All 5 `LibraryScreen` states (populated/empty/loading/filtered-empty/error) + both themes spot-checked; `ComingSoonScreen` renders with a given title | `test/presentation/screens/**/*_test.dart` | `flutter test test/presentation/screens/` |
| Routing (`AppRouter`) | widget | Initial route renders `LibraryScreen`; each named placeholder route renders `ComingSoonScreen` | `test/presentation/routing/*_test.dart` | `flutter test test/presentation/routing/` |
| `main.dart` wiring | widget (smoke) | App boots, Biblioteca route visible, no crash | `test/main_test.dart` | `flutter test test/main_test.dart` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task with only unit tests | `flutter test test/domain/ test/data/ test/presentation/providers/` |
| Full | After a task with widget tests | `flutter test test/presentation/` |
| Build | After the last task in a phase, or the feature's last task | `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/` |

---

## Execution Plan

### Phase 1: Domain extension

```
T1 -> T2
T1 -> T3
```

### Phase 2: Data + infrastructure

```
T1 -> T4
T4 -> T5
T2 -> T6
T4 -> T6
T3 -> T7
T5 -> T7
T6 -> T7
```

### Phase 3: Shared widgets (no screen yet)

No real dependencies between these 8 — each is an independent file reading only the theme layer. Executed in listed order (T8..T15) for a single worker's convenience, not because of a data dependency.

### Phase 4: Providers

```
T4 -> T16
T2 -> T17
T3 -> T17
T16 -> T17
```

### Phase 5: Screens, routing, wiring

```
T8 -> T18
T9 -> T18
T14 -> T18
T10 -> T19
T11 -> T19
T12 -> T19
T13 -> T19
T14 -> T19
T15 -> T19
T17 -> T19
T18 -> T20
T19 -> T20
T20 -> T21
```

---

## Task Breakdown

### T1: SongOrigin enum

**What**: `enum SongOrigin { created, received }`.
**Where**: `lib/domain/entities/song_origin.dart`
**Depends on**: None
**Reuses**: `lib/domain/entities/naipe.dart`'s one-enum-per-file convention
**Requirement**: LIB-12

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] Enum defined with exactly `created`, `received`
- [x] Gate check passes: `flutter test test/domain/`

**Tests**: unit
**Gate**: quick
**Status**: Done

---

### T2: Extend `Song` with `origin` and `lastRehearsedAt`

**What**: Add `SongOrigin origin = SongOrigin.created` and `DateTime? lastRehearsedAt` as optional named constructor params; no new asserts needed.
**Where**: `lib/domain/entities/song.dart`
**Depends on**: T1
**Reuses**: existing `Song` constructor/field pattern (mirrors how `version` already defaults)
**Requirement**: LIB-12

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `Song(id: ..., name: ..., author: ...)` (no `origin`/`lastRehearsedAt` passed) still compiles and `origin == SongOrigin.created`, `lastRehearsedAt == null`
- [x] A unit test confirms both defaults and an explicit-value round-trip
- [x] Gate check passes: `flutter test test/domain/`
- [x] Test count: 1+ new test, all existing `Song` tests still pass unmodified

**Tests**: unit
**Gate**: quick
**Status**: Done

---

### T3: Add `SongRepository.markRehearsed`

**What**: `Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at)` added to the abstract interface.
**Where**: `lib/domain/repositories/song_repository.dart`
**Depends on**: T1 (not a real dependency, but grouped — no new code references `SongOrigin` here; listed for phase-sequencing clarity only)
**Reuses**: `Result`/`Unit`/`Failure`
**Requirement**: LIB-13, LIB-14

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] Method signature added to the abstract class

**Tests**: none
**Gate**: build

**Status**: ⚠️ Deviation — **merged forward into T7's commit**, per `implement.md`'s "Resolving compilation dependencies" rule. Discovered mid-execution: adding this abstract method makes `DriftSongRepository` a non-abstract class with a missing concrete implementation, so `flutter analyze` (this task's own gate) cannot pass in isolation — it only passes once T7 also exists. The code change itself is written (interface method present), but it is committed together with T7's implementation, not on its own. `tasks.md` corrected to document this rather than silently diverging from the "no task produces unverified code" rule.

---

### T4: Add `origin`/`lastRehearsedAt` columns to `SongsTable`

**What**: `TextColumn get origin => text().withDefault(const Constant('created'))();` and `DateTimeColumn get lastRehearsedAt => dateTime().nullable()();`
**Where**: `lib/infrastructure/database/tables/songs_table.dart`
**Depends on**: T1
**Reuses**: existing `SongsTable` column style
**Requirement**: LIB-12

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] Both columns added with the exact types/defaults above
- [x] `build_runner` codegen re-run successfully (`app_database.g.dart` regenerates with no errors)
- [x] Gate check passes: `flutter analyze`

**Tests**: none
**Gate**: build

**Status**: ⚠️ Deviation — **merged forward into T7's commit**, same reason as T3: the project-wide `flutter analyze`/`flutter test` gate cannot pass in isolation while T3's interface addition sits uncommitted in the working tree with no implementation yet. T4's own code (the two columns + regenerated codegen) is correct and final; only its commit point moved.

---

### T5: `schemaVersion` 1→2 migration

**What**: Bump `AppDatabase.schemaVersion` to `2`; add an additive upgrade step to the existing `MigrationStrategy`.
**Where**: `lib/infrastructure/database/app_database.dart`
**Depends on**: T4
**Reuses**: AD-009's additive-migration decision (first real application)
**Requirement**: LIB-12

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `onCreate` path unchanged (still `m.createAll()` for a fresh v2 install)
- [x] Additive upgrade step added, both columns backfilled on an upgrade
- [x] A migration test (raw `sqlite3` builds a v1-shaped file with `PRAGMA user_version = 1`, then the real `AppDatabase` opens that same file) asserts: a pre-existing row survives, `origin` reads back as `'created'`, `lastRehearsedAt` reads back `null`
- [x] Gate check passes: `flutter test test/infrastructure/`
- [x] Test count: 2 new tests

**Tests**: unit
**Gate**: quick

**Status**: ⚠️ Deviation (API) + merged forward (commit point) — see `app_database.dart`'s `SPEC_DEVIATION` comment: drift's `stepByStep(from1To2: ...)` helper (as AD-009/design.md originally named it) is now generated-only (`VersionedSchema.stepByStepHelper`, requiring `drift_dev schema` snapshot export, which this project has never adopted). Used `Migrator.addColumn` directly inside a hand-written `onUpgrade: (m, from, to)` callback instead — same additive-only, versioned-by-`from` semantics, no codegen dependency. AD-009 should be amended to reflect the actual API; flagged for the Verifier / a follow-up STATE.md edit. Also added `sqlite3: ^3.5.2` to `dev_dependencies` (test-only, already a resolved transitive version) to seed a raw v1-shaped file for the migration test — required by this task's own "Done when", not scope creep. Commit point: merged into T7's commit (project-wide gate still blocked by T3 until T7 lands).

---

### T6: Extend `SongMapper`

**What**: `toCompanion` writes `origin: Value(song.origin.name)`, `lastRehearsedAt: Value(song.lastRehearsedAt)`; `fromRow` reads `origin: SongOrigin.values.byName(row.origin)`, `lastRehearsedAt: row.lastRehearsedAt`.
**Where**: `lib/data/mappers/song_mapper.dart`
**Depends on**: T2, T4
**Reuses**: existing mapper structure
**Requirement**: LIB-12

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] Both directions updated
- [x] A unit test round-trips a `Song` with `origin: SongOrigin.received` and a non-null `lastRehearsedAt` through `toCompanion`→(constructed row)→`fromRow` and confirms both fields survive
- [x] Gate check passes: `flutter test test/data/`
- [x] Test count: 2 new tests, existing mapper tests unmodified (the shared `_row()` test helper was updated to pass `origin`/`lastRehearsedAt` through, since `SongsTableData`'s generated constructor now requires `origin` — a mechanical consequence of T4's schema change, not a weakened assertion)

**Tests**: unit
**Gate**: quick

**Status**: ⚠️ Deviation — **merged forward into T7's commit**, same reason as T3/T4.

---

### T7: `DriftSongRepository.markRehearsed`

**What**: Implements the interface method: not-found check (reusing `delete`'s existence-check pattern) → single-column `update` via a `SongsTableCompanion` that touches only `lastRehearsedAt`. **This commit also includes T3, T4, T5, T6** (see each one's Status note — all merged forward because none of them can pass the project-wide gate alone while T3's interface addition sits unimplemented).
**Where**: `lib/data/repositories/drift_song_repository.dart`, plus T3/T4/T5/T6's files, committed together
**Depends on**: T3, T5, T6
**Reuses**: the existing not-found-check pattern from `delete`
**Requirement**: LIB-13, LIB-14

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] Existing song: `lastRehearsedAt` updates to the given value; `tracks`/`lyrics` rows untouched (asserted by re-reading via `getById` and comparing track/lyric lists before/after)
- [x] Non-existent id: returns `Result.failure(NotFoundFailure(code: 'song_not_found'))`
- [x] Gate check passes: `flutter test test/data/`
- [x] Test count: 2 new tests (success path, not-found path)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete (combined T3-T7 commit). Full Phase 2 sanity gate: `flutter analyze` 0 issues, `flutter test test/domain/ test/data/ test/infrastructure/` **255/255**, `check_layers.py` clean, `dart analyze lib/domain/` clean.

---

### T8: `CantaeScaffold`

**What**: Base screen shell — top row (left/right widget slots), scrollable body, optional fixed footer.
**Where**: `lib/presentation/widgets/cantae_scaffold.dart`
**Depends on**: None
**Reuses**: `CantaeSpacing` (margin 20, footer 12/28), `CantaeColors.bg`
**Requirement**: LIB-02 (structural, shared by every AC)

**Tools**: MCP: NONE · Skill: `flutter-clean-architecture` (confirm `presentation/widgets/` placement — first widget file in this directory)

**Done when**:
- [ ] Renders top/body/footer slots per `COMPONENTS.md`
- [ ] Widget test: renders with/without footer, both themes, safe-area respected
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T9: `NavPill`

**What**: Top nav pill, variants `back`/`exit`/`cancel`/`action`. This feature uses `action` ("Importar") and will reuse `back` in `ComingSoonScreen`.
**Where**: `lib/presentation/widgets/nav_pill.dart`
**Depends on**: None
**Reuses**: `CantaeColors.fillMuted`, `CantaeTypography.label`
**Requirement**: LIB-10

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] All 4 variants render with correct label/semantics (button role)
- [ ] Widget test: each variant, both themes, tap callback fires
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T10: `SearchField`

**What**: Search input, `fillField` background, search icon, placeholder "Buscar música ou autor".
**Where**: `lib/presentation/widgets/search_field.dart`
**Depends on**: None
**Reuses**: theme tokens
**Requirement**: LIB-04, LIB-05

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] Renders with placeholder; `onChanged` fires with the typed text; supports a `enabled: false` state (for the loading-state Edge Case)
- [ ] Widget test: text entry triggers callback, disabled state blocks input, both themes
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T11: `SegmentedControl`

**What**: Generic N-option segmented control (tab/radio semantics), track `fillField`, active segment `segmentSelected` + shadow.
**Where**: `lib/presentation/widgets/segmented_control.dart`
**Depends on**: None
**Reuses**: theme tokens
**Requirement**: LIB-02, LIB-06

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] Generic over a list of `(label, value)` options; exposes tab/radio semantics; selecting a segment calls `onChanged` with that value
- [ ] Widget test: selection changes visual state and fires callback, semantics exposed, both themes
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T12: `VoicePartBadge`

**What**: Naipe badge — `filled`/`missing`/`visitor`/`all` variants, sizes 18/22/26.
**Where**: `lib/presentation/widgets/voice_part_badge.dart`
**Depends on**: None
**Reuses**: `VoicePartColors`
**Requirement**: LIB-02

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] All 4 variants render with the letter/name required by `VoicePartColors` (color is never the only signal — letter always present)
- [ ] Widget test: each variant renders its letter, `missing` shows dashed outline, both themes
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T13: `SongRow`

**What**: One library list row — title, "Autor · status" subtitle (status text per spec's confirmed "Falta {Naipe}"/"Faltam {N} naipes" rule, `warningInline` when present), up to 4 `VoicePartBadge`s, optional "destacado" (`surface`) background.
**Where**: `lib/presentation/widgets/song_row.dart`
**Depends on**: None (takes `Song` + `highlighted: bool` as plain params; doesn't read providers itself — stays presentation-dumb/testable in isolation)
**Reuses**: `VoicePartBadge` (T12), `CantaeTypography.listTitle`
**Requirement**: LIB-02, LIB-08

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] Complete song: no status text. Missing 1 naipe: "Falta {Naipe}". Missing 2+: "Faltam {N} naipes"
- [ ] `highlighted: true` renders the `surface` background treatment
- [ ] Widget test: all three status variants, highlighted vs. not, tap callback fires, both themes
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T14: `EmptyState`

**What**: Icon (72×72, `accentSoft`) + title (28/700) + message + primary action + optional secondary action.
**Where**: `lib/presentation/widgets/empty_state.dart`
**Depends on**: None
**Reuses**: theme tokens
**Requirement**: LIB-03

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] Renders with/without the secondary action; primary action always present and tappable
- [ ] Widget test: both action configurations, tap callbacks fire, both themes
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T15: `PrimaryButton` / `SecondaryButton`

**What**: Two small button widgets sharing one file (cohesive — both are fixed-height pill buttons differing only in color/role, per the granularity rule's "2-3 related things in same file = OK if cohesive").
**Where**: `lib/presentation/widgets/buttons.dart`
**Depends on**: None
**Reuses**: theme tokens (`accent`/`fillSecondary`)
**Requirement**: LIB-03, LIB-10

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] Both render at pill height 54, correct colors per `COMPONENTS.md`; `PrimaryButton` supports a `loading` state (indicator + text) and `disabled` state
- [ ] Widget test: normal/pressed-visual/loading/disabled for `PrimaryButton`, normal for `SecondaryButton`, both themes
- [ ] Gate check passes: `flutter test test/presentation/widgets/`

**Tests**: widget
**Gate**: full

---

### T16: `AppDatabase` + `songRepositoryProvider`

**What**: A `Provider<AppDatabase>` constructing the real on-device database (via `sqlite3_flutter_libs`/`path_provider`, following the existing infra pattern) and a `Provider<SongRepository>` wrapping it in `DriftSongRepository`.
**Where**: `lib/presentation/providers/song_repository_provider.dart`
**Depends on**: T4 (needs the final `AppDatabase` shape to exist, even though this task doesn't touch the migration itself)
**Reuses**: `AppDatabase`, `DriftSongRepository`
**Requirement**: LIB-02 (infra glue, no AC of its own)

**Tools**: MCP: NONE · Skill: `flutter-clean-architecture` (confirm provider file doesn't leak infra types into widgets)

**Done when**:
- [ ] `songRepositoryProvider` resolves to a working `SongRepository` backed by a real file-based `AppDatabase`
- [ ] A unit test overrides this provider with an in-memory `AppDatabase` (via `ProviderContainer(overrides: [...])`) and confirms `songRepositoryProvider` resolves without throwing
- [ ] Gate check passes: `flutter test test/presentation/providers/`

**Tests**: unit
**Gate**: quick

---

### T17: `library_providers.dart`

**What**: `LibrarySortOrder` enum; `songsProvider` (`FutureProvider<List<Song>>`); `searchQueryProvider`, `originFilterProvider`, `sortOrderProvider` (`StateProvider`s); `visibleSongsProvider` (derived `Provider<AsyncValue<List<Song>>>`); `highlightedSongIdProvider` (derived `Provider<String?>`, computed from `songsProvider`'s raw list only).
**Where**: `lib/presentation/providers/library_providers.dart`
**Depends on**: T2, T3, T16
**Reuses**: `songRepositoryProvider` (T16), `Song`/`SongOrigin` (T2/T1)
**Requirement**: LIB-04, LIB-05, LIB-06, LIB-07, LIB-08

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] `visibleSongsProvider` combines search (case-insensitive substring on name/author) + origin filter + sort (name A-Z / lastRehearsedAt desc-with-nulls-last) correctly for every combination
- [ ] `highlightedSongIdProvider` returns the id of the song with the latest non-null `lastRehearsedAt` across the full list (ties → first in list order), or `null` if none
- [ ] Unit tests (`ProviderContainer`) cover: each sort order, origin filter alone, search alone, combined filter+search, the highlight tie-break rule, and the "all null → no highlight" case
- [ ] Gate check passes: `flutter test test/presentation/providers/`
- [ ] Test count: 8+ new tests

**Tests**: unit
**Gate**: quick

---

### T18: `ComingSoonScreen`

**What**: Single shared placeholder screen, parameterized by `title`, used by all 5 not-yet-built routes.
**Where**: `lib/presentation/screens/coming_soon/coming_soon_screen.dart`
**Depends on**: T8, T9, T14
**Reuses**: `CantaeScaffold` (T8), `NavPill` (T9, `back` variant), `EmptyState` (T14)
**Requirement**: LIB-09, LIB-10

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] Renders the given `title`, a "Voltar" `NavPill`, and an `EmptyState`-style "Em breve" message
- [ ] Widget test: renders with an arbitrary title, back pill present, both themes
- [ ] Gate check passes: `flutter test test/presentation/screens/`

**Tests**: widget
**Gate**: full

---

### T19: `LibraryScreen`

**What**: Assembles `CantaeScaffold` + `SearchField` + `SegmentedControl` + count label + sort control + `SongRow` list, wired to `visibleSongsProvider`/`highlightedSongIdProvider`, covering all 5 spec states (populated, empty, loading-skeleton, filtered-empty, error).
**Where**: `lib/presentation/screens/library/library_screen.dart`
**Depends on**: T10, T11, T12, T13, T14, T15, T17
**Reuses**: every widget from Phase 3, both providers from T17
**Requirement**: LIB-01 through LIB-11 (all of P1)

**Tools**: MCP: NONE · Skill: `flutter-ui-ux` (final screen-assembly pass — layout/accessibility checklist)

**Done when**:
- [ ] Loading: 5-row skeleton, `SearchField` disabled
- [ ] Populated: search/filter/sort/count/list all functional per spec ACs LIB-02, 05, 06, 07, 08
- [ ] Empty (zero songs): `EmptyState` per §6.2b, no search/filter UI
- [ ] Filtered-empty (search or filter yields zero of a non-empty library): "Nada encontrado para "{query}"" + "Limpar busca"
- [ ] Error: `InlineBanner` (error variant) + "Tentar de novo" invalidating `songsProvider`
- [ ] Tapping a row calls `context.goNamed('song-detail', pathParameters: {'id': song.id})`; footer/top actions call the other 4 named routes
- [ ] Widget tests for all 5 states + at least one dark-theme spot-check + navigation calls (using a fake `GoRouter`/route-observer, not a real navigation stack)
- [ ] Gate check passes: `flutter test test/presentation/screens/`
- [ ] Test count: 8+ new tests (one per state minimum, plus interaction tests)

**Tests**: widget
**Gate**: full

---

### T20: `go_router` dependency + `AppRouter`

**What**: Add `go_router: ^18.1.4` to `pubspec.yaml`; build the `routerProvider` with the 6 named routes (`library`, `song-detail`, `room-create`, `room-join`, `profile`, `package-import`).
**Where**: `pubspec.yaml` (one dependency line — not a deliverable on its own, has no independent test or gate), `lib/presentation/routing/app_router.dart` (the actual deliverable this task produces)
**Depends on**: T18, T19
**Reuses**: `LibraryScreen` (T19), `ComingSoonScreen` (T18)
**Requirement**: LIB-09, LIB-10

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] All 6 named routes resolve; `library` is `/`; the other 5 render `ComingSoonScreen` with an appropriate title
- [ ] Widget test: pumping a `MaterialApp.router` with this router shows `LibraryScreen` at `/`, and `router.goNamed('room-create')` (etc., for all 5) shows `ComingSoonScreen`
- [ ] Gate check passes: `flutter test test/presentation/routing/`
- [ ] Test count: 6+ new tests (one per route)

**Tests**: widget
**Gate**: full

---

### T21: Wire `main.dart`

**What**: `MaterialApp` → `MaterialApp.router` reading `routerProvider`; `theme`/`darkTheme` → `AppTheme.light`/`AppTheme.dark`; `themeMode` → `AppTheme.defaultThemeMode`.
**Where**: `lib/main.dart`
**Depends on**: T20
**Reuses**: `AppTheme` (theme-tokens feature), `routerProvider` (T20)
**Requirement**: LIB-01 through LIB-11 (closes the loop — this is what makes the screen actually reachable on app start)

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] App boots to the Biblioteca screen (not the Flutter starter placeholder)
- [ ] Smoke widget test: pump `CantaeApp`, confirm `LibraryScreen` (or its loading/empty state) is visible, no exception thrown
- [ ] Full BUILD gate check passes (last task of the feature): `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`
- [ ] Test count: 1+ new test; total suite count ≥ 282 (count at this feature's start) + all new tests from T1-T21

**Tests**: widget
**Gate**: build

---

## Phase Execution Map

```
T1 -> T2
T1 -> T4
T1 -> T3
T2 -> T6
T4 -> T6
T4 -> T5
T3 -> T7
T5 -> T7
T6 -> T7
T4 -> T16
T2 -> T17
T3 -> T17
T16 -> T17
T8 -> T18
T9 -> T18
T14 -> T18
T10 -> T19
T11 -> T19
T12 -> T19
T13 -> T19
T14 -> T19
T15 -> T19
T17 -> T19
T18 -> T20
T19 -> T20
T20 -> T21
```

T8-T15 (Phase 3) have no dependency edges — each is independent. All other edges above match each task's `Depends on` field exactly (T3's `Depends on: T1` is listed as a sequencing-only note in T3's body, not a real data dependency, but is still declared and diagrammed to keep this check mechanical and honest).

**21 tasks total.** Packed into task-budgeted batches (~7/worker, whole phases only): **Batch A** = Phase 1 + Phase 2 (7 tasks: T1-T7), **Batch B** = Phase 3 (8 tasks: T8-T15), **Batch C** = Phase 4 + Phase 5 (6 tasks: T16-T21). This exceeds the ~8-task single-batch threshold, so the sub-agent offer is presented to the user before Execute begins.

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: SongOrigin | 1 enum, 1 file | ✅ Granular |
| T2: Song extension | 1 class modified, 2 new fields | ✅ Granular |
| T3: SongRepository.markRehearsed | 1 interface method | ✅ Granular |
| T4: SongsTable columns | 1 table, 2 columns | ✅ Granular |
| T5: Migration | 1 migration step | ✅ Granular |
| T6: SongMapper | 1 class, 2 methods modified | ✅ Granular |
| T7: DriftSongRepository.markRehearsed | 1 method, 1 file | ✅ Granular |
| T8: CantaeScaffold | 1 widget, 1 file | ✅ Granular |
| T9: NavPill | 1 widget, 1 file | ✅ Granular |
| T10: SearchField | 1 widget, 1 file | ✅ Granular |
| T11: SegmentedControl | 1 widget, 1 file | ✅ Granular |
| T12: VoicePartBadge | 1 widget, 1 file | ✅ Granular |
| T13: SongRow | 1 widget, 1 file | ✅ Granular |
| T14: EmptyState | 1 widget, 1 file | ✅ Granular |
| T15: PrimaryButton/SecondaryButton | 2 small cohesive widgets, 1 file | ✅ Granular (cohesive pair, same reasoning as theme-tokens' T2) |
| T16: AppDatabase+songRepositoryProvider | 2 providers, 1 file | ✅ Granular (cohesive — one wraps the other) |
| T17: library_providers.dart | 6 small providers/enum, 1 file, 1 cohesive concern (library list derivation) | ✅ Granular (cohesive — matches the chosen "small composed providers" architecture, which is explicitly one file by design) |
| T18: ComingSoonScreen | 1 widget, 1 file | ✅ Granular |
| T19: LibraryScreen | 1 widget, 1 file (the screen itself — large by nature of assembling 7 dependencies, but it IS the one deliverable the whole feature exists to produce) | ✅ Granular (single cohesive deliverable, not multiple unrelated things) |
| T20: go_router + AppRouter | 1 dependency + 1 router file | ✅ Granular |
| T21: main.dart wiring | 1 file modified | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | (no incoming edge) | ✅ Match |
| T2 | T1 | `T1 -> T2` | ✅ Match |
| T3 | T1 | `T1 -> T3` | ✅ Match |
| T4 | T1 | `T1 -> T4` | ✅ Match |
| T5 | T4 | `T4 -> T5` | ✅ Match |
| T6 | T2, T4 | `T2 -> T6`, `T4 -> T6` | ✅ Match |
| T7 | T3, T5, T6 | `T3 -> T7`, `T5 -> T7`, `T6 -> T7` | ✅ Match |
| T8 | None | (no incoming edge) | ✅ Match |
| T9 | None | (no incoming edge) | ✅ Match |
| T10 | None | (no incoming edge) | ✅ Match |
| T11 | None | (no incoming edge) | ✅ Match |
| T12 | None | (no incoming edge) | ✅ Match |
| T13 | None | (no incoming edge) | ✅ Match |
| T14 | None | (no incoming edge) | ✅ Match |
| T15 | None | (no incoming edge) | ✅ Match |
| T16 | T4 | `T4 -> T16` | ✅ Match |
| T17 | T2, T3, T16 | `T2 -> T17`, `T3 -> T17`, `T16 -> T17` | ✅ Match |
| T18 | T8, T9, T14 | `T8 -> T18`, `T9 -> T18`, `T14 -> T18` | ✅ Match |
| T19 | T10, T11, T12, T13, T14, T15, T17 | `T10 -> T19`, `T11 -> T19`, `T12 -> T19`, `T13 -> T19`, `T14 -> T19`, `T15 -> T19`, `T17 -> T19` | ✅ Match |
| T20 | T18, T19 | `T18 -> T20`, `T19 -> T20` | ✅ Match |
| T21 | T20 | `T20 -> T21` | ✅ Match |

No task depends on a later-phase task; every `Depends on` resolves to an earlier or same-phase task.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: SongOrigin | Domain entity/enum | unit (spot-check) | unit | ✅ OK |
| T2: Song extension | Domain entity/enum | unit (spot-check) | unit | ✅ OK |
| T3: SongRepository.markRehearsed | Domain (interface only) | none (interface has no logic; matrix's "interface itself needs no test" note) | none | ✅ OK |
| T4: SongsTable columns | Infrastructure (schema) | none (matrix: data layer's test requirement attaches to the migration/mapper, not the raw column declaration) | none | ✅ OK |
| T5: Migration | Data/infra | unit | unit | ✅ OK |
| T6: SongMapper | Data | unit | unit | ✅ OK |
| T7: DriftSongRepository.markRehearsed | Data | unit | unit | ✅ OK |
| T8-T15: shared widgets | Presentation widgets | widget | widget | ✅ OK (all 8) |
| T16: providers (infra glue) | Presentation providers | unit | unit | ✅ OK |
| T17: library_providers | Presentation providers | unit | unit | ✅ OK |
| T18: ComingSoonScreen | Presentation screens | widget | widget | ✅ OK |
| T19: LibraryScreen | Presentation screens | widget | widget | ✅ OK |
| T20: AppRouter | Routing | widget | widget | ✅ OK |
| T21: main.dart | main wiring | widget (smoke) | widget | ✅ OK |

No violations.

---

## MCPs and Skills

No project or user MCP servers are configured for this session beyond the ones already declared unavailable (`context7` needs auth, `context-mode` failed to connect). Every task lists `MCP: NONE`. `flutter-clean-architecture` is invoked twice (T8, T16 — first widget file and first provider file, confirming layer placement); `flutter-ui-ux` is invoked once (T19, the final screen-assembly pass). `flutter-widget-performance` and `flutter-routing` informed the design but need no further per-task invocation beyond what design.md already resolved.
