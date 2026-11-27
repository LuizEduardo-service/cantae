# Criar sala + Entrar em sala (room-entry) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/room-entry/design.md`
**Status**: In Progress

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found:
> - `AGENTS.md` §5/§7: a widget test per component (states, dark theme, semantics); every screen state; 130 % font; ≥ 44 dp.
> - `CLAUDE.md`: failure-first for isolated systems; E2E for features with a reviewable artifact.
> - AD-010: repositories on `NativeDatabase.memory()`.
> - Standing rule: every bug gets a failing regression test in the same commit as its fix.
>
> Sampled: `test/data/session/room_session_controller_test.dart` (loopback TCP + bus discovery), `test/domain/session/*_test.dart`, `test/infrastructure/database/app_database_migration_test.dart`, `test/presentation/providers/song_editor_notifier_test.dart`, `test/presentation/screens/song_editor/song_editor_screen_test.dart`, `test/e2e/track_upload_flow_test.dart`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Domain (rules, state machine) | unit (failure modes first) | 1:1 to ROOM-02, 34, 46, 48; boundaries 0/1/40/41; every failure code → outcome | `test/domain/session/*_test.dart` | `flutter test test/domain/session` |
| Domain ports (`RoomDiscovery`, `SystemSettings`, `LocalProfileRepository`) | none | Build gate; behaviour tested through adapters and fakes | - | build gate |
| Data (wire codec) | unit | v2 round-trip, legacy body = version 0, empty/long name | `test/data/session/session_wire_message_test.dart` | `flutter test test/data/session` |
| Data (controller) | integration (loopback TCP + bus discovery) | Every new join outcome on the wire, cancel, leave, lost connection, announcement, reasons | `test/data/session/room_session_controller_test.dart` | `flutter test test/data/session` |
| Infrastructure (schema, migration) | unit | v5 → v6 keeps every table; new table | `test/infrastructure/database/*_test.dart` | `flutter test test/infrastructure/database` |
| Data (profile repository) | unit (`NativeDatabase.memory()`) | Device id created once and stable; name saved; failures → `StorageFailure` | `test/data/repositories/*_test.dart` | `flutter test test/data/repositories` |
| Infrastructure (NSD TXT mapping) | unit on the pure mapping functions | TXT round-trip, 255-byte cut, missing keys, `lost`, `securityIssue` → permission code | `test/infrastructure/network/*_test.dart` | `flutter test test/infrastructure/network` |
| Infrastructure (manifests, native channel) | none | Build gate + device script | - | build gate |
| Presentation (notifiers) | unit (fake discovery + loopback TCP or fake controller) | Every state and transition of HostRoomState / JoinRoomState / MemberRoomState | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers` |
| Presentation (widgets) | widget | Every variant, dark theme, semantics labels, ≥ 44 dp | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets` |
| Presentation (screens, routes) | widget (e2e-equivalent) | Every spec state with its text and action, confirmations, navigation, both themes, 360 dp at 130 % | `test/presentation/screens/room_*/*_test.dart` | `flutter test test/presentation/screens` |
| Feature flow | widget e2e (two real controllers on loopback TCP, in-memory discovery, real DB in memory) | Name → Criar sala → pedido → aprovar → sala; recusa; código errado; encerrar; artifact = printed log | `test/e2e/room_entry_flow_test.dart` | `flutter test test/e2e` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After a task with tests in one area | `flutter test <changed test file(s)>` |
| Full | After a task that changes a shared contract (port, controller, schema, routing) | `flutter test` |
| Build | After phase completion | `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test && python scripts/check_layers.py` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Domain

```
T1 → T2 → T3
```

### Phase 2: Session, discovery, persistence and platform

```
T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11
```

### Phase 3: Application state

```
T12 → T13 → T14 → T15
```

### Phase 4: Components

```
T16 → T17 → T18 → T19 → T20 → T21
```

### Phase 5: Screens and routes

```
T22 → T23 → T24 → T25 → T26 → T27
```

### Phase 6: Flow and device script

```
T28 → T29
```

Full cross-phase chain:

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11 → T12 → T13 → T14 → T15 → T16 → T17 → T18 → T19 → T20 → T21 → T22 → T23 → T24 → T25 → T26 → T27 → T28 → T29
```

---

## Task Breakdown

### T1: Room entry rules

**What**: Pure `roomProtocolVersion = 1`, `displayNameMaxLength = 40`, `validateDisplayName`, `sanitizeRemoteDisplayName`, `JoinOutcome` and `joinOutcomeFor(Failure)`.
**Where**: `lib/domain/session/room_entry_rules.dart`
**Depends on**: None
**Reuses**: `song_rules.dart` shape, `ValidationFailure`
**Requirement**: ROOM-02, ROOM-34, ROOM-35, ROOM-36, ROOM-48

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes in the test header, then tests: name blank, 1, 40, 41 chars; trimmed result; remote name with control characters, 200 chars, only spaces → "Sem nome"; each code (`session.rejected`, `room-full`, `protocol-mismatch`, `request-expired`, `invalid-code`, `join-cancelled`) → its outcome; unknown code → `connectionLost`
- [x] `python scripts/check_layers.py` passes
- [x] Gate check passes: `flutter test test/domain/session`
- [x] Test count: all existing + ≥ 12 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): add the display name and join outcome rules`

---

### T2: Join request carries name and protocol version

**What**: `RoomSessionStateMachine.requestJoin` gains `displayName` and `protocolVersion` (defaults keep callers compiling); version mismatch rejected first with `session.protocol-mismatch`; `ParticipantSession.displayName`.
**Where**: `lib/domain/session/room_session_state_machine.dart`
**Depends on**: T1
**Reuses**: existing limits and TTLs
**Requirement**: ROOM-11, ROOM-34, ROOM-46

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes first: wrong version with right code → protocol-mismatch (not invalid-code); version 0 → mismatch; name kept on the pending participant and after approval; pending never becomes connected without `approve` (ROOM-46); existing state machine tests unchanged and passing
- [x] Gate check passes: `flutter test test/domain/session`
- [x] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): keep the name and check the protocol version on join`

---

### T3: Room discovery port carries the announcement

**What**: `RoomAnnouncement {masterName, songName?, protocolVersion}` (no code, NET-01); `advertise(id, port, announcement)` returns `Result<Unit, NetworkFailure>`; `DiscoveredRoom` gains `masterName`, `songName`, `protocolVersion`, `available`; every fake in `test/` and `integration_test/` updated; `NsdRoomDiscovery` and the controller compile with a minimal pass-through.
**Where**: `lib/domain/session/room_discovery.dart`
**Depends on**: T2
**Reuses**: existing fakes
**Requirement**: ROOM-09, ROOM-23

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] 9 fakes compile with the new signature; no assertion changed
- [x] Gate check passes: `flutter test` (all existing tests pass)

**Tests**: none
**Gate**: full
**Commit**: `refactor(room-entry): carry the room announcement through discovery`

---

### T4: JoinRequest v2 on the wire

**What**: `JoinRequestMessage` appends `protocolVersion` (u16) and `displayName`; decoding a legacy body yields version 0 and `""`.
**Where**: `lib/data/session/session_wire_message.dart`
**Depends on**: T3
**Reuses**: `_u16LenStringBytes`, `_readU16LenString`
**Requirement**: ROOM-11, ROOM-34

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Tests: v2 round-trip with accents ("João Conceição"); legacy bytes → version 0, empty name; empty name round-trip
- [x] Gate check passes: `flutter test test/data/session`
- [x] Test count: all existing + ≥ 3 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): send the name and protocol version in the join request`

---

### T5: Master side of the controller

**What**: `createRoom({masterName, songName})` announces master/song/version (never the code) and returns the `advertise` failure; `updateAnnouncement`; `roomCode`; incoming name sanitized; `reject` sends `JoinRejected(session.rejected)`; expired pending requests get `JoinRejected(session.request-expired)` before the close.
**Where**: `lib/data/session/room_session_controller.dart`
**Depends on**: T4
**Reuses**: tick, `_closeConnectionsForTerminatedParticipants`
**Requirement**: ROOM-05, ROOM-09, ROOM-13, ROOM-15, ROOM-20, ROOM-21

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes first, loopback tests: announcement holds master/song/version and no code; song change re-announces; advertise failure → createRoom failure with the same code; reject → joiner receives `session.rejected`; expiry (injected clock) → `session.request-expired`; stalled handshake still closes without a reason; 200-char name arrives cut to 40
- [x] Playback and transfer tests still pass
- [x] Gate check passes: `flutter test`
- [x] Test count: all existing + ≥ 7 new

**Tests**: integration
**Gate**: full
**Commit**: `feat(room-entry): announce the room and tell joiners why they were refused`

---

### T6: Joining side of the controller

**What**: `requestJoin(room, code, {displayName})` sends v2; `connect` failure → `session.connect-failed`; connection closed before the answer → `session.connection-lost`; 75 s without answer → `session.request-expired`; `cancelJoin`; `leaveRoom`; `masterConnectionLost` stream after joining.
**Where**: `lib/data/session/room_session_controller.dart`
**Depends on**: T5
**Reuses**: `_joinCompleter`, `_handleConnectionClosed`
**Requirement**: ROOM-30, ROOM-35, ROOM-36, ROOM-43, ROOM-44

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes first, loopback tests: a refused attempt (invalid-code) followed by a second `requestJoin` on another room works on the same controller; master closes before answering → connection-lost (no hang); unreachable port → connect-failed; injected short answer timeout → request-expired; cancelJoin → join completes with join-cancelled and the master snapshot drops the pending request; leaveRoom → master snapshot shows disconnected; master `endRoom` → `masterConnectionLost` fires once
- [x] Gate check passes: `flutter test`
- [x] Test count: all existing + ≥ 6 new

**Tests**: integration
**Gate**: full
**Commit**: `feat(room-entry): let a joiner cancel, leave and notice a lost room`

---

### T7: NSD announcement mapping

**What**: Pure `announcementToTxt` / `discoveredRoomFrom(service, status)` (TXT `m`/`s`/`v`, never the code, song cut to 255 UTF-8 bytes, `lost` → `available=false`); `NsdError(securityIssue)` → `discovery.permission-denied`, other errors → `discovery.failed`, on advertise and on the discovery stream.
**Where**: `lib/infrastructure/network/nsd_room_discovery.dart`
**Depends on**: T6
**Reuses**: existing register/discover cycle
**Requirement**: ROOM-20, ROOM-23, ROOM-37, ROOM-50

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Tests on the pure functions: round-trip; 300-byte song name cut without breaking a UTF-8 character; no TXT (older app) → listed with "Sem nome" and version 0; `lost` → unavailable; error cause mapping; the NET-01 test now asserts the TXT holds no code and no key material (D7)
- [x] Gate check passes: `flutter test test/infrastructure/network`
- [x] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): announce code, master and song over mDNS`

---

### T8: Schema v6 with `local_profile`

**What**: `LocalProfileTable` (id 1, `device_id`, `display_name`, `created_at`); `schemaVersion` 6 with an additive `from < 6` step.
**Where**: `lib/infrastructure/database/app_database.dart`
**Depends on**: T7
**Reuses**: `from < 5` migration pattern
**Requirement**: ROOM-03, ROOM-48

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Migration test: v5 database with songs, tracks, custom naipes and rehearsals opens at v6 with all rows and an empty `local_profile`
- [x] Gate check passes: `flutter test test/infrastructure/database`
- [x] Test count: all existing + ≥ 1 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): add the local profile table`

---

### T9: Local profile repository

**What**: `LocalProfile` entity, `LocalProfileRepository` port and `DriftLocalProfileRepository` (`load` creates the device id once; `saveDisplayName`).
**Where**: `lib/data/repositories/drift_local_profile_repository.dart`
**Depends on**: T8
**Reuses**: `uuidV4`, `DriftCustomNaipeRepository` pattern
**Requirement**: ROOM-03, ROOM-48

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes first: two loads return the same device id; a new database instance on the same file keeps it; name saved and read back; closed database → `StorageFailure` with a non-empty code
- [x] Gate check passes: `flutter test test/data/repositories`
- [x] Test count: all existing + ≥ 4 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): keep the device id and the room name on the device`

---

### T10: Platform permissions

**What**: Android main manifest gains `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`; iOS `Info.plist` gains `NSLocalNetworkUsageDescription` (pt-BR) and `NSBonjourServices` = `_cantae._tcp`.
**Where**: `android/app/src/main/AndroidManifest.xml`
**Depends on**: T9
**Reuses**: nothing
**Requirement**: ROOM-49

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Both files carry the entries (checked by reading them)
- [x] Gate check passes: `flutter analyze && flutter test`

**Tests**: none
**Gate**: build
**Commit**: `chore(room-entry): declare the local network permissions`

---

### T11: "Abrir ajustes" channel

**What**: `SystemSettings` port; `MethodChannelSystemSettings` (`cantae/system_settings`, `openAppSettings`); handlers in `MainActivity.kt` and `AppDelegate.swift`.
**Where**: `lib/infrastructure/platform/method_channel_system_settings.dart`
**Depends on**: T10
**Reuses**: nothing
**Requirement**: ROOM-20, ROOM-37, ROOM-57

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Dart side calls the channel method (checked through `TestDefaultBinaryMessenger` mock handler); a `MissingPluginException` is swallowed
- [ ] Gate check passes: `flutter analyze && flutter test`

**Tests**: unit
**Gate**: build
**Commit**: `feat(room-entry): open the app settings from the room screens`

---

### T12: Room providers and the active room

**What**: `room_providers.dart` (discovery, transport factory, handshake, settings, profile providers) and `ActiveRoomNotifier` (`host`, `join`, `cancelJoin`, `close`, one room per device).
**Where**: `lib/presentation/providers/active_room_notifier.dart`
**Depends on**: T11
**Reuses**: `RoomSessionController`, `uuidV4`
**Requirement**: ROOM-17, ROOM-31, ROOM-41, ROOM-43, ROOM-47

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Failure modes first (loopback + bus discovery): host then join on the same notifier closes the hosted room first; close as host ends the room and disposes the controller; close as member leaves; join outcome mapped through `joinOutcomeFor`; host failure leaves state `null`
- [ ] Gate check passes: `flutter test test/presentation/providers`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): hold one active room per device`

---

### T13: HostRoomNotifier

**What**: Criar sala / sala provisória do Mestre state: generating, ready, permissionDenied, failed; pending, members, isFull, hasPeople; approve, reject, chooseSong, retry, end.
**Where**: `lib/presentation/providers/host_room_notifier.dart`
**Depends on**: T12
**Reuses**: `ActiveRoomNotifier`, `songRepositoryProvider`
**Requirement**: ROOM-05, ROOM-07..19, ROOM-40, ROOM-53, ROOM-54

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tests for every state: generating → ready with code; song from `songId`; choose/clear song re-announces; pending listed with name; approved hidden until connected; reject and expiry drop the request; member disconnect drops the member; 8 members → isFull and approve refused; two simultaneous requests; permission-denied and failed with retry
- [ ] Gate check passes: `flutter test test/presentation/providers`
- [ ] Test count: all existing + ≥ 10 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): add the room host state`

---

### T14: JoinRoomNotifier

**What**: Entrar em sala state: searching, noneFound (10 s), awaiting, outcome, codeNotFound, permissionDenied; dedupe and removal of rooms; room selection; code input tried on the selected room or on each room in order; cancel; retry.
**Where**: `lib/presentation/providers/join_room_notifier.dart`
**Depends on**: T13
**Reuses**: `ActiveRoomNotifier`, `joinOutcomeFor`
**Requirement**: ROOM-22..37, ROOM-55, ROOM-56, ROOM-58

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tests for every phase and transition with a fake clock: 10 s → noneFound, late room still added; searchAgain restarts; same room twice → one entry; lost room removed; selected room + code → only that room asked; no selection → rooms asked in order, next only after invalid-code, the first that accepts keeps the request (ROOM-58); every room invalid-code or no room → codeNotFound; selected room invalid-code → codeNotFound; awaiting ignores a second join; every outcome; cancel returns to the list; permission error → permissionDenied
- [ ] Gate check passes: `flutter test test/presentation/providers`
- [ ] Test count: all existing + ≥ 12 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): add the join room state`

---

### T15: MemberRoomNotifier

**What**: Sala provisória do Cantor state (`masterName`, `songName`, `lost`) and `leave()`.
**Where**: `lib/presentation/providers/member_room_notifier.dart`
**Depends on**: T14
**Reuses**: `ActiveRoomNotifier`, `masterConnectionLost`
**Requirement**: ROOM-42, ROOM-43, ROOM-44

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tests: master ends → lost true once; leave → active room null and master sees disconnected
- [ ] Gate check passes: `flutter test test/presentation/providers`
- [ ] Test count: all existing + ≥ 2 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(room-entry): add the room member state`

---

### T16: `RoomCodeDisplay`

**What**: Card "Código da sala", code in `monoLarge`, "Copiar" (clipboard + toast "Código copiado"), instruction line; COMPONENTS.md updated.
**Where**: `lib/presentation/widgets/room_code_display.dart`
**Depends on**: T15
**Reuses**: `Toast`, tokens
**Requirement**: ROOM-05, ROOM-06

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: code shown in mono, copy puts the code in the clipboard and shows the toast, semantics label "Código da sala 4827", dark theme, ≥ 44 dp button
- [ ] Gate check passes: `flutter test test/presentation/widgets`
- [ ] Test count: all existing + ≥ 4 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): add the room code display`

---

### T17: `CodeInput`

**What**: 4-digit field, Geist Mono 28/+8, numeric keyboard, digits only, error border; COMPONENTS.md updated.
**Where**: `lib/presentation/widgets/code_input.dart`
**Depends on**: T16
**Reuses**: tokens
**Requirement**: ROOM-26, ROOM-27

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: letters and a 5th digit refused; error border on `hasError`; disabled state; semantics label "Código da sala"; dark theme
- [ ] Gate check passes: `flutter test test/presentation/widgets`
- [ ] Test count: all existing + ≥ 4 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): add the code input`

---

### T18: `RoomTile`

**What**: Found room: master name, song or "Sem música escolhida", chevron, 2 px accent border when selected, disabled state; COMPONENTS.md updated (no code, NET-01; no "N pessoas").
**Where**: `lib/presentation/widgets/room_tile.dart`
**Depends on**: T17
**Reuses**: tokens
**Requirement**: ROOM-23, ROOM-28, ROOM-29

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: content, no-song text, selected border, disabled ignores taps, one button node "Sala de Marina, Ave Verum Corpus", ≥ 44 dp, dark theme, 360 dp at 130 % without overflow
- [ ] Gate check passes: `flutter test test/presentation/widgets`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): add the room tile`

---

### T19: `JoinRequestRow`

**What**: Pending request: name, "Recusar" and "Aprovar" with labels "Recusar Marina" / "Aprovar Marina"; approve disabled with "Sala cheia: 8 de 8."; COMPONENTS.md updated.
**Where**: `lib/presentation/widgets/join_request_row.dart`
**Depends on**: T18
**Reuses**: buttons, tokens
**Requirement**: ROOM-11, ROOM-14, ROOM-54

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: callbacks, labels with the name, full state disables approve and shows the sentence, ≥ 44 dp, dark theme, 360 dp at 130 %
- [ ] Gate check passes: `flutter test test/presentation/widgets`
- [ ] Test count: all existing + ≥ 4 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): add the join request row`

---

### T20: `RoomPersonRow`

**What**: Person in the room: name and "papel" ("Você · Mestre", "Marina · Cantor"); COMPONENTS.md updated as the minimal `ParticipantRow`.
**Where**: `lib/presentation/widgets/room_person_row.dart`
**Depends on**: T19
**Reuses**: tokens
**Requirement**: ROOM-12, ROOM-39

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: text, one semantics node per row, dark theme, long name ellipsis at 360 dp
- [ ] Gate check passes: `flutter test test/presentation/widgets`
- [ ] Test count: all existing + ≥ 3 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): add the room person row`

---

### T21: `StatusPill` synced variant

**What**: `StatusPill` gains the `synced` variant (accentSoft, accent dot) and keeps `neutral`; live region; COMPONENTS.md updated.
**Where**: `lib/presentation/widgets/status_pill.dart`
**Depends on**: T20
**Reuses**: existing pill
**Requirement**: ROOM-05

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: synced colors from tokens in both themes, live region, neutral unchanged (existing tests pass)
- [ ] Gate check passes: `flutter test test/presentation/widgets`
- [ ] Test count: all existing + ≥ 2 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): add the synced status pill`

---

### T22: `DisplayNameSheet`

**What**: "Como você quer aparecer na sala?", field, "Salvar nome" (disabled when invalid, "Use até 40 caracteres."), save failure message; closing without saving returns `null`.
**Where**: `lib/presentation/screens/room/display_name_sheet.dart`
**Depends on**: T21
**Reuses**: `validateDisplayName`, `localProfileRepositoryProvider`
**Requirement**: ROOM-01..04

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: blank and 41 chars keep the button off; 41 shows the sentence; save stores the trimmed name; failure keeps the field with "Não foi possível salvar o nome."; close returns null; dark theme
- [ ] Gate check passes: `flutter test test/presentation/screens/room`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): ask for the name shown in the room`

---

### T23: `SongChoiceSheet`

**What**: Library songs list with the current one marked, "Sem música" option, loading/empty/error states.
**Where**: `lib/presentation/screens/room_create/song_choice_sheet.dart`
**Depends on**: T22
**Reuses**: `songsProvider`, `SongRow` if it fits
**Requirement**: ROOM-09

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Widget tests: choosing returns the song; "Sem música" returns none; empty library text; error text; current one marked for the screen reader
- [ ] Gate check passes: `flutter test test/presentation/screens/room_create`
- [ ] Test count: all existing + ≥ 4 new

**Tests**: widget
**Gate**: quick
**Commit**: `feat(room-entry): let the master pick the room song`

---

### T24: Criar sala screen and route

**What**: `RoomCreateScreen` (§6.7) with name gate, code, pill, song row, requests, members, banners, "Começar a conduzir", Cancelar/back with `ConfirmSheet`; `room-create` route takes `songId`; Detalhe passes it; UI_SPEC §6.7 updated (8 people, pill text, no Wi‑Fi name).
**Where**: `lib/presentation/screens/room_create/room_create_screen.dart`
**Depends on**: T23
**Reuses**: T13, T16, T19, T20, T21, T22, T23, `ConfirmSheet`, `InlineBanner`
**Requirement**: ROOM-01, ROOM-05..21, ROOM-51, ROOM-52

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-routing`

**Done when**:
- [ ] Widget tests per state: name sheet first; generating; ready with code; song from Detalhe with "Trocar"; "Escolher música" from Biblioteca; empty requests text; request approve/reject; full; permission banner opens settings; failed banner retries; start → `room-host`; cancel empty → Biblioteca without sheet; cancel with people → `ConfirmSheet`; system back same; both themes; 360 dp at 130 %
- [ ] Router and Detalhe tests updated
- [ ] Gate check passes: `flutter test`
- [ ] Test count: all existing + ≥ 15 new

**Tests**: widget
**Gate**: full
**Commit**: `feat(room-entry): add the Criar sala screen`

---

### T25: Sala provisória do Mestre and route

**What**: `RoomHostScreen` ("Sala <código>", "Você · Mestre", members, pending requests, "Encerrar sala" with `ConfirmSheet`, back = encerrar); route `room-host`.
**Where**: `lib/presentation/screens/room_host/room_host_screen.dart`
**Depends on**: T24
**Reuses**: T13, T19, T20
**Requirement**: ROOM-39, ROOM-40, ROOM-41, ROOM-45

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-routing`

**Done when**:
- [ ] Widget tests: title and rows; pending section approve/reject; encerrar confirms then Biblioteca; back with nobody → Biblioteca at once; no active room → Biblioteca; both themes; 360 dp at 130 %
- [ ] Gate check passes: `flutter test`
- [ ] Test count: all existing + ≥ 6 new

**Tests**: widget
**Gate**: full
**Commit**: `feat(room-entry): add the temporary master room`

---

### T26: Entrar em sala screen and route

**What**: `RoomJoinScreen` (§6.8) with name gate, `CodeInput` + Entrar, "Salas neste Wi‑Fi", tile selection with "Digite o código que aparece na tela de <Mestre>.", one banner per phase with its action, iOS hint, footer; `room-join` route; UI_SPEC §6.8 and COMPONENTS `RoomTile` updated (8 de 8, footer, protocol action, iOS hint, no code on the tile).
**Where**: `lib/presentation/screens/room_join/room_join_screen.dart`
**Depends on**: T25
**Reuses**: T14, T17, T18, T22, `InlineBanner`
**Requirement**: ROOM-01, ROOM-22..38, ROOM-51, ROOM-52, ROOM-55..58

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-routing`

**Done when**:
- [ ] Widget tests, one per state with its text and action: procurando; nenhuma (Android) and nenhuma + dica (iOS via `debugDefaultTargetPlatformOverride`); tile tap selects the room and focuses the field with the master's name; código não encontrado (border + Digitar de novo clears and focuses); aguardando (tile border, controls disabled, cancel); recusada; cheia; versão; não respondeu; sem conexão; permissão; joined → `room-member`; footer; banners are live regions; both themes; 360 dp at 130 %
- [ ] Gate check passes: `flutter test`
- [ ] Test count: all existing + ≥ 16 new

**Tests**: widget
**Gate**: full
**Commit**: `feat(room-entry): add the Entrar em sala screen`

---

### T27: Sala provisória do Cantor and route

**What**: `RoomMemberScreen` ("Você está na sala de <Mestre>", song, "O ensaio começa quando o Mestre conduzir.", "Sair da sala"; lost → Biblioteca + toast); route `room-member`.
**Where**: `lib/presentation/screens/room_member/room_member_screen.dart`
**Depends on**: T26
**Reuses**: T15, `Toast`
**Requirement**: ROOM-42, ROOM-43, ROOM-44

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-routing`

**Done when**:
- [ ] Widget tests: texts; leave → Biblioteca; lost → Biblioteca + toast "A sala foi encerrada ou a conexão caiu."; no active room → Biblioteca; both themes; 360 dp at 130 %
- [ ] Gate check passes: `flutter test`
- [ ] Test count: all existing + ≥ 4 new

**Tests**: widget
**Gate**: full
**Commit**: `feat(room-entry): add the temporary singer room`

---

### T28: Room entry flow end to end

**What**: Widget e2e with two real controllers on loopback TCP and in-memory discovery: master names itself, creates the room; singer names itself, mistypes the code, taps the tile, waits; master approves; singer reaches the room; second singer refused; master ends; singer sees the toast. Prints the artifact (codes, names, outcomes, snapshot states).
**Where**: `test/e2e/room_entry_flow_test.dart`
**Depends on**: T27
**Reuses**: `test/e2e/track_upload_flow_test.dart` structure
**Requirement**: ROOM-01, ROOM-12, ROOM-13, ROOM-17, ROOM-26, ROOM-31, ROOM-32, ROOM-41, ROOM-44, ROOM-46

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] The flow passes and prints the artifact; the pending singer is absent from "Na sala" until "Aprovar" (ROOM-46)
- [ ] Gate check passes: `flutter test`

**Tests**: e2e
**Gate**: build
**Commit**: `test(room-entry): cover the room entry flow end to end`

---

### T29: Device script for rooms

**What**: Room steps in a device script: two phones on one Wi‑Fi, permission prompt and denial on iOS and Android, "Abrir ajustes", create/join/approve/refuse/full/leave/end, release build.
**Where**: `docs/device-test-room-entry.md`
**Depends on**: T28
**Reuses**: `docs/device-test-background-audio.md` format
**Requirement**: ROOM-20, ROOM-37, ROOM-49, ROOM-50, ROOM-57

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Script lists each step with the expected screen text
- [ ] Gate check passes: build gate

**Tests**: none
**Gate**: build
**Commit**: `docs(room-entry): add the room device test script`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6

Phase 1:  T1 → T2 → T3
Phase 2:  T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11
Phase 3:  T12 → T13 → T14 → T15
Phase 4:  T16 → T17 → T18 → T19 → T20 → T21
Phase 5:  T22 → T23 → T24 → T25 → T26 → T27
Phase 6:  T28 → T29
```

Execution is strictly sequential.

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1 | 1 file of pure rules | ✅ Granular |
| T2 | 1 method + 1 field | ✅ Granular |
| T3 | 1 port; fakes are mechanical signature updates | ⚠️ Many files, one concept (cannot compile partially) |
| T4 | 1 message codec | ✅ Granular |
| T5 | Master half of 1 class | ✅ Granular |
| T6 | Joining half of 1 class | ✅ Granular |
| T7 | 1 adapter + 2 pure functions | ✅ Granular |
| T8 | 1 table + 1 migration step | ✅ Granular |
| T9 | 1 repository with its entity and port | ⚠️ 3 small files, one concept |
| T10 | 2 platform config files, one concern | ⚠️ Cohesive |
| T11 | 1 channel (Dart + 2 native handlers) | ⚠️ Cohesive, one method |
| T12–T15 | 1 notifier each | ✅ Granular |
| T16–T21 | 1 component each | ✅ Granular |
| T22–T23 | 1 sheet each | ✅ Granular |
| T24–T27 | 1 screen + its route each | ✅ Granular |
| T28 | 1 test file | ✅ Granular |
| T29 | 1 doc | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | start of Phase 1 | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | T3 | Phase 1 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |
| T7 | T6 | T6 → T7 | ✅ Match |
| T8 | T7 | T7 → T8 | ✅ Match |
| T9 | T8 | T8 → T9 | ✅ Match |
| T10 | T9 | T9 → T10 | ✅ Match |
| T11 | T10 | T10 → T11 | ✅ Match |
| T12 | T11 | Phase 2 → T12 | ✅ Match |
| T13 | T12 | T12 → T13 | ✅ Match |
| T14 | T13 | T13 → T14 | ✅ Match |
| T15 | T14 | T14 → T15 | ✅ Match |
| T16 | T15 | Phase 3 → T16 | ✅ Match |
| T17 | T16 | T16 → T17 | ✅ Match |
| T18 | T17 | T17 → T18 | ✅ Match |
| T19 | T18 | T18 → T19 | ✅ Match |
| T20 | T19 | T19 → T20 | ✅ Match |
| T21 | T20 | T20 → T21 | ✅ Match |
| T22 | T21 | Phase 4 → T22 | ✅ Match |
| T23 | T22 | T22 → T23 | ✅ Match |
| T24 | T23 | T23 → T24 | ✅ Match |
| T25 | T24 | T24 → T25 | ✅ Match |
| T26 | T25 | T25 → T26 | ✅ Match |
| T27 | T26 | T26 → T27 | ✅ Match |
| T28 | T27 | Phase 5 → T28 | ✅ Match |
| T29 | T28 | T28 → T29 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1 | Domain rules | unit | unit | ✅ OK |
| T2 | Domain state machine | unit | unit | ✅ OK |
| T3 | Domain port | none | none | ✅ OK |
| T4 | Data wire codec | unit | unit | ✅ OK |
| T5 | Data controller | integration | integration | ✅ OK |
| T6 | Data controller | integration | integration | ✅ OK |
| T7 | Infrastructure NSD mapping | unit | unit | ✅ OK |
| T8 | Infrastructure schema | unit | unit | ✅ OK |
| T9 | Data repository | unit | unit | ✅ OK |
| T10 | Platform config | none | none | ✅ OK |
| T11 | Native channel (Dart side testable) | none (native) / unit (Dart) | unit | ✅ OK |
| T12–T15 | Presentation notifiers | unit | unit | ✅ OK |
| T16–T21 | Presentation widgets | widget | widget | ✅ OK |
| T22–T27 | Presentation screens, routes | widget | widget | ✅ OK |
| T28 | Feature flow | e2e | e2e | ✅ OK |
| T29 | Doc | none | none | ✅ OK |
