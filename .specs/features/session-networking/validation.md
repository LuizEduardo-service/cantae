# Session & Networking Validation

**Date**: 2026-10-06
**Spec**: `.specs/features/session-networking/spec.md`
**Diff range**: `d1b4c52..750b1cf` (branch `feat/phase-3-session-networking`); Round 2 isolated at `750b1cf~1..750b1cf`
**Verifier**: independent sub-agent (author ≠ verifier) — re-verification **iteration 3 of max 3 (final)**

This report supersedes the iteration-2 report. All coverage below was **re-derived from scratch** against the current tree (evidence-or-zero); iteration-2's citations were spot-checked independently rather than inherited, and its sensor mutation 3 was re-run as this round's primary sensor.

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1-T17 | ✅ Done | One atomic Conventional Commit each (`git log d1b4c52..HEAD`) |
| Fix round 1 (`4c3ca5d`, gaps 1-8) | ✅ Done | Independently re-confirmed in iteration 2; spot-re-checked here (see below) |
| Fix round 2 (`750b1cf`, 1 Major + 1 Minor) | ✅ Done | NET-06 test now discriminates (proven by mutation, below); NET id labels corrected |

---

## Round 2 Diff Review (`git show 750b1cf`)

`750b1cf` touches 7 files: 3 test files and 4 spec documents. **No `lib/` change at all** — product code is byte-identical to `4c3ca5d`.

| File | Change | Finding |
| ---- | ------ | ------- |
| `test/data/session/room_session_controller_test.dart:236-237` | NET-06 wait window `Duration(seconds: 5)` → `Duration(seconds: 1)`, plus an 8-line comment explaining why | ✅ Exactly the fix described, nothing else. Comment accurately records the iteration-2 finding. |
| `test/domain/session/envelope_authenticator_verify_test.dart:99` | test name `(NET-14)` → `(NET-13)` | ✅ Cosmetic relabel, matches spec.md's "P2 ACs 10-15" |
| `test/domain/session/room_session_state_machine_envelope_test.dart:93, 174` | `(NET-10/NET-14)` → `(NET-10/NET-13)`; `(NET-15)` → `(NET-14)` | ✅ Cosmetic relabel, correct against spec.md |
| `design.md`, `spec.md`, `tasks.md`, `validation.md` | NET id table fix, traceability update, Fix Round 2 section, iteration-2 report | ✅ Documentation only |

**No scope creep. No `tickInterval` override introduced.** Independently confirmed: `grep -rn "tickInterval" test/ integration_test/ lib/` returns only `test/data/session/room_session_controller_test.dart:127` and `:326` (both `Duration(milliseconds: 20)`), `lib/data/session/room_session_controller.dart:29/59/67/386` (field, default `5s`, assignment, `Timer.periodic`). **No long-interval override exists anywhere** — the reverted 1-hour-tick hang risk is confirmed absent from the tree.

### Spot-re-check of iteration-2's "verified" claims (not inherited)

| Claim | Independent finding this round |
| ----- | ------------------------------ |
| Pre-auth reset hole closed | ✅ `lib/domain/session/room_session_state_machine.dart:41-49` — `if (existing != null && !_isRejoinable(existing.state))` → `ValidationFailure('session.already-joined')`, returned **before** any mutation of `_participants`, so the victim's `sessionKey` is untouched. `_isRejoinable` (`:235-238`) admits only `rejected`/`disconnected`/`expired`. No bypass. |
| 10s handshake TTL frees the slot | ✅ `room_session_state_machine.dart:212-224` (`approvedSince` + `handshakeTtl`); `_admittedCount()` (`:240-246`) counts only `approved`+`connected`, so the `rejected` transition genuinely frees a slot. |
| `endRoom()` closes every connection + stops advertising | ✅ `lib/data/session/room_session_controller.dart:193-203`. Also newly mutation-tested this round (mutation 4, killed). |
| Tick sweep closes terminated participants | ✅ `room_session_controller.dart:398-410`, wired at `:388`. |
| NET-15 cross-forgery test is genuine | ✅ `test/domain/session/room_session_state_machine_envelope_test.dart:217` (keys differ), `:233-238` (forged envelope → `session.hmac-mismatch`, `lastAcceptedSequence` unchanged), `:253` (genuine keyB envelope accepted). |

---

## Spec-Anchored Acceptance Criteria

### P1: Discover, Request to Join, Get Approved, Handshake (NET-01..09)

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | -------------------- | ----------------------- | ------ |
| NET-01 advertise with service name, random room id, **no embedded secret** | service registered; nothing secret in the advert | `test/infrastructure/network/nsd_room_discovery_test.dart:67` - `expect(fakePlatform.registeredService!.name, equals('room-456'))`, `:68-71` `.type`, `:72` `.port`; `:86` - `expect(fakePlatform.registeredService!.txt, isNull)` | ✅ PASS |
| NET-02 list **every** LAN room within 5 s, no code required | all advertised rooms listed ≤5 s | `test/infrastructure/network/nsd_room_discovery_test.dart:124` - `await roomFuture.timeout(const Duration(seconds: 5))`, `:125-127` - `expect(room.id/host/port, ...)`; `test/data/session/room_session_controller_test.dart:82-83` - `expect(discoveredRoom.id, equals(roomId))` after a 5 s-bounded await | ⚠️ Spec-precision gap (unchanged, not worse) — one fake service is asserted, not "every room"; the 5 s bound is a test timeout over an in-process fake, not a real-LAN latency measurement |
| NET-03 valid code → TCP open + `pending-approval`, **no key exchange** | state `pendingApproval`, no session key | `test/domain/session/room_session_state_machine_join_test.dart:45` - `expect(session!.state, equals(ParticipantState.pendingApproval))`; `test/data/session/room_session_controller_test.dart:88-92` - pending participant observed on the master over real loopback TCP before any approve | ✅ PASS |
| NET-04 wrong code → typed failure, **no pending entry** | `ValidationFailure('session.invalid-code')`, no entry | `test/domain/session/room_session_state_machine_join_test.dart:62` - `expect(f, isA<ValidationFailure>())`, `:63` - `expect(f.code, equals('session.invalid-code'))`, `:66` - `expect(machine.participant(const ParticipantId('device-1')), isNull)` | ✅ PASS |
| NET-05 approve → X25519 ECDH + HKDF session key | matching 32-byte key on both ends | `test/domain/session/handshake_service_test.dart:50` - `expect(aliceBytes.length, equals(32))`, `:52` - `expect(bobBytes, equals(aliceBytes))`; `test/data/session/room_session_controller_test.dart:112` - `expect(connected.sessionKey!.length, equals(32))`; `integration_test/session_networking_test.dart:165-167` - `expect(masterSideKey, equals(visitorSideKey))` | ✅ PASS |
| NET-06 reject → close TCP, no key exchange | socket closed by `reject()`; no handshake | domain: `test/domain/session/room_session_state_machine_join_test.dart:259` - `expect(session!.state, equals(ParticipantState.rejected))`; transport: `test/data/session/room_session_controller_test.dart:236-237` - `visitorTransport.closedConnections.first.timeout(Duration(seconds: 1))`, `:241` - `expect(closedConnectionId, equals(visitor.debugMasterConnection))` | ✅ PASS — **and now discriminating**, proven by sensor mutation 1 |
| NET-07 handshake failure (malformed key, >10 s) → typed failure, not admitted | `session.handshake-failed`; slot freed | `test/domain/session/handshake_service_test.dart:72` and `:88` - `expect(f.code, equals('session.handshake-failed'))` (malformed peer key; wrong-length derived key); `test/domain/session/room_session_state_machine_lifecycle_test.dart:120` - `tick(+11s)` → `expect(session!.state, equals(ParticipantState.rejected))`; `:131` boundary at exactly 10 s still `approved`; `:158` - `expect(afterTimeout.isSuccess, isTrue)` (slot actually freed in a full 8/8 room) | ✅ PASS |
| NET-08 reject join at 8 approved, before any handshake step | `ValidationFailure('session.room-full')` | `test/domain/session/room_session_state_machine_join_test.dart:88` - `expect(f.code, equals('session.room-full'))` (room filled 8/8 at `:73-77`, failure raised in `requestJoin` before `approve` is ever reached); `integration_test/session_networking_test.dart:286-290` - 9th join over real TCP fails `session.room-full` | ✅ PASS |
| NET-09 pending expires after 60 s → `rejected` | state `rejected` after >60 s | `test/domain/session/room_session_state_machine_join_test.dart:287` - `tick(+61s)` → `expect(session!.state, equals(ParticipantState.rejected))`; `:297` boundary — exactly 60 s is still `pendingApproval`; `test/data/session/room_session_controller_test.dart:168-179` - real `Timer.periodic` (20 ms) + fake clock drives it end-to-end | ✅ PASS |

### P2: Authenticated, Replay-Protected Envelopes (NET-10..15)

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | -------------------- | ----------------------- | ------ |
| NET-10 (P2.1) envelope carries monotonic per-sender sequence + HMAC-SHA-256 | HMAC-SHA-256 over the envelope with the sender's session key; sequence increments per send | `test/domain/session/envelope_authenticator_sign_test.dart` (sign shape + determinism); `lib/data/session/room_session_controller.dart:141` - `_visitorNextSequence++` per send; `integration_test/session_networking_test.dart:176-178` - `lastAcceptedSequence` goes `0` → `1` | ✅ PASS |
| NET-11 (P2.2) bad HMAC discarded, **state unapplied** | `session.hmac-mismatch`, state unchanged | `test/domain/session/envelope_authenticator_verify_test.dart:40-42`; `test/domain/session/room_session_state_machine_envelope_test.dart:167` - `expect(f.code, equals('session.hmac-mismatch'))` **and** `:170` - `expect(session!.lastAcceptedSequence, equals(-1))`; `integration_test/session_networking_test.dart:204-207` | ✅ PASS |
| NET-12 (P2.3) sequence ≤ last accepted → replay, not applied | `session.replay-detected`, state unchanged | `test/domain/session/envelope_authenticator_verify_test.dart:70` (strictly-less case) and `:85` (`==` boundary) - `expect(f.code, equals('session.replay-detected'))`; `integration_test/session_networking_test.dart:239-242` - `lastAcceptedSequence` unchanged after a valid-HMAC replay. Boundary case independently mutation-tested (sensor mutation 2) | ✅ PASS |
| NET-13 (P2.4) valid HMAC + strictly greater sequence → accept, apply, advance | accepted; `lastAcceptedSequence` advances | `test/domain/session/room_session_state_machine_envelope_test.dart:105` - `expect(result.isSuccess, isTrue)`, `:107` - `expect(session!.lastAcceptedSequence, equals(1))`; `test/domain/session/envelope_authenticator_verify_test.dart:89-97` (gap of 10000 accepted) | ✅ PASS |
| NET-14 (P2.5) Master-only message from a Visitor → rejected, not applied | `ValidationFailure('session.unauthorized-role')`, state unchanged | `test/domain/session/room_session_state_machine_envelope_test.dart:194` - `expect(f, isA<ValidationFailure>())`, `:195` - `expect(f.code, equals('session.unauthorized-role'))`, `:199` - `expect(session!.lastAcceptedSequence, equals(-1))`; `integration_test/session_networking_test.dart:255-258`. Independently mutation-tested (sensor mutation 3) | ✅ PASS |
| NET-15 (P2.6) distinct session key per participant; no cross-forgery | forged cross-sender envelope rejected | `test/domain/session/room_session_state_machine_envelope_test.dart:217` (`keyA` vs `keyB` asserted distinct), `:233-236` (`device-b` envelope signed with `keyA` → `session.hmac-mismatch`), `:238` (`device-b.lastAcceptedSequence` still `-1`), `:253` (genuine keyB envelope accepted) | ✅ PASS |

### P3: Session Lifecycle (NET-16..20)

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | -------------------- | ----------------------- | ------ |
| NET-16 30 min silence → `expired`, slot freed, socket closed | state `expired`; slot freed; TCP closed | `test/domain/session/room_session_state_machine_lifecycle_test.dart:171` - `tick(+31min)` → `expect(session!.state, equals(ParticipantState.expired))`; `:182` boundary — exactly 30 min still `connected`; `:203` - `expect(afterExpiry.isSuccess, isTrue)` (slot freed in a previously full room); socket: `test/data/session/room_session_controller_test.dart:365-370` - `visitorTransport.closedConnections.first.timeout(5s)` awaited after the clock advances (times out → test fails if the socket is never closed) | ✅ PASS |
| NET-17 TCP close (clean or abrupt) → `disconnected`, slot freed, key unusable | state `disconnected`, `sessionKey == null`, old key rejected | `test/domain/session/room_session_state_machine_lifecycle_test.dart:59` - `expect(session!.state, equals(ParticipantState.disconnected))`, `:60` - `expect(session.sessionKey, isNull)`; `:80` - old key → `session.participant-not-found`; end-to-end: `test/data/session/room_session_controller_test.dart:420` - `visitorTransport.destroy(...)` (abrupt kill), `:432` - `expect(disconnected.state, equals(ParticipantState.disconnected))` | ✅ PASS |
| NET-18 rejoin after disconnected/expired → brand-new join, never resume key | new `pendingApproval`, `sessionKey == null` | `test/domain/session/room_session_state_machine_lifecycle_test.dart:102` - `expect(session!.state, equals(ParticipantState.pendingApproval))`, `:103` - `expect(session.sessionKey, isNull)`; `test/domain/session/room_session_state_machine_join_test.dart:171-173` - rejoin after `rejected` allowed. Negative side locked by `:130-136` / `:151-154` (`session.already-joined` for a connected/approved device) | ✅ PASS |
| NET-19 hard cap of 8 approved at request, approval, reconnect | `session.room-full` at each decision point | request: `test/domain/session/room_session_state_machine_join_test.dart:88`; approval (two pending racing for the last slot): `:241` - `expect(firstApproval.isSuccess, isTrue)`, `:242/:245` - second → `session.room-full`; reconnect/freed slot: `test/domain/session/room_session_state_machine_lifecycle_test.dart:203`. Product-side both gates present: `room_session_state_machine.dart:51` (requestJoin) and `:79` (approve) | ✅ PASS |
| NET-20 endRoom → all `disconnected`, every TCP closed, mDNS stopped | all disconnected, sockets closed, advertising stopped | `test/domain/session/room_session_state_machine_lifecycle_test.dart:227` - every participant `disconnected`, `:228` - `sessionKey` null, `:230` - `expect(machine.room.state, equals(RoomLifecycle.ended))`; `test/data/session/room_session_controller_test.dart:292-297` - visitor-side close awaited (5 s timeout), `:298` - `expect(discoveryCalls, contains('stopAdvertising'))`, `:310` - `room.state == RoomLifecycle.ended`. Independently mutation-tested (sensor mutation 4) | ✅ PASS |

**Status**: ✅ 19/20 ACs covered with spec-matching, discriminating assertions. 1 ⚠️ spec-precision gap (NET-02), unchanged from iteration 2 and accepted as a sandbox limitation (no real multicast LAN available; `design.md` Risks records the same).

---

## Discrimination Sensor

All mutations applied **only** in the Verifier's disposable verification worktree, each reverted with `git checkout -- <file>`. `git status --porcelain` was empty before the first mutation and empty after every revert (verified 4×). No `git stash` used.

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| 1 (re-run of iteration-2's surviving mutant 3) | `lib/data/session/room_session_controller.dart:185` | Removed `_closeConnectionFor(id)` from `reject()` | ✅ **Killed** — `reject() closes the rejected participant's transport connection (NET-06)` failed with `TimeoutException after 0:00:01.000000: Future not completed`. Failed **promptly** (~1 s after `reject()`); the whole file ran in 27 s with no hang. |
| 2 | `lib/domain/session/envelope_authenticator.dart:44` | Replay boundary `envelope.sequence <= lastAcceptedSequence` → `<` (equal sequence accepted) | ✅ Killed — `sequence exactly equal to last accepted is rejected as replay-detected (boundary, NET-12)` failed; the strictly-less test correctly still passed (precise, not blanket, discrimination) |
| 3 | `lib/domain/session/room_session_state_machine.dart:158` | Disabled role enforcement: `if (requiresMasterRole && …)` → `if (false && requiresMasterRole && …)` | ✅ Killed — `a Visitor sending a Master-only message type is rejected and state is unchanged (NET-14)` failed |
| 4 | `lib/data/session/room_session_controller.dart:195-197` | Removed the connection-close loop from `endRoom()` | ✅ Killed — `endRoom() disconnects every participant, closes every connection, and stops advertising (NET-20)` failed |

**Sensor depth**: P0-leaning (4 mutations; this is auth/session-integrity code). Mutations 2-4 target code not previously exercised adversarially.
**Result**: **4/4 killed — PASS ✅**

**Note on mutation 1's margin (observation, not a gap):** the NET-06 test's discrimination depends on `reject()` being called more than 1 s before the master's first 5 s tick. Measured on this machine: the test body reaches `reject()` well under 1 s after `createRoom()`, leaving ≈4 s of margin; the ~5 s per-test wall time observed for the default-`tickInterval` controller tests is the Dart test runner draining the outstanding periodic `Timer` **after** the body finishes, not setup latency. The margin is comfortable, and a future shrink of it would degrade the test to non-discriminating (silently passing), never to a false failure.

---

## Code Quality

Checked against `references/coding-principles.md`, scoped to Round 2 (`git show 750b1cf --stat`: 3 test files + 4 spec docs; **zero `lib/` changes**) and re-confirmed over the cumulative feature diff.

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ — Round 2 is a one-token test change (`seconds: 5` → `seconds: 1`) plus 3 test-name relabels |
| Surgical changes | ✅ — only the file the gap named, plus the two files holding the mislabelled test names |
| No scope creep | ✅ — no product code touched, no new abstractions, no `tickInterval` override introduced |
| Matches patterns | ✅ — `Result<S, Failure>` with typed `code` strings, no `throw` in `domain/`, pure `tick(DateTime)` with an injected clock, `copyWith` + explicit `clearX` flags |
| Domain purity | ✅ — `python scripts/check_layers.py --root .` exit 0; `dart analyze lib/domain/` clean |
| Spec-anchored outcome check | ⚠️ — 19/20 match exactly; NET-02 flagged, not rounded up |
| Per-layer Coverage Expectation met | ✅ — domain 1:1 AC mapping; data/infrastructure covered by real-loopback-TCP tests; e2e covers happy + adversarial + capacity paths |
| Every test maps to a spec requirement — no unclaimed tests | ✅ — all 185 tests trace to an AC, a listed edge case, or a Done-when criterion |
| Would a senior engineer approve? | ✅ — the fix is the right shape: it removes the masking window instead of adding test machinery (the reverted 1-hour-tick alternative would have traded a weak test for a 1-hour hang) |
| Documented guidelines followed | ✅ — `CLAUDE.md` (Result/no-throw, complexity ≤15, layer purity, Conventional Commits, E2E-first testing), `references/coding-principles.md` |

---

## Edge Cases

- [x] **Concurrent join, 1 slot left → at most one admit** — `test/domain/session/room_session_state_machine_join_test.dart:241-245`: first approval succeeds, second fails `session.room-full`. No race-dependent double-admit (the cap is re-checked inside `approve()` at `room_session_state_machine.dart:79`, not only at request time).
- [x] **Master loses network mid-handshake → never silently approved** — pending stays `pendingApproval` until the 60 s expiry (`room_session_state_machine_join_test.dart:287/:297`); a stalled *approved* handshake additionally times out at 10 s (`room_session_state_machine_lifecycle_test.dart:110-158`) rather than holding the slot forever.
- [x] **Huge forward sequence gap is legal, not replay** — `test/domain/session/envelope_authenticator_verify_test.dart:89-97`: sequence 10001 against last-accepted 1 is accepted.
- [x] **Wrong-length derived key is a handshake failure, never truncated/padded** — `test/domain/session/handshake_service_test.dart:76-89`: injected HKDF returning 16 bytes → `session.handshake-failed`.
- [x] **Code rotation out of scope** — no rotation mechanism exists; `Room.code` is immutable for the room's lifetime (`lib/domain/session/room.dart`).

---

## Gate Check

- **Gate command**: `flutter analyze` → `flutter test` → `python scripts/check_layers.py --root .` → `dart analyze lib/domain/`
- `flutter analyze`: **No issues found!** (ran in 2.1 s, exit 0)
- `flutter test`: **185 passed, 0 failed, 0 skipped** (exit 0) — **total wall time 37.9 s**, no hang, no outlier test. The slowest tests are the 4 real-loopback-TCP controller tests at ~5 s each; that tail is the test runner draining the controller's default 5 s periodic `Timer` after each body completes, which is expected and bounded.
- `python scripts/check_layers.py --root .`: OK — no forbidden imports in `lib/domain/` (exit 0)
- `dart analyze lib/domain/`: No issues found (exit 0)
- `integration_test/session_networking_test.dart`: at verification time, no device existed in this sandbox, so it was verified via a scratch-copy VM run (1 passed). **Superseded after this report**: `android/`/`ios/` platform scaffolding was generated, a physical Android phone (API 33) was connected over USB, and the test was run for real via `flutter test -d <device-id> integration_test/session_networking_test.dart`. **Result: `All tests passed!`** — the full 16-step transition log printed on real hardware, including `adversarial: tampered payload + stale HMAC rejected, state unchanged`, `adversarial: replayed sequence rejected, state unchanged`, `adversarial: Visitor-sent Master-only message rejected, state unchanged`, `well-formed next-sequence message accepted after adversarial attempts`, `9th join request rejected: session.room-full`. This is the first run of this feature's real `nsd_android` plugin channel and real Android TCP/crypto path (the VM scratch copy never touches either). Details in tasks.md's "Real-Device Confirmation" section.
- **Test count before this feature**: 110 (Phase 2 handoff)
- **Test count after T17**: 172 · **after fix round 1**: 185 · **after fix round 2**: 185 (unchanged — Round 2 strengthened an existing test and relabelled names; it added none)
- **Delta**: +75
- **Test integrity**: no test deleted; no assertion weakened. The one weak assertion found in iteration 2 (NET-06) was **strengthened**, and the strengthening is empirically proven by sensor mutation 1.

---

## Fix Plans

**None required.** The iteration-2 Major gap is closed and proven closed by independent mutation. The only open item is the acknowledged NET-02 spec-precision gap:

### Carried (accepted, not a merge blocker): NET-02 precision

- **Root cause**: "list **every** room advertised on the same LAN within 5 seconds" is asserted with a single fake service and a test timeout, not a multi-room count or a real-LAN latency measurement.
- **Why accepted**: real mDNS multicast is not exercisable in this sandbox; `design.md`'s Risks section already records this. The infrastructure adapter's mapping logic *is* covered; only the "every room" cardinality and the real-world latency bound are not.
- **Recommendation (Minor, not blocking)**: when Phase 5's room-list UI lands on real devices, add a two-service fake-platform assertion (cheap, closes the cardinality half) and record a manual on-device latency observation (closes the latency half).
- **Priority**: Minor

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| NET-01 | ✅ Verified | ✅ Verified |
| NET-02 | ⚠️ Verified (spec-precision gap) | ⚠️ Verified (spec-precision gap — accepted) |
| NET-03 | ✅ Verified | ✅ Verified |
| NET-04 | ✅ Verified | ✅ Verified |
| NET-05 | ✅ Verified | ✅ Verified |
| NET-06 | ⚠️ Fixed, pending re-verification | ✅ **Verified** (discrimination proven by sensor mutation 1) |
| NET-07 | ✅ Verified | ✅ Verified |
| NET-08 | ✅ Verified | ✅ Verified |
| NET-09 | ✅ Verified | ✅ Verified |
| NET-10 | ✅ Verified | ✅ Verified |
| NET-11 | ✅ Verified | ✅ Verified |
| NET-12 | ✅ Verified | ✅ Verified |
| NET-13 | ✅ Verified | ✅ Verified |
| NET-14 | ✅ Verified | ✅ Verified |
| NET-15 | ✅ Verified | ✅ Verified |
| NET-16 | ✅ Verified | ✅ Verified |
| NET-17 | ✅ Verified | ✅ Verified |
| NET-18 | ✅ Verified | ✅ Verified |
| NET-19 | ✅ Verified | ✅ Verified |
| NET-20 | ✅ Verified | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready to merge

**Spec-anchored check**: 19/20 ACs matched the spec-defined outcome exactly; 1 spec-precision gap (NET-02), accepted and documented, unchanged from iteration 2
**Sensor**: 4/4 mutations killed (including the iteration-2 survivor, re-run as this round's primary sensor)
**Gate**: `flutter test` 185 passed / 0 failed / 0 skipped in 37.9 s; `flutter analyze` clean; layer purity clean; `dart analyze lib/domain/` clean; e2e passes via scratch copy with a reviewable artifact log

**What works**: The iteration-2 blocker is genuinely fixed. Deleting `_closeConnectionFor(id)` from `RoomSessionController.reject()` now fails the NET-06 test in ~1 s with a `TimeoutException` — the periodic sweep can no longer mask it, and the failure is prompt rather than a timeout-hang. Three additional mutations on code never previously tested adversarially (replay boundary, role enforcement, `endRoom()`'s close loop) were all killed by exactly the right test, so the suite's discrimination is not a one-off. The feared 1-hour-`tickInterval` hang is confirmed absent from the tree: the only `tickInterval` overrides anywhere are two 20 ms values, and the full suite completes in 38 s. Round 2's diff is minimal and surgical — zero product-code change, one test constant, three test-name relabels. All 20 ACs, all 5 listed edge cases, and all 7 Round-1 fixes were re-derived from the current tree with fresh `file:line` evidence rather than inherited from the prior report.

**Issues found**: None blocking. One carried Minor: NET-02's "every room within 5 s" remains asserted via a single-service fake and a test timeout (sandbox limitation, documented in `design.md` Risks). One observation recorded above: NET-06's discrimination rests on a timing margin (~4 s measured) rather than a structural guarantee; if that margin ever shrinks, the test degrades to silently non-discriminating rather than failing loudly.

**Next steps**: Merge `feat/phase-3-session-networking` — real-device E2E confirmation (see Gate Check) has since closed the one deferred item from this report. Fold the NET-02 cardinality/latency assertions into Phase 5's room-list work.
