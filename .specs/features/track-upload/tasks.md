# Cadastrar música e enviar faixas (track-upload) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/track-upload/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found:
> - `AGENTS.md` §5/§7: a widget test per component (states, dark theme, semantics); screen states; 130% font; ≥ 44 dp.
> - `CLAUDE.md`: failure-first for isolated systems; E2E-equivalent tests for features; heavy work off the UI thread.
> - AD-010: repositories tested on `NativeDatabase.memory()`.
> - The user's standing rule: every bug gets a failing regression test in the same commit as its fix.
>
> Sampled: `test/data/repositories/drift_song_repository_test.dart`, `test/infrastructure/database/app_database_migration_test.dart`, `test/data/transfer/chunked_file_receiver_test.dart`, `test/presentation/providers/track_align_notifier_test.dart`, `test/presentation/screens/song_detail/song_detail_screen_test.dart`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Domain (rules, audio check) | unit (failure modes first) | 1:1 to UPL-05, 07, 08, 14; every boundary (0/1/80/81, 24/25, 100 MB ± 1) and every signature | `test/domain/library/*_test.dart` | `flutter test test/domain/library` |
| Infrastructure (schema, migration) | unit | v4 → v5 keeps songs, tracks and rehearsals; new table and columns | `test/infrastructure/database/*_test.dart` | `flutter test test/infrastructure/database` |
| Data (repositories) | unit (`NativeDatabase.memory()`) | Custom naipe round-trip, reuse across songs, sorted list, batched load, failures → `StorageFailure` | `test/data/repositories/*_test.dart` | `flutter test test/data/repositories` |
| Data (inspector, importer, saver) | unit on a temp directory (failure modes first) | Every rejection code; copy + verify; reuse; mismatch deletes; saver rollback; kept delay vs new delay 0 | `test/data/library/*_test.dart` | `flutter test test/data/library` |
| Infrastructure (picker adapter) | none (thin plugin adapter) | Build gate; behaviour covered through the port with a fake | - | build gate |
| Presentation (labels, badge) | unit (widget) | Every naipe kind, custom initial, dark theme, semantics | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets` |
| Presentation (notifier) | unit | Every state and transition, token guard, limits, dirty flag, save success/failure | `test/presentation/providers/song_editor_notifier_test.dart` | `flutter test test/presentation/providers` |
| Presentation (screen, routes, entry points) | widget (e2e-equivalent) | Every state, sheet, confirmations, navigation, both themes, 360 dp at 130 % | `test/presentation/screens/song_editor/*_test.dart`, existing screen tests | `flutter test test/presentation` |
| Feature flow | widget e2e (real DB in memory, real importer on a temp dir, fake picker) | Library → Nova música → save → Detalhe → Faixas → trocar → save; artifact = test output | `test/e2e/track_upload_flow_test.dart` | `flutter test test/e2e` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After a task with tests in one area | `flutter test <changed test file(s)>` |
| Full | After a task that changes a shared contract (entity, schema, labels, routing) | `flutter test` |
| Build | After phase completion | `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Domain

```
T1 → T2
```

### Phase 2: Persistence and files

```
T3 → T4 → T5 → T6 → T7 → T8
```

### Phase 3: Interface

```
T9 → T10 → T11 → T12 → T13
```

Full cross-phase chain:

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11 → T12 → T13
```

---

## Task Breakdown

### T1: `CustomNaipe`, `SongTrack` fields and song rules

**What**: `CustomNaipe` entity; `SongTrack` gains `customNaipe`, `fileName`, `fileSizeBytes` (assert custom naipe only on `Naipe.custom`); pure `validateSongFields` and `validateCustomNaipeName` with the limits as constants.
**Where**: `lib/domain/library/song_rules.dart`
**Depends on**: None
**Reuses**: `ValidationFailure`, AD-006 const entities
**Requirement**: UPL-05, UPL-14

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed in the test header, then tests: name empty/blank, 1, 80, 81 chars; author 0, 80, 81; trimmed values returned; naipe name empty, 24, 25; reserved names in any case (Soprano, contralto, TENOR, Baixo, Playback); duplicate of an existing custom naipe ignoring case and spaces; valid name returned trimmed
- [x] `scripts/check_layers.py` passes
- [x] Gate check passes: `flutter test test/domain/library`
- [x] Test count: all existing + ≥ 12 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(track-upload): add the custom naipe and the song field rules`

---

### T2: Audio file check

**What**: `AudioFormat`, `detectAudioFormat(header)` and `checkTrackFile(sizeBytes:, header:)` with codes `track_file_empty`, `track_file_too_large`, `track_file_unsupported`.
**Where**: `lib/domain/library/audio_file_check.dart`
**Depends on**: T1
**Reuses**: `ChunkPlanner.maxTransferableSizeBytes`
**Requirement**: UPL-07, UPL-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first, then tests: ID3 → mp3; MPEG frame sync → mp3; ADTS → aac; `ftyp` at offset 4 → m4a; RIFF…WAVE → wav; RIFF without WAVE, plain text, a PNG header, a header shorter than the signature → null; size 0 → empty; 100 MB → accepted; 100 MB + 1 → too large; size checked before format
- [x] `scripts/check_layers.py` passes
- [x] Gate check passes: `flutter test test/domain/library`
- [x] Test count: all existing + ≥ 12 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(track-upload): detect audio files by content and size`

---

### T3: Schema v5

**What**: `custom_naipes` table (`id`, `name`, unique `name_key`); `song_tracks` gains `custom_naipe_id` (nullable FK), `file_name`, `file_size_bytes`; `schemaVersion` 5 with an additive `from < 5` step.
**Where**: `lib/infrastructure/database/tables/custom_naipes_table.dart`
**Depends on**: T2
**Reuses**: v4 migration pattern, `app_database_migration_test.dart`
**Requirement**: UPL-15, UPL-19

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tests: a v4 file with a song, tracks and a rehearsal upgrades to v5 intact; new columns are null on old tracks; `custom_naipes` columns asserted exactly; `name_key` rejects a duplicate
- [ ] `app_database.g.dart` regenerated
- [ ] Gate check passes: `flutter test`
- [ ] Test count: all existing + ≥ 3 new

**Tests**: unit
**Gate**: full
**Commit**: `feat(track-upload): add custom naipes to the database schema`

---

### T4: Repositories for custom naipes

**What**: `CustomNaipeRepository` port + drift implementation (sorted by name); `SongTrackMapper` maps the 3 new fields; `DriftSongRepository.save` inserts referenced custom naipes (insert-or-ignore) in its transaction; `getById`/`getAll` load them in one batched query.
**Where**: `lib/data/repositories/drift_custom_naipe_repository.dart`
**Depends on**: T3
**Reuses**: `DriftSongRepository`, AD-010
**Requirement**: UPL-15, UPL-16, UPL-19

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tests: a song with a "Solista" track round-trips name, file name and size; the same custom naipe in two songs is stored once; `getAll` lists custom naipes by name, including one whose songs were deleted; `getAll` songs resolve custom naipes for several songs; a failing database → `StorageFailure`
- [ ] Gate check passes: `flutter test test/data/repositories`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(track-upload): store and load custom naipes`

---

### T5: `TrackFileInspector` and the picker port

**What**: Domain port `TrackFilePicker` + `PickedTrackFile`; data `TrackFileInspector.inspect` returning `InspectedTrackFile` (size, header, streamed SHA-256 inside `Isolate.run`) or a rejection, IO errors → `track_file_unreadable`.
**Where**: `lib/data/library/track_file_inspector.dart`
**Depends on**: T4
**Reuses**: T2 check, `crypto`
**Requirement**: UPL-07, UPL-08, UPL-09

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Failure modes listed first, then tests on a temp directory: a real WAV header file → wav with the right size and SHA-256; a `.mp3` that is text → unsupported; an empty file → empty; a sparse 100 MB + 1 file → too large without hashing; a missing path → unreadable
- [ ] Gate check passes: `flutter test test/data/library`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(track-upload): inspect picked files off the UI thread`

---

### T6: `TrackFileImporter`

**What**: Copy to `<sha>.<ext>.part`, hash the copy, rename on match; reuse a matching existing file; overwrite a stale one; delete the `.part` on mismatch or IO error; `discard` deletes only created files.
**Where**: `lib/data/library/track_file_importer.dart`
**Depends on**: T5
**Reuses**: `LibraryStoragePaths.trackFilePath`
**Requirement**: UPL-04, UPL-10, UPL-22

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Failure modes listed first, then tests: copy lands at `<root>/<sha>.mp3` with equal bytes and `created`; same file twice → reused, not `created`; a corrupt file at the final path is replaced; injected hasher mismatch → `track_hash_mismatch` and no `.part` or final file left; missing source → `track_copy_failed`; `discard` removes created and keeps reused
- [ ] Gate check passes: `flutter test test/data/library`
- [ ] Test count: all existing + ≥ 6 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(track-upload): copy tracks into the library and verify the hash`

---

### T7: `SongTracksSaver`

**What**: Build the `Song` from a `SongSaveRequest` (kept tracks unchanged, new files → new tracks with delay 0, file name and size; base song's lyrics, metronome, version, origin and last rehearsal kept), import new files, save; on any failure discard every created file.
**Where**: `lib/data/library/song_tracks_saver.dart`
**Depends on**: T6
**Reuses**: T4 repository, T6 importer, `uuidV4`
**Requirement**: UPL-04, UPL-10, UPL-15, UPL-19

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Failure modes listed first, then tests: new song saved as `created` with Soprano + Playback + "Solista"; existing song keeps Soprano delay 400, replaced Tenor gets 0, lyrics and metronome intact; the second import fails → first copy discarded, nothing saved; repository save fails → copies discarded; the same file for two naipes → one file
- [ ] Gate check passes: `flutter test test/data/library`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(track-upload): save a song with its new tracks atomically`

---

### T8: `file_picker` adapter and providers

**What**: Add `file_picker` (AD-013); `FilePickerTrackFilePicker` (audio filter, one file, cancel → null, exception → `picker_failed`); providers for the picker, inspector, importer, saver and custom naipe repository.
**Where**: `lib/presentation/providers/track_upload_providers.dart`
**Depends on**: T7
**Reuses**: `appDatabaseProvider`, `LibraryStoragePaths.resolveLibraryRoot`
**Requirement**: UPL-03, UPL-11

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] The installed `file_picker` source was read before writing the adapter; its cache behaviour noted in the commit body
- [ ] Tests: providers build the saver and repository on an in-memory database (overrides work)
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test`
- [ ] Test count: all existing + ≥ 1 new

**Tests**: unit
**Gate**: build
**Commit**: `feat(track-upload): add the system file picker behind a port`

---

### T9: Single naipe label mapping and custom badge

**What**: `naipe_labels.dart` becomes the only naipe → name/badge mapping (`trackDisplayName`, badge for a track); `VoicePartBadge` gains the neutral `custom` variant with an initial; the private copies in detail, align row, lyric row and song row are removed; COMPONENTS.md updated.
**Where**: `lib/presentation/widgets/naipe_labels.dart`
**Depends on**: T8
**Reuses**: `VoicePartColors` `todos`
**Requirement**: UPL-16

**Tools**:
- MCP: NONE
- Skill: flutter-ui-ux

**Done when**:
- [ ] Tests: names for the 4 naipes, Playback, "Solista", a nameless custom → "Outro naipe"; custom badge shows "S" for "Solista" in light and dark; existing screen tests still pass
- [ ] Gate check passes: `flutter test`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: full
**Commit**: `refactor(widgets): keep one naipe label mapping and add the custom badge`

---

### T10: `SongEditorNotifier`

**What**: Editor state for a new or existing song: load (loading, not found, error, read-only, ready), slots, pick with token guard, reject messages, remove with saved/removed states, add existing or new custom naipe (limit 4), dirty flag, save through the saver.
**Where**: `lib/presentation/providers/song_editor_notifier.dart`
**Depends on**: T9
**Reuses**: T1 rules, T5 inspector, T7 saver, T8 providers
**Requirement**: UPL-02, UPL-03, UPL-04, UPL-05, UPL-06, UPL-07, UPL-08, UPL-09, UPL-11, UPL-12, UPL-13, UPL-14, UPL-15, UPL-18, UPL-19, UPL-20, UPL-21, UPL-23

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tests: new song starts ready with 4 empty naipes + Playback; existing song loads saved slots and its custom naipes; not found, error + retry, received → read-only; pick → checking → chosen; each rejection keeps the previous slot and sets the spec message; cancel changes nothing; picker failure → message; a second pick during checking wins; create/choose custom naipe, 5th blocked, invalid name → reason; remove saved → removed, remove chosen → previous; dirty only after a change; save disabled with an invalid name; save success returns the id and invalidates the library; save failure → spec message; double save ignored
- [ ] Gate check passes: `flutter test test/presentation/providers`
- [ ] Test count: all existing + ≥ 20 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(track-upload): add the song editor state`

---

### T11: `SongEditorScreen`, add-naipe sheet and routes

**What**: The "Nova música" / "Faixas" screen and the add-naipe sheet per the design; routes `song-create` (`/song-editor`) and `track-upload` (`/song-editor/:id?naipe=`); `?naipe=` opens the picker once; discard confirmation on back; UI_SPEC section for the screen.
**Where**: `lib/presentation/screens/song_editor/song_editor_screen.dart`
**Depends on**: T10
**Reuses**: `CantaeScaffold`, `NavPill`, `ConfirmSheet`, `InlineBanner`, `EmptyState`, buttons, T9 labels
**Requirement**: UPL-02, UPL-03, UPL-05, UPL-06, UPL-12, UPL-13, UPL-14, UPL-16, UPL-18, UPL-20, UPL-21, UPL-23

**Tools**:
- MCP: NONE
- Skill: flutter-ui-ux

**Done when**:
- [ ] Tests: every state renders; choosing a file shows name and `MB`; rejection text; "Salvar música" disabled with the name limit shown, in progress while saving, opens the detail after save; sheet lists available custom naipes, creates one, shows the reason, "Até 4 naipes extras por música."; Trocar/Remover confirm and cancel; back with changes asks, cancel stays, confirm leaves; `?naipe=tenor` opens the picker once; read-only explanation; light and dark; 360 dp at 130 % without overflow; touch targets ≥ 44 dp; semantics on rows and buttons
- [ ] UI_SPEC.md section added
- [ ] Gate check passes: `flutter test test/presentation`
- [ ] Test count: all existing + ≥ 18 new

**Tests**: widget
**Gate**: full
**Commit**: `feat(track-upload): add the song editor screen`

---

### T12: Entry points and custom naipes in the existing screens

**What**: Library "Cadastrar primeira música" → `song-create`; Detalhe "Enviar faixa" → `track-upload` with id and naipe; Modo solo and Alinhamento → `track-upload` with id; Detalhe lists custom naipe tracks with their badge; Modo solo and Alinhamento show the custom name (via T9).
**Where**: `lib/presentation/screens/song_detail/song_detail_screen.dart`
**Depends on**: T11
**Reuses**: T9 labels
**Requirement**: UPL-01, UPL-16, UPL-17

**Tools**:
- MCP: NONE
- Skill: flutter-ui-ux

**Done when**:
- [ ] Tests: library empty state → `route:song-create`; detail Tenor row → `route:track-upload:<id>?naipe=tenor`; solo empty → `track-upload:<id>`; align empty → `track-upload:<id>`; detail shows "Solista" with an "S" badge; solo mix row and align row show "Solista"; router test maps both new routes
- [ ] UI_SPEC §6.2b/§6.3 updated
- [ ] Gate check passes: `flutter test`
- [ ] Test count: all existing + ≥ 7 new

**Tests**: widget
**Gate**: full
**Commit**: `feat(track-upload): open the editor from the library, detail, solo and align`

---

### T13: End-to-end flow test

**What**: One widget e2e test over the real app router, an in-memory database, the real inspector and importer on a temp directory and a fake picker: empty library → Nova música → name + Soprano + "Solista" → save → Detalhe shows both → Enviar faixa (Tenor) → save → files on disk and saved song checked; a text file named `.mp3` is refused along the way.
**Where**: `test/e2e/track_upload_flow_test.dart`
**Depends on**: T12
**Reuses**: everything above
**Requirement**: UPL-01, UPL-04, UPL-07, UPL-15, UPL-17, UPL-19, UPL-22

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] The test passes and prints the saved song and library file list as its artifact
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test`
- [ ] Test count: all existing + ≥ 1 new

**Tests**: e2e
**Gate**: build
**Commit**: `test(track-upload): cover the upload flow end to end`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 → T2
Phase 2:  T3 → T4 → T5 → T6 → T7 → T8
Phase 3:  T9 → T10 → T11 → T12 → T13
```

Execution is strictly sequential.

Total: 13 tasks → two batches. Sub-agents stay unavailable (the `context-mode` plugin blocks the Agent tool), so execution runs inline, as in the earlier features.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 | 1 entity + its field rules (one contract) | ✅ Granular |
| T2 | 1 pure check | ✅ Granular |
| T3 | 1 table + 1 migration step | ✅ Granular |
| T4 | 1 repository + its mapping in the song repository | ✅ Granular |
| T5 | 1 inspector + its port | ✅ Granular |
| T6 | 1 importer | ✅ Granular |
| T7 | 1 saver | ✅ Granular |
| T8 | 1 adapter + its providers | ✅ Granular |
| T9 | 1 label mapping + 1 badge variant | ✅ Granular |
| T10 | 1 notifier | ✅ Granular |
| T11 | 1 screen + its sheet and routes | ✅ Granular |
| T12 | entry-point wiring in existing screens | ✅ Granular |
| T13 | 1 e2e test | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1→T2 | ✅ Match |
| T3 | T2 | T2→T3 (cross-phase chain) | ✅ Match |
| T4 | T3 | T3→T4 | ✅ Match |
| T5 | T4 | T4→T5 | ✅ Match |
| T6 | T5 | T5→T6 | ✅ Match |
| T7 | T6 | T6→T7 | ✅ Match |
| T8 | T7 | T7→T8 | ✅ Match |
| T9 | T8 | T8→T9 (cross-phase chain) | ✅ Match |
| T10 | T9 | T9→T10 | ✅ Match |
| T11 | T10 | T10→T11 | ✅ Match |
| T12 | T11 | T11→T12 | ✅ Match |
| T13 | T12 | T12→T13 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Domain | unit | unit | ✅ OK |
| T2 | Domain | unit | unit | ✅ OK |
| T3 | Infrastructure (schema) | unit | unit | ✅ OK |
| T4 | Data (repositories) | unit | unit | ✅ OK |
| T5 | Data (inspector) | unit | unit | ✅ OK |
| T6 | Data (importer) | unit | unit | ✅ OK |
| T7 | Data (saver) | unit | unit | ✅ OK |
| T8 | Infrastructure adapter + providers | none / unit | unit | ✅ OK |
| T9 | Presentation (labels, badge) | unit (widget) | unit | ✅ OK |
| T10 | Presentation (notifier) | unit | unit | ✅ OK |
| T11 | Screen | widget | widget | ✅ OK |
| T12 | Screens | widget | widget | ✅ OK |
| T13 | Feature flow | widget e2e | e2e | ✅ OK |
