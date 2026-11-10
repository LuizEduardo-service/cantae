# File Transfer & Synchronized Playback Tasks

## Execution Protocol (MANDATORY — do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/file-transfer-and-sync-playback/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling (`test/data/session/room_session_controller_test.dart`, `test/infrastructure/network/tcp_session_transport_test.dart`, `test/domain/audio/*_test.dart`) and project guidelines. Guidelines found: `CLAUDE.md` ("Testing Rules" — E2E as primary mechanism, failure-first for isolation tests), `.specs/STATE.md` AD-001/AD-002/AD-005/AD-010. No `AGENTS.md` or lint-coverage-threshold config exists; coverage depth below follows CLAUDE.md's explicit rules plus the strong default for anything it doesn't specify.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Domain pure logic (`ChunkPlanner`, `FileTransferState`, `LatencyEstimator`) | unit (failure-modes-first per CLAUDE.md Testing Rule 3 — isolation tests only, since these are pure functions with no E2E surface of their own) | All branches; 1:1 to the ACs listed in each task's Requirement field | `test/domain/transfer/*_test.dart`, `test/domain/playback/*_test.dart` | `flutter test test/domain/transfer test/domain/playback` |
| `AudioPlaybackEngine` interface, `PlaybackPhase`/`TransferPhase` enums | none | — (build gate only; no behavior to test, same precedent as `SongRepository`'s interface) | — | build gate only |
| Wire protocol (`RoomApplicationMessage` encode/decode) | unit | Every message variant round-trips; a malformed/truncated byte sequence is rejected — mirrors `session_wire_message_test.dart`'s existing depth | `test/data/session/room_application_message_test.dart` | `flutter test test/data/session` |
| `RoomSessionController` extension (`applicationMessages`, `sendEnvelopeTo`, `broadcastEnvelope`) | E2E (CLAUDE.md Testing Rule 2 — real two-controller loopback TCP, no mocks, same harness `room_session_controller_test.dart` already uses) | Verified payload reaches the stream; a rejected (bad HMAC/replay/role) envelope never does; broadcast reaches every connected participant; non-master `sendEnvelopeTo` with `requiresMasterRole: true` is rejected at the existing gate | `test/data/session/room_session_controller_test.dart` (extended) | `flutter test test/data/session` |
| File transfer (`ChunkedFileSender`, `ChunkedFileReceiver`, `SongSyncCoordinator`, storage-path resolver) | E2E (real loopback TCP + real temp-dir files, no mocked transport — CLAUDE.md Testing Rule 2) | Every P1 "file transfer" AC: happy path, resume-after-disconnect, hash-mismatch retry+discard, dedup skip, oversize rejection, insufficient-storage abort | `test/data/transfer/*_test.dart` | `flutter test test/data/transfer` |
| Synchronized playback (`PlaybackCommandBroadcaster`, `PlaybackCommandHandler`) | E2E (real loopback TCP; `AudioPlaybackEngine` is faked here — the real engine is plugin-backed and covered separately below) | Every P1 "synchronized playback" AC: latency-compensated scheduling, visitor rejection, late-join waiting state, pause/stop/loop-reposition | `test/data/playback/*_test.dart` | `flutter test test/data/playback` |
| Plugin-backed infrastructure (`MultiTrackAudioEngine` w/ `just_audio`, `BackgroundAudioHandler` w/ `audio_service`) | E2E on real device (`integration_test` — cannot run under `flutter test`; same constraint the project already hit with `nsd`/mDNS in Phase 3, see `.specs/STATE.md` Handoff) | Real multi-track load+play, background continuation, lock-screen/notification control tap round-trips through the role gate | `integration_test/file_transfer_and_sync_playback_test.dart` | `flutter test -d <device-id> integration_test/file_transfer_and_sync_playback_test.dart` |

## Gate Check Commands

> Generated from codebase (`.specs/STATE.md` Handoff section lists these exact commands for every prior phase).

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a domain-only task (Phase 1) | `flutter test test/domain` |
| Full | After any task touching `data/` or extending session/transfer/playback E2E tests | `flutter test` |
| Build | After each phase completes, and always before the final commit of the feature | `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/` |
| Device | Only for Phase 5/6 tasks that touch `just_audio`/`audio_service` | `flutter test -d <device-id> integration_test/file_transfer_and_sync_playback_test.dart` |

---

## Execution Plan

### Phase 1: Domain Foundations (pure, no I/O)

T1, T2, T3, T4, T5, T6 — independent of each other (no data dependency between them); grouped in this phase and executed in this order purely for human readability. Each one's `Depends on` is `None`; the real cross-phase dependencies onto later tasks are shown in the Phase Execution Map below.

### Phase 2: Wire Protocol & Session Extension

T7, then T8 (T8 depends on T7 — see Phase Execution Map).

### Phase 3: File Transfer

T9, T10, T11, T12, T13, executed in this order. T9 is independent; T10/T11/T12/T13's real dependencies (several reaching back into Phase 1/2) are shown in the Phase Execution Map below.

### Phase 4: Synchronized Playback

T14, then T15 (dependencies shown in the Phase Execution Map below).

### Phase 5: Audio Engine Infrastructure (plugin-backed, real device)

T16, then T17 (dependencies shown in the Phase Execution Map below).

### Phase 6: Real-Device E2E & Layer-Purity Close-out

T18, then T19 (dependencies shown in the Phase Execution Map below).

---

## Task Breakdown

### T1: Add `PlaybackFailure` to the domain Failure hierarchy

**What**: Add a `PlaybackFailure extends Failure` class alongside the existing `NotFoundFailure`/`ValidationFailure`/`StorageFailure`/`NetworkFailure`, for playback-engine-origin failures (e.g. `audio.focus-lost`) that don't fit the existing four.
**Where**: `lib/domain/core/failures.dart`
**Depends on**: None
**Reuses**: Existing `Failure` base class pattern (AD-002) in the same file.
**Requirement**: BG-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `PlaybackFailure` follows the exact shape of the other four subclasses (constructor, `code` field, no `throw`)
- [x] `flutter analyze` reports 0 new issues

**Tests**: none (entity/config-level addition — no new behavior to test; existing `Failure` behavior is already covered by `test/domain/core/result_test.dart`)
**Gate**: quick

**Commit**: `feat(domain): add PlaybackFailure to the Failure hierarchy`

---

### T2: Create `ChunkPlanner`

**What**: Pure static-method class computing chunk count, resume-from-index, and the 100 MB size-cap check.
**Where**: `lib/domain/transfer/chunk_planner.dart`
**Depends on**: None
**Reuses**: Nothing existing — new domain math, styled like `lib/domain/audio/timeline_converter.dart` (`abstract final class` with static methods, asserts on invalid input).
**Requirement**: XFER-02, XFER-03, XFER-04 (plus the 100 MB Edge Case)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `chunkCount`, `resumeFromChunkIndex`, `exceedsMaxSize` implemented exactly as signed in design.md
- [x] Unit tests cover: exact multiple of chunk size, remainder chunk, zero-size file (0 chunks), `lastAckedChunkIndex == -1` → resume at 0, `lastAckedChunkIndex == N` → resume at N+1, size at/under/over the 100 MB cap boundary
- [x] `flutter test test/domain/transfer` passes

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add ChunkPlanner for file-transfer chunk math`

---

### T3: Create `FileTransferState` + `TransferEvent`/`TransferPhase`

**What**: Guarded state machine for one track's transfer to one participant (`pending → inProgress → validating → available` / `failed`), returning `Result<FileTransferState, PlaybackFailure>`... — **correction, uses a transfer-domain failure, not `PlaybackFailure`**: reuse `ValidationFailure`/`StorageFailure`/`NetworkFailure` per the Error Handling Strategy table in design.md (hash-mismatch → `ValidationFailure`, insufficient-storage → `StorageFailure`, chunk-delivery-failed → `NetworkFailure`). No new Failure subclass needed here.
**Where**: `lib/domain/transfer/file_transfer_state.dart`
**Depends on**: None
**Reuses**: `Result`/`Failure` pattern (AD-002); `ValidationFailure`, `StorageFailure`, `NetworkFailure` from `lib/domain/core/failures.dart`.
**Requirement**: XFER-05, XFER-06, XFER-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `TransferPhase` enum and `FileTransferState` class match design.md's data model
- [x] `advance(TransferEvent)` enforces valid transitions only (e.g. `available` is unreachable except from `validating` on a hash match; `failed` is terminal)
- [x] Unit tests cover every valid transition and at least one invalid-transition rejection per state (failure-modes-first, per CLAUDE.md Testing Rule 3: the failure list was written before this `Done when` item)
- [x] `flutter test test/domain/transfer` passes

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add FileTransferState guarded transfer state machine`

---

### T4: Create `LatencyEstimator`

**What**: Pure function turning a round-trip probe timestamp triple into a one-way delay estimate (`(receivedBackAtEpochMs - sentAtEpochMs) ~/ 2`).
**Where**: `lib/domain/playback/latency_estimator.dart`
**Depends on**: None
**Reuses**: Styled like `TimelineConverter`.
**Requirement**: SYNC-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `estimateOneWayDelayMs` implemented exactly as signed in design.md
- [x] Unit tests cover: zero RTT, typical LAN RTT (a few ms), and an asserted-invalid input (echoed-before-sent clock skew) handled per an explicit failure-modes list written before the test
- [x] `flutter test test/domain/playback` passes

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add LatencyEstimator for playback scheduling`

---

### T5: Create `RoomPlaybackSnapshot` / `PlaybackPhase`

**What**: Value type for a device's current playback phase (`idle`/`waiting`/`scheduled`/`playing`/`paused`) and the active song/scheduled-start, per design.md's Data Models section.
**Where**: `lib/domain/playback/room_playback_snapshot.dart`
**Depends on**: None
**Reuses**: Styled like `lib/domain/session/room_session_snapshot.dart`.
**Requirement**: SYNC-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `PlaybackPhase` enum and `RoomPlaybackSnapshot` class defined exactly per design.md
- [x] `flutter analyze` reports 0 new issues; `const` constructor per AD-006 where applicable

**Tests**: none (plain value type/enum — no behavior; same precedent as `RoomSessionSnapshot`, which also has no dedicated unit test file)
**Gate**: quick

**Commit**: `feat(domain): add RoomPlaybackSnapshot value type`

---

### T6: Define `AudioPlaybackEngine` domain interface

**What**: Abstract interface (`loadSong`, `playAt`, `pause`, `stop`, `seekAllTo`) that `MultiTrackAudioEngine` (Phase 5, infrastructure) will implement, and that `PlaybackCommandHandler` (Phase 4, data) depends on — so the data layer never imports `just_audio` directly. This refines design.md's component list: the design showed `PlaybackCommandHandler` depending on the concrete `MultiTrackAudioEngine`; this task interposes the same interface pattern the codebase already uses for `SongRepository`/`DriftSongRepository`, keeping data-layer tests plugin-free.
**Where**: `lib/domain/audio/audio_playback_engine.dart`
**Depends on**: None
**Reuses**: `SongRepository`'s interface-in-domain, implementation-in-data/infrastructure pattern (`lib/domain/repositories/song_repository.dart`).
**Requirement**: SYNC-01 (foundational — enables the testable split, no AC of its own)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Interface signatures match design.md's `MultiTrackAudioEngine` method list, with `Song` (domain entity) as the `loadSong` parameter type — no Flutter/plugin types in the signature
- [x] `python scripts/check_layers.py --root .` passes (zero violations)

**Tests**: none (interface only — behavior is tested through its implementations in T15 (fake) and T16 (real))
**Gate**: quick

**Commit**: `feat(domain): define AudioPlaybackEngine interface`

---

### T7: Create `RoomApplicationMessage` wire family

**What**: New tag-prefixed message family (`TransferBeginMessage`, `ChunkDataMessage`, `ChunkAckMessage`, `TransferCompleteMessage`, `PlayCommandMessage`, `PauseCommandMessage`, `StopCommandMessage`, `LoopRepositionMessage`, `LatencyProbeMessage`, `LatencyProbeReplyMessage`, `PlaybackSnapshotMessage`) carried inside `Envelope.payload`, encoded/decoded exactly like `SessionWireMessage`.
**Where**: `lib/data/session/room_application_message.dart`
**Depends on**: None
**Reuses**: `_withU16LenString`/`_readU16LenString` helper pattern from `lib/data/session/session_wire_message.dart` (extended with a `_withU32LenBytes`/`_readU32LenBytes` pair for the chunk-data payload).
**Requirement**: XFER-01, XFER-02 (wire shape for transfer); SYNC-02, SYNC-03, SYNC-05, SYNC-07, SYNC-08 (wire shape for playback commands)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] All 11 variants implement `encode()`/`decode()` round-trip
- [x] Unit tests cover every variant's round-trip, plus an unknown-tag and a truncated-body decode both rejected (mirrors `session_wire_message_test.dart`'s existing malformed-input coverage)
- [x] `flutter test test/data/session` passes

**Tests**: unit
**Gate**: quick

**Commit**: `feat(data): add RoomApplicationMessage wire protocol family`

---

### T8: Extend `RoomSessionController` with `applicationMessages` + master-side send helpers

**What**: Close the dispatch gap found during Design — after an inbound `EnvelopeMessage` passes `_authenticator.verify`/`acceptEnvelope`, decode its payload as a `RoomApplicationMessage` and publish `(senderId, payload)` on a new broadcast stream, on **both** the master dispatch path (`_handleMasterMessage`) and the visitor dispatch path (`_handleVisitorMessage`). Add the master-side `sendEnvelopeTo(ParticipantId, Uint8List, {requiresMasterRole})` and `broadcastEnvelope(Uint8List, {requiresMasterRole})`, symmetric to the existing visitor-side `sendEnvelope`.
**Where**: `lib/data/session/room_session_controller.dart` (modify)
**Depends on**: T7
**Reuses**: Existing per-connection sequence counters, `_connectionByParticipant`/`_participantByConnection` maps, existing `EnvelopeAuthenticator` calls — this is additive, not a rewrite.
**Requirement**: XFER-01, XFER-09; SYNC-05, SYNC-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `applicationMessages` stream emits only after successful envelope verification on both master and visitor paths; a bad-HMAC/replay/wrong-role envelope never reaches it (reuses the exact rejection paths Phase 3's `NET` tests already proved)
- [x] `sendEnvelopeTo`/`broadcastEnvelope` sign with the correct per-connection sequence and reach every currently-connected participant (broadcast) or exactly one (targeted)
- [x] Extended `test/data/session/room_session_controller_test.dart` covers: a verified payload surfaces on `applicationMessages`; a role-violating envelope does not; `broadcastEnvelope` reaches 2+ connected participants in a 3-device loopback scenario
- [x] `flutter test test/data/session` passes; full suite still green (`flutter test`)

**Tests**: E2E (loopback TCP, two/three real `RoomSessionController`s)
**Gate**: full

**Commit**: `feat(data): expose applicationMessages stream and master-side envelope send on RoomSessionController`

---

### T9: Create content-addressed library storage path resolver

**What**: Resolves the app-sandbox root for received files (`<app docs>/library/tracks/<sha256>.<ext>`), as the first real consumer of the already-declared `path_provider` dependency (AD-004). Takes the resolved root directory as an injected parameter so it's testable without faking platform channels.
**Where**: `lib/data/transfer/library_storage_paths.dart`
**Depends on**: None
**Reuses**: `path_provider` (already in `pubspec.yaml`).
**Requirement**: XFER-06, XFER-07

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `trackFilePath({required Directory root, required String sha256, required String extension})` returns the content-addressed path; a second call with the same hash returns the identical path (dedup is "same path" by construction)
- [x] `resolveLibraryRoot()` wraps `path_provider.getApplicationDocumentsDirectory()` and appends `library/tracks/`, creating the directory if absent
- [x] Unit test uses `Directory.systemTemp.createTempSync()` as the injected root (no platform-channel fake needed) to verify path shape and dedup-by-construction
- [x] `flutter test test/data/transfer` passes

**Tests**: unit
**Gate**: quick

**Commit**: `feat(data): add content-addressed library storage path resolver`

---

### T10: Create `ChunkedFileSender`

**What**: Master-side orchestration — reads a local track file, sends `TransferBeginMessage` then `ChunkDataMessage`s (64 KiB each) starting from a given resume index, waits for each `ChunkAckMessage` with bounded retry (5 attempts), sends `TransferCompleteMessage` when done.
**Where**: `lib/data/transfer/chunked_file_sender.dart`
**Depends on**: T2, T7, T8
**Reuses**: `ChunkPlanner`, `RoomApplicationMessage`, `RoomSessionController.sendEnvelopeTo`.
**Requirement**: XFER-01, XFER-02, XFER-03, XFER-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `sendTrack` sends exactly `ChunkPlanner.chunkCount(...) - resumeFromChunkIndex` chunks and emits a `Result.failure(NetworkFailure(code: 'transfer.chunk-delivery-failed'))` after 5 unACKed attempts on one chunk
- [x] E2E test (2 real loopback `RoomSessionController`s + a real temp file) covers: full send of a multi-chunk file, receiver ACKing every chunk in order
- [x] `flutter test test/data/transfer` passes

**Tests**: E2E
**Gate**: full

**Commit**: `feat(data): add ChunkedFileSender for master-side file transfer`

---

### T11: Create `ChunkedFileReceiver`

**What**: Participant-side orchestration — on `TransferBeginMessage`, opens a `.partial` file under the T9 storage root; on each `ChunkDataMessage`, writes it, ACKs it, tracks `lastAckedChunkIndex`; on completion, computes SHA-256 and either renames the file into its final content-addressed path (making it visible) or discards it and signals retry (bounded to 2 whole-track retries); aborts with `StorageFailure` on a write error (insufficient storage).
**Where**: `lib/data/transfer/chunked_file_receiver.dart`
**Depends on**: T3, T7, T8, T9
**Reuses**: `FileTransferState`, `RoomApplicationMessage`, `RoomSessionController.applicationMessages`, `crypto` package (SHA-256), T9's path resolver.
**Requirement**: XFER-05, XFER-06, XFER-07, XFER-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] A reassembled file whose SHA-256 matches the declared hash is renamed into its final path and never otherwise (hash-mismatch path never promotes a file — written and asserted before the happy-path test, per CLAUDE.md Testing Rule 3)
- [x] A hash mismatch triggers a fresh whole-track transfer up to 2 times, then surfaces `ValidationFailure(code: 'transfer.hash-mismatch')` and leaves no promoted file
- [x] A file whose SHA-256 already exists at the target path is detected before any bytes are written (dedup skip) — test asserts zero `ChunkDataMessage`-triggered writes occur for an already-present hash
- [x] A simulated write failure (e.g. injected via a wrapped `File` that throws on `writeAsBytes`) aborts the transfer with `StorageFailure(code: 'transfer.insufficient-storage')` without affecting any other in-flight transfer
- [x] E2E test (2 real loopback controllers + real temp dir) covers the full happy path end-to-end with T10's sender
- [x] `flutter test test/data/transfer` passes

**Tests**: E2E
**Gate**: full

**Commit**: `feat(data): add ChunkedFileReceiver with hash validation and dedup`

---

### T12: Wire resume-after-disconnect between `ChunkedFileSender` and `ChunkedFileReceiver`

**What**: On a fresh `TransferBeginMessage` for a track already partially received (a `.partial` file with a tracked `lastAckedChunkIndex` exists), the receiver reports its resume point back to the sender (reusing `ChunkAckMessage` for the last-known-good index) instead of restarting; the sender calls `ChunkPlanner.resumeFromChunkIndex` and continues from there.
**Where**: `lib/data/transfer/chunked_file_sender.dart`, `lib/data/transfer/chunked_file_receiver.dart` (both modified)
**Depends on**: T10, T11
**Reuses**: `ChunkPlanner.resumeFromChunkIndex` (T2).
**Requirement**: XFER-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] E2E test: start a transfer over a real loopback TCP connection, close the receiver's socket mid-transfer (simulating a Wi-Fi drop), reconnect within the test's simulated session, confirm the number of `ChunkDataMessage`s sent after reconnect is strictly less than the file's total chunk count, and the final reassembled file still hash-matches
- [x] `flutter test test/data/transfer` passes; full suite green

**Tests**: E2E
**Gate**: full

**Commit**: `feat(data): resume interrupted file transfers from the last ACKed chunk`

---

### T13: Create `SongSyncCoordinator`

**What**: Presentation-facing entry point — fans a song's tracks out to every currently-connected participant via `ChunkedFileSender`, rejecting (before any `TransferBeginMessage`) a track whose declared size exceeds `ChunkPlanner.exceedsMaxSize`, and queuing a second `syncSongToRoom` call if one is already in flight (one active song-transfer per room at a time, per spec).
**Where**: `lib/data/transfer/song_sync_coordinator.dart`
**Depends on**: T10, T11
**Reuses**: `RoomSessionController`'s `RoomSessionSnapshot` (participant list), `ChunkedFileSender`, `ChunkPlanner.exceedsMaxSize`.
**Requirement**: XFER-01, XFER-08, XFER-09 (plus the oversize Edge Case)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `syncSongToRoom` sends every track to every connected participant (not just one) in a 2+ participant E2E scenario
- [ ] A song with one track over 100 MB is rejected with `ValidationFailure(code: 'transfer.file-too-large')` before any chunk is sent (asserted via a zero-`ChunkDataMessage` check)
- [ ] Calling `syncSongToRoom` again while a transfer is in flight queues rather than interleaving — asserted by observing song B's transfer starts only after song A's completes
- [ ] `flutter test test/data/transfer` passes

**Tests**: E2E
**Gate**: full

**Commit**: `feat(data): add SongSyncCoordinator for room-wide file transfer orchestration`

---

### T14: Create `PlaybackCommandBroadcaster`

**What**: Master-side — on `play`/`pause`/`stop`/`repositionToLoopStart`, sends a `LatencyProbeMessage` to each connected participant, awaits `LatencyProbeReplyMessage`, computes each participant's scheduled epoch via `LatencyEstimator`, then sends that participant's `PlayCommandMessage`/etc. with its own `masterSendEpochMs`.
**Where**: `lib/data/playback/playback_command_broadcaster.dart`
**Depends on**: T4, T7, T8
**Reuses**: `LatencyEstimator`, `RoomApplicationMessage`, `RoomSessionController.sendEnvelopeTo`/`broadcastEnvelope`.
**Requirement**: SYNC-02, SYNC-04, SYNC-07, SYNC-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `play(songId)` on a 3-device loopback room produces a distinct `PlayCommandMessage` per participant, each carrying that participant's own latency-adjusted epoch
- [ ] `pause()`/`stop()`/`repositionToLoopStart()` follow the identical probe-then-command sequence
- [ ] A command sent with `requiresMasterRole: true` from a non-master device is rejected at the existing envelope gate (regression-style check reusing T8's coverage, not duplicating it — assert via the same rejection path)
- [ ] E2E test asserts the above using real loopback `RoomSessionController`s
- [ ] `flutter test test/data/playback` passes

**Tests**: E2E
**Gate**: full

**Commit**: `feat(data): add PlaybackCommandBroadcaster with latency-compensated scheduling`

---

### T15: Create `PlaybackCommandHandler`

**What**: Per-device — listens on `applicationMessages` for playback commands, schedules the call into the injected `AudioPlaybackEngine` (interface from T6, faked in this task's tests) at the message's target epoch, maintains a `RoomPlaybackSnapshot` (reacting to `PlaybackSnapshotMessage` on connect/reconnect by entering `waiting` instead of calling the engine if the room is already `playing`).
**Where**: `lib/data/playback/playback_command_handler.dart`
**Depends on**: T5, T6, T8, T14
**Reuses**: `RoomPlaybackSnapshot`, `AudioPlaybackEngine` (interface only — a fake implementation lives in the test file), `RoomSessionController.applicationMessages`.
**Requirement**: SYNC-01, SYNC-03, SYNC-05, SYNC-06, SYNC-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `snapshots` stream transitions `idle → scheduled → playing` on a received `PlayCommandMessage`, calling the fake engine's `playAt` at (approximately) the scheduled epoch
- [ ] A device connecting while another snapshot shows `playing` enters `waiting` and does **not** call the fake engine until the next `PlayCommandMessage`/`LoopRepositionMessage`
- [ ] A command arriving without having passed the role gate (simulated by bypassing T8's dispatch — i.e., injected directly) is not accepted as a trust boundary re-check (documents that this handler trusts the gate, per design.md's Tech Decisions — test asserts the handler has no independent role-checking code path to bypass)
- [ ] E2E test combines T14's broadcaster output with this handler across 3 real loopback devices and a fake `AudioPlaybackEngine` per device, asserting all three receive `playAt` calls with epochs within the expected latency-estimate spread
- [ ] `flutter test test/data/playback` passes; full suite green

**Tests**: E2E
**Gate**: full

**Commit**: `feat(data): add PlaybackCommandHandler with waiting-state late-join handling`

---

### T16: Implement `MultiTrackAudioEngine`

**What**: Infrastructure implementation of `AudioPlaybackEngine` using one `just_audio` `AudioPlayer` per track, applying `AudioMixCalculator.ownGain`/`choirGain` and `TimelineConverter`/`LoopController` for seek/loop targets. **Before writing any `just_audio` call, confirm the exact `AudioPlayer` API surface against the installed package version (`just_audio: ^0.9.39` per `pubspec.yaml`) by reading its source in the pub cache** — design.md flagged that this API was not independently re-verified during Design (Context7 was unavailable that session).
**Where**: `lib/infrastructure/audio/multi_track_audio_engine.dart`
**Depends on**: T6
**Reuses**: `AudioPlaybackEngine` interface, `AudioMixCalculator`, `LoopController`, `TimelineConverter` (all unchanged pure domain math).
**Requirement**: SYNC-01, SYNC-03, SYNC-04, SYNC-07

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Implements every `AudioPlaybackEngine` method; `package:just_audio` is imported nowhere else in the codebase (`check_layers.py` would also catch an accidental domain import, but this confirms the infra-only boundary by inspection)
- [ ] Device integration test (Phase 6, T18) is the verification vehicle — this task's "done" is compile-clean + manual smoke confirmation is deferred to T18, consistent with the plugin-backed row in the Test Coverage Matrix
- [ ] `flutter analyze` reports 0 new issues; `python scripts/check_layers.py --root .` still passes

**Tests**: e2e (deferred to T18's real-device integration_test — this task has no standalone `flutter test` coverage per the matrix, since `just_audio` requires platform channels unavailable there)
**Gate**: build

**Commit**: `feat(infrastructure): implement MultiTrackAudioEngine with just_audio`

---

### T17: Implement `BackgroundAudioHandler`

**What**: `audio_service`'s `BaseAudioHandler` implementation exposing one logical "song" MediaItem, delegating `play()`/`pause()`/`stop()` to `PlaybackCommandBroadcaster` (not directly to the engine) so a background/lock-screen tap goes through the same role-gated, latency-compensated path as an in-app tap. Catches `just_audio`'s audio-interruption callback and calls `MultiTrackAudioEngine.pause()` locally (no room-wide broadcast) on focus loss, surfacing `PlaybackFailure(code: 'audio.focus-lost')`. **Same API-verification caveat as T16** — confirm `audio_service: ^0.18.13`'s exact `BaseAudioHandler` surface against the installed package before implementing.
**Where**: `lib/infrastructure/audio/background_audio_handler.dart`
**Depends on**: T1, T14, T16
**Reuses**: `PlaybackFailure` (T1), `PlaybackCommandBroadcaster` (T14), `MultiTrackAudioEngine` (T16).
**Requirement**: BG-01, BG-02, BG-03, BG-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `play()`/`pause()`/`stop()` call into `PlaybackCommandBroadcaster`, not the engine directly (a visitor-role background tap is therefore rejected by the same gate as an in-app one — no separate check needed here)
- [ ] Focus-loss handling pauses locally only (verified in T18, not here — no platform channel under `flutter test`)
- [ ] `flutter analyze` reports 0 new issues; `python scripts/check_layers.py --root .` still passes

**Tests**: e2e (deferred to T18, same plugin constraint as T16)
**Gate**: build

**Commit**: `feat(infrastructure): implement BackgroundAudioHandler delegating to PlaybackCommandBroadcaster`

---

### T18: Real-device E2E for file transfer, sync playback, and background audio

**What**: `integration_test` suite run on a physical device (same pattern as Phase 3's `session_networking_test.dart`), exercising: a real multi-track transfer end-to-end against the real `MultiTrackAudioEngine`, a real play command producing audible/measurable playback start, and a real backgrounding + lock-screen control tap. **Honest scope note** (mirrors Phase 3's acknowledged NET-02 gap): the project currently has access to one physical device at a time per `.specs/STATE.md`'s AD-007/Handoff notes; the ≤100 ms cross-device delta (SYNC-03) cannot be measured with real hardware timing across *multiple* physical devices in this environment. This task measures what a single real device *can* prove (real engine load+play latency, real background continuation, real lock-screen control round-trip) and documents the multi-device timing gap explicitly in the task's result and in `validation.md`, the same way NET-02 was documented rather than silently skipped.
**Where**: `integration_test/file_transfer_and_sync_playback_test.dart`
**Depends on**: T16, T17
**Reuses**: Same `flutter test -d <device-id> integration_test/...` invocation pattern as Phase 3.
**Requirement**: all (vertical confirmation); explicitly flags the SYNC-03 multi-device measurement gap

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `flutter test -d <device-id> integration_test/file_transfer_and_sync_playback_test.dart` reports `All tests passed!` on a connected physical device
- [ ] Test log captures: real transfer completing with a hash-validated file in the library, real `playAt` producing audible output, real background continuation after screen lock, a lock-screen control tap pausing playback
- [ ] The multi-device timing limitation is written into the test file's doc comment and will be carried into `validation.md` by the Verifier

**Tests**: e2e (real device)
**Gate**: device

**Commit**: `test(e2e): verify file transfer and playback engine on real device`

---

### T19: Layer-purity close-out

**What**: Run the project's domain-purity gate against every file this feature added, fixing any violation before the feature is considered done.
**Where**: N/A (verification task, no new file)
**Depends on**: T18
**Reuses**: `scripts/check_layers.py` (AD-001).
**Requirement**: N/A — cross-cutting enforcement of AD-001, not a spec requirement

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `python scripts/check_layers.py --root .` exits 0
- [ ] `dart analyze lib/domain/` reports 0 issues
- [ ] `flutter analyze && flutter test` (full suite) both pass

**Tests**: none (verification-only task)
**Gate**: build

**Commit**: `chore: verify domain layer purity for file-transfer-and-sync-playback feature`

---

## Phase Execution Map

Phases run in sequence (Phase 1 → 2 → 3 → 4 → 5 → 6); within a phase, tasks execute in the order listed above. The diagram below is the authoritative, exhaustive set of real `Depends on` edges — every edge here has a matching `Depends on` entry in the Task Breakdown, and every non-`None` `Depends on` entry has a matching edge here (see Diagram-Definition Cross-Check).

```
T7 -> T8
T2 -> T10
T7 -> T10
T8 -> T10
T3 -> T11
T7 -> T11
T8 -> T11
T9 -> T11
T10 -> T12
T11 -> T12
T10 -> T13
T11 -> T13
T4 -> T14
T7 -> T14
T8 -> T14
T5 -> T15
T6 -> T15
T8 -> T15
T14 -> T15
T6 -> T16
T1 -> T17
T14 -> T17
T16 -> T17
T16 -> T18
T17 -> T18
T18 -> T19
```

T1, T2, T3, T4, T5, T6, and T9 have no incoming edges (`Depends on: None`) — they are each other's phase-mates by grouping only, not by data dependency. Execution is strictly sequential — there is no intra-phase parallelism.

**Batching (19 tasks → ~3 workers of ~7, whole phases only):**
- Batch 1: Phase 1 + Phase 2 (T1–T8, 8 tasks)
- Batch 2: Phase 3 + Phase 4 (T9–T15, 7 tasks)
- Batch 3: Phase 5 + Phase 6 (T16–T19, 4 tasks)

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Add PlaybackFailure | 1 class, 1 file | ✅ Granular |
| T2: ChunkPlanner | 1 class, 1 file | ✅ Granular |
| T3: FileTransferState | 1 class + 1 enum, 1 file | ✅ Granular |
| T4: LatencyEstimator | 1 class, 1 file | ✅ Granular |
| T5: RoomPlaybackSnapshot | 1 class + 1 enum, 1 file | ✅ Granular |
| T6: AudioPlaybackEngine interface | 1 interface, 1 file | ✅ Granular |
| T7: RoomApplicationMessage family | 1 cohesive file, 1 wire protocol | ✅ Granular (mirrors `session_wire_message.dart`'s existing multi-variant-in-one-file precedent) |
| T8: RoomSessionController extension | 1 file modified, 1 cohesive gap fix (stream + symmetric send helpers) | ✅ Granular |
| T9: Storage path resolver | 1 file | ✅ Granular |
| T10: ChunkedFileSender | 1 class, 1 file | ✅ Granular |
| T11: ChunkedFileReceiver | 1 class, 1 file | ✅ Granular |
| T12: Resume wiring | 2 files, 1 cohesive behavior (sender+receiver handshake for one feature) | ✅ Granular (2 files but one indivisible protocol behavior) |
| T13: SongSyncCoordinator | 1 class, 1 file | ✅ Granular |
| T14: PlaybackCommandBroadcaster | 1 class, 1 file | ✅ Granular |
| T15: PlaybackCommandHandler | 1 class, 1 file | ✅ Granular |
| T16: MultiTrackAudioEngine | 1 class, 1 file | ✅ Granular |
| T17: BackgroundAudioHandler | 1 class, 1 file | ✅ Granular |
| T18: Real-device E2E | 1 test file | ✅ Granular |
| T19: Layer-purity close-out | 0 new files, verification only | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | (no incoming edge) | ✅ Match |
| T2 | None | (no incoming edge) | ✅ Match |
| T3 | None | (no incoming edge) | ✅ Match |
| T4 | None | (no incoming edge) | ✅ Match |
| T5 | None | (no incoming edge) | ✅ Match |
| T6 | None | (no incoming edge) | ✅ Match |
| T7 | None | (no incoming edge) | ✅ Match |
| T8 | T7 | `T7 -> T8` | ✅ Match |
| T9 | None | (no incoming edge) | ✅ Match |
| T10 | T2, T7, T8 | `T2 -> T10`, `T7 -> T10`, `T8 -> T10` | ✅ Match |
| T11 | T3, T7, T8, T9 | `T3 -> T11`, `T7 -> T11`, `T8 -> T11`, `T9 -> T11` | ✅ Match |
| T12 | T10, T11 | `T10 -> T12`, `T11 -> T12` | ✅ Match |
| T13 | T10, T11 | `T10 -> T13`, `T11 -> T13` | ✅ Match |
| T14 | T4, T7, T8 | `T4 -> T14`, `T7 -> T14`, `T8 -> T14` | ✅ Match |
| T15 | T5, T6, T8, T14 | `T5 -> T15`, `T6 -> T15`, `T8 -> T15`, `T14 -> T15` | ✅ Match |
| T16 | T6 | `T6 -> T16` | ✅ Match |
| T17 | T1, T14, T16 | `T1 -> T17`, `T14 -> T17`, `T16 -> T17` | ✅ Match |
| T18 | T16, T17 | `T16 -> T18`, `T17 -> T18` | ✅ Match |
| T19 | T18 | `T18 -> T19` | ✅ Match |

No task depends on a later-phase task; every `Depends on` resolves to an earlier or same-phase task.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: PlaybackFailure | Entity/config | none | none | ✅ OK |
| T2: ChunkPlanner | Domain pure logic | unit | unit | ✅ OK |
| T3: FileTransferState | Domain pure logic | unit | unit | ✅ OK |
| T4: LatencyEstimator | Domain pure logic | unit | unit | ✅ OK |
| T5: RoomPlaybackSnapshot | Entity/config | none | none | ✅ OK |
| T6: AudioPlaybackEngine | Interface | none | none | ✅ OK |
| T7: RoomApplicationMessage | Wire protocol | unit | unit | ✅ OK |
| T8: RoomSessionController extension | Data session integration | E2E | E2E | ✅ OK |
| T9: Storage path resolver | Data (file transfer) | E2E (matrix row) — but this sub-piece is pure path math with no network behavior | unit | ✅ OK (uses the HIGHEST-required-type rule's inverse correctly: this task creates no network-facing behavior, only a helper later tasks compose into the E2E-tested layer; its own unit test exceeds the "none" floor, and the composed behavior is E2E-tested in T10/T11/T13) |
| T10: ChunkedFileSender | Data file transfer | E2E | E2E | ✅ OK |
| T11: ChunkedFileReceiver | Data file transfer | E2E | E2E | ✅ OK |
| T12: Resume wiring | Data file transfer | E2E | E2E | ✅ OK |
| T13: SongSyncCoordinator | Data file transfer | E2E | E2E | ✅ OK |
| T14: PlaybackCommandBroadcaster | Data playback | E2E | E2E | ✅ OK |
| T15: PlaybackCommandHandler | Data playback | E2E | E2E | ✅ OK |
| T16: MultiTrackAudioEngine | Plugin-backed infrastructure | e2e (real device) | e2e (deferred to T18) | ✅ OK |
| T17: BackgroundAudioHandler | Plugin-backed infrastructure | e2e (real device) | e2e (deferred to T18) | ✅ OK |
| T18: Real-device E2E | Plugin-backed infrastructure | e2e (real device) | e2e (real device) | ✅ OK |
| T19: Layer-purity close-out | Verification only | — | none | ✅ OK |

No violations. T9 is the one row worth a second look: it sits inside the "File transfer" matrix row (E2E) but is pure path-string math with an injected directory, so it gets its own unit test (exceeding the floor) while the network-facing behavior it supports is E2E-tested where that behavior actually lives (T10/T11/T13) — this is "merge forward" territory handled by placement, not by deferring a test.

---

## MCPs and Skills

No project or user MCP servers are configured for this session beyond the ones already declared unavailable (`context7` needs auth, `context-mode` failed to connect). Every task above lists `MCP: NONE`. No additional skill beyond `tlc-spec-driven` itself is needed per task — the flutter-specific skills already available (`flutter-clean-architecture`, `flutter-quality-gates`, `flutter-widget-performance`) are not presentation-layer tasks here, but worth invoking if a worker drifts on layer placement (`flutter-clean-architecture`) or before the final gate (`flutter-quality-gates`).
