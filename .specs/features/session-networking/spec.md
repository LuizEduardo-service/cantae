# Session & Networking Specification

## Problem Statement

Cantaê is local-first: rehearsals happen peer-to-peer over LAN with no cloud backend. Before any shared playback (Phase 4/5) can exist, devices need a secure way to find each other on the same Wi-Fi, have a host approve who joins, and exchange messages that cannot be forged or replayed by another device on the network. This feature builds that session layer: discovery, join approval, ephemeral-key handshake, and authenticated message envelopes.

## Goals

- [ ] A device can discover nearby rooms over mDNS and request to join with a 4-digit code
- [ ] The master explicitly approves or rejects each join request before any key exchange happens
- [ ] Approved devices complete an ephemeral X25519 ECDH handshake and derive a per-session HMAC key
- [ ] Every post-handshake message is authenticated (HMAC-SHA-256) and protected against replay (monotonic sequence)
- [ ] Session lifecycle (capacity, inactivity TTL, disconnect, role enforcement) is governed by a single, pure, testable state machine

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
| --- | --- |
| File/audio transfer over the session | Belongs to Phase 4 ("File transfer & real audio") — this feature only establishes the authenticated channel |
| Multi-track playback / sync / mixing | Belongs to Phase 1/4/5 — this feature carries opaque authenticated envelopes, it does not interpret playback payloads |
| Master election / failover | Out of scope for MVP per CLAUDE.md — the device that creates the room is always master for its lifetime |
| Internet/cloud relay, NAT traversal | Local-first constraint — LAN-only mDNS discovery and direct TCP, no WAN path |
| UI screens (room list, approval dialog, lobby) | Belongs to Phase 5 — this feature delivers the domain/data/infrastructure session layer consumed by that UI |
| Session resume after reconnect without re-approval | Rejected in discussion — every reconnect redoes the full handshake (see Assumptions) |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Handshake crypto scheme | Ephemeral X25519 ECDH per join, HKDF-derived session HMAC key | Forward secrecy per session; 4-digit code stays a discovery/UX gate, never a crypto secret | y |
| Join approval flow | Manual — master sees a pending request and must explicitly approve/reject | Matches CLAUDE.md's "visitor cannot auto-download" posture — no network action proceeds without a host decision | y |
| Reconnect-within-TTL behavior | Full handshake + new master approval on every reconnect, no session-resume token | Single entry path is simpler to verify and closes a replay surface a resume-token would open; reopened later if UX friction proves real in testing | y |
| Transport topology | Star: every participant holds one direct TCP connection to the master; no visitor-to-visitor links | Matches CLAUDE.md's master-room / singer-player screen split (Phase 5) — only the master needs the full participant graph | y |
| Where crypto/state-machine logic lives | Handshake math (X25519/HKDF/HMAC) and the session state machine live in `domain/` (pure Dart, no Flutter/plugin deps); mDNS and raw TCP sockets live in `infrastructure/` | `crypto`/`cryptography` are pure-Dart packages with no platform channel — they don't violate AD-001's domain-purity rule; `nsd` and `dart:io` sockets do, so they're confined to infrastructure |  y |
| Join-request pending queue size | Unbounded by a separate limit; capped implicitly by the 8-participant room limit plus a 60s per-request expiry | No signal this needs its own limit; reuses existing room-capacity and timeout concepts instead of inventing a new one | y |
| Clock basis for TTL / sequence | Monotonic local clock on the master (`Duration` since last authenticated message per participant), not wall-clock timestamps in envelopes | Avoids cross-device clock-skew bugs; replay detection only needs ordering (sequence number), not wall time | y |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Discover, Request to Join, Get Approved, Handshake ⭐ MVP

**User Story**: As a singer arriving at rehearsal, I want to find the room on my phone, enter the 4-digit code, and have the host let me in, so that I'm securely connected before any audio starts.

**Why P1**: Nothing else in Phase 3+ is reachable without a discovered, approved, authenticated connection. This is the minimum vertical slice: two devices, one becomes master, the other finds it, joins, and both end up holding a shared session key.

**Acceptance Criteria**:

1. WHEN a master device creates a room THEN the system SHALL advertise it over mDNS with a service name, a random room ID, and no embedded secret.
2. WHEN a visitor device scans THEN the system SHALL list every room advertised on the same LAN within 5 seconds, without requiring the code yet.
3. WHEN a visitor submits a join request with a 4-digit code THEN the system SHALL open a TCP connection to the master and transition the request to `pending-approval` without performing any key exchange.
4. IF the submitted 4-digit code does not match the master's current code THEN the system SHALL reject the request with a typed failure and SHALL NOT create a pending-approval entry.
5. WHEN the master approves a pending request THEN the system SHALL run an ephemeral X25519 ECDH handshake with that visitor and derive a session HMAC key via HKDF.
6. WHEN the master rejects a pending request THEN the system SHALL close the TCP connection and SHALL NOT perform any key exchange.
7. IF a handshake step fails (malformed key, timeout > 10s) THEN the system SHALL abort the join for that device with a typed failure and SHALL NOT admit it to the room.
8. The system SHALL reject a join request WHEN the room already holds 8 approved participants, before any handshake step runs.
9. WHILE a join request is in `pending-approval` the system SHALL expire it after 60 seconds of no master decision, returning it to `rejected`.

**Independent Test**: Run two app instances on the same Wi-Fi; create a room on one, discover and join from the other with the correct code, approve on the master, and assert both sides report a derived session key of the expected length (32 bytes) and matching value on both ends.

---

### P2: Authenticated, Replay-Protected Message Envelopes

**User Story**: As the master, I want every message after handshake to be provably from an approved participant and impossible to replay, so a rogue device on the same Wi-Fi can't inject or resend commands.

**Why P2**: The handshake alone only proves identity once; every subsequent message needs its own integrity guarantee, and this is squarely the "forged/replayed/unauthorized messages do not alter app state" acceptance gate from CLAUDE.md.

**Acceptance Criteria**:

1. WHEN a participant sends a message THEN the system SHALL wrap it in an envelope carrying a monotonically increasing per-sender sequence number and an HMAC-SHA-256 computed over the envelope with that participant's session key.
2. WHEN the master receives an envelope THEN the system SHALL recompute the HMAC with the sender's stored session key and SHALL discard the message without applying it to session state if the HMAC does not match.
3. IF an incoming envelope's sequence number is less than or equal to the highest sequence number already accepted from that sender THEN the system SHALL discard it as a replay and SHALL NOT apply it to session state.
4. WHEN a message's HMAC is valid and its sequence number is strictly greater than the sender's last accepted sequence THEN the system SHALL accept it, apply it, and advance that sender's last-accepted sequence.
5. IF a message of a type requiring Master privilege is received from a participant whose role is Visitor THEN the system SHALL reject it and SHALL NOT apply it to session state.
6. The system SHALL use a distinct session HMAC key per participant, so that no participant can forge a message on behalf of another.

**Independent Test**: With a live session, craft envelopes with (a) a tampered payload and stale-but-correct HMAC key, (b) a correct HMAC but a replayed sequence number, (c) a Visitor-role sender on a Master-only message type; assert all three are rejected and session state is unchanged, while a well-formed next-sequence message from the right role is accepted.

---

### P3: Session Lifecycle — Capacity, TTL, Disconnect, Cleanup

**User Story**: As the master, I want stale or disconnected participants cleared automatically and the room to stay within its 8-device cap, so the room doesn't silently accumulate dead slots or let a 9th singer in.

**Why P3**: Not needed to demo the happy path (P1+P2 already prove join + secure messaging), but required before this feature is production-ready per CLAUDE.md's "Session TTL: 30 min inactivity" and "Max 8 participants" acceptance gates.

**Acceptance Criteria**:

1. WHILE a participant has sent no authenticated message for 30 minutes THE system SHALL transition that participant to `expired`, free their room slot, and close their TCP connection.
2. WHEN a participant's TCP connection closes (clean or abrupt) THEN the system SHALL transition them to `disconnected`, free their room slot, and SHALL NOT keep their session key usable for new messages.
3. IF a device that was previously `disconnected` or `expired` tries to rejoin THEN the system SHALL treat it as a brand-new join request (full P1 flow), never resuming the old session key.
4. The system SHALL enforce a hard cap of 8 `approved` participants per room at every join decision point (request, approval, reconnect).
5. WHEN the master ends the room THEN the system SHALL transition every participant to `disconnected`, close every TCP connection, and stop mDNS advertisement.

**Independent Test**: Simulate a participant going silent for the TTL window and assert their slot frees and their old session key is rejected on any further message; separately, kill the TCP socket from the visitor side and assert the master detects `disconnected` and frees the slot without waiting for the TTL.

---

## Edge Cases

- IF two visitors submit join requests with the same 4-digit code at the same moment and only 1 slot remains THEN the system SHALL approve at most one and reject the other with a capacity failure, not a race-dependent double-admit.
- IF the master device itself loses network mid-handshake with a visitor THEN the system SHALL leave that visitor in `pending-approval` until the 60s expiry fires — never silently `approved`.
- IF an envelope arrives with a sequence number far beyond any plausible next value (e.g., sequence jumps by 10000+) THEN the system SHALL still accept it as valid forward progress — sequence gaps are legal (dropped packets), only non-increasing sequences are replay.
- IF a participant is approved but the HKDF/X25519 handshake math produces a key of unexpected length THEN the system SHALL treat it as a handshake failure (AC P1.7), never truncate/pad silently.
- WHEN the room's 4-digit code is regenerated (not specified as a trigger in this feature — no rotation mechanism is built) THEN this is explicitly out of scope; the code is fixed for the room's lifetime.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| NET-01 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-02 | P1: Discover/Join/Approve/Handshake | Execute | ⚠️ Verified (spec-precision gap) |
| NET-03 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-04 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-05 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-06 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-07 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-08 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-09 | P1: Discover/Join/Approve/Handshake | Execute | ✅ Verified |
| NET-10 | P2: Authenticated Envelopes | Execute | ✅ Verified |
| NET-11 | P2: Authenticated Envelopes | Execute | ✅ Verified |
| NET-12 | P2: Authenticated Envelopes | Execute | ✅ Verified |
| NET-13 | P2: Authenticated Envelopes | Execute | ✅ Verified |
| NET-14 | P2: Authenticated Envelopes | Execute | ✅ Verified |
| NET-15 | P2: Authenticated Envelopes | Execute | ✅ Verified |
| NET-16 | P3: Session Lifecycle | Execute | ✅ Verified |
| NET-17 | P3: Session Lifecycle | Execute | ✅ Verified |
| NET-18 | P3: Session Lifecycle | Execute | ✅ Verified |
| NET-19 | P3: Session Lifecycle | Execute | ✅ Verified |
| NET-20 | P3: Session Lifecycle | Execute | ✅ Verified |

**ID format:** `NET-[NUMBER]`, assigned in spec order (P1 ACs 1-9, P2 ACs 10-15, P3 ACs 16-20).

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 20 total, 20 mapped to tasks (T1-T17 + fix rounds 1-2). Verification iteration 3 — final (`.specs/features/session-networking/validation.md`): **19 ✅ Verified, 1 ⚠️ spec-precision gap (NET-02, accepted — real-LAN multicast not exercisable in this sandbox)**. Discrimination sensor 4/4 mutations killed, including a re-run of the iteration-2 survivor on NET-06. Gate: 185 tests passed, 0 failed. Ready to merge.

---

## Success Criteria

- [ ] Two physical/emulated devices on the same Wi-Fi can discover, join (with manual approval), and complete a handshake producing matching 32-byte session keys on both ends
- [ ] A forged, replayed, or role-unauthorized message never changes session state (automated test proves it for all three cases)
- [ ] A room never exceeds 8 approved participants under concurrent join attempts
- [ ] A silent participant is expired and their slot freed within the 30-minute TTL, with no manual intervention
- [ ] `domain/` session state machine and handshake math compile with `dart compile` (no Flutter SDK) — layer-purity check stays clean
