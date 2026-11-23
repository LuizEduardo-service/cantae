# Editor de letra (lyrics-editor) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/lyrics-editor/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling. Guidelines found: `AGENTS.md` §7 (widget tests + accessibility checklist before done), `CLAUDE.md` (project conventions), no coverage-threshold tool config found (`analysis_options.yaml` has lint rules only, no coverage gate). No testing-framework question needed - the repo already has an extensive `flutter_test`/`mocktail` suite; sampled `test/domain/entities/`, `test/data/mappers/lyric_line_mapper_test.dart`, `test/data/repositories/drift_song_repository_test.dart`, `test/infrastructure/database/app_database_migration_test.dart`, `test/presentation/providers/track_align_notifier_test.dart`, `test/presentation/widgets/track_align_row_test.dart`, `test/presentation/screens/track_align/track_align_screen_test.dart`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | --------------------- | ----------------- | ------------ |
| Domain entity (`LyricLine`) | unit | Constructor assert branches (null/valid/negative `onsetMs`) | `test/domain/entities/*_test.dart` | `flutter test test/domain/entities/lyric_line_test.dart` |
| Infrastructure (schema/migration) | unit (in-memory DB) | v2→v3 migration preserves existing non-null `onset_ms` rows; fresh install creates nullable column directly | `test/infrastructure/database/*_test.dart` | `flutter test test/infrastructure/database/app_database_migration_test.dart` |
| Data (mapper) | unit | Round-trip for null/non-null `onsetMs`, consistent with existing null-naipe/null-dynamics cases already covered | `test/data/mappers/*_test.dart` | `flutter test test/data/mappers/lyric_line_mapper_test.dart` |
| Data (repository ordering) | unit (in-memory DB) | `getById`/`getAll` return lyrics in `rowId` order regardless of `onsetMs` nullity, incl. mixed marked/unmarked | `test/data/repositories/*_test.dart` | `flutter test test/data/repositories/drift_song_repository_test.dart` |
| Presentation (notifier) | unit | 1:1 to spec ACs: add/edit/reject-bounds, markNow (success/no-op/out-of-order-reject), preview start/stop (incl. tracks-empty no-op), save (success/failure preserves state), currentLineIndex/markedCount/nextUnmarkedIndex getters | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers/lyrics_editor_notifier_test.dart` |
| Presentation (shared widget `LyricLineRow`) | unit (widget) | Collapsed vs. expanded rendering, blur-revert on invalid text/dinâmica, naipe `SegmentedControl` selection callback, `isCurrent` highlight style | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets/lyric_line_row_test.dart` |
| Presentation (screen) | widget (e2e-equivalent per `AGENTS.md`) | Every status (`loading`/`notFound`/`error`/`loaded`) renders; empty state; tracks-empty banner; primary action "Salvar"; preview footer appears/disappears; two themes; semantics per AGENTS.md §7 checklist | `test/presentation/screens/lyrics_editor/*_test.dart` | `flutter test test/presentation/screens/lyrics_editor/lyrics_editor_screen_test.dart` |
| Routing | none | wiring only, covered by the screen test reaching the route | - | build gate only |

**Coverage Expectation values** - strong defaults applied for domain/presentation per matrix above; `AGENTS.md` §7's widget-test + accessibility checklist is the project's own documented guideline for the screen layer, cited above.

## Gate Check Commands

> Generated from codebase - no CI workflow file found; commands are Flutter's own CLI, consistent with how this repo has gated prior features (track-align-screen).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After a task with unit tests only | `flutter test <changed test file(s)>` |
| Full | After a task that touches DB/repository/notifier/screen layers | `flutter test` |
| Build | After phase completion | `flutter analyze && dart format --set-exit-if-changed lib test && flutter test` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Domain + Schema + Data

```
T1 → T2 → T3 → T4
```

### Phase 2: Presentation - Notifier + Shared Widget

```
T5 → T6
```

### Phase 3: Presentation - Screen + Routing

```
T7 → T8
```

Full cross-phase chain (bridges Phase 1→2→3, for the dependency cross-check):

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8
```

---

## Task Breakdown

### T1: Make `LyricLine.onsetMs` nullable

**What**: Change `LyricLine.onsetMs` from `int` to `int?`, update the constructor assert, write/extend the entity's unit tests.
**Where**: `lib/domain/entities/lyric_line.dart`
**Depends on**: None
**Reuses**: n/a (first dedicated test file for this entity)
**Requirement**: LYR-01, LYR-13

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture` (confirm the entity stays Flutter/plugin-free)

**Done when**:
- [x] `onsetMs` is `int?`; assert is `onsetMs == null || onsetMs >= 0`
- [x] `test/domain/entities/lyric_line_test.dart` created covering: `onsetMs: null` constructs; `onsetMs: 0` constructs; negative `onsetMs` throws the assert; empty `text` still throws its existing assert
- [x] Gate check passes: `flutter test test/domain/entities/lyric_line_test.dart`
- [x] Test count: 4 tests pass (no silent deletions)

**Tests**: unit
**Gate**: quick
**Commit**: `feat(lyrics-editor): make LyricLine.onsetMs nullable`

---

### T2: Migrate `lyric_lines.onset_ms` to nullable (schema v2 → v3)

**What**: Make the `LyricLinesTable.onsetMs` column nullable and add the `onUpgrade` v2→v3 step using `Migrator.alterTable(TableMigration(...))`; write the migration test proving existing non-null rows survive.
**Where**: `lib/infrastructure/database/tables/lyric_lines_table.dart`, `lib/infrastructure/database/app_database.dart`
**Depends on**: T1
**Reuses**: `app_database.dart:23-35`'s existing `onUpgrade` shape and `SPEC_DEVIATION` comment precedent; `test/infrastructure/database/app_database_migration_test.dart`'s raw-sqlite3-seed-then-`AppDatabase(NativeDatabase(File(...)))` pattern (same file, new `group`).
**Requirement**: LYR-01, LYR-02 (persistence), design.md Risks row 1

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `LyricLinesTable.onsetMs` is `integer().nullable()()`
- [x] `schemaVersion` is `3`; `onUpgrade` adds `if (from < 3) { await m.alterTable(TableMigration(lyricLinesTable)); }`
- [x] New test in `app_database_migration_test.dart`: seed a raw v2 DB with a `lyric_lines` row where `onset_ms` is a non-null int, open it with `AppDatabase`, assert the row (`text`, `onset_ms`, `naipe`, `dynamics`) is unchanged after the v2→v3 upgrade
- [x] New test: a fresh install (`NativeDatabase.memory()`) allows inserting a `lyric_lines` row with `onsetMs: null` without a constraint error
- [x] Gate check passes: `flutter test test/infrastructure/database/app_database_migration_test.dart`
- [x] Test count: 4 tests pass (2 pre-existing LIB-12 tests + 2 new)

**Tests**: unit (in-memory/file-backed DB)
**Gate**: quick
**Commit**: `feat(lyrics-editor): add schema v2->v3 migration for nullable onset_ms`

---

### T3: Update `LyricLineMapper` for nullable `onsetMs`

**What**: `toCompanion` wraps `onsetMs` in `Value(...)`; `fromRow` passes `row.onsetMs` through directly (now `int?`); extend the mapper's round-trip tests with a null-`onsetMs` case.
**Where**: `lib/data/mappers/lyric_line_mapper.dart`
**Depends on**: T2
**Reuses**: `test/data/mappers/lyric_line_mapper_test.dart`'s existing `_row()` helper and round-trip test shape (already handles null `naipe`/`dynamics` the same way).
**Requirement**: LYR-01

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `toCompanion` passes `onsetMs: Value(line.onsetMs)`
- [x] `fromRow` passes `onsetMs: row.onsetMs` directly, no cast
- [x] New test: round-trips a line with `onsetMs: null` (text + naipe + dynamics all present) and asserts `roundTripped.onsetMs` is `null`
- [x] Gate check passes: `flutter test test/data/mappers/lyric_line_mapper_test.dart`
- [x] Test count: 4 tests pass (3 pre-existing + 1 new)

**Tests**: unit
**Gate**: quick
**Commit**: `feat(lyrics-editor): map nullable onsetMs in LyricLineMapper`

---

### T4: Update `DriftSongRepository` lyric ordering

**What**: Drop `onsetMs` from both lyric queries' `orderBy`, keep only `OrderingTerm.asc(l.rowId)`; extend repository tests to cover mixed marked/unmarked ordering.
**Where**: `lib/data/repositories/drift_song_repository.dart:78-83` (in `getById`), `:113-119` (in `getAll`)
**Depends on**: T3
**Reuses**: `test/data/repositories/drift_song_repository_test.dart`'s existing in-memory-DB save/fetch round-trip pattern.
**Requirement**: LYR-01

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Both `orderBy` calls are `[(l) => OrderingTerm.asc(l.rowId)]` only
- [ ] New test: save a song whose `lyrics` list has an unmarked line (`onsetMs: null`) inserted between two marked lines, fetch via `getById`, assert the returned list preserves the original list order (not sorted by `onsetMs`)
- [ ] Gate check passes: `flutter test` (full - cross-layer change, touches the same DB the migration test and mapper test exercise)
- [ ] Test count: all existing + 1 new repository test pass

**Tests**: unit (in-memory DB)
**Gate**: full

**Commit**: `feat(lyrics-editor): order lyrics by insertion instead of onsetMs`

---

### T5: `LyricsEditorNotifier` + `LyricsEditorState`

**What**: Implement the notifier (status enum, state fields/getters, `addLine`/`updateText`/`updateNaipe`/`updateDynamics`/`setExpanded`/`togglePreview`/`markNow`/`save`/`retry`/`dispose`) and its `autoDispose.family` provider, per design.md's full interface spec.
**Where**: `lib/presentation/providers/lyrics_editor_notifier.dart`
**Depends on**: T4
**Reuses**: `lib/presentation/providers/track_align_notifier.dart` (structural template: `_ref.listen(fireImmediately: true)` wiring, "don't await `cancel()`" fix, try/catch-on-load-song shape, `save()`/`retry()` shapes).
**Requirement**: LYR-03 through LYR-12, LYR-13, LYR-14

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [ ] All methods and getters from design.md's Components section are implemented exactly as specified (including `markNow()`'s backward-scan out-of-order rejection and `_stopPreview()`'s non-awaited `cancel()`)
- [ ] `lyrics_editor_notifier_test.dart` covers, 1:1 to spec ACs: addLine appends+expands+dirties; updateText rejects empty/>200 chars; updateDynamics rejects >40 chars; updateNaipe always accepts; markNow no-ops when nothing to mark; markNow rejects a mark earlier than the previous marked line's onset (no mutation); markNow succeeds and advances `nextUnmarkedIndex`; togglePreview no-ops when `tracks.isEmpty`; togglePreview sets `previewError` on engine-load failure; save success clears `hasUnsavedChanges` and invalidates `songByIdProvider`; save failure preserves `lines`/sets `saveError`; `currentLineIndex` returns the greatest marked `onsetMs <= currentPositionMs` or null; `markedCount`/`nextUnmarkedIndex` correctness
- [ ] Gate check passes: `flutter test test/presentation/providers/lyrics_editor_notifier_test.dart`
- [ ] Test count: ≥13 tests pass (one per bullet above; no silent deletions)

**Tests**: unit
**Gate**: quick
**Commit**: `feat(lyrics-editor): add LyricsEditorNotifier`

---

### T6: `LyricLineRow` shared widget + `COMPONENTS.md` entry

**What**: Build the collapsed/expanded inline-edit row widget exactly per design.md's interface, and add it to `docs/design/COMPONENTS.md` under "Reprodução e letra" in the same task (AGENTS.md §6).
**Where**: `lib/presentation/widgets/lyric_line_row.dart`, `docs/design/COMPONENTS.md`
**Depends on**: T5
**Reuses**: `lib/presentation/widgets/track_align_row.dart`'s blur-revert `TextEditingController`/`FocusNode` pattern; `VoicePartBadge`; `SegmentedControl<Naipe?>`; `TrackAlignDuration.format`.
**Requirement**: LYR-04, LYR-05, LYR-09, LYR-10, P2 (naipe/dinâmica) ACs

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux` (tokens-only visuals, AA contrast, 44dp touch targets, no literal colors/spacing)

**Done when**:
- [ ] Collapsed state renders tempo (mono, "—" when `onsetMs == null`), texto, naipe selo + dinâmica, "Editar"
- [ ] Expanded state renders texto field, `SegmentedControl<Naipe?>` (4 naipes + "Nenhum"), dinâmica field; blur reverts invalid input instead of showing a modal error
- [ ] `isCurrent: true` applies the "linha atual destacada" visual treatment using theme tokens only (no literal colors)
- [ ] Renders correctly under both `AppTheme.light` and `AppTheme.dark`
- [ ] `lib/docs/design/COMPONENTS.md` updated with the new component's name, props, and states in the same commit
- [ ] `test/presentation/widgets/lyric_line_row_test.dart` covers: collapsed render, expanded render + each `on*Changed` callback, blur-revert on invalid text/dinâmica, `isCurrent` highlight, dark theme smoke test
- [ ] Gate check passes: `flutter test test/presentation/widgets/lyric_line_row_test.dart`
- [ ] Test count: ≥7 tests pass

**Tests**: unit (widget)
**Gate**: quick

**Commit**: `feat(lyrics-editor): add LyricLineRow shared component`

---

### T7: `LyricsEditorScreen`

**What**: Build the full screen (all 4 statuses, header, scrollable line list + "+ Acrescentar linha", tracks-empty banner, preview footer, unsaved-changes `ConfirmSheet` on back) per design.md.
**Where**: `lib/presentation/screens/lyrics_editor/lyrics_editor_screen.dart`
**Depends on**: T6
**Reuses**: `lib/presentation/screens/track_align/track_align_screen.dart`'s `_StateScaffold`/`_LoadingBody`/`_NotFoundBody`/`_ErrorBody` shapes verbatim; `ConfirmSheet`, `Toast`, `EmptyState`, `InlineBanner`, `NavPill`, `CantaeScaffold`, `PrimaryButton`/`SecondaryButton`.
**Requirement**: LYR-01 through LYR-22 (screen is the integration point for all P1/P2/P3 ACs)

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-widget-performance` (preview footer rebuilds on every `positionMs` tick - scope rebuilds to the footer/current-line only, not the whole list)

**Done when**:
- [ ] All 4 statuses render per design.md; empty-lines state shows `EmptyState`; tracks-empty shows `InlineBanner.warning` (never blocks editing/saving)
- [ ] "Ouvir com a letra" toggles the preview footer ("Próxima: `<texto>` `<mm:ss.s>`" + Pausar + Marcar agora, disabled when nothing to mark)
- [ ] "Salvar" is always visible/enabled regardless of preview state; unsaved-exit triggers `ConfirmSheet`
- [ ] Both themes verified; system font scale 130% does not clip/overlap; touch targets ≥44dp; semantics for buttons/live status region per AGENTS.md §3/§7
- [ ] `test/presentation/screens/lyrics_editor/lyrics_editor_screen_test.dart` covers: loading/notFound/error/loaded renders, empty-lines state, tracks-empty banner present but non-blocking, add-line action, "Marcar agora" disabled with nothing to mark, save success toast, save failure banner, dark theme smoke test, semantics check
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test`
- [ ] Test count: ≥10 tests pass

**Tests**: widget (e2e-equivalent per AGENTS.md)
**Gate**: build
**Commit**: `feat(lyrics-editor): add LyricsEditorScreen`

---

### T8: Wire the real route

**What**: Replace the `lyrics-editor` route's `ComingSoonScreen` placeholder with `LyricsEditorScreen`, add the `:id` path segment, and update `song_detail_screen.dart`'s "Sincronizar letra" row to pass `pathParameters: {'id': song.id}`.
**Where**: `lib/presentation/routing/app_router.dart:69-74`, `lib/presentation/screens/song_detail/song_detail_screen.dart:269-274`
**Depends on**: T7
**Reuses**: The `track-align` route's exact `:id`-param shape directly above it in `app_router.dart`.
**Requirement**: LYR-01 (navigation entry point)

**Tools**:
- MCP: NONE
- Skill: `flutter-routing`

**Done when**:
- [ ] Route is `path: '/lyrics-editor/:id'`, `builder: (context, state) => LyricsEditorScreen(songId: state.pathParameters['id']!)`
- [ ] `song_detail_screen.dart`'s "Sincronizar letra" row passes `pathParameters: {'id': song.id}` to `context.goNamed('lyrics-editor', ...)`
- [ ] Existing `song_detail_screen_test.dart` (if it asserts on the nav call) updated to match; no regression
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test`
- [ ] Test count: full suite passes, 0 regressions

**Tests**: none (routing wiring; covered transitively by screen test reaching the route and existing song_detail tests)
**Gate**: build

**Commit**: `feat(lyrics-editor): wire LyricsEditorScreen into song detail and router`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 ------→ T2 ------→ T3 ------→ T4
Phase 2:  T5 ------→ T6
Phase 3:  T7 ------→ T8
```

Execution is strictly sequential - there is no intra-phase parallelism. A single agent (or batch worker) works one task at a time, in order.

Total: 8 tasks → single batch, no sub-agent delegation needed (≤ ~8 tasks).

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1: Make `LyricLine.onsetMs` nullable | 1 entity | ✅ Granular |
| T2: Migrate schema v2→v3 | 1 table + 1 migration step | ✅ Granular |
| T3: Update `LyricLineMapper` | 1 file | ✅ Granular |
| T4: Update repository ordering | 1 file, 2 queries (cohesive) | ✅ Granular |
| T5: `LyricsEditorNotifier` | 1 notifier + its provider | ✅ Granular |
| T6: `LyricLineRow` + docs | 1 widget + 1 doc entry (cohesive, same PR requirement) | ✅ Granular |
| T7: `LyricsEditorScreen` | 1 screen file | ✅ Granular |
| T8: Wire route | 2 files, pure wiring (cohesive) | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ----------------------- | --------------- | ------ |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1→T2 | ✅ Match |
| T3 | T2 | T2→T3 | ✅ Match |
| T4 | T3 | T3→T4 | ✅ Match |
| T5 | T4 | T4→T5 (full cross-phase chain) | ✅ Match |
| T6 | T5 | T5→T6 | ✅ Match |
| T7 | T6 | T6→T7 (full cross-phase chain) | ✅ Match |
| T8 | T7 | T7→T8 | ✅ Match |

Note: `Depends on` lists the minimum ordering edge (immediate predecessor); a task's **Reuses** field names any earlier task's artifact it actually consumes (e.g. T6 consumes T1's nullable `LyricLine` type, already satisfied transitively by the time T6 runs).

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | ----------------------------- | ------------------ | ----------- | -------- |
| T1: `LyricLine` | Domain entity | unit | unit | ✅ OK |
| T2: schema/migration | Infrastructure (schema) | unit (in-memory DB) | unit | ✅ OK |
| T3: `LyricLineMapper` | Data (mapper) | unit | unit | ✅ OK |
| T4: `DriftSongRepository` | Data (repository) | unit (in-memory DB) | unit | ✅ OK |
| T5: `LyricsEditorNotifier` | Presentation (notifier) | unit | unit | ✅ OK |
| T6: `LyricLineRow` | Presentation (shared widget) | unit (widget) | unit (widget) | ✅ OK |
| T7: `LyricsEditorScreen` | Presentation (screen) | widget (e2e-equivalent) | widget | ✅ OK |
| T8: routing wiring | Routing | none | none | ✅ OK |

---

## Tips

- **Phases are ordered** - Each phase completes before the next; tasks run in order within a phase
- **Reuses = Token saver** - Always reference existing code
- **Tools per task** - MCPs and Skills prevent wrong approaches
- **Dependencies are gates** - Clear what blocks what
- **Done when = Testable** - If you can't verify it, rewrite it
- **Requirement ID = Traceable** - Every task traces back to a spec requirement
- **One commit per task** - Plan the commit message format in advance

---

## Task Verification Standards

Every task MUST follow the `Done when` + `Tests` + `Gate` fields defined in the **Task Breakdown** template above. Each `Done when` entry must be specific, testable (binary pass/fail), and reference the gate check command from the `Gate Check Commands` section. Include the expected test count to prevent silent deletions.
