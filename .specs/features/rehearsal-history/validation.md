# Ensaios anteriores (rehearsal-history) Validation

**Date**: 2026-11-25
**Spec**: `.specs/features/rehearsal-history/spec.md`
**Diff range**: `7a7251a..d768831` (branch `feature/phase-5-rehearsal-history`; spec at `b1b767b`, design/tasks at `7a7251a`)
**Verifier**: standalone fallback, run by the author. The sub-agent call is blocked by auto mode because the `context-mode` plugin rewrites Agent prompts; the user approved the same fallback for the earlier features. Author ≠ verifier does **not** hold for this run.

**Verdict**: PASS ✅ (iteration 1)

---

## Task Completion

| Task | Status | Commit |
| ---- | ------ | ------ |
| T1 `RehearsalLog` + `RehearsalSessionTracker` | ✅ Done | `3107386` |
| T2 `rehearsal_logs` table + schema v4 | ✅ Done | `e1feab5` |
| T3 repository + `uuidV4` | ✅ Done | `67e4e8e` |
| T4 providers + `RehearsalRecorder` | ✅ Done | `7a5aa58` |
| T5 Modo solo records the session | ✅ Done | `181e964` |
| T6 `StatTile` | ✅ Done | `d4bfc5a` |
| T7 history notifier + formatting | ✅ Done | `e2ebaa5` |
| T8 Ensaios screen, route, detail count | ✅ Done | `d768831` |
| Fix found during T8: `StatTile` semantics merged in a list item | ✅ Done (red-first regression) | `39541d9` |

---

## Spec-Anchored Acceptance Criteria

| Req | Evidence (`file:line` — assertion) | Spec outcome | Result |
| --- | ---------------------------------- | ------------ | ------ |
| HIST-01 | `test/domain/rehearsal/rehearsal_session_tracker_test.dart:27` — `durationMs == 70000` with pauses; `test/presentation/providers/solo_player_notifier_test.dart:1326` — 40 s + 30 s playing around 300 s paused → `70000` | Only playing time | ✅ |
| HIST-02 | `rehearsal_session_tracker_test.dart:51` — `loopCount == 2` (jumps while paused ignored); `solo_player_notifier_test.dart:1274` — 3 loop jumps → `loopCount == 3` | One per jump back to the start | ✅ |
| HIST-03 | `solo_player_notifier_test.dart:1274` — one log: `songId 'ave'`, `durationMs 75000`, `loopCount 3`, `mode solo`, `startedAt` = first play, `endedAt` = leave; `rehearsal_session_tracker_test.dart:96` — role null, 1 participant; `drift_rehearsal_repository_test.dart:59` every field round-trips | Recorded on leaving with all fields | ✅ |
| HIST-04 | `rehearsal_session_tracker_test.dart:72` (59 999 ms → null), `:84` (60 000 ms → log), `:90` (never played → null); `solo_player_notifier_test.dart:1303` (59 s), `:1315` (never) → nothing recorded | Not recorded under 60 s | ✅ |
| HIST-05 | `test/presentation/providers/rehearsal_providers_test.dart:111` — `marked.single == ('ave', endedAt)` | Last-rehearsed = end of the rehearsal | ✅ |
| HIST-06 | `lib/domain/entities/rehearsal_log.dart` holds only the PRD fields; `rehearsal_logs` columns asserted exactly at `app_database_migration_test.dart:155/166` (`_rehearsalColumns`) | No audio, lyrics or other people's data | ✅ (by construction + exact column set) |
| HIST-07 | `rehearsal_providers_test.dart:135` (save fails → no mark, no throw), `:143` (mark fails → completes); `solo_player_notifier_test.dart:1405` — save fails, leaving still stops the engine | Leaving never blocked | ✅ |
| HIST-08 | `test/presentation/screens/song_detail/song_detail_screen_test.dart:368` — "Ensaios anteriores (2)" → `route:song-history:s1`; `:387` — 0 → "Ensaios anteriores" | Row with count opens this song | ✅ |
| HIST-09 | `test/presentation/screens/history/rehearsal_history_screen_test.dart:164` — "‹ Ave Verum Corpus", "Ensaios", "Registrados só neste aparelho." | Top, title, line | ✅ |
| HIST-10 | `rehearsal_history_screen_test.dart:164` — semantics "ensaios: 2", "tempo: 15:35", "loops: 8"; `rehearsal_history_notifier_test.dart:143` totals `935000` / `8`; `stat_tile_test.dart:28-73` | 3 summaries | ✅ |
| HIST-11 | `rehearsal_history_screen_test.dart:164` — newest row above the older one, "12:30", "8 loops", "3:05", "sem loops", "Modo solo" ×2; `drift_rehearsal_repository_test.dart:79` newest first; `rehearsal_format_test.dart:8-21` | List newest first with date, mode, duration, loops | ✅ |
| HIST-12 | `rehearsal_history_screen_test.dart:191` — "Nenhum ensaio registrado ainda", no delete buttons, "Ensaiar agora" → `route:solo-player:ave` | Empty state | ✅ |
| HIST-13 | `rehearsal_history_screen_test.dart:202` loading, `:219` error + retry, `:229` not found → library; `rehearsal_history_notifier_test.dart:139/154/161` | Loading, error, not found | ✅ |
| HIST-14 | `rehearsal_history_screen_test.dart:246` — confirm → empty, toast, `logs == ['other']`; `:260` cancel → `hasLength(3)`; `drift_rehearsal_repository_test.dart:92` | Delete this song only, with confirmation | ✅ |
| HIST-15 | `rehearsal_history_screen_test.dart:270` — message mentions "todas as músicas deste aparelho", confirm → `logs` empty; `drift_rehearsal_repository_test.dart:102` | Delete everything, with confirmation | ✅ |
| HIST-16 | `rehearsal_history_screen_test.dart:285` — banner "Não foi possível apagar os ensaios.", list kept, no toast; `rehearsal_history_notifier_test.dart:199` | Failure keeps the list | ✅ |
| HIST-17 | `rehearsal_history_screen_test.dart:246` toast "Ensaios apagados"; `rehearsal_history_notifier_test.dart:174` — `rehearsalLogsProvider` re-read after delete | Toast + detail count refreshed | ✅ |
| HIST-18 | `app_database_migration_test.dart:173` — deleting `ave-1` leaves only `aleluia`'s rehearsal | Song delete cascades | ✅ |
| HIST-19 | `solo_player_notifier_test.dart:1342` end + replay summed (80 000), `:1360` call pause excluded (65 000), `:1374` lock-screen play counts; background: the notifier has no lifecycle hook, and `solo_player_notifier_test.dart:1073` (background-audio) shows no pause on `AppLifecycleState.paused`. The lazy list is `ListView.builder` | Edge cases | ✅ (background and lazy list by construction) |

**Status**: ✅ All 19 requirements covered.

---

## Discrimination Sensor

Run in a temporary `git worktree` under the scratchpad (with `app_database.g.dart` copied), never `git stash`. Each mutant ran the test files of its area, and kill reasons were checked: none is a compile error.

| IDs | Area | Result |
| --- | ---- | ------ |
| R1–R7 | tracker: repeated play restarts the span, startedAt = last play, loops while paused, 60 s off by one, open span lost, wrong participants, only the last span counts | 7 killed |
| R8 | cascade removed | **survived as written, then killed** (see below) |
| R9 | upgrade misses the table | killed |
| R10–R14 | repository: oldest first, songs mixed, role lost, deleteBySong deletes all; uuid not v4 | 5 killed |
| R15–R19 | recorder: marks after a failed save, marks with start time, Library or count not refreshed, failure escapes | 5 killed |
| R20–R23 | Modo solo: state not fed, loops not reported, never records, paused time counted | 4 killed |
| R24–R25 | `StatTile`: semantics merge, label without caption | 2 killed |
| R26–R31 | history notifier and formatting: wrong total, missing song as error, failed delete empties, stale count, always h:mm:ss, month spelling | 6 killed |
| R32–R39 | screen and detail: cancel deletes, toast on failure, "Apagar tudo" deletes one song, no count, received song loses history, oldest first, zero-loops text, wrong song id | 8 killed |

**R8:**
- **As written:** R8 changed `onDelete` in `rehearsal_logs_table.dart`. Drift writes the FK clause into the generated `app_database.g.dart`, which the worktree copied and did not regenerate. The mutant never reached the database, so its survival was a sensor artefact.
- **Re-run:** the clause was removed from the generated code (`'REFERENCES songs (id) ON DELETE CASCADE'` → `''`, rehearsal table only). `app_database_migration_test.dart:173` then failed on the assertion: `Expected ['aleluia'], Actual ['ave-1', 'aleluia']`. The generated file was then restored, which `cmp` confirmed.

**Result**: **39/39 killed: PASS ✅**. Real-tree porcelain was empty before and after; the worktree was removed.

---

## Code Quality

- `scripts/check_layers.py`: OK. The domain files (`rehearsal_log.dart`, `rehearsal_session_tracker.dart`, `rehearsal_repository.dart`) are pure Dart.
- Migration v4 is additive (`createTable` + `createIndex`), and a v3 file with a song upgrades intact.
- New token `monoStat` is documented in DESIGN_SYSTEM.md; COMPONENTS.md and UI_SPEC §6.3/§6.16 are updated.
- Decision recorded in the spec (T8): a received song keeps "Ensaios anteriores" in its own section, because the PRD (history for every role) outranks the UI_SPEC (no "Preparar" for received songs).

---

## Gate Check

- `flutter analyze`: no issues.
- `dart format --set-exit-if-changed lib test integration_test`: clean.
- `flutter test`: **829 passed** (765 before the feature, +64).

---

## Requirement Traceability Update

HIST-01 to HIST-19: Implementing → Verified.

---

## Summary

**Overall**: ✅ Ready.

**Spec-anchored check**: 19/19 requirements matched to the spec outcome.
**Sensor**: 39/39 mutations killed (R8 re-run in the generated code).
**Gate**: 829 passed.

**Known limits**:
- A rehearsal is lost if the OS kills the app before the singer leaves Modo solo (spec assumption).
- Only Modo solo records for now; room rehearsals land with the room screens.

**Next steps**: merging `feature/phase-5-rehearsal-history` into `develop` needs the user's go-ahead.
