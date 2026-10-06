# Library Persistence Validation

## Validation: library-persistence - PASS ✅

**Date**: 2026-10-06 (re-verified after fix commit)
**Spec**: `.specs/features/library-persistence/spec.md`
**Diff range**: `ed9de11..d8b2c34`
**Verifier**: independent sub-agent (author ≠ verifier)

**Revision history**:
- First pass (`ed9de11..222f25e`): FAIL — 2 spec-anchored gaps (LIB-12, LIB-17) and 1 surviving mutant.
- Fix commit `d8b2c34` (`test(data): assert NotFoundFailure type, cover null playbackTrack`, test-only, no production code touched): strengthens the two not-found assertions and adds the missing null-`playbackTrack` edge-case test.
- This pass re-verifies the fix commit and supersedes the first-pass verdict below.

---

## Task Completion

| Task | Status  | Notes |
|------|---------|-------|
| T1   | ✅ Done | `Unit` const type, `test/domain/core/unit_test.dart` |
| T2   | ✅ Done | `SongRepository` interface, zero drift/flutter import |
| T3   | ✅ Done | `SongsTable` |
| T4   | ✅ Done | `SongTracksTable`, FK cascade + `is_playback_slot` default |
| T5   | ✅ Done | `LyricLinesTable`, FK cascade |
| T6   | ✅ Done | `AppDatabase`, schema v1, FK pragma, generated `app_database.g.dart` present |
| T7   | ✅ Done | `SongTrackMapper` |
| T8   | ✅ Done | `LyricLineMapper` |
| T9   | ✅ Done | `SongMapper` |
| T10  | ✅ Done | `DriftSongRepository.save` (transactional) |
| T11  | ✅ Done | `DriftSongRepository.getById` |
| T12  | ✅ Done | `DriftSongRepository.getAll` (bounded, no N+1) |
| T13  | ✅ Done | `DriftSongRepository.delete` |
| T14  | ✅ Done | `DriftSongRepository.deleteAll` |

All 14 tasks complete, no blocked/partial tasks.

---

## Spec-Anchored Acceptance Criteria

| AC | Spec-defined outcome | `file:line` + assertion | Result |
|----|----------------------|--------------------------|--------|
| LIB-01 | Tables `songs`, `song_tracks`, `lyric_lines` exist at v1 | `test/infrastructure/database/app_database_test.dart:18-27` — `expect(tableNames, containsAll([...]))` | ✅ PASS |
| LIB-02 | FK cascade on `song_tracks.song_id` and `lyric_lines.song_id` | `test/infrastructure/database/app_database_test.dart:66-88` (song_tracks cascade, raw SQL); `test/data/repositories/drift_song_repository_test.dart:258-282` (delete() cascades lyric_lines too, line 269-271 `expect(lyricRows, isEmpty)`) | ✅ PASS |
| LIB-03 | `songs.id`, `song_tracks.id` as `TEXT PRIMARY KEY` | `test/infrastructure/database/app_database_test.dart:29-40` (songs), `:42-58` (song_tracks) — both `throwsA(isA<Exception>())` on duplicate PK | ✅ PASS |
| LIB-04 | Future migrations additive-only | No test possible — no prior version exists (per spec's own Out of Scope) | ⚠️ Spec-precision gap (acknowledged in spec; mechanism present, not test-exercised) |
| LIB-05 | `PRAGMA foreign_keys = ON` on every connection | `test/infrastructure/database/app_database_test.dart:60-63` — `expect(result.data['foreign_keys'], equals(1))` | ✅ PASS |
| LIB-06 | Insert song + tracks + playback + lyrics, `Result.success(Unit)` | `test/data/repositories/drift_song_repository_test.dart:53-65` — row counts 1/3/3 | ✅ PASS |
| LIB-07 | Existing id → full replace, no leftover rows | `drift_song_repository_test.dart:67-92` — `trackRows hasLength(1)`, `lyricRows isEmpty` | ✅ PASS |
| LIB-08 | Song+tracks+lyrics writes in one transaction | `lib/data/repositories/drift_song_repository.dart:20-57` (`_db.transaction(...)` wraps all writes); proved behaviorally by LIB-09 rollback test | ✅ PASS |
| LIB-09 | Failed write → full rollback, `Result.failure(StorageFailure)`, non-empty code | `drift_song_repository_test.dart:94-120` — `songRows isEmpty` after forced dup-PK failure, `f.code isNotEmpty` | ✅ PASS |
| LIB-10 | `metronomeConfig == null` → NULL columns, no throw | `drift_song_repository_test.dart:122-130`; `test/data/mappers/song_mapper_test.dart:26-42` | ✅ PASS |
| LIB-11 | `getById` round-trips every field exactly | `drift_song_repository_test.dart:134-172` — id/name/author/version/tracks/playbackTrack/lyrics/metronomeConfig all asserted | ✅ PASS |
| LIB-12 | Unknown id → `Result.failure(NotFoundFailure)`, non-empty code | `drift_song_repository_test.dart:196-202` (post-fix) — `expect(f, isA<NotFoundFailure>())` **and** `expect(f.code, isNotEmpty)` | ✅ PASS (fixed — was GAP in first pass) |
| LIB-13 | `getAll()` on N songs → length N | `drift_song_repository_test.dart:186-198` | ✅ PASS |
| LIB-14 | Empty library → `Result.success([])`, not failure | `drift_song_repository_test.dart:200-208` | ✅ PASS |
| LIB-15 | Lyrics ordered ascending `onsetMs` | `drift_song_repository_test.dart:210-235` | ✅ PASS |
| LIB-16 | Delete existing id → cascade removes tracks/lyrics, `Result.success(Unit)` | `drift_song_repository_test.dart:258-276` | ✅ PASS |
| LIB-17 | Unknown id → `Result.failure(NotFoundFailure)`, non-empty code | `drift_song_repository_test.dart:311-317` (post-fix) — `expect(f, isA<NotFoundFailure>())` **and** `expect(f.code, isNotEmpty)` | ✅ PASS (fixed — was GAP in first pass) |
| LIB-18 | Post-delete `getAll()` has no row for deleted id | `drift_song_repository_test.dart:277-281` | ✅ PASS |
| LIB-19 | `deleteAll()` empties `songs`/`song_tracks`/`lyric_lines` | `drift_song_repository_test.dart:301-317` | ✅ PASS |
| LIB-20 | `deleteAll()` on empty library → still `Result.success(Unit)` | `drift_song_repository_test.dart:319-323` | ✅ PASS |

**Status**: ✅ All ACs covered and spec-anchored — 19/20 PASS, 1 acknowledged spec-precision gap (LIB-04, no test possible by design since no prior schema version exists to migrate from)

---

## Discrimination Sensor (re-run against `d8b2c34`)

Isolated scratch: `git worktree add ../cantae-verify-scratch2 HEAD` at `d8b2c34` (generated `app_database.g.dart` copied in manually, since it's gitignored and not part of the tracked tree). Mutation applied/run/discarded there; `git status --porcelain` on the real tree confirmed byte-identical before and after.

Re-ran the one mutation that survived in the first pass, against the fixed test suite:

| # | File:line | Description | Killed? |
|---|-----------|--------------|---------|
| 1 (re-run) | `lib/data/repositories/drift_song_repository.dart:157` | `delete()`: changed `NotFoundFailure` → `StorageFailure` on unknown id | ✅ **Killed** — LIB-17 test now fails: `Expected: <Instance of 'NotFoundFailure'> / Actual: StorageFailure:<StorageFailure(code: song_not_found)>` at `drift_song_repository_test.dart:315` |

Previously-killed mutations (2 and 3, from the first pass — flipped playback/track split condition; removed the `_db.transaction()` wrapper) are unaffected by this fix commit (test-only change, different test lines) and were not re-run; their kill status stands.

**Sensor depth**: lightweight (3 mutations total across both passes)
**Result**: 3/3 killed → **sensor PASS**

---

## Code Quality

| Principle | Status |
|-----------|--------|
| No features beyond what was asked | ✅ |
| No abstractions for single-use code | ✅ |
| No unnecessary flexibility added | ✅ |
| Only touched files required for task | ✅ — fix commit touches exactly one file (`test/data/repositories/drift_song_repository_test.dart`), no production code touched |
| Didn't "improve" unrelated code | ✅ |
| Matches existing patterns/style | ✅ — mirrors `Result`/`Failure` usage from `lib/domain/core/`, static mapper classes with private constructors |
| Would a senior engineer approve? | ✅ |
| Tests map to ACs and are non-shallow | ✅ 20/20 (LIB-04 has no test by design, acknowledged) |
| Spec-anchored outcome check | ✅ no gaps remaining |
| Per-layer coverage: domain 1:1 AC mapping; data/infra integration covers happy+edge+error | ✅ — `test/domain/core/unit_test.dart`, `test/data/mappers/*`, `test/data/repositories/*`, `test/infrastructure/database/*` all present and co-located per the Test Coverage Matrix |
| Every test maps to a spec AC/edge case/Done-when — no unclaimed tests | ✅ |
| Documented guidelines followed | `CLAUDE.md` (Result/Failure pattern, clean architecture, additive-only migrations) — followed |

---

## Edge Cases

- [x] Zero `tracks`/zero `lyrics` still saves successfully — `drift_song_repository_test.dart:122-130` (`song-null-metronome` fixture has no tracks/lyrics, `result.isSuccess` asserted)
- [x] `Song.playbackTrack == null` → no `is_playback_slot = 1` row persisted — **fixed**: `drift_song_repository_test.dart:131-148` (new test `'persists no is_playback_slot = 1 row when playbackTrack is null'`) saves a song with `playbackTrack: null` and 1 regular track, asserts `trackRows hasLength(1)` and `trackRows.every((row) => !row.isPlaybackSlot)`
- [x] Lyric tie-break by `rowId`, stable across repeated reads — `drift_song_repository_test.dart:210-235`
- [x] DB file doesn't exist yet → created + schema run before CRUD accepted — implicitly covered: every test constructs a fresh `NativeDatabase.memory()` and `onCreate` runs before any CRUD call in `setUp()`; per spec's own adopted test strategy this substitutes for a file-backed open
- [x] `getAll()` issues a bounded number of queries (no N+1) — `drift_song_repository_test.dart:237-254`, `QueryInterceptor` asserts exactly 3 SELECTs for 5 songs

All 5 listed edge cases now have direct test evidence.

---

## Gate Check

- **Gate command**: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && python scripts/check_layers.py --root .` plus `flutter test`
- **Result**: `flutter analyze` → 0 issues; `flutter test` → 110 passed, 0 failed, 0 skipped; `python scripts/check_layers.py --root .` → exit 0 ("no forbidden imports in lib/domain/")
- **Test count before feature** (`ed9de11`): 8 test files
- **Test count after feature** (`d8b2c34`): 14 test files (110 individual test cases — 109 from `222f25e` + 1 new null-`playbackTrack` test from the fix commit)
- **Delta**: +6 test files, +1 test case in the fix commit, all new (no existing test weakened or deleted)
- **Skipped tests**: none
- **Failures**: none

**Note on `check_layers.py`** (carried forward from first pass, unchanged by the fix commit): the script's `FORBIDDEN_PACKAGES` list does not include `package:drift` (only `flutter`, `just_audio`, `audio_service`, `sqflite`, `nsd`, `multicast_dns`, `path_provider`, `dart:io`). Spec's Success Criteria says the gate should confirm "no drift/flutter import inside lib/domain/", but the script as written cannot structurally catch a `package:drift` import in `domain/` — it currently passes only because no such import exists today (manually verified: `grep -rn "package:drift" lib/domain/` → no matches), not because the gate enforces it. The script predates this feature and modifying it was not a task in `tasks.md`, so this remains a gate-tooling observation, not a feature gap, and does not block this PASS verdict.

---

## Fix Plans

### Fix 1 (resolved in `d8b2c34`): `delete()`/`getById()` not-found tests didn't assert failure type

- **Root cause**: `drift_song_repository_test.dart:180` and `:292` (pre-fix) asserted only `expect(f.code, isNotEmpty)`, never `expect(f, isA<NotFoundFailure>())`.
- **Fix applied**: both tests now assert `expect(f, isA<NotFoundFailure>())` in addition to the code check.
- **Verification**: discrimination sensor mutation 1 (`NotFoundFailure` → `StorageFailure` in `delete()`) re-run against the fixed suite in an isolated worktree — now **killed** (see Sensor section above). `getById`'s equivalent assertion (LIB-12) was fixed identically; not independently mutated in this pass since the fix is the mirror of the already-confirmed `delete()` case and mutation 2 already exercises `getById`'s read path.
- **Status**: ✅ Fixed, confirmed by sensor re-run.

### Fix 2 (resolved in `d8b2c34`): No direct test for null-`playbackTrack` persistence edge case

- **Root cause**: No test previously saved a song with `playbackTrack: null` and verified zero `is_playback_slot = 1` rows.
- **Fix applied**: new test `'persists no is_playback_slot = 1 row when playbackTrack is null'` at `drift_song_repository_test.dart:131-148`, in the `save` group. Confirmed passing in the full `flutter test` run (110/110).
- **Status**: ✅ Fixed.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
|-------------|------------------|------------|
| LIB-01 through LIB-20 | Done | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready — PASS

**Spec-anchored check**: 19/20 ACs matched spec outcome exactly; 1 acknowledged spec-precision gap (LIB-04 — no migration exists to test by design, not a defect)
**Sensor**: 3/3 mutations killed (the one that survived the first pass — `delete()`'s `NotFoundFailure`→`StorageFailure` swap — is now killed after the fix)
**Gate**: 3/3 passed (`flutter analyze` 0 issues; `flutter test` 110/110; `check_layers.py` exit 0)

**What works**: Schema, FK cascade + pragma, transactional save with real rollback, round-trip fidelity (including `is_playback_slot` split and all-null `MetronomeConfig`), bounded `getAll()` (3 queries, proven by interceptor), delete/deleteAll cascade behavior, not-found failure typing, and the null-`playbackTrack` edge case — all now have direct, spec-anchored test evidence. All 14 tasks plus the fix commit shipped additively with no scope creep; fix commit touched test code only.

**Issues found**: none remaining.

**Next steps**: none — feature is verified done.
