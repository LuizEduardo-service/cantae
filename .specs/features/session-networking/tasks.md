# Session & Networking Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/session-networking/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase sampling (`test/domain/**`, `test/data/**`, `test/infrastructure/database/app_database_test.dart`) and root `CLAUDE.md` Testing Rules. Guidelines found: `CLAUDE.md` (Testing Rules — E2E-first, failure-modes-first for isolated units, no post-hoc unit tests), `.claude/skills/flutter-quality-gates/SKILL.md` (gate order and commands).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `domain/session/*` (state machine, handshake math, envelope auth) + `domain/core` (constant-time compare) | unit, failure-modes-first (AD-005) | List failure modes before writing code; 1:1 to spec ACs NET-01..20; every listed Edge Case has a test | `test/domain/session/*_test.dart`, `test/domain/core/*_test.dart` | `flutter test test/domain/session/ test/domain/core/` |
| `infrastructure/network/*` (TCP transport, mDNS discovery adapters) | integration, real I/O not mocked (AD-010 precedent — real SQLite over mocks; same policy applies to real loopback sockets over mocked `Socket`) | Connect/send/receive/close over real `127.0.0.1` TCP; `nsd` adapter covered by a thin contract test only (real mDNS multicast is not exercisable in CI — flagged in Risks) | `test/infrastructure/network/*_test.dart` | `flutter test test/infrastructure/network/` |
| `data/session/room_session_controller.dart` (orchestration) | integration | Full join→approve→handshake→authenticated-envelope flow across two controller instances over real loopback TCP, with a fake `RoomDiscovery` (no real mDNS in CI); asserts `tick()` is actually wired to a periodic timer (Risk in design.md) | `test/data/session/room_session_controller_test.dart` | `flutter test test/data/session/` |
| E2E / primary verification (CLAUDE.md E2E-first) | integration_test, produces a logged artifact | Two `RoomSessionController`s (master + visitor) over real sockets, full P1+P2+P3 happy path plus the 3 adversarial cases from spec's P2 Independent Test (tampered HMAC, replay, role violation) — asserts final state AND prints/asserts a transition log as the reviewable artifact | `integration_test/session_networking_test.dart` | `flutter test integration_test/session_networking_test.dart` |
| Entity/value objects with no logic (`Room`, `ParticipantSession`, `Envelope` plain data holders) | none | Build gate only (matches `entities_test.dart` sampling — only entities with validation/const-assert logic get dedicated tests) | n/a | build gate only |
| `pubspec.yaml` dependency addition (`cryptography`) | none | Build gate only | n/a | build gate only |

## Gate Check Commands

> Generated from `.claude/skills/flutter-quality-gates/SKILL.md` and sampled repo structure - confirm before Execute.

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After tasks touching only `domain/session` or `domain/core` unit tests | `flutter test test/domain/session/ test/domain/core/` |
| Full | After tasks touching `infrastructure/network`, `data/session`, or the integration_test suite | `flutter test` then `flutter test integration_test/session_networking_test.dart` |
| Build | After phase completion, the dependency task, or any entity/config-only task | `dart format --output=none --set-exit-if-changed .` then `flutter analyze` then `dart analyze lib/domain/` then `flutter test` then `flutter test integration_test/session_networking_test.dart` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Each phase's dependency diagram is shown directly above its tasks in the Task Breakdown below (arrows show only real same-phase data dependencies; a task with no same-phase dependency is listed without an incoming arrow — its dependency is on an earlier phase, already satisfied by sequencing).

---

## Task Breakdown

### Phase 1: Foundation

```
T1 → T2
T3
T4
```

#### T1: Add `cryptography` dependency

**What**: Add `cryptography: ^2.7.0` to `pubspec.yaml` dependencies and run `flutter pub get`.
**Where**: `pubspec.yaml`
**Depends on**: None
**Reuses**: n/a
**Requirement**: NET-05 (enabling dependency)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `cryptography` listed under `dependencies` in `pubspec.yaml`
- [x] `flutter pub get` succeeds, `pubspec.lock` updated
- [x] Build gate passes: `dart format --output=none --set-exit-if-changed .` then `flutter analyze`

**Tests**: none
**Gate**: build

**Commit**: `chore(deps): add cryptography package for X25519 handshake`

---

#### T2: Record AD-011 in STATE.md

**What**: Confirm/finalize the AD-011 entry already drafted in `.specs/STATE.md` (amends AD-004) now that the dependency is actually added.
**Where**: `.specs/STATE.md`
**Depends on**: T1
**Reuses**: AD-009's amendment pattern (the `drift` precedent)
**Requirement**: n/a (project memory, not a spec requirement)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] AD-011 entry present and accurate (already drafted during Design; this task just confirms it ships with the dependency)

**Tests**: none
**Gate**: build

**Commit**: `docs(specs): confirm AD-011 cryptography dependency decision`

---

#### T3: `constantTimeEquals` helper

**What**: Add a constant-time byte-comparison function to `domain/core`, used later by `EnvelopeAuthenticator.verify`.
**Where**: `lib/domain/core/constant_time_equals.dart`
**Depends on**: None
**Reuses**: none existing
**Requirement**: NET-11 (enabling: prevents timing side-channel on HMAC compare)

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture` (confirm domain-purity placement)

**Done when**:
- [x] Failure modes listed first (per AD-005): unequal length, equal length+equal bytes, equal length+unequal bytes, both empty
- [x] Function implemented without early-exit branching that leaks length-independent timing (compare full length always, OR accept length as a non-secret pre-check — documented inline why that's safe)
- [x] Unit tests cover all 4 listed failure modes
- [x] Gate passes: `flutter test test/domain/core/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add constant-time byte comparison helper`

---

#### T4: `SessionId`/`ParticipantId`/`RoomId`/`DeviceId` value types

**What**: Define the small typed-id wrapper classes used across every session entity (avoids stringly-typed ids throughout the state machine).
**Where**: `lib/domain/session/ids.dart`
**Depends on**: None
**Reuses**: pattern from existing entity id types (e.g. how `Song` ids are typed, per `entities_test.dart` sampling)
**Requirement**: NET-01..20 (enabling: used by every subsequent entity/method signature)

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [x] `RoomId`, `DeviceId`, `ParticipantId` value classes defined, `const` constructors, value equality (per AD-006 pattern)
- [x] No logic beyond identity/equality — Coverage Expectation says "none" for pure value holders
- [x] Build gate passes

**Tests**: none
**Gate**: build

**Commit**: `feat(domain): add session identifier value types`

---

### Phase 2: Domain — Handshake & Envelope Security (P1 + P2)

```
T5 → T6 → T7
T8
```

#### T5: `Envelope` value object

**What**: Define the `Envelope` data class (senderId, sequence, payload, hmac) per design's Data Models.
**Where**: `lib/domain/session/envelope.dart`
**Depends on**: T4
**Reuses**: `ParticipantId` from T4
**Requirement**: NET-10

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [x] `Envelope` class defined exactly per design.md Data Models, `const` constructor
- [x] Build gate passes

**Tests**: none
**Gate**: build

**Commit**: `feat(domain): add Envelope value object`

---

#### T6: `EnvelopeAuthenticator.sign`

**What**: Implement HMAC-SHA-256 signing of an outgoing envelope.
**Where**: `lib/domain/session/envelope_authenticator.dart`
**Depends on**: T5
**Reuses**: `crypto` package `Hmac`/`sha256` (already declared)
**Requirement**: NET-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first: empty payload, max-size payload, key length mismatch
- [x] `sign(sender, sequence, payload, key)` returns an `Envelope` with a correct 32-byte HMAC verified against a hand-computed reference vector in the test
- [x] Unit tests cover the listed failure modes + the happy path
- [x] Gate passes: `flutter test test/domain/session/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): implement envelope HMAC signing`

---

#### T7: `EnvelopeAuthenticator.verify`

**What**: Implement HMAC verification + strictly-increasing sequence check, using `constantTimeEquals` from T3.
**Where**: `lib/domain/session/envelope_authenticator.dart` (same file as T6)
**Depends on**: T6, T3
**Reuses**: `constantTimeEquals` (T3)
**Requirement**: NET-11, NET-12, NET-13, NET-14

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first: tampered payload w/ stale HMAC, wrong key, replayed sequence (≤ last accepted), out-of-order-but-valid gap (sequence jump), exact boundary (sequence == last accepted)
- [x] `verify()` returns `NetworkFailure(code: 'session.hmac-mismatch')` on bad HMAC, `NetworkFailure(code: 'session.replay-detected')` on non-increasing sequence, success otherwise
- [x] Unit tests cover NET-11/12/13/14 and the Edge Case "sequence jumps by 10000+ is legal forward progress"
- [x] Gate passes: `flutter test test/domain/session/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): implement envelope HMAC and replay verification`

---

#### T8: `HandshakeService` (X25519 ECDH + HKDF)

**What**: Implement ephemeral X25519 keypair generation and session-key derivation via ECDH + HKDF-SHA256.
**Where**: `lib/domain/session/handshake_service.dart`
**Depends on**: T4
**Reuses**: `cryptography` package (T1)
**Requirement**: NET-05, NET-07

**Tools**:
- MCP: `context7` (verify current `cryptography` package X25519/Hkdf API before coding — Knowledge Verification Chain step 3)
- Skill: NONE

**Done when**:
- [x] Failure modes listed first: malformed/wrong-length peer public key, handshake producing a key of unexpected length (must fail, never truncate/pad — per spec Edge Case)
- [x] `generateEphemeralKeyPair()` and `deriveSessionKey()` implemented; two independently generated keypairs produce matching 32-byte shared session keys on both ends in the test
- [x] `NetworkFailure(code: 'session.handshake-failed')` returned for every listed failure mode
- [x] Gate passes: `flutter test test/domain/session/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): implement X25519 ECDH handshake and HKDF key derivation`

---

### Phase 3: Domain — Room Session State Machine (P1 + P2 + P3)

```
T9 → T10 → T11 → T12
```

#### T9: `Room` and `ParticipantSession` entities

**What**: Define the two stateful entities the state machine operates on, per design.md Data Models.
**Where**: `lib/domain/session/room.dart`, `lib/domain/session/participant_session.dart`
**Depends on**: T4
**Reuses**: `RoomId`/`ParticipantId`/`DeviceId` (T4)
**Requirement**: NET-01..20 (enabling)

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [x] `Room`, `ParticipantSession`, `ParticipantRole` enum, `ParticipantState` enum defined exactly per design.md
- [x] Build gate passes

**Tests**: none
**Gate**: build

**Commit**: `feat(domain): add Room and ParticipantSession entities`

---

#### T10: `RoomSessionStateMachine` — join, approve, reject, capacity (P1)

**What**: Implement `requestJoin`, `approve`, `reject`, and the 8-participant capacity check.
**Where**: `lib/domain/session/room_session_state_machine.dart`
**Depends on**: T9
**Reuses**: `Room`/`ParticipantSession` (T9)
**Requirement**: NET-01, NET-02, NET-03, NET-04, NET-05 (state transition only — key material comes from T8 via the controller in Phase 5), NET-06, NET-08, NET-09

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first: wrong code, room at 8/8 at request time, room at 8/8 at approval time (race: two pending requests, one slot), approving/rejecting an unknown participant id, approving a non-`pendingApproval` participant
- [x] `requestJoin`/`approve`/`reject` implemented with the above failures returning the matching typed `Failure` from design.md's code table
- [x] `tick(now)` expires `pendingApproval` entries older than 60s to `rejected` (NET-09)
- [x] Unit tests cover NET-03/04/06/08/09 and the two listed capacity-race failure modes (NET-01/02 are mDNS advertise/discover — not exercisable at this pure-domain layer; deferred to T14/T15, noted as a spec-precision gap rather than a fabricated assertion)
- [x] Gate passes: `flutter test test/domain/session/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): implement join request, approval, and capacity in state machine`

---

#### T11: `RoomSessionStateMachine` — envelope acceptance & role enforcement (P2)

**Note (execution-time plan correction):** `acceptEnvelope` only operates on a `connected` participant holding a `sessionKey`, and that transition is `completeHandshake` — originally scheduled in T12. Testing T11 in isolation requires it now, so `completeHandshake` (NET-05/07, with its own failure-mode tests: unknown id, non-`approved` source state) is implemented here instead. T12 no longer implements it — see T12's note.

**What**: Implement `acceptEnvelope`, wiring to `EnvelopeAuthenticator` (T7) plus the Master-only role check; implement `completeHandshake` as its prerequisite.
**Where**: `lib/domain/session/room_session_state_machine.dart` (same file as T10)
**Depends on**: T10, T7
**Reuses**: `EnvelopeAuthenticator` (T6/T7)
**Requirement**: NET-10, NET-11, NET-12, NET-13, NET-14, NET-15

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first: envelope from unknown sender, envelope from a `disconnected`/`expired` sender, Visitor sending a Master-only message type (disconnected/expired is a spec-precision gap here — `disconnect()`/TTL expiry for `connected` participants don't exist until T12; the never-connected case, which hits the same code path, is tested instead)
- [x] Failure modes for `completeHandshake` (pulled in from T12, see Note above): unknown participant id, participant not in `approved` state
- [x] `completeHandshake` transitions `approved` → `connected` and sets `sessionKey` (NET-05/07)
- [x] `acceptEnvelope` delegates HMAC/sequence to `EnvelopeAuthenticator`, adds the role check, and never mutates state on any rejection path (spec's Independent Test for P2 asserts this directly)
- [x] Unit tests cover NET-10..15 plus the 3 listed failure modes
- [x] Gate passes: `flutter test test/domain/session/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): implement authenticated envelope acceptance and role enforcement`

---

#### T12: `RoomSessionStateMachine` — TTL, disconnect, room end (P3)

**Note (execution-time plan correction):** `completeHandshake` was moved to T11 (it's a prerequisite for testing `acceptEnvelope` in isolation — see T11's note). This task now covers only `disconnect`, TTL expiry in `tick()`, and `endRoom`.

**What**: Implement `disconnect`, TTL expiry in `tick()`, and `endRoom`.
**Where**: `lib/domain/session/room_session_state_machine.dart` (same file as T10/T11)
**Depends on**: T11, T8 (handshake key shape)
**Reuses**: same file, extends `tick()` from T10
**Requirement**: NET-05, NET-07, NET-16, NET-17, NET-18, NET-19, NET-20

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first: `disconnect` called for an unknown participant, rejoin attempt reusing an old session key (must be rejected — spec Edge Case)
- [x] `tick()` now also expires `connected` participants silent for 30 min to `expired`, freeing their slot (NET-16)
- [x] `disconnect()` frees the slot immediately and invalidates the session key for future `acceptEnvelope` calls (NET-17)
- [x] `endRoom()` disconnects every participant and marks the room ended (NET-20)
- [x] Unit tests cover NET-16/17/18/19/20 and the 2 listed failure modes (NET-05/07 were covered by T11's `completeHandshake`, pulled forward — see T11's note)
- [x] Gate passes: `flutter test test/domain/session/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): implement TTL expiry, disconnect, and room-end lifecycle`

---

### Phase 4: Infrastructure Adapters

```
T13
T14
```

#### T13: `SessionTransport` port + `TcpSessionTransport` (loopback-tested)

**What**: Define the `SessionTransport` domain port and implement it over real `dart:io` TCP sockets.
**Where**: port `lib/domain/session/session_transport.dart`; impl `lib/infrastructure/network/tcp_session_transport.dart`
**Depends on**: T4
**Reuses**: `ParticipantId` (T4)
**Requirement**: NET-03 (enabling transport for join requests)

**Tools**:
- MCP: `context7` (confirm current `dart:io` `ServerSocket`/`Socket` stream-closing semantics before coding)
- Skill: `flutter-clean-architecture` (confirm port lives in domain, impl in infrastructure)

**Done when**:
- [x] Port interface matches design.md exactly (extended with `listen`/`boundPort`/`connect`/`closedConnections` — see design.md's T13 addendum; the original 4-method sketch had no way to open a connection or learn of a peer-initiated close)
- [x] `TcpSessionTransport` connects two instances over real `127.0.0.1:0` (OS-assigned port), sends bytes both directions, and detects connection close (clean + abrupt socket kill) — real sockets, not mocked, per AD-010 precedent
- [x] Integration tests cover: connect/send/receive round-trip, clean close detected, abrupt close (socket destroyed) detected
- [x] Gate passes: `flutter test test/infrastructure/network/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(infrastructure): implement TCP session transport over loopback sockets`

---

#### T14: `RoomDiscovery` port + `NsdRoomDiscovery`

**What**: Define the `RoomDiscovery` domain port and implement it over the `nsd` mDNS plugin.
**Where**: port `lib/domain/session/room_discovery.dart`; impl `lib/infrastructure/network/nsd_room_discovery.dart`
**Depends on**: T4
**Reuses**: `nsd` package (already declared), `RoomId` (T4)
**Requirement**: NET-01, NET-02

**Tools**:
- MCP: `context7` (confirm current `nsd` package API — advertise/discover signatures — before coding)
- Skill: `flutter-clean-architecture`

**Done when**:
- [x] Port interface matches design.md exactly (extended with a `port` param on `advertise` and a `DiscoveredRoom` value object — see design.md's T14 addendum)
- [x] `NsdRoomDiscovery` implements advertise/discover/stopAdvertising against the real `nsd` API
- [x] A thin contract test confirms the adapter calls `nsd` with the correct service type/name and maps results to `DiscoveredRoom` (real mDNS multicast is NOT exercised — flagged as an accepted gap in design.md Risks, verified manually on real devices during Phase 3 manual QA, not by this task's automated gate)
- [x] Gate passes: `flutter test test/infrastructure/network/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(infrastructure): implement mDNS room discovery via nsd`

---

### Phase 5: Orchestration & E2E

```
T15 → T16 → T17
```

#### T15: `RoomSessionController` — orchestration + `tick()` wiring

**What**: Implement the controller wiring state machine + handshake service + transport + discovery, including the periodic `Timer` that drives `tick()`.
**Where**: `lib/data/session/room_session_controller.dart`
**Depends on**: T12, T13, T14
**Reuses**: all domain/session components, `SessionTransport`/`RoomDiscovery` ports
**Requirement**: NET-01..09 (orchestration), plus the design's flagged Risk: "`tick()` must actually be wired"

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture` (Riverpod DI wiring pattern, same as `SongRepository`)

**Done when**:
- [x] `createRoom`, `discoverRooms`, `requestJoin`, `approve`, `reject`, `snapshots` stream implemented per design.md interfaces (plus a Wire Protocol addendum to design.md — framing + message types — required for any of this to work over a byte-stream TCP connection; see design.md)
- [x] A `Timer.periodic` invokes `tick()` on the underlying state machine with an injectable clock; integration test uses a fake clock (not real 60s/30min waits) to assert expiry actually fires through the controller, not just in isolated state-machine unit tests
- [x] Integration test runs two controller instances over real loopback TCP (via T13) with a fake `RoomDiscovery` (no real mDNS in test) proving join→approve→handshake completes end-to-end
- [x] Gate passes: `flutter test test/data/session/`

**Tests**: integration
**Gate**: full

**Commit**: `feat(data): implement RoomSessionController orchestration`

---

#### T16: E2E — full session lifecycle over real sockets

**What**: Write the primary verification per CLAUDE.md's E2E-first rule: two `RoomSessionController`s (master + visitor) over real TCP, exercising the full P1→P2→P3 happy path plus the three adversarial P2 cases.
**Where**: `integration_test/session_networking_test.dart`
**Depends on**: T15
**Reuses**: `RoomSessionController` (T15)
**Requirement**: NET-01..20 (full-stack confirmation), spec's three Independent Test sections

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Happy path: discover (faked) → join request → manual approve → handshake → matching 32-byte keys on both ends → authenticated envelope exchanged and accepted
- [x] Adversarial case 1: tampered payload + stale HMAC → rejected, state unchanged
- [x] Adversarial case 2: replayed sequence number → rejected, state unchanged
- [x] Adversarial case 3: Visitor sends a Master-only message type → rejected, state unchanged
- [x] Capacity: 9th join request rejected once 8 are approved
- [x] Test prints/logs the full transition sequence as the reviewable artifact (CLAUDE.md: "every E2E test must produce a verifiable, repeatable artifact")
- [x] Gate passes: `flutter test integration_test/session_networking_test.dart` — **environment note**: files under `integration_test/` are routed by Flutter tooling through device-based execution (`flutter test -d <device>`) even for plain `flutter test`; no device/emulator is available in this sandbox (Windows/web aren't configured platforms for this Android/iOS-only project per CLAUDE.md). Verified correctness instead by running the identical test body through the plain VM runner from a temporary, uncommitted copy under `test/` — all steps passed, including the printed transition log. The committed file is unchanged from what was verified. Real execution via the documented gate command is deferred to a CI runner or device with Flutter's on-device test support.

**Tests**: integration_test (e2e per CLAUDE.md)
**Gate**: build

**Commit**: `test(e2e): verify full session handshake and envelope-security lifecycle`

---

#### T17: Layer-purity and full build gate sweep

**What**: Final confirmation that `domain/session/` stayed Flutter/plugin/`dart:io`-free, and run the complete build gate.
**Where**: n/a (verification task, no new files)
**Depends on**: T16
**Reuses**: `check_layers.py` (AD-001), `flutter-quality-gates` skill
**Requirement**: Spec Success Criteria — "`domain/` session state machine and handshake math compile with `dart compile`"

**Tools**:
- MCP: NONE
- Skill: `flutter-quality-gates`

**Done when**:
- [x] `python scripts/check_layers.py --root .` exits 0
- [x] `dart analyze lib/domain/` exits 0 (confirms no Flutter SDK needed)
- [x] Full build gate: `flutter analyze` (0 issues, project-wide) → `flutter test` (172 passed, 0 failed) → `flutter test integration_test/session_networking_test.dart` (no device available in this sandbox — see T16's environment note; verified via an uncommitted VM-run copy instead, all steps passed)
  - `dart format --output=none --set-exit-if-changed .` exits 1, but the 17 flagged files are all pre-existing Phase 1/2 files (audio domain, mappers, repositories) unrelated to this feature — confirmed via `git stash` before any session-networking change existed. Every file this feature added or touched is independently format-clean. Left untouched per the surgical-changes rule.
- [x] Total test count recorded: 172 passed (0 failed) — up from the Phase 2 handoff's 110, i.e. 62 new tests from this feature

**Tests**: none (verification only)
**Gate**: build

**Commit**: `chore: verify domain layer purity for session-networking feature`

---

## Fix Tasks (Post-Verification, Round 1)

The independent Verifier (dispatched after T17) returned **FAIL** with 7 ranked gaps. Routed back and fixed in one round before re-verification:

| # | Gap | Fix | Files |
| - | --- | --- | ----- |
| 1 | **Security bug**: `requestJoin` unconditionally overwrote any existing session for a `deviceId`, letting a device that merely knows the (non-secret) 4-digit code reset an already-admitted victim's connection and wipe its session key | Guard: reject (`session.already-joined`) unless the existing session is `rejected`/`disconnected`/`expired` | `room_session_state_machine.dart`, `room_session_state_machine_join_test.dart` |
| 2 | NET-07/Edge Case 2: `approve()` moved to `approved` before handshake; nothing timed that out — a stalled handshake held the slot forever | Added `ParticipantSession.approvedSince`; `tick()` rejects an `approved` participant past a 10s handshake TTL | `participant_session.dart`, `room_session_state_machine.dart`, `room_session_state_machine_lifecycle_test.dart` |
| 3 | NET-20 had no caller: `RoomSessionController.endRoom()` didn't exist | Added `RoomSessionController.endRoom()`: calls the state machine, closes every connection, stops advertising | `room_session_controller.dart`, `room_session_controller_test.dart` |
| 4 | NET-06: `reject()` updated domain state but never closed the participant's TCP connection | `reject()` now closes the connection via a shared `_closeConnectionFor` helper | `room_session_controller.dart`, `room_session_controller_test.dart` |
| 5 | NET-16/07: tick-driven `expired`/`rejected` transitions never closed the socket | Controller's tick loop now sweeps terminated participants and closes their connections | `room_session_controller.dart`, `room_session_controller_test.dart` |
| 6 | NET-15 (distinct per-participant key / no cross-forgery) had zero test coverage | Added a two-participant test: distinct keys, a forged cross-sender envelope rejected, a genuine same-key envelope accepted | `room_session_state_machine_envelope_test.dart` |
| 7 | NET-17's two halves (domain `disconnect()`, transport close detection) were proven separately but never end-to-end through the controller | Added a controller-level test: abrupt visitor-side socket kill → master detects it and calls `disconnect()` | `room_session_controller_test.dart` |
| 8 | NET-01 precision gap: "no embedded secret" was never asserted | Added a thin test asserting the registered mDNS service carries no `txt` records (and noting `advertise()`'s signature structurally has no code parameter at all) | `nsd_room_discovery_test.dart` |

**Result**: 185 tests passing (up from 172), 0 failures, `flutter analyze` clean. Design decisions recorded in design.md's "Post-Verification Fixes" addendum. Re-verification (iteration 2) dispatched next.

## Fix Tasks (Post-Verification, Round 2)

Iteration-2 Verifier returned **FAIL** with 1 Major gap and 2 Minor: the discrimination sensor found fix #4 (NET-06, `reject()` closes the socket) was **not discriminating** — the test's 5s wait window let the default 5s periodic terminated-participant sweep close the same socket even with `reject()`'s own close call deleted, masking a potential regression on a security-posture criterion.

| # | Gap | Fix |
| - | --- | --- |
| Major | NET-06 test satisfied by the tick sweep, not by `reject()` itself | Shortened the test's wait window from 5s to 1s — well under the default 5s tick period, so the sweep can't fire before the assertion resolves. (First attempt used a 1-hour `tickInterval` override instead; this caused the Dart test runner to block for the full configured duration waiting on the outstanding periodic `Timer`, a real hang. Reverted — the short-wait-window approach needs no `tickInterval` override at all.) Verified both directions locally before re-dispatching the Verifier: mutant (close call removed) → test fails in ~6s; real code → test passes in ~5s. |
| Minor | NET id labelling drift in P2 (`design.md` + test names off-by-one: replay as NET-13 instead of NET-12, role enforcement as NET-15 instead of NET-14) | Relabelled to match spec.md's stated P2 ACs 10-15 assignment |
| Minor | NET-02 "list every room within 5s" asserted only via a single-service fake + test timeout | Left as an acknowledged spec-precision gap (consistent with design.md's existing Risks entry on real mDNS not being exercisable in this sandbox) |

**Result**: 185 tests passing, 0 failures (test count unchanged — this round strengthened an existing test and relabelled comments, added no new test).

## Final Verification — Iteration 3 of 3 (PASS)

The final allowed Verifier iteration re-derived all 20 ACs from scratch (not inherited from iteration 2), re-ran iteration-2's surviving mutation independently, and added 3 more mutations on previously-untested-adversarially code (replay boundary, role enforcement, `endRoom()`'s close loop). All 4 killed. Verdict: **PASS — ready to merge.**

- 19/20 ACs verified with spec-matching, discriminating assertions; NET-02 remains an accepted spec-precision gap (real mDNS multicast not exercisable in this sandbox, already documented in design.md Risks).
- Gate: `flutter analyze` clean, `flutter test` 185/185 in 37.9s (no hang), `check_layers.py` exit 0, `dart analyze lib/domain/` clean, E2E verified via scratch copy.
- Report: `.specs/features/session-networking/validation.md` (iteration 3, final/authoritative).
- `validate_state.py session-networking` → exit 0.
- Lessons distilled (first iteration with a non-disposable worktree to do so): `.specs/lessons.json` / `.specs/LESSONS.md` — 2 candidate lessons recorded (L-001: assert collection cardinality >1 when spec says "every"/"all"; L-002: bound a wait window below a periodic sweep's interval when asserting an event-triggered side effect the sweep also produces). Both `status: candidate`, `recurrence: 1` — not yet promoted to Confirmed (needs a second distinct feature).

**Feature status: DONE.** Merge of `feat/phase-3-session-networking` requires explicit user go-ahead (not performed automatically, per the skill's blast-radius rule).

---

## Phase Execution Map

```
Phase 1:  T1 → T2
Phase 2:  T5 → T6 → T7
Phase 3:  T9 → T10 → T11 → T12
Phase 5:  T15 → T16 → T17
```

(Phase 4's T13/T14 run independently of each other, each depending only on Phase 1's T4 — see the per-phase diagram above the Phase 4 tasks; omitted here since it has no intra-phase arrow to show.)

Execution is strictly sequential within a phase - a single agent (or batch worker) works one task at a time, in order. Phases run in sequence (1→2→3→4→5); cross-phase dependencies (e.g. T5 needs T4, T15 needs T12/T13/T14) are satisfied by phase ordering alone and are listed in each task's `Depends on` field, not re-drawn here.

17 tasks total → packs into 3 batches of ~6 tasks each at the ~7-task budget (Phase 1+2 = batch 1, Phase 3+4 = batch 2, Phase 5 = batch 3), all phase-boundary cuts. Sub-agent delegation will be offered before Execute starts, per the skill's trigger (>~8 tasks).

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Add `cryptography` dependency | 1 file (pubspec.yaml) | ✅ Granular |
| T2: Record AD-011 | 1 file (STATE.md) | ✅ Granular |
| T3: `constantTimeEquals` helper | 1 function | ✅ Granular |
| T4: Id value types | 1 file, 3 cohesive small types | ✅ Granular (cohesive, same concept) |
| T5: `Envelope` value object | 1 file, 1 class | ✅ Granular |
| T6: `EnvelopeAuthenticator.sign` | 1 function | ✅ Granular |
| T7: `EnvelopeAuthenticator.verify` | 1 function, same file as T6 | ✅ Granular |
| T8: `HandshakeService` | 1 component (2 cohesive methods) | ✅ Granular |
| T9: `Room`/`ParticipantSession` entities | 2 files, pure data holders, 1 concept | ✅ Granular (cohesive, same concept) |
| T10: State machine — join/approve/capacity | 1 component, 1 cohesive concern (P1 admission) | ✅ Granular |
| T11: State machine — envelope acceptance | 1 component, same file, 1 cohesive concern (P2 auth) | ✅ Granular |
| T12: State machine — TTL/disconnect/end | 1 component, same file, 1 cohesive concern (P3 lifecycle) | ✅ Granular |
| T13: `SessionTransport`/`TcpSessionTransport` | 1 port + 1 impl, 1 concept | ✅ Granular |
| T14: `RoomDiscovery`/`NsdRoomDiscovery` | 1 port + 1 impl, 1 concept | ✅ Granular |
| T15: `RoomSessionController` | 1 component | ✅ Granular |
| T16: E2E test | 1 test file, 1 concern (full lifecycle verification) | ✅ Granular |
| T17: Layer-purity sweep | 0 new files, verification only | ✅ Granular |

---

## Diagram-Definition Cross-Check

Only same-phase dependencies are drawn as arrows (cross-phase dependencies are satisfied by phase ordering and need no arrow — see rule in `tasks.md` process docs).

| Task | Phase | Depends On (task body) | Same-phase dep? | Diagram Shows | Status |
| --- | --- | --- | --- | --- | --- |
| T1 | 1 | None | n/a | (no incoming arrow) | ✅ Match |
| T2 | 1 | T1 | yes | T1→T2 | ✅ Match |
| T3 | 1 | None | n/a | standalone, no arrow | ✅ Match |
| T4 | 1 | None | n/a | standalone, no arrow | ✅ Match |
| T5 | 2 | T4 | no (T4 is Phase 1) | standalone start of chain, no incoming arrow | ✅ Match |
| T6 | 2 | T5 | yes | T5→T6 | ✅ Match |
| T7 | 2 | T6, T3 | T6 yes, T3 no (Phase 1) | T6→T7 | ✅ Match |
| T8 | 2 | T4 | no (T4 is Phase 1) | standalone, no arrow | ✅ Match |
| T9 | 3 | T4 | no (T4 is Phase 1) | standalone start of chain, no incoming arrow | ✅ Match |
| T10 | 3 | T9 | yes | T9→T10 | ✅ Match |
| T11 | 3 | T10, T7 | T10 yes, T7 no (Phase 2) | T10→T11 | ✅ Match |
| T12 | 3 | T11, T8 | T11 yes, T8 no (Phase 2) | T11→T12 | ✅ Match |
| T13 | 4 | T4 | no (T4 is Phase 1) | standalone, no arrow | ✅ Match |
| T14 | 4 | T4 | no (T4 is Phase 1) | standalone, no arrow | ✅ Match |
| T15 | 5 | T12, T13, T14 | none (all earlier phases) | standalone start of chain, no incoming arrow | ✅ Match |
| T16 | 5 | T15 | yes | T15→T16 | ✅ Match |
| T17 | 5 | T16 | yes | T16→T17 | ✅ Match |

**Rule check**: no task depends on a later-phase task — every `Depends on` points to an earlier or same-phase task. ✅

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: cryptography dep | pubspec config | none | none | ✅ OK |
| T2: AD-011 | project memory doc | none | none | ✅ OK |
| T3: constantTimeEquals | domain/core | unit | unit | ✅ OK |
| T4: id value types | domain entity (value holder) | none | none | ✅ OK |
| T5: Envelope | domain entity (value holder) | none | none | ✅ OK |
| T6: sign | domain/session | unit | unit | ✅ OK |
| T7: verify | domain/session | unit | unit | ✅ OK |
| T8: HandshakeService | domain/session | unit | unit | ✅ OK |
| T9: Room/ParticipantSession | domain entity (value holder) | none | none | ✅ OK |
| T10: state machine join/approve | domain/session | unit | unit | ✅ OK |
| T11: state machine envelope accept | domain/session | unit | unit | ✅ OK |
| T12: state machine TTL/disconnect | domain/session | unit | unit | ✅ OK |
| T13: TcpSessionTransport | infrastructure/network | integration | integration | ✅ OK |
| T14: NsdRoomDiscovery | infrastructure/network | integration | integration | ✅ OK |
| T15: RoomSessionController | data/session | integration | integration | ✅ OK |
| T16: E2E test | integration_test | integration_test (e2e) | integration_test (e2e) | ✅ OK |
| T17: purity sweep | none (verification) | none | none | ✅ OK |

No violations. No task defers its required tests to a later task.

---

## Tools Question (per skill process step 6)

For this feature, the tasks above already specify per-task tool usage. Notable points:
- **`context7` MCP** is called out for T8 (`cryptography` X25519/Hkdf API), T13 (`dart:io` socket close semantics), and T14 (`nsd` API) — all first-time or unfamiliar-API usage, per the Knowledge Verification Chain.
- **`flutter-clean-architecture` skill** is called out wherever new domain/infrastructure boundary placement needs confirming.
- **`flutter-quality-gates` skill** is called out for T17's final sweep.

No other project MCPs/skills apply to this feature's tasks (no UI, no routing, no widget performance concerns — those skills' triggers don't match this phase's scope).
