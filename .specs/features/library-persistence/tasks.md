# Library Persistence Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/library-persistence/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling (`test/domain/core/result_test.dart`, `test/domain/entities/song_test.dart`, `test/fixtures/fixture_songs.dart`) and the spec's 20 ACs + 5 edge cases. No `AGENTS.md`/CI config found — strong defaults applied, adjusted to this repo's existing floor (every domain file has a co-located `_test.dart`; fixtures live in `test/fixtures/`).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
|---|---|---|---|---|
| Domain core — `Unit` | unit | Equality/const identity (mirrors `result_test.dart`'s style for the sealed-class core type it plugs into) | `test/domain/core/unit_test.dart` | `flutter test test/domain/core/unit_test.dart` |
| Domain core — `SongRepository` interface | none | Contract only, no behavior — build gate only | — | `flutter analyze` + `python scripts/check_layers.py --root .` |
| Infrastructure — `drift` tables + `AppDatabase` + migration | integration | Schema creation, FK pragma, cascade behavior — 1:1 to LIB-01..05, via `NativeDatabase.memory()` | `test/infrastructure/database/app_database_test.dart` | `flutter test test/infrastructure/` |
| Data — mappers (`SongTrackMapper`, `LyricLineMapper`, `SongMapper`) | unit | Every entity field round-trips through `toCompanion`/`fromRow`, including the `is_playback_slot` marker and the all-null `MetronomeConfig` state | `test/data/mappers/*_test.dart` | `flutter test test/data/mappers/` |
| Data — `DriftSongRepository` | integration | 1:1 to LIB-06..20 + all 5 listed Edge Cases (zero tracks/lyrics, null `playbackTrack`, lyric tie-break order, bounded `getAll()` queries) | `test/data/repositories/drift_song_repository_test.dart` | `flutter test test/data/` |

## Gate Check Commands

| Gate Level | When to Use | Command |
|---|---|---|
| Quick | After a single-file unit-test task (T1, T7, T8, T9) | `flutter test <the task's test file>` |
| Full | After an integration-test task (T6, T10-T14) | `flutter test test/data/ test/infrastructure/` |
| Build | After every task, before commit (codegen + layer purity + static analysis) | `dart run build_runner build --delete-conflicting-outputs && flutter analyze && python scripts/check_layers.py --root .` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Domain Foundation

```
T1 → T2
```

### Phase 2: Infrastructure — Schema & Migration

```
T3 → T4
T3 → T5
T3 → T6
T4 → T6
T5 → T6
```

### Phase 3: Data — Mappers

```
T6 → T7
T6 → T8
T6 → T9
```

### Phase 4: Data — Repository

```
T2 → T10
T7 → T10
T8 → T10
T9 → T10
T10 → T11
T11 → T12
T12 → T13
T13 → T14
```

(T10 depends on T2, T7, T8, T9 — four separate edges into T10, listed on their own lines above.)

---

## Task Breakdown

### T1: Create `Unit` type ✅ Complete

**What**: Add `lib/domain/core/unit.dart` with a single-value `const Unit` class (value-equal to itself), per AD-008.
**Where**: `lib/domain/core/unit.dart`
**Depends on**: None
**Reuses**: Fits directly into the existing `Result<S, F>` sealed class (`lib/domain/core/result.dart`) with no changes to it.
**Requirement**: AD-008 (supports LIB-06, LIB-09, LIB-16, LIB-19, LIB-20 return types)

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture` (domain placement)

**Done when**:
- [ ] `Unit` is a `const`-constructible class with value equality (two `Unit()` instances are `==`)
- [ ] Zero `package:flutter` import
- [ ] `test/domain/core/unit_test.dart` asserts const identity/equality
- [ ] Gate passes: `flutter test test/domain/core/unit_test.dart`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add Unit type for void-like Result success values`

---

### T2: Create `SongRepository` domain interface ✅ Complete

**What**: Add the abstract `SongRepository` contract (`save`, `getById`, `getAll`, `delete`, `deleteAll`) exactly as specified in design.md's Components section — pure Dart, zero `drift` import.
**Where**: `lib/domain/repositories/song_repository.dart`
**Depends on**: T1 (uses `Unit`)
**Reuses**: `Result`, `Failure`/`StorageFailure`/`NotFoundFailure` (`lib/domain/core/`), `Song` entity.
**Requirement**: N/A (structural contract underlying all of LIB-06..20)

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [ ] Interface declares all 5 methods with the exact signatures from design.md
- [ ] Zero `package:flutter`/`package:drift` import
- [ ] `python scripts/check_layers.py --root .` exits 0
- [ ] `flutter analyze` exits 0

**Tests**: none (contract only, per matrix)
**Gate**: build

**Commit**: `feat(domain): add SongRepository interface`

---

### T3: Create `SongsTable` ✅ Complete

**What**: Add the `drift` `Table` subclass for `songs` (id, name, author, version, 4 nullable metronome columns) exactly per design.md's Data Models section.
**Where**: `lib/infrastructure/database/tables/songs_table.dart`
**Depends on**: None
**Reuses**: nothing — first table declaration.
**Requirement**: LIB-01, LIB-03

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `id` is `.text()().primaryKey()`, all 4 metronome columns are `.nullable()`
- [ ] `flutter analyze` exits 0 (table compiles; generation deferred to T6)

**Tests**: none (schema declaration only — exercised by T6's integration test)
**Gate**: build

**Commit**: `feat(infra): add songs table schema`

---

### T4: Create `SongTracksTable` ✅ Complete

**What**: Add the `drift` `Table` subclass for `song_tracks` (id, song_id FK cascade, file_path, naipe, start_delay_ms, is_playback, is_playback_slot) per design.md.
**Where**: `lib/infrastructure/database/tables/song_tracks_table.dart`
**Depends on**: T3 (`.references(SongsTable, #id, ...)`)
**Reuses**: `SongsTable` (T3).
**Requirement**: LIB-01, LIB-02, LIB-03

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `song_id` declared `.references(SongsTable, #id, onDelete: KeyAction.cascade)`
- [ ] `is_playback_slot` has `.withDefault(const Constant(false))`
- [ ] `flutter analyze` exits 0

**Tests**: none (schema declaration only — exercised by T6's integration test)
**Gate**: build

**Commit**: `feat(infra): add song_tracks table schema`

---

### T5: Create `LyricLinesTable` ✅ Complete

**What**: Add the `drift` `Table` subclass for `lyric_lines` (row_id autoincrement PK, song_id FK cascade, text, onset_ms, nullable naipe/dynamics) per design.md.
**Where**: `lib/infrastructure/database/tables/lyric_lines_table.dart`
**Depends on**: T3 (`.references(SongsTable, #id, ...)`)
**Reuses**: `SongsTable` (T3).
**Requirement**: LIB-01, LIB-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `row_id` declared `.integer().autoIncrement()`, never mapped onto `LyricLine`
- [ ] `song_id` declared `.references(SongsTable, #id, onDelete: KeyAction.cascade)`
- [ ] `flutter analyze` exits 0

**Tests**: none (schema declaration only — exercised by T6's integration test)
**Gate**: build

**Commit**: `feat(infra): add lyric_lines table schema`

---

### T6: Create `AppDatabase` with migration and FK pragma ✅ Complete

**What**: Add the `@DriftDatabase(tables: [...])` class with `schemaVersion = 1`, `onCreate: (m) => m.createAll()`, empty `stepByStep` migration scaffold, and `beforeOpen` running `PRAGMA foreign_keys = ON;`. Run `build_runner` to generate `app_database.g.dart`.
**Where**: `lib/infrastructure/database/app_database.dart`
**Depends on**: T3, T4, T5
**Reuses**: the three table classes.
**Requirement**: LIB-01, LIB-02, LIB-04, LIB-05

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `dart run build_runner build --delete-conflicting-outputs` generates `app_database.g.dart` with no errors
- [ ] `test/infrastructure/database/app_database_test.dart` opens an `AppDatabase(NativeDatabase.memory())`, queries `sqlite_master` and asserts all 3 table names exist, and asserts `PRAGMA foreign_keys` reads `1`
- [ ] A second test inserts a `songs` row + a `song_tracks` row referencing it, deletes the `songs` row, and asserts the `song_tracks` row is gone (cascade proof — LIB-02)
- [ ] If `NativeDatabase.memory()` fails to load a native SQLite library under `flutter test` on this platform, resolve via `sqlite3`'s `open.overrideFor(...)` pointed at the library `sqlite3_flutter_libs` bundles — flagged here as unconfirmed since no existing project test exercises this path yet; verify against current `drift`/`sqlite3` docs before assuming the exact API
- [ ] Gate passes: `flutter test test/infrastructure/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(infra): add AppDatabase with v1 schema and FK enforcement`

---

### T7: Create `SongTrackMapper` ✅ Complete

**What**: Add `toCompanion(SongTrack, {required String songId, required bool isPlaybackSlot})` and `fromRow(SongTrackRow)` pure functions.
**Where**: `lib/data/mappers/song_track_mapper.dart`
**Depends on**: T6 (needs generated `SongTrackRow`/`SongTracksTableCompanion`)
**Reuses**: `SongTrack`, `Naipe` (`.name`/`.values.byName`).
**Requirement**: supports LIB-06, LIB-07, LIB-10, LIB-11

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Round-trips `id`, `filePath`, `naipe`, `startDelayMs`, `isPlayback` exactly
- [ ] `is_playback_slot` is written from the caller-supplied flag, never from `SongTrack.isPlayback`, and is never read back onto the entity
- [ ] `test/data/mappers/song_track_mapper_test.dart` covers: round trip with `isPlaybackSlot: true`, round trip with `isPlaybackSlot: false`, non-zero `startDelayMs`, each `Naipe` value
- [ ] Gate passes: `flutter test test/data/mappers/song_track_mapper_test.dart`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(data): add SongTrackMapper`

---

### T8: Create `LyricLineMapper` ✅ Complete

**What**: Add `toCompanion(LyricLine, {required String songId})` and `fromRow(LyricLineRow)` pure functions.
**Where**: `lib/data/mappers/lyric_line_mapper.dart`
**Depends on**: T6 (needs generated `LyricLineRow`/`LyricLinesTableCompanion`)
**Reuses**: `LyricLine`, `Naipe`.
**Requirement**: supports LIB-11, LIB-15

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Round-trips `text`, `onsetMs`, nullable `naipe`, nullable `dynamics` exactly, including both-null case
- [ ] `row_id` is never mapped onto `LyricLine`
- [ ] `test/data/mappers/lyric_line_mapper_test.dart` covers: full fields present, both nullable fields null, `naipe` null with `dynamics` present
- [ ] Gate passes: `flutter test test/data/mappers/lyric_line_mapper_test.dart`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(data): add LyricLineMapper`

---

### T9: Create `SongMapper`

**What**: Add `toCompanion(Song)` / `fromRow(SongRow)` pure functions for the `songs` row only — `MetronomeConfig` in/out as the 4-column group, treating "all 4 null" and "all 4 present" as the only valid states.
**Where**: `lib/data/mappers/song_mapper.dart`
**Depends on**: T6 (needs generated `SongRow`/`SongsTableCompanion`)
**Reuses**: `Song`, `MetronomeConfig`.
**Requirement**: supports LIB-10, LIB-11

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Round-trips `id`, `name`, `author`, `version` exactly
- [ ] `metronomeConfig == null` maps to all 4 columns `NULL` and back to `null` (LIB-10), without throwing
- [ ] A present `metronomeConfig` round-trips all 4 fields (`bpm`, `beatsPerMeasure`, `downbeatAccent`, `enabledByDefault`) exactly
- [ ] `test/data/mappers/song_mapper_test.dart` covers both states
- [ ] Gate passes: `flutter test test/data/mappers/song_mapper_test.dart`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(data): add SongMapper`

---

### T10: Implement `DriftSongRepository.save()`

**What**: Implement the `save(Song)` upsert — one `db.transaction()` writing the song row, all track rows (tagging the `playbackTrack` row with `is_playback_slot: true` if present), and all lyric rows; catches DB exceptions into `Result.failure(StorageFailure)`.
**Where**: `lib/data/repositories/drift_song_repository.dart` (new file, `save` method)
**Depends on**: T2, T7, T8, T9
**Reuses**: `SongRepository` (T2), the three mappers (T7-T9), `AppDatabase` (T6).
**Requirement**: LIB-06, LIB-07, LIB-08, LIB-09, LIB-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Insert path: new `Song.id` creates song + N track rows + 1 playback row (if present) + M lyric rows in one transaction
- [ ] Upsert path: saving a `Song` with an existing `id` fully replaces its tracks/lyrics (no leftover rows) — verified by a direct row-count query against `NativeDatabase.memory()`
- [ ] A forced write failure inside the transaction rolls back every row and returns `Result.failure(StorageFailure)` with a non-empty `code`
- [ ] `metronomeConfig: null` saves without throwing (LIB-10)
- [ ] `test/data/repositories/drift_song_repository_test.dart` (`save` group) covers: fresh insert, upsert-replaces, transactional rollback on forced failure, null metronome config
- [ ] Gate passes: `flutter test test/data/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(data): implement DriftSongRepository.save`

---

### T11: Implement `DriftSongRepository.getById()`

**What**: Implement `getById(String id)` — fetch the song row, its tracks (split into `tracks`/`playbackTrack` by `is_playback_slot`), and its lyrics; `NotFoundFailure` if the song row is absent.
**Where**: `lib/data/repositories/drift_song_repository.dart` (add `getById` method)
**Depends on**: T10 (shares the file; needs saved fixtures to read back)
**Reuses**: the three mappers, `AppDatabase`.
**Requirement**: LIB-11, LIB-12

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Save a fixture `Song` (2 tracks, 1 playback track, 3 lyrics, a `metronomeConfig`); `getById` returns every field exactly equal, field-by-field (entities have no `==` override — compare fields, not instances)
- [ ] `getById` on an unknown id returns `Result.failure(NotFoundFailure)` with a non-empty `code`
- [ ] `test/data/repositories/drift_song_repository_test.dart` (`getById` group) covers both cases
- [ ] Gate passes: `flutter test test/data/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(data): implement DriftSongRepository.getById`

---

### T12: Implement `DriftSongRepository.getAll()`

**What**: Implement `getAll()` — one `select(songs)`, one bounded `song_tracks WHERE song_id IN (...)`, one bounded `lyric_lines WHERE song_id IN (...) ORDER BY onset_ms, row_id`, grouped by `songId` in Dart; 3 queries total regardless of song count.
**Where**: `lib/data/repositories/drift_song_repository.dart` (add `getAll` method)
**Depends on**: T11 (shares the file)
**Reuses**: the three mappers, `AppDatabase`.
**Requirement**: LIB-13, LIB-14, LIB-15

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Save N songs (N ≥ 3); `getAll()` returns exactly N songs
- [ ] `getAll()` on an empty library returns `Result.success(<Song>[])`, not a failure
- [ ] Lyrics on each returned song are ordered by ascending `onsetMs`; two lyrics sharing the same `onsetMs` stay in stable, repeatable order across repeated calls (tie-broken by `row_id`)
- [ ] A query-count assertion (e.g. a test `QueryExecutor`/logging wrapper counting statements) confirms `getAll()` issues a bounded number of queries independent of N (no N+1)
- [ ] `test/data/repositories/drift_song_repository_test.dart` (`getAll` group) covers all of the above
- [ ] Gate passes: `flutter test test/data/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(data): implement DriftSongRepository.getAll`

---

### T13: Implement `DriftSongRepository.delete()`

**What**: Implement `delete(String id)` — existence check via `getSingleOrNull()`, then delete the song row (cascade removes its tracks/lyrics); `NotFoundFailure` if absent.
**Where**: `lib/data/repositories/drift_song_repository.dart` (add `delete` method)
**Depends on**: T12 (shares the file)
**Reuses**: `AppDatabase`'s cascade FK (T4/T5/T6).
**Requirement**: LIB-16, LIB-17, LIB-18

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Deleting an existing song with tracks+lyrics removes the song row and cascades away every associated `song_tracks`/`lyric_lines` row (verified by a direct row-count query by the deleted `song_id`)
- [ ] Deleting an unknown id returns `Result.failure(NotFoundFailure)` with a non-empty `code`, no rows touched
- [ ] A subsequent `getAll()` after delete contains no row referencing the deleted id
- [ ] `test/data/repositories/drift_song_repository_test.dart` (`delete` group) covers all of the above
- [ ] Gate passes: `flutter test test/data/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(data): implement DriftSongRepository.delete`

---

### T14: Implement `DriftSongRepository.deleteAll()`

**What**: Implement `deleteAll()` — unconditional delete of every row in `songs` (cascades `song_tracks`/`lyric_lines`); always returns `Result.success(Unit)`, including on an already-empty library.
**Where**: `lib/data/repositories/drift_song_repository.dart` (add `deleteAll` method)
**Depends on**: T13 (shares the file)
**Reuses**: `AppDatabase`'s cascade FK.
**Requirement**: LIB-19, LIB-20

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Save 3 songs with tracks/lyrics; `deleteAll()`; `getAll()` returns an empty list and direct queries on `song_tracks`/`lyric_lines` return zero rows
- [ ] `deleteAll()` on an already-empty library still returns `Result.success(Unit)`
- [ ] `test/data/repositories/drift_song_repository_test.dart` (`deleteAll` group) covers both cases
- [ ] Gate passes: `flutter test test/data/` (full suite for the feature)
- [ ] Final gate: `flutter test && flutter analyze && python scripts/check_layers.py --root .` all exit 0

**Tests**: integration
**Gate**: full

**Commit**: `feat(data): implement DriftSongRepository.deleteAll`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4

T1 → T2
T3 → T4
T3 → T5
T3 → T6
T4 → T6
T5 → T6
T6 → T7
T6 → T8
T6 → T9
T2 → T10
T7 → T10
T8 → T10
T9 → T10
T10 → T11
T11 → T12
T12 → T13
T13 → T14
```

Execution is strictly sequential - there is no intra-phase parallelism. A single agent (or batch worker) works one task at a time, in order.

**Batch packing (14 tasks → 2 batches, whole phases only):**

- **Batch A** = Phase 1 + Phase 2 (6 tasks: T1-T6)
- **Batch B** = Phase 3 + Phase 4 (8 tasks: T7-T14)

---

## Task Granularity Check

| Task | Scope | Status |
|---|---|---|
| T1: Create Unit type | 1 file, 1 type | ✅ Granular |
| T2: Create SongRepository interface | 1 file, 1 interface | ✅ Granular |
| T3: Create SongsTable | 1 file, 1 table | ✅ Granular |
| T4: Create SongTracksTable | 1 file, 1 table | ✅ Granular |
| T5: Create LyricLinesTable | 1 file, 1 table | ✅ Granular |
| T6: Create AppDatabase + migration + pragma | 1 file (+ generated), 1 cohesive bootstrap unit | ✅ Granular (codegen + migration + pragma are one indivisible bootstrap — splitting would leave an uncompilable intermediate state) |
| T7: Create SongTrackMapper | 1 file, 1 mapper | ✅ Granular |
| T8: Create LyricLineMapper | 1 file, 1 mapper | ✅ Granular |
| T9: Create SongMapper | 1 file, 1 mapper | ✅ Granular |
| T10: save() | 1 file (1 method added), 1 behavior | ✅ Granular |
| T11: getById() | 1 file (1 method added), 1 behavior | ✅ Granular |
| T12: getAll() | 1 file (1 method added), 1 behavior | ✅ Granular |
| T13: delete() | 1 file (1 method added), 1 behavior | ✅ Granular |
| T14: deleteAll() | 1 file (1 method added), 1 behavior | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1 | None | None (start of Phase 1) | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | None | None (start of Phase 2) | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T3 | T3 → T5 | ✅ Match |
| T6 | T3, T4, T5 | T3 → T6, T4 → T6, T5 → T6 | ✅ Match |
| T7 | T6 | T6 → T7 (Phase 2 → Phase 3 boundary) | ✅ Match |
| T8 | T6 | T6 → T8 | ✅ Match |
| T9 | T6 | T6 → T9 | ✅ Match |
| T10 | T2, T7, T8, T9 | T9 → T10 (Phase 3 → Phase 4 boundary) | ✅ Match |
| T11 | T10 | T10 → T11 | ✅ Match |
| T12 | T11 | T11 → T12 | ✅ Match |
| T13 | T12 | T12 → T13 | ✅ Match |
| T14 | T13 | T13 → T14 | ✅ Match |

No task depends on a later phase. All dependencies point backward or within the same phase.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
|---|---|---|---|---|
| T1: Unit | Domain core (Unit) | unit | unit | ✅ OK |
| T2: SongRepository interface | Domain core (interface) | none | none | ✅ OK |
| T3: SongsTable | Infra schema (declaration) | none (exercised by T6) | none | ✅ OK |
| T4: SongTracksTable | Infra schema (declaration) | none (exercised by T6) | none | ✅ OK |
| T5: LyricLinesTable | Infra schema (declaration) | none (exercised by T6) | none | ✅ OK |
| T6: AppDatabase | Infrastructure (AppDatabase + migration) | integration | integration | ✅ OK |
| T7: SongTrackMapper | Data (mapper) | unit | unit | ✅ OK |
| T8: LyricLineMapper | Data (mapper) | unit | unit | ✅ OK |
| T9: SongMapper | Data (mapper) | unit | unit | ✅ OK |
| T10: save() | Data (DriftSongRepository) | integration | integration | ✅ OK |
| T11: getById() | Data (DriftSongRepository) | integration | integration | ✅ OK |
| T12: getAll() | Data (DriftSongRepository) | integration | integration | ✅ OK |
| T13: delete() | Data (DriftSongRepository) | integration | integration | ✅ OK |
| T14: deleteAll() | Data (DriftSongRepository) | integration | integration | ✅ OK |

No violations. T3-T5 declare schema with no independent behavior to test; their correctness (table creation, FK cascade, PK constraints) is exercised end-to-end by T6's integration test against `NativeDatabase.memory()` — this is the "merge forward" resolution from the Tasks process (schema declarations aren't independently runnable until `AppDatabase` wires and generates them).

---

## Tools Question

Per the Tasks process, before Execute: **which MCPs/skills should be used per task?**

Proposed defaults (no project MCPs beyond the ones already surfaced):
- All tasks: `flutter-clean-architecture` skill for layer placement checks (T1, T2 especially — new domain files)
- T6, T10-T14: `flutter-quality-gates` skill for interpreting `flutter analyze`/`flutter test` failures
- No `context7`/web search anticipated — `drift` API usage is already pinned to concrete patterns in design.md; flag mid-task if an API surface doesn't match the installed `drift: ^2.21.0` version

---

## Sub-Agent Delegation Offer

14 tasks → packs into 2 batches (Batch A: T1-T6, Batch B: T7-T14), each ≈ the ~7-task worker budget. Per the skill's offer-then-confirm rule, I'll ask before dispatching any sub-agent.
