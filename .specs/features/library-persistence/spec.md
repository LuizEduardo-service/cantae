# Library Persistence Specification

## Problem Statement

Phase 1 produced pure domain entities (`Song`, `SongTrack`, `LyricLine`, `MetronomeConfig`) that exist only in memory. Phase 2 gives them a durable home: an additive-only SQLite schema and a repository that saves, loads, and deletes a `Song` with its tracks and lyrics as one atomic unit. Without this, no later phase (Studio, session sync, player) has anything to load from or save to.

## Goals

- [ ] A versioned, additive-only SQLite schema exists for `songs`, `song_tracks`, and `lyric_lines`, created on first app launch
- [ ] `SongRepository` (domain interface) can save a complete `Song` (upsert), fetch one by id, fetch all, and delete one by id, with cascading removal of its tracks and lyrics
- [ ] A `SongRepository.deleteAll()` capability exists so local data can be fully wiped without a server call
- [ ] Every repository write is atomic — a song, its tracks, and its lyrics commit together or not at all
- [ ] Every repository failure surfaces as a typed `Failure` via `Result`, never a thrown exception across the domain boundary
- [ ] Zero `package:flutter` or `sqflite` imports inside `lib/domain/`
- [ ] Round-trip fidelity: every field on every entity survives a save → load cycle unchanged

## Out of Scope

| Feature | Reason |
|---------|--------|
| Library browsing UI, search, filtering, pagination | Phase 5 (UI) — this phase is data access only |
| Audio file content / hash validation before library visibility | Phase 4 — requires the audio engine (`just_audio`) to read file content |
| Standalone track/lyric CRUD independent of a full `Song` save | Not needed until Studio (audio cutting); Phase 2 only persists whole songs |
| Session sync / networked persistence | Phase 3 (networking) |
| Studio (audio cutting) schema additions | Lands after Phase 2 per project phase table; this spec only covers the Phase 1 entity shapes |
| Schema migrations beyond v1 | No prior version exists yet; migration *mechanism* is built, but there is nothing to migrate from |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|-----------------------|----------------|-----------|------------|
| Schema normalization | Separate tables (`songs`, `song_tracks`, `lyric_lines`) with `song_id` foreign keys | Enables independent querying later (Studio); avoids rewriting a whole blob on small edits | y |
| Repository CRUD surface | Full-`Song` save only; no standalone track/lyric mutation methods | Matches current domain usage; narrower CRUD scope is easier to get right and extend later | y |
| Conflict handling on save | Upsert (`INSERT OR REPLACE` by primary key) | Matches local-first, single-device model; no separate create/update API needed | y |
| Cascade delete | `ON DELETE CASCADE` in schema (`song_tracks.song_id`, `lyric_lines.song_id` reference `songs.id`) | Song is the atomic persistence unit; deleting it should not leave orphan rows | y |
| File hash / content validation | Deferred to Phase 4 | Requires reading file content via the audio engine, not available yet; Phase 2 only validates `filePath` is a non-empty string (already enforced by `SongTrack`'s own assert) | y |
| `LyricLine` row identity | DB-assigned `INTEGER PRIMARY KEY AUTOINCREMENT` (SQLite rowid), never exposed on the domain entity; load order is `ORDER BY onset_ms ASC, rowid ASC` | `LyricLine` has no domain `id` field; a stable, deterministic order on read is required for round-trip fidelity of list order | n |
| `Song.playbackTrack` vs `Song.tracks` persistence | Both stored as rows in `song_tracks`; an extra boolean column `is_playback_slot` (distinct from the entity's own `isPlayback` field) marks the row that reconstructs into `Song.playbackTrack`. Rows with `is_playback_slot = 0` reconstruct into `Song.tracks` | `Song` carries `tracks` and `playbackTrack` as two distinct fields; without a dedicated marker, reconstruction cannot tell which `isPlayback: true` row (if several existed) is *the* `playbackTrack` | n |
| Repository implementation test strategy | Use `sqflite_common_ffi` (new dev dependency) to run repository tests against a real SQLite engine under plain `flutter test`, without platform channels | The plugin's default SQLite binding requires a running Android/iOS platform; `sqflite_common_ffi` is the standard way to exercise real SQL logic in a fast, non-UI test per the project's failure-first isolation-testing rule | n |
| Void-returning `Result` encoding | Add `lib/domain/core/unit.dart` with a singleton `Unit` type; `save`/`delete`/`deleteAll` return `Result<Unit, Failure>` | `Result<S, F>` requires a concrete success type; introducing `Unit` is the smallest addition consistent with the existing sealed-class pattern, avoiding `void` as a generic type argument | n |

**Open questions:** none — all resolved above (confirmed with the user) or logged as agent defaults with rationale (unconfirmed, to be re-surfaced in Design if the user wants to revisit).

---

## User Stories

### P1: Schema & Migration Infrastructure ⭐ MVP

**User Story**: As the app, I want a versioned SQLite schema created on first launch, so that every later phase has a stable, additive-only place to persist data.

**Why P1**: Every repository operation depends on the schema existing first; this is the foundation of the whole phase.

**Acceptance Criteria**:

1. WHEN the app opens the database for the first time THEN the system SHALL create tables `songs`, `song_tracks`, and `lyric_lines` at schema version `1`. <!-- LIB-01 -->
2. The system SHALL define `song_tracks.song_id` and `lyric_lines.song_id` as foreign keys referencing `songs.id` with `ON DELETE CASCADE`. <!-- LIB-02 -->
3. The system SHALL enforce `songs.id` and `song_tracks.id` as primary keys (`TEXT PRIMARY KEY`). <!-- LIB-03 -->
4. IF a future schema version adds a column or table THEN the migration SHALL be additive-only — no existing column is dropped, renamed, or type-changed. <!-- LIB-04 -->
5. The system SHALL enable foreign key enforcement (`PRAGMA foreign_keys = ON`) on every database connection. <!-- LIB-05 -->

**Independent Test**: Open a fresh database file; query `sqlite_master` for the three table names and confirm the foreign key pragma is `1`.

---

### P1: Song Repository — Save (Upsert) ⭐ MVP

**User Story**: As a calling feature (Studio, library UI), I want to save a complete `Song` in one call, so that I never have to orchestrate separate writes for its tracks and lyrics.

**Why P1**: Save is the single entry point every other phase writes through; a non-atomic or partial save corrupts the library silently.

**Acceptance Criteria**:

6. WHEN `SongRepository.save(song)` is called with a `Song` whose `id` does not yet exist in `songs` THEN the system SHALL insert the song, all its `tracks`, its `playbackTrack` (if present), and all its `lyrics`, and return `Result.success(Unit)`. <!-- LIB-06 -->
7. WHEN `SongRepository.save(song)` is called with a `Song` whose `id` already exists THEN the system SHALL replace the existing row and all its associated `song_tracks`/`lyric_lines` rows with the new data (upsert), and return `Result.success(Unit)`. <!-- LIB-07 -->
8. The system SHALL perform the song row write, track row writes, and lyric row writes for one `save()` call inside a single database transaction. <!-- LIB-08 -->
9. IF any write inside a `save()` transaction fails THEN the system SHALL roll back the entire transaction and return `Result.failure(StorageFailure)` with a non-empty `code`. <!-- LIB-09 -->
10. WHEN `Song.metronomeConfig` is `null` THEN the system SHALL persist the song's metronome columns as `NULL` and SHALL NOT throw. <!-- LIB-10 -->

**Independent Test**: Save a `Song` with 2 tracks, 1 playback track, 3 lyric lines, and a `metronomeConfig`; save it again with modified fields; confirm the second save fully replaces the first (no leftover rows) via a direct row count query.

---

### P1: Song Repository — Read ⭐ MVP

**User Story**: As a calling feature, I want to fetch one song by id or all songs, so that the library and player can load what was saved exactly as it was saved.

**Why P1**: Read is useless if it doesn't round-trip every field correctly — this is what Phase 4/5 will build directly on top of.

**Acceptance Criteria**:

11. WHEN `SongRepository.getById(id)` is called with an `id` that exists THEN the system SHALL return `Result.success(song)` where every field of `song` (including `tracks`, `playbackTrack`, `lyrics`, `metronomeConfig`) exactly equals what was last saved for that `id`. <!-- LIB-11 -->
12. IF `SongRepository.getById(id)` is called with an `id` that does not exist THEN the system SHALL return `Result.failure(NotFoundFailure)` with a non-empty `code`. <!-- LIB-12 -->
13. WHEN `SongRepository.getAll()` is called on a library with N saved songs THEN the system SHALL return `Result.success(songs)` where `songs.length == N`. <!-- LIB-13 -->
14. WHEN `SongRepository.getAll()` is called on an empty library THEN the system SHALL return `Result.success(<Song>[])` (empty list, not a failure). <!-- LIB-14 -->
15. WHEN a song's `lyrics` are loaded THEN the system SHALL return them ordered by ascending `onsetMs`. <!-- LIB-15 -->

**Independent Test**: Save a known `Song` fixture; `getById` and assert deep equality against the fixture; `getById` on a random unknown id and assert `NotFoundFailure`.

---

### P1: Song Repository — Delete ⭐ MVP

**User Story**: As a calling feature, I want to delete a song by id and have its tracks and lyrics disappear with it, so that the library never accumulates orphaned rows.

**Why P1**: Orphaned `song_tracks`/`lyric_lines` rows would silently leak and eventually corrupt `getAll()` results or disk usage.

**Acceptance Criteria**:

16. WHEN `SongRepository.delete(id)` is called with an `id` that exists THEN the system SHALL remove the song row and SHALL cascade-remove every associated `song_tracks` and `lyric_lines` row, returning `Result.success(Unit)`. <!-- LIB-16 -->
17. IF `SongRepository.delete(id)` is called with an `id` that does not exist THEN the system SHALL return `Result.failure(NotFoundFailure)` with a non-empty `code`. <!-- LIB-17 -->
18. WHEN a song is deleted THEN a subsequent `getAll()` SHALL NOT include any `song_tracks` or `lyric_lines` row that referenced that song's id. <!-- LIB-18 -->

**Independent Test**: Save a song with tracks and lyrics; delete it; query `song_tracks`/`lyric_lines` directly by the deleted `song_id` and assert zero rows.

---

### P2: Full Library Wipe

**User Story**: As the app, I want a single call that erases all locally stored songs, so that "full local data deletion without a server call" (a project-level acceptance criterion) is possible from day one of persistence.

**Why P2**: Not required for Studio/Phase 4 to function, but cheap to add now and directly satisfies a stated project acceptance criterion; delaying it would mean revisiting this exact schema later.

**Acceptance Criteria**:

19. WHEN `SongRepository.deleteAll()` is called THEN the system SHALL remove every row from `songs`, `song_tracks`, and `lyric_lines`, and return `Result.success(Unit)`. <!-- LIB-19 -->
20. WHEN `SongRepository.deleteAll()` is called on an already-empty library THEN the system SHALL still return `Result.success(Unit)` (not a failure). <!-- LIB-20 -->

**Independent Test**: Save 3 songs; call `deleteAll()`; call `getAll()` and assert an empty list.

---

## Edge Cases

- IF `SongRepository.save(song)` is called with a `Song` that has zero `tracks` and zero `lyrics` THEN the system SHALL still save the song row successfully (an incomplete song is a valid persisted state — `isComplete` is a domain query, not a save-time constraint).
- IF `Song.playbackTrack` is `null` THEN the system SHALL persist no `is_playback_slot = 1` row for that song.
- IF two `LyricLine`s share the same `onsetMs` THEN their relative order on read SHALL be stable across repeated `getById` calls for the same unchanged data (tie-broken by rowid).
- IF the database file does not yet exist on disk THEN opening the repository SHALL create it and run the version-1 schema before any CRUD call is accepted.
- WHEN `SongRepository.getAll()` is called THEN the system SHALL NOT perform one query per song (no N+1) — tracks and lyrics for all songs SHALL be fetched in a bounded number of queries independent of song count.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|----------------|-------|-------|--------|
| LIB-01 | P1: Schema & Migration | Tasks | Pending |
| LIB-02 | P1: Schema & Migration | Tasks | Pending |
| LIB-03 | P1: Schema & Migration | Tasks | Pending |
| LIB-04 | P1: Schema & Migration | Tasks | Pending |
| LIB-05 | P1: Schema & Migration | Tasks | Pending |
| LIB-06 | P1: Repository Save | Tasks | Pending |
| LIB-07 | P1: Repository Save | Tasks | Pending |
| LIB-08 | P1: Repository Save | Tasks | Pending |
| LIB-09 | P1: Repository Save | Tasks | Pending |
| LIB-10 | P1: Repository Save | Tasks | Pending |
| LIB-11 | P1: Repository Read | Tasks | Pending |
| LIB-12 | P1: Repository Read | Tasks | Pending |
| LIB-13 | P1: Repository Read | Tasks | Pending |
| LIB-14 | P1: Repository Read | Tasks | Pending |
| LIB-15 | P1: Repository Read | Tasks | Pending |
| LIB-16 | P1: Repository Delete | Tasks | Pending |
| LIB-17 | P1: Repository Delete | Tasks | Pending |
| LIB-18 | P1: Repository Delete | Tasks | Pending |
| LIB-19 | P2: Full Library Wipe | Tasks | Pending |
| LIB-20 | P2: Full Library Wipe | Tasks | Pending |

**Coverage:** 20 total, 0 mapped to tasks ⚠️ (tasks.md pending)

---

## Success Criteria

- [ ] `flutter test test/data/` and `test/infrastructure/` pass with zero failures, using `sqflite_common_ffi`
- [ ] `python scripts/check_layers.py --root .` exits 0 (no `sqflite`/`flutter` import inside `lib/domain/`)
- [ ] `flutter analyze` exits 0
- [ ] All 20 ACs covered by at least one test with `file:line` evidence
- [ ] A save → load round trip preserves every field of a fixture `Song` with tracks, a playback track, lyrics, and a metronome config
