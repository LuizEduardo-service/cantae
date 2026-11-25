# Ensaios anteriores (rehearsal-history) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/rehearsal-history/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found:
> - `AGENTS.md` §5/§7: a widget test per component (states, dark theme, semantics); screen states; 130% font; ≥ 44 dp.
> - `CLAUDE.md`: failure-first for isolated systems; E2E-equivalent widget tests for features.
> - AD-010: repositories tested on `NativeDatabase.memory()`.
> - The user's standing rule: every bug gets a failing regression test in the same commit as its fix.
>
> Sampled: `test/data/repositories/drift_song_repository_test.dart`, `test/infrastructure/database/app_database_migration_test.dart`, `test/presentation/providers/solo_player_notifier_test.dart`, `test/presentation/screens/song_detail/song_detail_screen_test.dart`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Domain (tracker) | unit (failure modes first) | 1:1 to HIST-01..04, HIST-19 | `test/domain/rehearsal/*_test.dart` | `flutter test test/domain/rehearsal` |
| Infrastructure (schema, migration) | unit on a real SQLite file / memory | v3 → v4 keeps songs; table + cascade | `test/infrastructure/database/*_test.dart` | `flutter test test/infrastructure/database` |
| Data (repository, uuid) | unit (`NativeDatabase.memory()`) | add / getBySong order / deleteBySong / deleteAll / failures → `StorageFailure`; cascade | `test/data/repositories/*_test.dart`, `test/data/ids/*_test.dart` | `flutter test test/data` |
| Presentation (providers, notifiers) | unit | Recorder saves, marks, invalidates, swallows failures; solo notifier records on dispose; history notifier states + deletes | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers` |
| Presentation (shared widget) | unit (widget) | value + caption, semantics, dark theme, 130% | `test/presentation/widgets/stat_tile_test.dart` | `flutter test test/presentation/widgets/stat_tile_test.dart` |
| Presentation (screen) | widget (e2e-equivalent) | Every state, deletes with confirm/cancel/failure, toast, navigation, detail count, themes, 130% | `test/presentation/screens/history/*_test.dart` | `flutter test test/presentation/screens/history` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After a task with tests in one area | `flutter test <changed test file(s)>` |
| Full | After a task that changes a shared contract (schema, `SoloPlayerNotifier`, routing) | `flutter test` |
| Build | After phase completion | `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Domain and persistence

```
T1 → T2 → T3
```

### Phase 2: Recording

```
T4 → T5
```

### Phase 3: Screen

```
T6 → T7 → T8
```

Full cross-phase chain:

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8
```

---

## Task Breakdown

### T1: `RehearsalLog` + `RehearsalSessionTracker`

**What**: Domain entity (PRD fields, `RehearsalMode`, `RehearsalRole`) and the pure tracker: `setPlaying(bool, now)`, `loopJumped()`, `finish(id:, songId:, now:)` returning null under 60 s or when never played.
**Where**: `lib/domain/entities/rehearsal_log.dart`, `lib/domain/rehearsal/rehearsal_session_tracker.dart`
**Depends on**: None
**Reuses**: AD-006 const entities
**Requirement**: HIST-01, HIST-02, HIST-03, HIST-04, HIST-06, HIST-19

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed in the test header, then tests: only playing spans count (pauses excluded, several spans summed, end + replay continue the same session); an open span is closed by `finish`; repeated `setPlaying` values do not double count; loops only while playing; `startedAt` = first play; 59 999 ms → null, 60 000 ms → log; never played → null; log has mode solo, role null, 1 participant
- [x] `scripts/check_layers.py` passes
- [x] Gate check passes: `flutter test test/domain/rehearsal`
- [x] Test count: all existing + ≥ 9 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(rehearsal-history): add the rehearsal log and the session tracker`

---

### T2: `rehearsal_logs` table + schema v4

**What**: Drift table (FK to songs, cascade; index on `song_id`), `schemaVersion` 4, `if (from < 4) createTable`; regenerate `app_database.g.dart`.
**Where**: `lib/infrastructure/database/tables/rehearsal_logs_table.dart`, `lib/infrastructure/database/app_database.dart`
**Depends on**: T1
**Reuses**: `song_tracks_table.dart` FK pattern, migration test pattern
**Requirement**: HIST-18

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first, then tests: a v3 file with a song upgrades to v4 with the song intact and the table present; a fresh v4 install has the table; deleting a song deletes its rows (cascade)
- [x] Gate check passes: `flutter test` (full: schema change)
- [x] Test count: all existing + ≥ 3 new

**Tests**: unit
**Gate**: full
**Commit**: `feat(rehearsal-history): add the rehearsal_logs table`

---

### T3: `RehearsalRepository` + drift implementation + `uuidV4`

**What**: Domain interface; mapper; `DriftRehearsalRepository` (add, getBySong newest first, deleteBySong, deleteAll; exceptions → `StorageFailure`); `uuidV4()`.
**Where**: `lib/domain/repositories/rehearsal_repository.dart`, `lib/data/mappers/rehearsal_log_mapper.dart`, `lib/data/repositories/drift_rehearsal_repository.dart`, `lib/data/ids/uuid_v4.dart`
**Depends on**: T2
**Reuses**: `DriftSongRepository` error mapping
**Requirement**: HIST-03, HIST-11, HIST-14, HIST-15

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first, then tests: every field round-trips (role null and set); getBySong newest first and only that song; deleteBySong leaves other songs; deleteAll empties; a closed database → `StorageFailure` from each method; uuid matches the v4 pattern and 1000 calls are distinct
- [x] Gate check passes: `flutter test test/data`
- [x] Test count: all existing + ≥ 8 new

**Tests**: unit
**Gate**: build
**Commit**: `feat(rehearsal-history): store rehearsal logs in the database`

---

### T4: Providers + `RehearsalRecorder`

**What**: `rehearsalRepositoryProvider`, `clockProvider`, `rehearsalLogsProvider` family, `rehearsalRecorderProvider` (add → markRehearsed → invalidate `songsProvider`, `songByIdProvider(id)`, `rehearsalLogsProvider(id)`; never throws).
**Where**: `lib/presentation/providers/rehearsal_providers.dart`
**Depends on**: T3
**Reuses**: `songRepositoryProvider`, `appDatabaseProvider`
**Requirement**: HIST-05, HIST-07

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Tests first with fake repositories: record saves the log and marks the song with `endedAt`; after record, a listened `rehearsalLogsProvider(id)` and `songsProvider` re-read; add fails → no mark, no throw; mark fails → no throw
- [x] Gate check passes: `flutter test test/presentation/providers/rehearsal_providers_test.dart`
- [x] Test count: all existing + ≥ 4 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(rehearsal-history): record a rehearsal and refresh what shows it`

---

### T5: Modo solo records the session

**What**: `SoloPlayerNotifier` reads the recorder and clock in its constructor, overrides the `state` setter to feed the tracker, reports loop jumps, and records on dispose.
**Where**: `lib/presentation/providers/solo_player_notifier.dart`
**Depends on**: T4
**Reuses**: `RehearsalSessionTracker`, `uuidV4`
**Requirement**: HIST-01, HIST-02, HIST-03, HIST-04, HIST-07, HIST-19

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Tests first with a fake clock and a fake recorder: play 75 s with 3 loop jumps, dispose → one log (75 000 ms, 3 loops, solo, song id, startedAt/endedAt); 59 s → nothing; never played → nothing; pause excluded; end + replay summed; interruption pause excluded; lock-screen play counts; the metronome's internal pause/resume does not split the time; recorder failure does not throw from dispose
- [x] Gate check passes: `flutter test` (full: the notifier is shared by the screen tests)
- [x] Test count: all existing + ≥ 8 new

**Tests**: unit
**Gate**: build
**Commit**: `feat(solo-player): record the rehearsal when leaving Modo solo`

---

### T6: `StatTile`

**What**: Shared widget: large Geist Mono value + caption; one semantics node "caption: value"; COMPONENTS.md entry updated if needed.
**Where**: `lib/presentation/widgets/stat_tile.dart`
**Depends on**: T5
**Reuses**: `CantaeTypography`, `CantaeColors`
**Requirement**: HIST-10

**Tools**:
- MCP: NONE
- Skill: flutter-ui-ux

**Done when**:
- [x] Tests first: shows value and caption; value uses the mono style; semantics label; dark theme; three tiles in a row at 360 dp / 130 % without overflow
- [x] Gate check passes: `flutter test test/presentation/widgets/stat_tile_test.dart`
- [x] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(widgets): add StatTile`

---

### T7: `RehearsalHistoryNotifier` + formatting

**What**: Family notifier (loading / notFound / error / ready, logs, totals, deleting, deleteError; retry, deleteForSong, deleteAll with invalidation) and `formatDuration` / `formatRehearsalDate`.
**Where**: `lib/presentation/providers/rehearsal_history_notifier.dart`, `lib/presentation/formatting/rehearsal_format.dart`
**Depends on**: T6
**Reuses**: `songByIdProvider`, `rehearsalRepositoryProvider`
**Requirement**: HIST-10, HIST-11, HIST-13, HIST-14, HIST-15, HIST-16, HIST-17

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Tests first: ready with logs newest first and totals; notFound; read error → error, retry reloads; deleteForSong success → empty + `rehearsalLogsProvider` re-read; deleteAll success; delete failure → logs kept + `deleteError`; formatting: 59 000 → "0:59", 750 000 → "12:30", 3 723 000 → "1:02:03", date → "25 nov 2026 · 19:40"
- [x] Gate check passes: `flutter test test/presentation/providers/rehearsal_history_notifier_test.dart test/presentation/formatting`
- [x] Test count: all existing + ≥ 10 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(rehearsal-history): add the history state and formatting`

---

### T8: `RehearsalHistoryScreen`, route and detail count

**What**: The screen (UI_SPEC §6.16, all states, delete flows with `ConfirmSheet`, toast, banner); route `/song-history/:id`; song detail row "Ensaios anteriores (N)" passing the id; UI_SPEC §6.16 updated with the states.
**Where**: `lib/presentation/screens/history/rehearsal_history_screen.dart`, `lib/presentation/routing/app_router.dart`, `lib/presentation/screens/song_detail/song_detail_screen.dart`, `docs/design/UI_SPEC.md`
**Depends on**: T7
**Reuses**: `CantaeScaffold`, `NavPill`, `EmptyState`, `ConfirmSheet`, `Toast`, `InlineBanner`, `StatTile`
**Requirement**: HIST-08, HIST-09, HIST-10, HIST-11, HIST-12, HIST-13, HIST-14, HIST-15, HIST-16, HIST-17

**Tools**:
- MCP: NONE
- Skill: flutter-ui-ux

**Done when**:
- [ ] Tests first: ready (title, line, 3 tiles with values, rows in order with date / "Modo solo" / duration / loops); empty with "Ensaiar agora" → solo-player route; loading; error + retry; notFound + "Voltar à Biblioteca"; back → song detail; "Apagar desta música" confirm → empty + toast, cancel → unchanged; "Apagar tudo" confirm; delete failure banner; detail row shows "(2)" and opens the screen with the id; dark theme; 360 dp at 130 %; buttons ≥ 44 dp
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test`
- [ ] Test count: all existing + ≥ 13 new

**Tests**: widget
**Gate**: build
**Commit**: `feat(rehearsal-history): add the Ensaios screen`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 → T2 → T3
Phase 2:  T4 → T5
Phase 3:  T6 → T7 → T8
```

Execution is strictly sequential.

Total: 8 tasks → fits a single batch → execute inline.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 | 1 entity + 1 pure class (one contract) | ✅ Granular |
| T2 | 1 table + its migration step | ✅ Granular |
| T3 | 1 repository (interface + impl + mapper) + 1 id helper | ✅ Granular |
| T4 | 1 providers file | ✅ Granular |
| T5 | 1 notifier extension | ✅ Granular |
| T6 | 1 widget | ✅ Granular |
| T7 | 1 notifier + its formatters | ✅ Granular |
| T8 | 1 screen + route + entry row + UI_SPEC section | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1→T2 | ✅ Match |
| T3 | T2 | T2→T3 | ✅ Match |
| T4 | T3 | T3→T4 (cross-phase chain) | ✅ Match |
| T5 | T4 | T4→T5 | ✅ Match |
| T6 | T5 | T5→T6 (cross-phase chain) | ✅ Match |
| T7 | T6 | T6→T7 | ✅ Match |
| T8 | T7 | T7→T8 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Domain | unit | unit | ✅ OK |
| T2 | Infrastructure (schema) | unit | unit | ✅ OK |
| T3 | Data (repository, uuid) | unit | unit | ✅ OK |
| T4 | Presentation (providers) | unit | unit | ✅ OK |
| T5 | Presentation (notifier) | unit | unit | ✅ OK |
| T6 | Shared widget | unit (widget) | unit | ✅ OK |
| T7 | Presentation (notifier) | unit | unit | ✅ OK |
| T8 | Screen | widget | widget | ✅ OK |
