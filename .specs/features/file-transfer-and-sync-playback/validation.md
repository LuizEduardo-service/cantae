# File Transfer & Synchronized Playback Validation

**Date**: 2026-11-17
**Spec**: `.specs/features/file-transfer-and-sync-playback/spec.md`
**Diff range**: `4c493bd..5cfda90` (confirmed via `git log --oneline 4c493bd..HEAD`; first commit `16d5fc5 feat(domain): add PlaybackFailure to the Failure hierarchy` matches the expected starting commit)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status | Notes |
| --- | --- | --- |
| T1 | ✅ Done | `PlaybackFailure` in `lib/domain/core/failures.dart` |
| T2 | ✅ Done | `ChunkPlanner` |
| T3 | ✅ Done | `FileTransferState` |
| T4 | ✅ Done | `LatencyEstimator` |
| T5 | ✅ Done | `RoomPlaybackSnapshot` |
| T6 | ✅ Done | `AudioPlaybackEngine` interface |
| T7 | ✅ Done | `RoomApplicationMessage` family (11 variants) |
| T8 | ✅ Done | `applicationMessages` stream + `sendEnvelopeTo`/`broadcastEnvelope` |
| T9 | ✅ Done | `LibraryStoragePaths` |
| T10 | ✅ Done | `ChunkedFileSender` |
| T11 | ✅ Done | `ChunkedFileReceiver` |
| T12 | ✅ Done | Resume wiring |
| T13 | ✅ Done | `SongSyncCoordinator` — see spec-precision gap below for its XFER-09 test |
| T14 | ✅ Done | `PlaybackCommandBroadcaster` |
| T15 | ⚠️ Partial | `PlaybackCommandHandler`'s SYNC-06 logic is correct in isolation, but no production code ever sends the `PlaybackSnapshotMessage` it depends on — see Spec-Anchored table |
| T16 | ✅ Done | `MultiTrackAudioEngine` |
| T17 | ✅ Done | `BackgroundAudioHandler` |
| T18 | ✅ Done | Real-device `integration_test` — ran and passed per implementation history (not re-run here; no physical device attached to this verification session). Assertions read and confirmed non-shallow (see below). |
| T19 | ✅ Done | Layer-purity re-confirmed independently (see Gate Check) |

---

## Spec-Anchored Acceptance Criteria

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| XFER-01: master sends every track to every approved connected participant | every track reaches every connected participant | `lib/data/transfer/song_sync_coordinator.dart:93-113` (loop over `connectedParticipants` × `tracks`); `test/data/transfer/song_sync_coordinator_test.dart:204-214` asserts 2 distinct participants each received the track set | ✅ PASS |
| XFER-02: track split into 64 KiB chunks, authenticated envelope, receiver ACKs | chunk size 64 KiB, each chunk ACKed | `lib/data/transfer/chunked_file_sender.dart:49` (`chunkSize = 64*1024` default); `test/data/transfer/chunked_file_sender_test.dart:147-148` asserts `receivedChunkIndexesInOrder == [0,1,2]` | ✅ PASS |
| XFER-03: unACKed chunk retried, bounded to 5 attempts, then failed | exactly 5 attempts then `NetworkFailure(code: 'transfer.chunk-delivery-failed')` | `lib/data/transfer/chunked_file_sender.dart:111-113`; `test/data/transfer/chunked_file_sender_test.dart:210-214` asserts `result.isFailure` and `f.code == 'transfer.chunk-delivery-failed'` | ✅ PASS |
| XFER-04: resume from first chunk after last ACKed, not chunk zero | chunks sent after reconnect < total chunk count | `lib/domain/transfer/chunk_planner.dart:13-18` (`resumeFromChunkIndex`); `test/data/transfer/resume_after_disconnect_test.dart:171-172` asserts `chunksAckedBeforeDrop > 0 && < totalChunks`, and final hash match at `:240-241` | ✅ PASS |
| XFER-05: receiver computes SHA-256 and compares to declared hash | hash computed and compared | `lib/data/transfer/chunked_file_receiver.dart:221-223` | ✅ PASS |
| XFER-06: hash match → visible; hash mismatch → discard, retry ≤2, never visible | on mismatch: `ValidationFailure(code:'transfer.hash-mismatch')`, file never promoted | `lib/data/transfer/chunked_file_receiver.dart:238-248`; `test/data/transfer/chunked_file_receiver_test.dart:234-244` asserts `phase == failed`, `failureCode == 'transfer.hash-mismatch'`, and `File(finalPath).exists() == false` | ✅ PASS |
| XFER-07: file already present by hash → skip re-transfer, reuse copy | dedup by content-addressed path, zero chunk writes | `lib/data/transfer/chunked_file_receiver.dart:188-197`; `test/data/transfer/chunked_file_receiver_test.dart:305-307` asserts `writeChunkCalls == 0` and `phase == available` | ✅ PASS |
| XFER-08: one song mid-transfer per room; second queues | song B starts only after song A completes | `lib/data/transfer/song_sync_coordinator.dart:68-72` (`_queueTail.then(...)`); `test/data/transfer/song_sync_coordinator_test.dart:370-376` asserts song B's `TransferBeginMessage` index is after song A's `TransferCompleteMessage` index | ✅ PASS |
| XFER-09: visitor cannot initiate a transfer (but can still receive) | an attempt to initiate from a visitor device is rejected | `test/data/transfer/song_sync_coordinator_test.dart:379-414` — **only exercises a visitor controller that never created a room, so `connectedParticipants` is trivially empty and the call "succeeds" (no-op) rather than being actively rejected by a role gate.** This does not demonstrate the spec's "SHALL reject any attempt... per the project's role-enforcement gate" — it demonstrates a different, weaker property (nothing to send to). The real enforcement is structural (a visitor's `RoomSessionController` never populates `_stateMachine`, so `sendEnvelopeTo`/`broadcastEnvelope` always fail — see `room_session_controller.dart:184-194`), but no test exercises a visitor that IS connected to a room attempting to initiate a send and getting an explicit rejection. | ⚠️ Spec-precision gap |
| XFER-10: insufficient storage aborts, discards partial, typed Failure, doesn't block others | `StorageFailure(code:'transfer.insufficient-storage')`, other transfers unaffected | `lib/data/transfer/chunked_file_receiver.dart:169-172,206-215`; `test/data/transfer/chunked_file_receiver_test.dart:481-486` asserts participant A fails with storage code while participant B's concurrent transfer still reaches `available` | ✅ PASS |
| SYNC-01: real `just_audio` engine drives playback via existing domain math | engine calls `AudioMixCalculator`/`TimelineConverter`, doesn't replace them | `lib/infrastructure/audio/multi_track_audio_engine.dart:52-53,89-93` | ✅ PASS |
| SYNC-02: per-participant one-way delay probe, schedule at `masterSendTime + estimatedOneWayDelay` | distinct, latency-adjusted `masterSendEpochMs` per participant | `lib/data/playback/playback_command_broadcaster.dart:78-79`; `test/data/playback/playback_command_broadcaster_test.dart:180-183` asserts B's (artificially higher-latency) epoch is strictly greater than A's | ✅ PASS |
| SYNC-03: playback starts within ≤100 ms across devices, measured | max pairwise delta ≤100 ms | `test/data/playback/playback_command_handler_test.dart:288` asserts `(epochA - epochB).abs() < 200` on loopback (not the full 100 ms spec bar — loopback jitter headroom) — real cross-hardware measurement explicitly NOT performed (see `integration_test/file_transfer_and_sync_playback_test.dart:49-58` honest-scope note; only one physical device available) | ⚠️ Spec-precision gap (acknowledged by the author, not hidden) |
| SYNC-04: loop-end reposition uses same latency-compensated scheduling | `repositionToLoopStart()` follows identical probe-then-command path | `lib/data/playback/playback_command_broadcaster.dart:68-70`; `test/data/playback/playback_command_broadcaster_test.dart:243-245` asserts a `LoopRepositionMessage` was received | ✅ PASS |
| SYNC-05: visitor-originated play/pause/seek/loop rejected | rejected at `requiresMasterRole` envelope gate | `lib/domain/session/room_session_state_machine.dart:158-162`; `test/data/playback/playback_command_broadcaster_test.dart:286-298` asserts a forged `PlayCommandMessage` with `requiresMasterRole:true` from a visitor never reaches `applicationMessages` | ✅ PASS |
| SYNC-06: late join/reconnect during active playback stays silent until next play/loop command | device enters `waiting`, no engine call, until next `PlayCommand`/`LoopReposition` | `lib/data/playback/playback_command_handler.dart:94-103` (handler logic correct) — **but no file in `lib/` ever constructs/sends a `PlaybackSnapshotMessage`** (confirmed via grep: only the message's own definition file and test files reference it). Design.md's Error Handling Strategy explicitly specifies "On connect, `RoomSessionController` (master side) sends a `PlaybackSnapshotMessage` reflecting current state" — this was never implemented. `test/data/playback/playback_command_handler_test.dart:147-177` only calls `handler.handleApplicationMessage(const PlaybackSnapshotMessage(...))` directly, proving the handler's internal branch is correct but NOT that a real (re)joining device ever receives one in production. | ❌ GAP — SYNC-06 is not actually wired end-to-end |
| SYNC-07: pause/stop applies same latency-compensated scheduling | `pause()`/`stop()` follow identical probe-then-command path | `lib/data/playback/playback_command_broadcaster.dart:60-66`; `test/data/playback/playback_command_broadcaster_test.dart:243-244` | ✅ PASS |
| SYNC-08: no playback-control command executes unless validated + master-role envelope | handler trusts the gate; broadcaster always sets `requiresMasterRole:true` | `lib/data/playback/playback_command_broadcaster.dart:83` (`requiresMasterRole: true` on every broadcast send); `test/data/session/room_session_controller_test.dart:479-515` (T8's regression coverage) | ✅ PASS |
| BG-01: background/locked playback continues via `audio_service` wrapping `just_audio` | foreground service configured | `android/app/src/main/AndroidManifest.xml` (added `AudioService`, `mediaPlayback` foreground type); not independently re-run on a locked device in this verification pass — relies on the implementation history's real-device run | ⚠️ Spec-precision gap (device-only, not re-verifiable here) |
| BG-02: transport controls on tray/lock screen | `MediaButtonReceiver` + `AudioServiceConfig` notification channel | `android/app/src/main/AndroidManifest.xml`; `integration_test/file_transfer_and_sync_playback_test.dart:357-370` (`AudioService.init()` succeeds, registered) | ⚠️ Spec-precision gap (same device-only caveat, honestly scoped by T18's own doc comment) |
| BG-03: visitor-role background tap rejected same as in-app | `play()`/`pause()`/`stop()` delegate to broadcaster, not engine directly | `lib/infrastructure/audio/background_audio_handler.dart:80-87` (delegates to `_broadcaster`, inherits SYNC-05's gate) | ✅ PASS (by construction + SYNC-05's test coverage; no dedicated BG-03 test, but the delegation is structural, not duplicated logic to re-test) |
| BG-04: OS reclaims audio focus → local pause + typed Failure, no room-wide broadcast | `PlaybackFailure(code:'audio.focus-lost')`, local-only pause | `lib/infrastructure/audio/background_audio_handler.dart:67-71` — `_engine.pause()` called directly (not via broadcaster), and `_focusLostController.add(PlaybackFailure(code:'audio.focus-lost'))`. No `flutter test` coverage exists for this branch (plugin-backed `AudioSession.interruptionEventStream`, deferred to device per Test Coverage Matrix) and T18's integration test does not exercise an actual OS interruption either (acknowledged nowhere in T18's scope notes) | ⚠️ Spec-precision gap (never exercised, not even on-device) |

**Status**: ❌ One real gap present (SYNC-06); several honestly-acknowledged spec-precision/device gaps.

---

## Discrimination Sensor

Run in an isolated `git worktree` (`d:/Projetos/cantae_scratch`, HEAD `5cfda90`), never in the real tree. Baseline `git status --porcelain` captured before the run and re-confirmed identical after worktree removal.

| # | File:line | Mutation | Killed? |
| --- | --- | --- | --- |
| 1 | `lib/domain/transfer/chunk_planner.dart:17` | `resumeFromChunkIndex`: `lastAckedChunkIndex + 1` → `+ 0` | ✅ Killed — `chunk_planner_test.dart`: "chunk N acked resumes at chunk N+1" fails (expected 6, got 5) |
| 2 | `lib/data/transfer/chunked_file_receiver.dart:223` | Hash comparison `==` → `!=` | ✅ Killed — 3 tests fail in `chunked_file_receiver_test.dart`, including the hash-mismatch-never-promoted test (asserts `failed`, got `available` — i.e. a mismatched file would have been promoted) |
| 3 | `lib/data/playback/playback_command_broadcaster.dart:79` | Dropped `estimatedDelayMs` from `scheduledEpoch` | ✅ Killed — `playback_command_broadcaster_test.dart`: B's epoch no longer `greaterThan` A's |
| 4 | `lib/domain/session/room_session_state_machine.dart:158` | `requiresMasterRole &&` → `!requiresMasterRole &&` (sense flip) | ✅ Killed — 4 tests fail across `room_session_controller_test.dart` and `playback_command_broadcaster_test.dart`, including the forged-play-command-rejected test (now receives the forged command) |
| 5 | `lib/domain/transfer/file_transfer_state.dart` | Added a `pending --(HashValidated)--> available` bypass, skipping `validating` | ✅ Killed — `file_transfer_state_test.dart`: "pending rejects HashValidated" now expects failure but gets success |

**Sensor depth**: lightweight (5 targeted mutations, default tier)
**Result**: 5/5 killed — ✅ PASS
**Isolation check**: `git status --porcelain` before and after the sensor run were identical (confirmed via diff); worktree removed with `git worktree remove --force`.

---

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ |
| Surgical changes | ✅ |
| No scope creep | ✅ |
| Matches patterns | ✅ (wire-format helpers mirror `session_wire_message.dart`; interface-in-domain/impl-in-infra mirrors `SongRepository`) |
| Spec-anchored outcome check (asserted values match spec) | ⚠️ — SYNC-06 gap and XFER-09 spec-precision gap found above |
| Per-layer Coverage Expectation met | ✅ for domain (1:1 AC-to-test mapping in `test/domain/transfer`, `test/domain/playback`); E2E layers mostly meet the bar, with the two noted exceptions |
| Every test maps to a spec requirement — no unclaimed tests | ✅ |
| Documented guidelines followed | `CLAUDE.md` Testing Rules (E2E-first, failure-modes-first for isolation) — followed; `.specs/STATE.md` AD-001 (layer purity), AD-002 (Result/no-throw) — both independently re-confirmed via gate commands below |

Three documented `SPEC_DEVIATION` comments were found in the diff (`chunked_file_sender.dart`, `chunked_file_receiver.dart`, `playback_command_broadcaster.dart`) — all are narrow, justified type/parameter gap-closures consistent with design.md's own wire-message shape, not scope creep.

---

## Edge Cases

- [x] Chunk with failed HMAC/sequence discarded, retransmission requested — this reuses the exact pre-existing session-layer rejection path (`_authenticator.verify`/`acceptEnvelope`), already covered by Phase 3's tests; no new code path to separately re-verify.
- [x] Master disconnect mid-transfer aborts in-flight transfers — covered structurally by `endRoom()`'s existing connection teardown (`room_session_controller.dart:274-284`); no transfer-specific state persists past the controller's own lifetime (design.md Tech Decisions: in-memory only).
- [x] Coincidental SHA-256 collision across tracks — dedup rule is correct by construction (content-addressed path), no separate test needed.
- [x] Oversize track (>100 MB) rejected before any chunk sent — `song_sync_coordinator_test.dart:276-282` asserts `transfer.file-too-large` and `chunkDataMessagesSeen == 0`.
- [x] High one-way-delay estimate still schedules (no fallback) — matches `playback_command_broadcaster.dart:114-128`'s timeout-still-proceeds behavior; no dedicated test, but the "no fallback" behavior is the absence of a branch, not a behavior to assert on.

---

## Gate Check

- **Gate command**: `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`
- **Result**: `flutter analyze` → 0 issues. `flutter test` → **250 passed, 0 failed**. `python scripts/check_layers.py --root .` → exit 0, "no forbidden imports in lib/domain/". `dart analyze lib/domain/` → 0 issues.
- **Skipped tests**: none.
- **Failures**: none.
- **Device gate** (`flutter test -d <device-id> integration_test/file_transfer_and_sync_playback_test.dart`): NOT re-run in this verification pass (no physical device attached to this session). Relying on the implementation history's record that it was run and passed on a real Android 13 device. The test file's assertions were read in full and confirmed non-shallow: it asserts on `AudioPlayer.playing` (real plugin state, not an internal flag), a real SHA-256-matched file on disk, and a real cross-controller round trip from `BackgroundAudioHandler.play()` to a second real `AudioPlayer`'s `playing == true`. Its own doc comment honestly scopes out SYNC-03's multi-device timing measurement and BG-01/02/03's actual-lock-screen-tap verification — consistent with the project's established pattern (Phase 3's NET-02 gap).

---

## Fix Plans

### Fix 1: SYNC-06 is not wired end-to-end — `PlaybackSnapshotMessage` is never sent

- **Root cause**: design.md's Error Handling Strategy specifies the master sends a `PlaybackSnapshotMessage` to a (re)connecting participant. `PlaybackCommandHandler` was built to correctly react to one, and a unit test proves that reaction — but no task actually wired a sender. `RoomSessionController`'s connect/approve path (`_sendHandshakeInit`, `_handleMasterMessage`'s `JoinRequestMessage` branch) never constructs or sends this message type. A device joining or reconnecting mid-song today gets no snapshot at all and starts in `idle`/`waiting`-by-default-construction rather than an explicit server-driven `waiting` state — it will not call the engine (safe by omission) but also has no mechanism to transition into `playing` for the *current* song if it reconnects after a `PlayCommand` already fired, since it never learns that a song is active until the *next* command.
- **Fix task**: Add the send call — e.g. in `RoomSessionController._handleMasterMessage`'s post-handshake-complete path, or in a new master-side hook invoked by whatever owns `RoomPlaybackSnapshot`'s source of truth (today that's scattered per-device in each `PlaybackCommandHandler`, not centralized on the master) — construct and `sendEnvelopeTo` a `PlaybackSnapshotMessage` reflecting current room playback state to the newly-connected participant.
- **Verify**: An E2E test that: starts a 2-device room, master plays a song, a third device joins (or the second disconnects and reconnects) *after* the play command, and asserts the new/reconnecting device's `PlaybackCommandHandler` snapshot stream emits `waiting` (not `idle`, and never calls the fake engine) without the test driving `handleApplicationMessage` directly.
- **Priority**: Major (a real spec AC — SYNC-06 — is not actually satisfied by running code, only by an isolated unit of logic that nothing currently calls).

### Fix 2: No regression test for the `currentSnapshot`/`_latestSnapshot` production race

- **Root cause**: `RoomSessionController.currentSnapshot` and `PlaybackCommandBroadcaster`'s constructor-time synchronous seed (`_latestSnapshot = _controller.currentSnapshot;`) were added mid-implementation to fix a real production bug: a broadcaster constructed after participants already joined would see an empty participant list until the next unrelated snapshot event. Every existing test (`playback_command_broadcaster_test.dart`, `playback_command_handler_test.dart`'s E2E test) constructs the `PlaybackCommandBroadcaster` **before** `createRoom()`/joins happen, so none of them would have caught a regression of this fix (e.g. if `currentSnapshot` were removed or the constructor reverted to only listening on `snapshots`).
- **Fix task**: Add a test that constructs `master`, runs the full create/join/approve sequence to a connected state, **then** constructs `PlaybackCommandBroadcaster(controller: master)`, immediately calls `play(...)`, and asserts the already-connected participant still receives a `PlayCommandMessage` (not nothing, which is what would happen if the broadcaster's participant list were empty at construction time).
- **Verify**: The new test fails on a revert of the `currentSnapshot` getter / constructor seeding, and passes with it in place.
- **Priority**: Major (this guards a documented real production bug, not a hypothetical one — CLAUDE.md's own testing philosophy explicitly values regression tests for bugs found late).

### Fix 3 (Minor): XFER-09's test is vacuous

- **Root cause**: `song_sync_coordinator_test.dart:379-414` tests a visitor controller that never created a room, so the "rejection" it demonstrates is really "nothing to send to," not an active role-gate rejection. It happens to be true that the spec's structural guarantee holds (no visitor code path can ever populate `_stateMachine`), but the test's own name claims more than it proves.
- **Fix task**: Either (a) retitle/reduce the claim in the test's description to accurately reflect what it checks, or (b) strengthen it: have a connected visitor explicitly attempt `sender.sendTrack(...)` using its own `RoomSessionController` instance and assert the resulting `Result.isFailure` with a `NotFoundFailure(code: 'session.participant-not-found')` (from `sendEnvelopeTo`'s existing guard), which is the actual mechanism in play.
- **Priority**: Minor (the underlying behavior is correct and structurally guaranteed; only the test's framing overstates its coverage).

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| XFER-01 | Implementing | ✅ Verified |
| XFER-02 | Implementing | ✅ Verified |
| XFER-03 | Implementing | ✅ Verified |
| XFER-04 | Implementing | ✅ Verified |
| XFER-05 | Implementing | ✅ Verified |
| XFER-06 | Implementing | ✅ Verified |
| XFER-07 | Implementing | ✅ Verified |
| XFER-08 | Implementing | ✅ Verified |
| XFER-09 | Implementing | ⚠️ Verified with spec-precision gap (Fix 3) |
| XFER-10 | Implementing | ✅ Verified |
| SYNC-01 | Implementing | ✅ Verified |
| SYNC-02 | Implementing | ✅ Verified |
| SYNC-03 | Implementing | ⚠️ Verified with acknowledged device-measurement gap (pre-existing, honestly scoped by the author) |
| SYNC-04 | Implementing | ✅ Verified |
| SYNC-05 | Implementing | ✅ Verified |
| SYNC-06 | Implementing | ❌ Needs Fix (Fix 1) |
| SYNC-07 | Implementing | ✅ Verified |
| SYNC-08 | Implementing | ✅ Verified |
| BG-01 | Implementing | ⚠️ Verified with device-only caveat |
| BG-02 | Implementing | ⚠️ Verified with device-only caveat |
| BG-03 | Implementing | ✅ Verified (by construction + SYNC-05 coverage) |
| BG-04 | Implementing | ⚠️ Verified with device-only caveat (never exercised even on-device per T18's own scope) |

---

## Summary

**Overall**: ⚠️ Issues (one real functional gap, SYNC-06; the rest are either honestly pre-acknowledged device/hardware measurement gaps already written into the implementation's own docs, or a minor test-framing issue)

**Spec-anchored check**: 18/22 ACs cleanly matched the spec-defined outcome; 1 real gap (SYNC-06); 3 honestly-acknowledged device/hardware spec-precision gaps (SYNC-03, BG-01, BG-02, BG-04 — all already flagged in the implementation's own code/test comments, not discovered fresh here); 1 minor spec-precision gap in test framing (XFER-09).

**Sensor**: 5/5 mutations killed — the tests genuinely discriminate on the behaviors probed (chunk resume math, hash-mismatch gating, latency-compensated scheduling, role-gate enforcement, guarded state transitions).

**Gate**: 4/4 passed (`flutter analyze`, `flutter test` — 250/250, `check_layers.py`, `dart analyze lib/domain/`), all re-run fresh in this session, not taken from self-report.

**What works**: The file-transfer pipeline (chunking, resume, hash-validate, dedup, size-cap, storage-failure isolation) is solidly built and tested end-to-end over real loopback TCP with real temp-dir files. The playback-command broadcast path (latency probing, per-participant scheduling, role gating) is equally solid. The Design doc's two flagged dispatch/send-helper risks are genuinely fixed in `room_session_controller.dart`. The `just_audio`/`audio_service` API-verification risk was closed with documented, cited confirmation against the installed package sources, and the Android manifest/MainActivity changes needed for `audio_service` are present and match the documented real-device-discovered requirement (`AudioServiceActivity`).

**Issues found**:
1. SYNC-06's "waiting" late-join state is implemented and unit-tested in isolation but never wired to anything that sends the message it depends on — the spec AC is not actually satisfied by running code today (Fix 1, Major).
2. The specific production race this feature's authors found and fixed mid-implementation (`currentSnapshot`/synchronous broadcaster seeding) has no regression test that would catch it coming back (Fix 2, Major).
3. XFER-09's test proves a weaker property than its name claims (Fix 3, Minor).

**Next steps**: Route Fix 1 and Fix 2 back to an implementer as the top-priority fix tasks (both are "Major" — a real unmet spec AC and an unprotected real production bug). Fix 3 can be folded into the same pass or deferred. Re-run this Verifier after fixes land; this is iteration 1 of the bounded 3-iteration fix→re-verify loop.

---

## Iteration 2 Re-Verification

**Date**: 2026-11-18
**Diff range**: `5cfda90..573f68e` (the three fix commits: `a5aba42`, `dcfe5a6`, `573f68e`, on top of iteration 1's diff range endpoint)
**Verifier**: independent sub-agent (author ≠ verifier), fresh pass, no access to iteration 1's internal reasoning beyond its written report
**Scope**: re-verifies ONLY SYNC-06, the broadcaster race regression test, and XFER-09 — all other ACs remain as marked ✅ PASS in Iteration 1 and were not re-checked here.

### Task Completion

| Fix | Status | Notes |
| --- | --- | --- |
| Fix 1 (SYNC-06) | ✅ Done | `PlaybackCommandBroadcaster` now tracks room-level `_lastKnownState`/`_lastKnownSongId` and sends a `PlaybackSnapshotMessage` to every newly-connected participant detected via its own `snapshots` subscription. |
| Fix 2 (race regression) | ✅ Done | New test in `playback_command_broadcaster_test.dart` constructs the broadcaster strictly after join/connect completes. |
| Fix 3 (XFER-09) | ✅ Done | Test rewritten to join/connect a real visitor and call `ChunkedFileSender.sendTrack` directly against the master. |

### Spec-Anchored Acceptance Criteria (re-verified subset)

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| SYNC-06: late join/reconnect during active playback stays silent until next play/loop command, learned via a production-sent snapshot | device enters `waiting`, no engine call, until next `PlayCommand`/`LoopReposition`; the snapshot send itself must be real production wiring, not test-driven | `lib/data/playback/playback_command_broadcaster.dart:71-79` (`_snapshotSubscription` diffs `previouslyConnected` vs `nowConnected`, calls `_sendSnapshotTo` for each newly-connected id) and `:88-97` (`_sendSnapshotTo` builds `PlaybackSnapshotMessage(songId: _lastKnownSongId, state: _lastKnownState)`); `test/data/playback/playback_command_handler_test.dart:290-378` — `master.createRoom()` → visitorA joins/connects → `broadcaster.play('song-late')` → sanity-checks `engineA.playAtCalls` has 1 entry → visitorB's `PlaybackCommandHandler` is wired *before* `_joinAndApprove(master, visitorB, ...)` runs → asserts `handlerB.current.phase == PlaybackPhase.waiting`, `activeSongId == 'song-late'`, `engineB.playAtCalls` is empty. The test never calls `handleApplicationMessage` directly (grepped: zero occurrences of that call in the new test body) — confirmed by code reading, not just the commit message's claim. | ✅ PASS |
| SYNC-06 (ordering regression it also guards): sends to the same participant from different call sites must never corrupt the wire | command-broadcast send and new-connection snapshot send to one participant must serialize, not interleave | `lib/data/playback/playback_command_broadcaster.dart:53,102-119` (`_sendQueueByParticipant` map; every `_sendTo` call, whether from `_broadcastCommand`, `_probeLatency`, or `_sendSnapshotTo`, chains onto the same per-participant `Future`) | ✅ PASS |
| Command-ordering tests unaffected by the new per-participant send queue | existing per-participant message-order assertions (e.g. probe-then-command sequencing, 3-device distinct-epoch test) still pass unmodified | full `flutter test` run below: 252/252 passed, including `playback_command_broadcaster_test.dart`'s pre-existing 3-device and pause/stop/reposition ordering tests, with no changes to those test bodies in this diff range (`git log -p` for `dcfe5a6` shows pure addition, no edits to existing tests) | ✅ PASS |
| Race regression: a broadcaster constructed AFTER participants are already connected still reaches them on the first `play()` | the already-connected participant receives exactly one `PlayCommandMessage`, not zero | `test/data/playback/playback_command_broadcaster_test.dart:300-374` — joins/approves visitor to `connected` BEFORE constructing `PlaybackCommandBroadcaster(controller: master)`, then calls `play('song-race')` immediately; asserts `playCommands.hasLength(1)` and `.songId == 'song-race'` | ✅ PASS |
| Race regression discriminates on the actual fix (`currentSnapshot` seeding) | reverting `_latestSnapshot = _controller.currentSnapshot;` (the constructor-time seed) must make this exact test fail | Verified empirically in the discrimination sensor below (Mutation 2): with the seed replaced by `_latestSnapshot = null;`, the new regression test fails with `Expected: an object with length of <1> / Actual: []` — proving the test is causally tied to the fix, not coincidentally passing | ✅ PASS |
| XFER-09: visitor cannot initiate a transfer — rejection must be an active role-gate rejection, not an empty-list no-op | a connected visitor's attempt to send fails, and the master never receives anything from it | `test/data/transfer/song_sync_coordinator_test.dart:379-479` — full `createRoom()`/join/approve of a real visitor to `connected`, then `ChunkedFileSender(controller: visitor, ...).sendTrack(...)` targeting the master directly (the real send path `SongSyncCoordinator` uses, not the coordinator itself — the coordinator would be a no-op for a different, unrelated structural reason, correctly noted in the test's own comment); asserts `result.isFailure == true`, `f.code == 'transfer.chunk-delivery-failed'`, AND `masterReceived.isEmpty` (master's `applicationMessages` stream never received the visitor's attempt at all) | ✅ PASS |
| XFER-09's test is non-vacuous (not trivially true regardless of the assertion's direction) | flipping the test's own success/failure assertion must make it fail against unchanged, correct production code | Verified empirically in the discrimination sensor below (Mutation 3): flipping `expect(result.isFailure, isTrue)` → `expect(result.isSuccess, isTrue)` makes the test fail (`Expected: true / Actual: <false>`) — proving the test's assertion direction is load-bearing, not vestigial | ✅ PASS |

**Status**: ✅ All three re-verified ACs cleanly matched the spec-defined outcome. No gaps found in this iteration's scope.

### Discrimination Sensor

Run in an isolated git worktree (`d:/Projetos/cantae_scratch2`, detached HEAD `573f68e`), never `git stash`. Baseline `git status --porcelain` on the real tree captured before the run and re-confirmed byte-identical after `git worktree remove --force` (diff produced no output).

| # | File:line | Mutation | Killed? |
| --- | --- | --- | --- |
| 1 | `lib/data/playback/playback_command_broadcaster.dart:76-78` | Dropped the `unawaited(_sendSnapshotTo(participantId))` call inside the newly-connected loop (snapshot send never fires) | ✅ Killed — `playback_command_handler_test.dart`'s SYNC-06 E2E test fails: `Expected: PlaybackPhase.waiting / Actual: PlaybackPhase.idle` |
| 2 | `lib/data/playback/playback_command_broadcaster.dart:70` | Reverted the constructor-time seed: `_latestSnapshot = _controller.currentSnapshot;` → `_latestSnapshot = null;` | ✅ Killed — `playback_command_broadcaster_test.dart`'s race regression test fails: `Expected: an object with length of <1> / Actual: []` |
| 3 | `test/data/transfer/song_sync_coordinator_test.dart:473` | Flipped the XFER-09 test's own assertion: `expect(result.isFailure, isTrue)` → `expect(result.isSuccess, isTrue)` | ✅ Killed — fails against unchanged, correct production code: `Expected: true / Actual: <false>` |

**Sensor depth**: lightweight (3 targeted mutations, one per fix, default tier — proportional to non-P0 scope)
**Result**: 3/3 killed — ✅ PASS
**Isolation check**: `git status --porcelain` before and after the sensor run were identical (confirmed via `diff`); worktree removed with `git worktree remove --force`; `git worktree list` afterward shows only the real tree.

### Code Quality (re-verified subset)

| Principle | Status |
| --- | --- |
| Minimum code | ✅ — Fix 1 adds exactly what's needed (state tracking + send-on-new-connection + the serialization queue its own race otherwise creates); no speculative generality |
| Surgical changes | ✅ — all three commits touch only the files their own commit message names; `git show --stat` confirms no incidental edits |
| No scope creep | ✅ |
| Matches patterns | ✅ — `_sendTo`'s per-participant `Future` chaining mirrors the project's existing async-serialization idiom elsewhere in the broadcaster (`_probeLatency`/`_awaitProbeReply`) |
| Spec-anchored outcome check | ✅ — see table above |
| Per-layer Coverage Expectation met | ✅ — both new playback tests are E2E over real loopback TCP; XFER-09 rewrite is also E2E over real loopback TCP, consistent with the project's established pattern |
| Every test maps to a spec requirement — no unclaimed tests | ✅ |
| Documented guidelines followed | `CLAUDE.md` Testing Rules (E2E-first) — followed; all three new/rewritten tests are E2E, none are post-hoc unit tests of already-written logic in isolation |

One new risk surfaced and independently confirmed closed: the per-participant send queue (`_sendQueueByParticipant`) introduced to fix the snapshot/command-broadcast race was checked against all pre-existing ordering-sensitive tests in `playback_command_broadcaster_test.dart` (3-device distinct-epoch test, pause/stop/reposition sequencing) — all pass unmodified in the full gate run below, and `git log -p dcfe5a6` confirms no existing test bodies were edited to accommodate it.

### Gate Check

- **Gate command**: `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`
- **Result**: `flutter analyze` → 0 issues (129.9s). `flutter test` → **252 passed, 0 failed** (up from 250 in Iteration 1; +2 net new tests: the SYNC-06 E2E test and the race regression test — XFER-09 was a rewrite, not a net add). `python scripts/check_layers.py --root .` → exit 0, "no forbidden imports in lib/domain/". `dart analyze lib/domain/` → 0 issues.
- **Skipped tests**: none.
- **Failures**: none.
- **Test count before this iteration's fixes**: 250. **After**: 252. **Delta**: +2 (consistent with the diff stat: 2 new test blocks added across `playback_command_handler_test.dart` and `playback_command_broadcaster_test.dart`; `song_sync_coordinator_test.dart`'s XFER-09 test was rewritten in place, not added).

### Summary

**Overall**: ✅ Ready — all three Major/Minor fixes from Iteration 1 are solid; no new gaps found.

**Spec-anchored check**: 3/3 re-verified criteria (plus 2 supporting assertions on the serialization queue and the test suite's non-regression) cleanly matched their spec-defined outcomes; 0 gaps, 0 spec-precision gaps in this iteration's scope.

**Sensor**: 3/3 mutations killed — each mutation targets exactly the behavior its corresponding fix introduced (snapshot send, constructor-time seed, and the new test's own assertion direction), and Mutation 2 doubles as direct empirical proof that the race regression test is causally tied to the fix it claims to guard, not coincidentally passing.

**Gate**: 4/4 passed (`flutter analyze`, `flutter test` — 252/252, `check_layers.py`, `dart analyze lib/domain/`), all re-run fresh in this session.

**What works**: SYNC-06 is now wired end-to-end in production code (not just unit-tested in isolation as in Iteration 1) — a real (re)joining device receives a `PlaybackSnapshotMessage` through the same `RoomSessionController`/`PlaybackCommandBroadcaster` machinery a real session uses, confirmed by an E2E test that never calls `handleApplicationMessage` directly. The documented production race (broadcaster constructed after participants already joined) now has a regression test that was empirically shown, via the sensor, to fail if the fix it guards is reverted. XFER-09's test now demonstrates an active role-gate rejection (master receives nothing) rather than a vacuous empty-participant-list no-op, and was empirically shown to be sensitive to its own assertion direction.

**Issues found**: None in this iteration's scope. (Iteration 1's remaining non-Major items — SYNC-03's acknowledged loopback-vs-100ms-bar gap, BG-01/02/04's device-only caveats — were out of scope for this re-verification pass and remain as recorded in Iteration 1.)

**Next steps**: No further fix→re-verify iterations needed for SYNC-06, the race regression, or XFER-09. The three previously-recorded lesson candidates (L-003, L-004, L-005) from Iteration 1 are grounded in gaps that this iteration found fully closed with empirically-verified (not just asserted) regression coverage — promotion from candidate to confirmed lesson appears warranted, but that bookkeeping step was left to the orchestrator per this task's scope (lessons.json/LESSONS.md were not touched by this Verifier).
