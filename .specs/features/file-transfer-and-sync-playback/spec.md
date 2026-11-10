# File Transfer & Synchronized Playback Specification

## Problem Statement

Phases 1-3 built the audio domain math (mix, loop, metronome, timeline), the local library (SQLite/drift), and the session/networking layer (mDNS discovery, authenticated TCP, HMAC-sealed envelopes) — but no audio ever actually moves between devices or plays out loud. A vocal group that joins a room today has a session, not a rehearsal. This feature closes that gap: the master's song files reach every approved participant's device over the existing authenticated transport, and every device starts playing its mixed tracks within the same ~100 ms window, using a real audio engine instead of domain-only calculators.

## Goals

- [ ] A participant's device holds a byte-for-byte, hash-validated copy of every track of the active song within one chunked transfer that survives a Wi-Fi drop.
- [ ] All participant devices in a room begin audio playback of a song within ≤100 ms of each other, measured from the master's play command.
- [ ] Audio keeps playing when the app is backgrounded or the screen locks, with working lock-screen/tray transport controls.
- [ ] Visitor-role devices can receive files and hear audio but cannot initiate a transfer, play, pause, seek, or loop.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Advanced clock-sync algorithms (NTP-style, PTP) | Explicitly out of scope per project guide; a single latency-estimate correction is enough for the 100 ms target on a LAN. |
| Live singer-to-singer audio / walkie-talkie | Explicitly out of scope per project guide. |
| Mid-song late join (playing from current position) | Resolved with user: late joiners wait silently until the next playback start, avoiding mid-stream position sync. |
| Per-naipe selective transfer (sending only one track per device) | Resolved with user: every device receives every track of the song, so a singer can switch naipe locally without re-transferring. |
| Transferring more than one song at a time per room | Single active transfer per room keeps chunk bookkeeping and resume state simple; queued songs transfer one after another. |
| Lock-screen artwork / rich media metadata | Cosmetic; functional transport controls (play/pause/stop) are in scope, visual polish is deferred to Phase 5 UI work. |
| Automatic master election / master handoff | Explicitly out of scope per project guide. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Track scope per transfer | All tracks of the song (every naipe + playback track) go to every approved participant | User decision | y |
| Interrupted-transfer recovery | Resume from the last chunk the receiver ACKed, keyed by content hash | User decision | y |
| Late join during active playback | Participant stays silent (no audio, UI shows "waiting") until the next play command | User decision | y |
| Chunk size | 64 KiB per chunk | Small enough to ACK/resume cheaply over a LAN socket, large enough to keep per-chunk envelope/HMAC overhead low; no project precedent, chosen as a safe default | n (default, revisit if real-device throughput tests show otherwise) |
| Max transferable file size per track | 100 MB | A4-choir-length stereo WAV/MP3 track comfortably fits well under this; guards against unbounded storage/time use on a phone. No existing cap in the codebase. | n (default) |
| Content addressing for dedup | Transferred file identity is its final SHA-256 hash; a file already present locally under that hash is never re-transferred, even for a different song/track record | Mirrors the project's existing "visible only after hash validates" library gate (project guide) and avoids re-sending identical playback tracks already shared in an earlier room | y (derived from existing project-wide gate, not a new decision) |
| Clock-sync method | One round-trip latency probe per participant (already-connected TCP socket) to estimate one-way delay; master schedules play at `referenceClockValue = masterSendTime + estimatedOneWayDelay`, no continuing clock-drift correction during a single song | Session TTL is 30 min and Wi-Fi LAN round-trip is sub-millisecond-to-low-tens-of-ms, so drift within one song is negligible; matches "no advanced clock sync" out-of-scope line while still hitting the 100 ms target | n (default; Design phase picks exact probe mechanics) |
| Concurrent transfer count | One active file transfer in flight per room at a time (song-by-song, not parallel per participant file-spray) | Keeps the authenticated-transport channel's chunk/ACK bookkeeping simple per TCP connection per participant; still parallel *across* participants (each gets its own stream) | n (default) |
| Storage location for received files | App sandbox, under the existing library storage root used for locally-imported songs (no separate "network cache" tree) | Project guide: "all audio and metadata stored in app sandbox only"; reusing one storage root keeps the drift-backed library repository as the single source of truth | y (derived from existing architecture, not a new decision) |
| Insufficient device storage during transfer | Transfer aborted, partial chunks discarded, a typed Failure surfaced to the receiving device's UI; master is not blocked for other participants | No existing precedent; chosen so one device's low storage never stalls the whole room | n (default) |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Master pushes song files to every approved participant ⭐ MVP

**User Story**: As the master of a rehearsal room, I want the song I selected to reach every approved participant's device automatically, so that the group can rehearse together without anyone manually copying files.

**Why P1**: Without the files on-device, there is nothing to play; this is the foundation the rest of the feature depends on.

**Acceptance Criteria**:

1. WHEN the master selects a song to rehearse THEN the system SHALL send every track of that song (all naipes + the playback track, per the all-tracks decision) to every approved, connected participant over the existing authenticated session transport.
2. WHEN a track is sent THEN the system SHALL split it into 64 KiB chunks, each delivered inside an authenticated envelope (reusing the existing HMAC + sequence mechanism), and the receiver SHALL ACK each chunk it has durably written.
3. WHILE a chunk-ACK has not been received for a sent chunk THE system SHALL retry delivery of that chunk before advancing, bounded to 5 attempts per chunk before marking the transfer failed for that participant.
4. IF the TCP connection to a participant drops mid-transfer and the participant reconnects within the session TTL THEN the system SHALL resume sending from the first chunk after the last chunk that participant ACKed (not from chunk zero).
5. WHEN all chunks of a track have been received THEN the receiving device SHALL compute the SHA-256 hash of the reassembled file and compare it to the hash declared by the master.
6. IF the computed hash matches the declared hash THEN the system SHALL make the file visible/usable in the receiving device's local library; IF it does not match THEN the system SHALL discard the reassembled file, retry the whole-track transfer up to 2 times, and SHALL NOT make a hash-mismatched file visible under any circumstance.
7. IF a file with the same SHA-256 hash already exists in the receiving device's local storage THEN the system SHALL skip re-transferring that file's bytes and reuse the existing copy for the new song/track record.
8. The system SHALL allow at most one song's files to be mid-transfer per room at a time; a second song selected by the master while a transfer is in flight SHALL queue behind the current one.
9. IF a participant's role is `visitor` THEN the system SHALL still receive and store files pushed by the master (visitors are not blocked from receiving) but SHALL reject any attempt by that device to *initiate* a transfer, per the project's role-enforcement gate.
10. IF available device storage is insufficient to complete a track's transfer THEN the system SHALL abort that participant's transfer, discard partial chunks, and surface a typed `Failure` with a non-empty `code` — without blocking transfer to other participants.

**Independent Test**: Start a 2-device room (1 master, 1 visitor), master selects a song with 2 tracks, kill Wi-Fi on the visitor mid-transfer, restore it, confirm the visitor's library ends up with both tracks byte-identical to the master's (hash match) and the transfer did not restart from zero (chunk count sent after reconnect < total chunk count).

---

### P1: Synchronized multi-track playback across devices ⭐ MVP

**User Story**: As a singer, I want my device to start playing at (practically) the same instant as everyone else's, so that the group sounds like one choir instead of an echo chamber.

**Why P1**: This is the headline capability of the phase — "real audio" only matters if it's synchronized; without it the app is just a file-sharing tool.

**Acceptance Criteria**:

1. The system SHALL use a real audio engine (`just_audio` per track) to play back the tracks of the active song, replacing no existing domain math (mix calculator, loop controller, timeline converter, metronome generator continue to drive the engine, not be replaced by it).
2. WHEN the master issues a play command THEN the system SHALL compute, for each connected participant, an estimated one-way network delay from a round-trip latency probe over the already-authenticated connection, and SHALL schedule that participant's playback start at `masterSendTime + estimatedOneWayDelay`.
3. WHEN a participant device's scheduled start time arrives THEN the system SHALL begin playback of all of that song's tracks, mixed per `AudioMixCalculator`, within ≤100 ms of the master's own playback start, measured across all connected devices in the room.
4. WHILE the master has an active loop region set (per `LoopController`) THE system SHALL reposition every participant device's playback to the loop start synchronously (same scheduling mechanism as a play command) when any device's position reaches the loop end.
5. IF a participant's role is `visitor` THEN the system SHALL reject any play, pause, seek, or loop command originating from that device, per the project's role-enforcement gate (visitors can only receive master-issued playback state).
6. WHEN a participant joins or reconnects while a song is already playing THEN that device SHALL remain silent (no audio output) and present a "waiting" state until the next play command for that song (next loop iteration or restart) is issued — it SHALL NOT attempt to join mid-stream.
7. IF the master issues a pause or stop command THEN every connected participant device SHALL stop audio output, applying the same latency-compensated scheduling as a play command.
8. The system SHALL NOT allow any command that controls playback (play/pause/seek/loop) to execute on a receiving device unless it arrived through a validated envelope from the room's current master (reuses existing `EnvelopeAuthenticator` + `requiresMasterRole` gate).

**Independent Test**: In a 3-device room (1 master, 2 visitors) with all three devices' files already transferred, master presses play; capture each device's actual first-audio-sample timestamp (e.g., via a logged engine callback) and confirm the max pairwise delta across the three devices is ≤100 ms, repeatable across 5 runs.

---

### P2: Background audio with lock-screen/tray controls

**User Story**: As a singer, I want the rehearsal audio to keep playing and be controllable if I lock my phone or switch apps mid-song, so that a glance at the lock screen or a notification tap doesn't interrupt the group.

**Why P2**: Important for a real rehearsal (phones get locked), but the room can be demoed and the sync behavior validated with the app in the foreground first — this story layers on top of P1's engine, it doesn't block it.

**Acceptance Criteria**:

1. WHILE a song is playing and the app is backgrounded or the device screen locks THE system SHALL continue audio playback uninterrupted on both Android and iOS, via `audio_service` wrapping the `just_audio` engine.
2. WHEN the app is backgrounded during playback THEN the system SHALL expose play/pause/stop transport controls on the Android notification tray and iOS lock screen / Control Center.
3. IF the device receiving the background-control tap has `visitor` role THEN the system SHALL reject the resulting play/pause/stop action the same way an in-app visitor action is rejected (per P1 AC5) — background controls do not bypass role enforcement.
4. IF the OS reclaims the background audio session (e.g., another app takes audio focus) THEN the system SHALL pause local playback and surface a typed `Failure`, without corrupting the room's shared playback state for other participants.

**Independent Test**: Start playback as master, lock the screen, confirm audio continues and the lock-screen pause control stops playback for that device without affecting the other participants in the room.

---

## Edge Cases

- IF a chunk's authenticated envelope fails HMAC/sequence validation (replay or corruption) THEN the system SHALL discard that chunk and request retransmission, exactly as an invalid envelope is already discarded at the session layer.
- IF the master disconnects (ends the room) mid-transfer THEN the system SHALL abort all in-flight transfers for that room and discard partial state, consistent with the existing `endRoom` teardown.
- IF two tracks happen to produce the same SHA-256 hash by coincidence of identical content (e.g., a silent placeholder track reused across songs) THEN the dedup rule in Assumptions still applies correctly — identical bytes are, by definition, the same file.
- WHEN a track's declared size exceeds the 100 MB cap THEN the system SHALL reject starting that transfer and surface a typed `Failure` to the master before any chunk is sent.
- IF a participant's estimated one-way delay from the latency probe exceeds 100 ms on its own (unusually congested Wi-Fi) THEN the system SHALL still schedule and attempt playback at the computed time — no fallback mode exists for this MVP; the 100 ms target is a measured acceptance bar, not a guaranteed clamp.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| XFER-01 | P1: Master pushes song files | Design | Pending |
| XFER-02 | P1: Master pushes song files | Design | Implementing |
| XFER-03 | P1: Master pushes song files | Design | Implementing |
| XFER-04 | P1: Master pushes song files | Design | Implementing |
| XFER-05 | P1: Master pushes song files | Design | Implementing |
| XFER-06 | P1: Master pushes song files | Design | Implementing |
| XFER-07 | P1: Master pushes song files | Design | Pending |
| XFER-08 | P1: Master pushes song files | Design | Pending |
| XFER-09 | P1: Master pushes song files | Design | Pending |
| XFER-10 | P1: Master pushes song files | Design | Implementing |
| SYNC-01 | P1: Synchronized multi-track playback | Design | Pending |
| SYNC-02 | P1: Synchronized multi-track playback | Design | Implementing |
| SYNC-03 | P1: Synchronized multi-track playback | Design | Pending |
| SYNC-04 | P1: Synchronized multi-track playback | Design | Pending |
| SYNC-05 | P1: Synchronized multi-track playback | Design | Pending |
| SYNC-06 | P1: Synchronized multi-track playback | Design | Pending |
| SYNC-07 | P1: Synchronized multi-track playback | Design | Pending |
| SYNC-08 | P1: Synchronized multi-track playback | Design | Pending |
| BG-01 | P2: Background audio | Design | Pending |
| BG-02 | P2: Background audio | Design | Pending |
| BG-03 | P2: Background audio | Design | Pending |
| BG-04 | P2: Background audio | Design | Implementing |

**ID format:** `[CATEGORY]-[NUMBER]` — `XFER` (file transfer), `SYNC` (synchronized playback), `BG` (background audio).

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 22 total, 0 mapped to tasks, 22 unmapped ⚠️ (expected at Specify — Design/Tasks phases will map these)

---

## Success Criteria

- [ ] A 2+ device room with a multi-track song ends with every participant holding byte-identical, hash-validated files to the master, even after a mid-transfer disconnect/reconnect.
- [ ] Measured max pairwise playback-start delta across all devices in a room is ≤100 ms, across repeated runs.
- [ ] A visitor device cannot start, stop, seek, or loop playback from the in-app UI or from lock-screen/notification controls — verified by an authenticated envelope reaching the role gate and being rejected.
- [ ] Audio keeps playing and stays controllable from the lock screen / notification tray on both a locked Android and a locked iOS device during a song.
