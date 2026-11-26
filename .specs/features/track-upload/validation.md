# Cadastrar música e enviar faixas (track-upload) Validation

**Date**: 2026-11-25
**Spec**: `.specs/features/track-upload/spec.md`
**Diff range**: `c78c9cc..8bace1a` (branch `feature/phase-5-track-upload`; spec at `98c9ae5`, design/tasks at `c78c9cc`)
**Verifier**: standalone fallback, run by the author. The Agent tool stays blocked by the `context-mode` plugin, and the user approved this fallback for the earlier features. Author ≠ verifier does **not** hold for this run.

**Verdict**: PASS ✅ (iteration 1)

---

## Task Completion

| Task | Status | Commit |
| ---- | ------ | ------ |
| T1 `CustomNaipe`, `SongTrack` fields, song rules | ✅ Done | `6c94413` |
| T2 audio file check | ✅ Done | `521e0da` |
| T3 schema v5 | ✅ Done | `233595d` |
| T4 custom naipe repositories | ✅ Done | `161cbaf` |
| T5 `TrackFileInspector` + picker port | ✅ Done | `d24762d` |
| T6 `TrackFileImporter` | ✅ Done | `14c3027` |
| T7 `SongTracksSaver` | ✅ Done | `1fe1955` |
| T8 `file_picker` adapter + providers | ✅ Done | `8037b3e` |
| T9 single naipe label mapping + custom badge | ✅ Done | `974d727` |
| T10 `SongEditorNotifier` | ✅ Done | `b6f3284` |
| T11 `SongEditorScreen`, sheet, routes, UI_SPEC §6.4 | ✅ Done | `d0c9c7d` |
| T12 entry points + custom naipes in existing screens | ✅ Done | `37ef4ad` |
| T13 end-to-end flow test | ✅ Done | `8bace1a` |

**Deviations recorded in `tasks.md`:**
- T10: "Remover" always leaves the slot without a track, including over a newly chosen file. The task text said a removed chosen file returns to the previous one.
- T11: the router test for the two new routes landed with the routes, not in T12.
- T3: the v1 and v2 migration seeds now create `song_tracks`. Every real database has had that table since Phase 2 (`3ffdc7f`), and the v5 step adds columns to it.

---

## Spec-Anchored Acceptance Criteria

| Req | Evidence (`file:line` — assertion) | Spec outcome | Result |
| --- | ---------------------------------- | ------------ | ------ |
| UPL-01 | `test/presentation/screens/library/library_screen_test.dart:209` — "Cadastrar primeira música" → `route:song-create`; `test/e2e/track_upload_flow_test.dart:63` — the real router reaches "Nova música" | Empty library opens Nova música | ✅ |
| UPL-02 | `test/presentation/screens/song_editor/song_editor_screen_test.dart:256` — Nome, "Autor (opcional)", 4 naipes, "Playback (opcional)", "Naipes extras"; `test/presentation/providers/song_editor_notifier_test.dart:205` — slots S, C, T, B, Playback | Fields and sections | ✅ |
| UPL-03 | `song_editor_screen_test.dart:276` — "soprano.mp3 · 12,4 MB"; `song_editor_notifier_test.dart:280` checking → chosen; picker filtered to `FileType.audio` in `lib/infrastructure/files/file_picker_track_file_picker.dart` | Pick and show name + MB | ✅ (audio filter by construction) |
| UPL-04 | `test/data/library/song_tracks_saver_test.dart:103` — saved as `created`, path `<root>/<sha>.mp3`; `test/data/library/track_file_importer_test.dart:62` copy equal bytes; `song_editor_screen_test.dart:342` → `route:song-detail:new-0`; e2e checks file paths and bytes | Copy, verify hash, save, open detail | ✅ |
| UPL-05 | `test/domain/library/song_rules_test.dart:26-68` — empty/blank, 1/80/81, author 0/80/81, trimmed; `song_editor_notifier_test.dart:463/479`; `song_editor_screen_test.dart:331` "Use até 80 caracteres." + button disabled | Name/author limits | ✅ |
| UPL-06 | `song_editor_notifier_test.dart:582` — second save returns null, one request; `song_editor_screen_test.dart:342` — `loading` true while saving | In progress, no double tap | ✅ |
| UPL-07 | `test/domain/library/audio_file_check_test.dart:30-81` (each signature, AVI, text, PNG, short header); `test/data/library/track_file_inspector_test.dart:55` text `.mp3` → unsupported; `song_editor_screen_test.dart:305` message; e2e refuses `coro.mp3` and the library keeps 3 files | Format by content | ✅ |
| UPL-08 | `audio_file_check_test.dart:93-110` (empty, 100 MB ok, +1 too large, size before format); `track_file_inspector_test.dart:61/67/80`; `song_editor_notifier_test.dart:304` (4 codes → spec messages, current file kept) | Size and unreadable | ✅ |
| UPL-09 | `song_editor_notifier_test.dart:280` checking state; `song_editor_screen_test.dart:288` "Conferindo arquivo…"; hashing inside `Isolate.run` (`lib/data/library/track_file_inspector.dart`, `track_file_importer.dart`) | Checking state off the UI thread | ✅ (isolate by construction) |
| UPL-10 | `track_file_importer_test.dart:90` mismatch → `track_hash_mismatch`, library empty; `song_tracks_saver_test.dart:203/227` copies removed, song not saved; `song_editor_screen_test.dart:361` message | Bad copy saves nothing | ✅ |
| UPL-11 | `song_editor_notifier_test.dart:322` cancel changes nothing; `:333` and `song_editor_screen_test.dart:321` "Não foi possível abrir os arquivos." | Cancel and picker failure | ✅ |
| UPL-12 | `song_editor_notifier_test.dart:205` Playback slot; `song_tracks_saver_test.dart:103` `playbackTrack.isPlayback`; `song_editor_screen_test.dart:559` "Escolher arquivo de Playback" | Optional Playback | ✅ |
| UPL-13 | `song_editor_notifier_test.dart:366/389`; `song_editor_screen_test.dart:376/387` — list of existing naipes, create "Solista" | Add existing or new | ✅ |
| UPL-14 | `song_rules_test.dart:80-129`; `song_editor_notifier_test.dart:399/419/430`; `song_editor_screen_test.dart:399/412` — reason shown, "Até 4 naipes extras por música.", button disabled | Name rules and limit 4 | ✅ |
| UPL-15 | `test/data/repositories/custom_naipe_persistence_test.dart:87/104` stored once, outlives deleted songs; `song_editor_notifier_test.dart:447` removing a row keeps it on the device; e2e device list `['Solista']` | Reusable device list | ✅ |
| UPL-16 | `test/presentation/widgets/naipe_labels_test.dart:39-75` name and neutral "S" in both themes; `song_detail_screen_test.dart:320`, `solo_player_screen_test.dart:453`, `track_align_screen_test.dart:230`, `song_editor_screen_test.dart:387` | Badge + name on 4 screens | ✅ |
| UPL-17 | `song_detail_screen_test.dart:306` → `track-upload:s1?naipe=tenor`; `solo_player_screen_test.dart:352`, `track_align_screen_test.dart:217`; `song_editor_screen_test.dart:509` picker opens once; `app_router_test.dart:208-238` | Entry points | ✅ |
| UPL-18 | `song_editor_screen_test.dart:453/467` — confirm sheets, cancel keeps, confirm applies; `song_editor_notifier_test.dart:556` | Trocar/Remover with confirmation | ✅ |
| UPL-19 | `song_tracks_saver_test.dart:146` — Soprano 400 kept, Tenor new id and 0, lyrics, metronome 72, origin, last rehearsal kept; `song_editor_notifier_test.dart:532` kept/new/removed and untouched legacy track | Save keeps delays, lyrics, tempo, origin | ✅ |
| UPL-20 | `song_editor_screen_test.dart:484/501` — ask, cancel stays, confirm leaves; no ask when clean | Discard confirmation | ✅ |
| UPL-21 | `song_editor_screen_test.dart:524/532/542`; `song_editor_notifier_test.dart:240/245/252/615` | Not found, error, read-only | ✅ |
| UPL-22 | `track_file_importer_test.dart:71` reused, not created; `song_tracks_saver_test.dart:250` one file for two naipes | Same file reused | ✅ |
| UPL-23 | `song_editor_notifier_test.dart:344` second pick wins; `song_editor_screen_test.dart:579` 360 dp at 130 %, no overflow, actions ≥ 44 dp | Latest pick; small screen | ✅ |

**Status**: ✅ All 23 requirements covered.

---

## Discrimination Sensor

Run in a temporary `git worktree` under the scratchpad (with `app_database.g.dart` copied), never `git stash`. Each mutant ran the test files of its area. Every anchor was checked to exist exactly once before the run.

| IDs | Area | Result |
| --- | ---- | ------ |
| U1–U7 | song and naipe rules: blank name, 80/24 limits off by one, untrimmed values, case-sensitive reserved and duplicate checks | 7 killed |
| U8–U12 | audio check: ADTS missed, any RIFF is WAV, short header crash, 100 MB off by one, empty not refused as empty | 5 killed |
| U13–U14 | migration misses the table / a column | 2 killed |
| U15–U19 | persistence: custom naipe or file name not stored, second song fails, unsorted list, only first naipe resolved | 5 killed |
| U20 | custom naipe list: database error escapes | **survived as written, then killed** (see below) |
| U21 | inspector: size not checked before reading | **equivalent** (see below) |
| U22–U23 | inspector: unreadable file throws, wrong hash | 2 killed |
| U24–U28 | importer: corrupt file reused, mismatch kept, `.part` left, discard deletes reused file, reused reported as created | 5 killed |
| U29–U33 | saver: copies kept after import or save failure, new song saved as received, lyrics dropped, size not stored | 5 killed |
| U34–U44 | editor state: older pick wins, rejection drops the file, 5th naipe ignored, save while checking, double tap, library not refreshed, removed track kept, untouched tracks dropped, unsaved duplicate, received song editable, picker cache kept | 11 killed |
| U45–U47 | labels and badge: custom name lost, badge colored as Soprano, initial not uppercased | 3 killed |
| U48–U53 | screen: cancel Trocar/Remover still acts, leaving does not ask, `?naipe` opens the wrong row, save enabled with an invalid name, size format | 6 killed |
| U54–U58 | router drops the naipe, Detalhe without naipe, Biblioteca goes nowhere, Alinhamento/Detalhe hide custom naipes | 5 killed |

**Kill reasons:**
- U22 is labelled COMPILE by the script only because the output contains "OS Error: ". Re-run, it fails `track_file_inspector_test.dart:80` with the escaped `PathNotFoundException`, so it is a real kill.
- U10, U19, U32 and U47 failed on thrown errors inside the test (a range error, a null check, `single`, `tester.widget`), not with "Expected:". All four are behaviour kills.

**U20.** As written, the mutant changed `catch (_)` to `on StateError`. A closed drift database throws a `StateError`, so for the test's own fault the mutant behaves exactly like the original, and its survival was a sensor artefact. Re-run with `on FormatException`, which leaves the real error unhandled, it was killed at `custom_naipe_persistence_test.dart:128` ("a database error is a StorageFailure"). The file was restored.

**U21.** The mutant removes the inspector's early size check. The oversized file is still refused with `track_file_too_large`, because `checkTrackFile` checks size before format and the hash runs only after that check passes. The only difference is reading 12 extra header bytes, which no spec outcome observes. It is recorded as equivalent, not as a gap.

**Result**: **57/57 non-equivalent mutants killed (U20 after the re-run), 1 equivalent: PASS ✅**. The real tree's porcelain was clean before the run. Afterwards the only change is this report; the worktree was removed.

---

## Code Quality

- `scripts/check_layers.py`: OK. `custom_naipe.dart`, `song_rules.dart`, `audio_file_check.dart`, `track_file_picker.dart` and `custom_naipe_repository.dart` are pure Dart.
- Migration v5 is additive (`createTable` + 3 × `addColumn`); a v4 file with a song, a track and a rehearsal upgrades intact.
- No N+1: custom naipes load in one `isIn` query for `getById` and `getAll`.
- Heavy work off the UI thread: the header read and SHA-256 run in `Isolate.run`, streamed, never holding 100 MB in memory.
- Docs updated in the same branch:
  - DESIGN_SYSTEM.md: `minTouchTarget`;
  - COMPONENTS.md: `VoicePartBadge.custom`, `NaipeBadge`;
  - UI_SPEC.md: §6.4 new, plus updates to §6.2b, §6.3, §6.5 and the nav map;
  - STATE.md: AD-013.
- The 5 private naipe → name mappings became one (`naipe_labels.dart`).

---

## Gate Check

- `flutter analyze`: no issues.
- `dart format --set-exit-if-changed lib test integration_test`: clean.
- `flutter test`: **955 passed** (829 before the feature, +126).

---

## Requirement Traceability Update

UPL-01 to UPL-23: Implementing → Verified.

---

## Summary

**Overall**: ✅ Ready.

**Spec-anchored check**: 23/23 requirements matched to the spec outcome.
**Sensor**: 57/57 non-equivalent mutants killed, 1 equivalent.
**Gate**: 955 passed.

**Known limits:**
- The real system file chooser was not run on a device. The adapter is a thin port, so tests use a fake. Android copies picked files into `cache/file_picker/`; `releaseTemporaryFiles()` clears them after a save.
- Files no track uses any more stay on disk (out of scope, Privacidade).
- Pre-existing, not from this feature: in the Detalhe, each missing-naipe row is announced as one button with repeated text ("T, Tenor, Enviar faixa de Tenor, Enviar faixa"). It works, but it is verbose.

**Next steps**: merging `feature/phase-5-track-upload` into `develop` needs the user's go-ahead.
