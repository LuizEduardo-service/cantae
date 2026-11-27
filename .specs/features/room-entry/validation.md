# Criar sala + Entrar em sala (room-entry) Validation

**Date**: 2026-11-27
**Spec**: `.specs/features/room-entry/spec.md`
**Diff range**: `develop..feature/phase-5-room-entry` = `45a800b..HEAD` (spec `45a800b`, design `4f9f58d`, tasks `17bf882`, last task `505063a`)
**Verifier**: standalone fallback, run by the author, as approved for the earlier features. Author ≠ verifier does **not** hold for this run.

**Verdict**: PASS ✅ (iteration 1; one coverage gap, ROOM-50, closed during validation)

---

## Task Completion

29/29 tasks done, one commit each (`022a231` … `505063a`). Commits outside the task list, each a bug found during the work with its red-first regression test:

| Commit | Bug | Regression test |
| --- | --- | --- |
| `b39e74d` fix(network) | `TcpSessionTransport.close()` ran while the last `flush()` was pending; dart:io refused it, the error was swallowed and the socket stayed open, so "Cancelar pedido" never reached the master (pre-existing, Phase 3) | `test/infrastructure/network/tcp_session_transport_test.dart` "regression: close() right after send()…" |
| `6733ec0` fix(room-entry) | Room rows and section labels used `Semantics` without a container; inside one list item the master's people list was read as one item | `test/presentation/widgets/room_person_row_test.dart` and `join_request_row_test.dart` "regression: …" |
| `f67df1c` fix(room-entry) | `JoinRoomNotifier.dispose` called `close()` on an already disposed `ActiveRoomNotifier` at app shutdown | `test/presentation/providers/active_room_notifier_test.dart` "regression: close() after the notifier is disposed…" |

A race found inside T5 (a room tick closing the socket while the refusal was being sent) was fixed in the T5 commit `72df383` with its deterministic regression test (`room_entry_master_test.dart` "regression: a room tick during the refusal…").

**Deviations recorded in the docs:**
- **NET-01 kept (context.md D7):** the room code is never announced; the spec, design and tasks changed before T3 (`f1bfa01`). The NET-01 test now locks the TXT keys to `{m, v}` instead of `txt == null`, as the user's decision implies.
- **`TonalButton.semanticLabel`** (T19): additive, documented in COMPONENTS.md.
- **`HostRoomNotifier.resume()`** (T25): added so the master's room screen never creates a room.
- **System back on the singer's room** leaves the room (T27); the spec did not say, and staying connected with no screen would be worse.

---

## Spec-Anchored Acceptance Criteria

| ID | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| ROOM-01 | Name sheet before creating or searching | `test/presentation/screens/room_create/room_create_screen_test.dart:158` - `expect(find.text('Como você quer aparecer na sala?'), findsOneWidget)`; `room_join_screen_test.dart` same + `expect(join.calls, isEmpty)` | ✅ |
| ROOM-02 | 0 or > 40 chars keep "Salvar nome" off; > 40 shows "Use até 40 caracteres." | `test/domain/session/room_entry_rules_test.dart:21` - `expect(_nameError(''), 'display_name_empty')`; `display_name_sheet_test.dart:80` - `expect(find.text('Use até 40 caracteres.'), findsOneWidget)` | ✅ |
| ROOM-03 | Name stored, not asked again, survives reopening | `display_name_sheet_test.dart:92` - `expect(profiles.displayName, 'Marina')`; `test/data/repositories/local_profile_repository_test.dart` - `expect(reopened.displayName, 'Marina')` | ✅ |
| ROOM-04 | Closing the sheet → Biblioteca, nothing started | `display_name_sheet_test.dart:127` - `expect(result.value, isNull)`; `room_create_screen_test.dart` - `expect(find.text('route:library'), findsOneWidget)` | ✅ |
| ROOM-05 | "Gerando código" → code in mono + "Visível neste Wi‑Fi" | `host_room_notifier_test.dart:137` - `expect(state().status, HostRoomStatus.generating)`; `room_create_screen_test.dart:180` - `expect(find.text('Gerando código'), findsOneWidget)`; `room_code_display_test.dart` - `expect(style.fontFamily, CantaeTypography.monoLarge.fontFamily)` | ✅ |
| ROOM-06 | Copies the code, toast "Código copiado" | `test/presentation/widgets/room_code_display_test.dart:61` - `expect(copied, ['4827'])` + `expect(find.text('Código copiado'), findsOneWidget)` | ✅ |
| ROOM-07 | From the Detalhe the song comes chosen, with "Trocar" | `host_room_notifier_test.dart:151` - `expect(state().songId, 'ave')`; `room_create_screen_test.dart:171` - `expect(host.calls.first, 'start:Marina:ave')`; `song_detail_screen_test.dart` - `expect(find.text('route:room-create?songId=s1'), findsOneWidget)` | ✅ |
| ROOM-08 | From the Biblioteca "Escolher música"; room works without | `host_room_notifier_test.dart:160` - `expect(state().songName, isNull)` + status ready; `room_create_screen_test.dart:203` - `expect(find.text('Nenhuma música escolhida'), findsOneWidget)` | ✅ |
| ROOM-09 | Picked song shown and announced | `host_room_notifier_test.dart:170` - `expect(masterDiscovery.announcements.last.songName, 'Cantate Domino')`; `room_entry_master_test.dart` - `expect(masterDiscovery.announcements.last.songName, 'Cantate Domino')` | ✅ |
| ROOM-10 | "Ninguém pediu para entrar ainda" with nobody | `room_create_screen_test.dart:192` block - `expect(find.text('Ninguém pediu para entrar ainda'), findsOneWidget)` | ✅ |
| ROOM-11 | Request listed with name, Recusar/Aprovar labelled with the name | `host_room_notifier_test.dart:186` - `expect(state().people.pending.map((p) => p.name), ['Ana', 'Bruno'])`; `join_request_row_test.dart` - `expect(find.bySemanticsLabel('Recusar Marina'), findsOneWidget)` | ✅ |
| ROOM-12 | Shown in "Na sala" only once connected; "N de 8 na sala" | `host_room_notifier_test.dart:199` - `expect(state().people.members.single.name, 'Ana')`; `hostPeopleOf` group - approved not listed; `room_create_screen_test.dart:230` - `expect(find.text('Na sala · 1 de 8'), findsOneWidget)` | ✅ |
| ROOM-13 | Refusal drops the request; singer sees "Entrada recusada" | `room_entry_master_test.dart:231` - `'session.rejected'`; `room_join_screen_test.dart` outcome loop - `expect(find.text('Entrada recusada'), findsOneWidget)` | ✅ |
| ROOM-14 | 8 in → "Aprovar" off, "Sala cheia: 8 de 8." announced | `host_room_notifier_test.dart:345` - `expect(people.isFull, isTrue)`; `join_request_row_test.dart` - `expect(sentence.flagsCollection.isLiveRegion, isTrue)` | ✅ |
| ROOM-15 | Expired / cancelled / lost request disappears | `host_room_notifier_test.dart` "an expired request disappears" - `until((s) => s.people.pending.isEmpty)`; `room_entry_joiner_test.dart:223` cancel → master `disconnected` | ✅ |
| ROOM-16 | Member who drops leaves "Na sala", count updated | `host_room_notifier_test.dart:241` - `expect(state().people.hasPeople, isFalse)` after `members.isEmpty` | ✅ |
| ROOM-17 | "Começar a conduzir" opens the master room, same code | `host_room_notifier_test.dart:284` - `expect(state().code, code)` + one announcement; `room_create_screen_test.dart` - `expect(find.text('route:room-host'), findsOneWidget)` | ✅ |
| ROOM-18 | Leaving with people asks "Encerrar sala?" | `room_create_screen_test.dart:294` - `expect(find.text('Encerrar sala?'), findsOneWidget)`; system back test same | ✅ |
| ROOM-19 | Leaving with nobody ends without asking | `room_create_screen_test.dart:282` - `expect(find.text('Encerrar sala?'), findsNothing)` + `expect(host.calls.last, 'end')` | ✅ |
| ROOM-20 | Permission failure → "Sem acesso à rede local" + "Abrir ajustes" opens settings | `host_room_notifier_test.dart:254` - `expect(state().status, HostRoomStatus.permissionDenied)` + `expect(settings.opened, 1)`; `room_create_screen_test.dart:249`; `method_channel_system_settings_test.dart` - `expect(calls, ['openAppSettings'])` | ✅ |
| ROOM-21 | Other failure → "Não foi possível criar a sala." + "Tentar de novo" retries | `host_room_notifier_test.dart:266` - failed → retry → `expect(state().status, HostRoomStatus.ready)`; `room_create_screen_test.dart:258` | ✅ |
| ROOM-22 | Searching with "Procurando salas…" | `join_room_notifier_test.dart:137` - `expect(state().phase, JoinPhase.searching)`; `room_join_screen_test.dart` - `expect(find.text('Procurando salas…'), findsOneWidget)` | ✅ |
| ROOM-23 | Tile with master and song (or "Sem música escolhida"), no code | `join_room_notifier_test.dart:147` - `expect(tile.masterName, 'Marina')`; `room_tile_test.dart` - `expect(find.textContaining(RegExp(r'\d{4}')), findsNothing)`; e2e - `expect(find.text(code), findsNothing)` | ✅ |
| ROOM-24 | 10 s with nothing → banner + "Procurar de novo"; later rooms still appear | `join_room_notifier_test.dart:156` - `expect(state().phase, JoinPhase.noneFound)` then `expect(state().rooms.single.masterName, 'Marina')`; `room_join_screen_test.dart:202` | ✅ |
| ROOM-25 | Code without a choice → rooms asked in order until one takes it | `join_room_notifier_test.dart:232` - `expect(rooms.asked.map((a) => a.$1), [_marina.id, _bruno.id])`; `room_entry_joiner_test.dart` second room after invalid-code succeeds | ✅ |
| ROOM-26 | No room takes it → error border, "Código não encontrado", "Digitar de novo" clears and focuses | `join_room_notifier_test.dart:263` - `codeNotFound`; `room_join_screen_test.dart` - `expect(tester.widget<CodeInput>(…).hasError, isTrue)` + `expect(field.focusNode.hasFocus, isTrue)`; e2e step | ✅ |
| ROOM-27 | Digits only, max 4, "Entrar" off below 4 | `code_input_test.dart` - `expect(controller.text, '4827')`; `join_room_notifier_test.dart:200` - `expect(state().code, '482')` + `canSubmit` false | ✅ |
| ROOM-28 | Tile tap marks the room, focuses, says whose code; only it is asked | `join_room_notifier_test.dart:218` - `expect(rooms.asked, [(_bruno.id, '4827', 'Ana')])`; `room_join_screen_test.dart` - `expect(find.text('Digite o código que aparece na tela de Bruno.'), findsOneWidget)` | ✅ |
| ROOM-29 | Waiting banner names the master; tile accent border; controls off | `room_join_screen_test.dart:283` - `expect(find.text('Aguardando Marina aprovar'), findsOneWidget)` + `expect(tiles.every((t) => t.onTap == null), isTrue)`; `room_tile_test.dart` border width 2 | ✅ |
| ROOM-30 | "Cancelar pedido" → list; request leaves master | `room_entry_joiner_test.dart:223` - `'session.join-cancelled'` + master `disconnected`; `join_room_notifier_test.dart:321` - `expect(state().phase, JoinPhase.searching)` | ✅ |
| ROOM-31 | Approved + secure connection → singer's room | `active_room_notifier_test.dart:130` - `JoinOutcome.joined` + `role == RoomRole.member`; `room_join_screen_test.dart` - `expect(find.text('route:room-member'), findsOneWidget)`; e2e | ✅ |
| ROOM-32 | Refusal → "Entrada recusada" + "Escolher outra sala" | `test/e2e/room_entry_flow_test.dart:157` - `expect(brunoCode, 'session.rejected')`; `room_join_screen_test.dart` outcome loop | ✅ |
| ROOM-33 | Full → "Sala cheia (8 de 8)" + "Escolher outra sala" | `join_room_notifier_test.dart` outcome loop (`roomFull`); `room_join_screen_test.dart` - `expect(find.text('Sala cheia (8 de 8)'), findsOneWidget)` | ✅ |
| ROOM-34 | Other version → "Versão do app incompatível" + "Atualize o Cantaê nos dois aparelhos." | `room_entry_master_test.dart:280` - `expect(refusal.reasonCode, 'session.protocol-mismatch')`; `room_session_state_machine_entry_test.dart:41`; `room_join_screen_test.dart` - `expect(find.text('Atualize o Cantaê nos dois aparelhos.'), findsOneWidget)` | ✅ |
| ROOM-35 | Expired → "O Mestre não respondeu" + "Tentar de novo" | `room_entry_master_test.dart` - `'session.request-expired'`; `room_entry_joiner_test.dart:204` (75 s guard); `join_room_notifier_test.dart:370` retry asks the same room | ✅ |
| ROOM-36 | Connection drops / never opens → "Não foi possível falar com a sala" + "Tentar de novo" | `room_entry_joiner_test.dart:174` - `'session.connection-lost'`; unreachable → `'session.connect-failed'` → `connectionLost` (`room_entry_rules_test.dart`) | ✅ |
| ROOM-37 | Android permission → "Sem acesso à rede local" + "Abrir ajustes" | `nsd_room_discovery_test.dart` - `expect((error! as NetworkFailure).code, 'discovery.permission-denied')`; `join_room_notifier_test.dart:383`; `room_join_screen_test.dart:348` | ✅ |
| ROOM-38 | Footer "Você entra como Cantor." | `room_join_screen_test.dart` searching test - `expect(find.text('Você entra como Cantor.'), findsOneWidget)` | ✅ |
| ROOM-39 | "Sala <código>", "Você · Mestre", "<nome> · Cantor" | `room_host_screen_test.dart` - `expect(find.text('Sala 4827'), findsOneWidget)` + `expect(find.bySemanticsLabel('Você, Mestre'), findsOneWidget)` | ✅ |
| ROOM-40 | Requests answerable in the master room | `room_host_screen_test.dart:131` - `expect(find.text('Pedindo para entrar · 1'), findsOneWidget)` + `['approve:ana', 'reject:ana']` | ✅ |
| ROOM-41 | "Encerrar sala" + confirm ends for all, stops announcing | `active_room_notifier_test.dart:166` - `expect(marina.discovery.stops, 1)` + singer `masterConnectionLost`; `room_host_screen_test.dart` confirm → `'end'`; e2e | ✅ |
| ROOM-42 | "Você está na sala de <Mestre>", song or "Sem música escolhida", "O ensaio começa quando o Mestre conduzir." | `room_member_screen_test.dart:84` - `expect(find.text('Você está na sala de Marina'), findsOneWidget)`; `:96` - `expect(find.text('Sem música escolhida'), findsOneWidget)` | ✅ |
| ROOM-43 | "Sair da sala" → Biblioteca, master drops the person | `active_room_notifier_test.dart:184` + master `disconnected`; `member_room_notifier_test.dart`; `room_member_screen_test.dart` - `expect(member.calls, ['leave'])` | ✅ |
| ROOM-44 | Room ended or lost → Biblioteca + toast | `room_member_screen_test.dart` - `expect(find.text('A sala foi encerrada ou a conexão caiu.'), findsOneWidget)`; `room_entry_joiner_test.dart:250` fires once; e2e | ✅ |
| ROOM-45 | Back in the master room = Encerrar rules | `room_host_screen_test.dart:173` - `expect(find.text('Encerrar sala?'), findsNothing)` + `expect(host.calls.last, 'end')`; with people asks | ✅ |
| ROOM-46 | Nobody in "Na sala" without "Aprovar" | `room_session_state_machine_entry_test.dart` - `'session.participant-not-approved'`; `test/e2e/room_entry_flow_test.dart:121` - `expect(host().people.members, isEmpty)` while pending | ✅ |
| ROOM-47 | One room per device | `active_room_notifier_test.dart:115` - search closes the hosted room: `expect(marina.notifier.state, isNull)` + `stops == 1` | ✅ |
| ROOM-48 | Device id stable across openings; name only as display text | `local_profile_repository_test.dart:34` - same id twice and after reopening; `active_room_notifier_test.dart` - `expect(snapshot.participants.single.id, const ParticipantId('ana-device'))` + `displayName 'Ana'` | ✅ |
| ROOM-49 | Android INTERNET/network/Wi‑Fi/multicast; iOS local network keys | Code reading: `android/app/src/main/AndroidManifest.xml:12-15`; `ios/Runner/Info.plist:50-55` (`plistlib` parse OK); debug APK built with exit 0 | ✅ (inspection; release build on device in `docs/device-test-room-entry.md`) |
| ROOM-50 | Multicast lock only while searching/announcing | `test/infrastructure/network/nsd_room_discovery_test.dart` (added by this validation) - `expect(fakePlatform.stoppedDiscoveries, [started])`; `join_room_notifier_test.dart` - leaving the screen stops the search; the plugin holds the lock only between `startDiscovery`/`stopDiscovery` (`nsd_android-2.2.0 NsdAndroidPlugin.kt:46,89`) | ✅ |
| ROOM-51 | Tokens only, both themes, ≥ 44 dp, 360 dp @ 130 %, banners as live regions | Screen tests "fits 360 dp at 130 % in both themes" (`room_create_screen_test.dart:338`, host, join, member); `room_join_screen_test.dart:376` - `isLiveRegion`; grep of new UI files finds no `Color(0x`, `fontSize:` or literal spacing | ✅ |
| ROOM-52 | pt-BR, no jargon (mDNS, handshake, sessionId, protocolo) | Code reading: case-insensitive grep of string literals in the new screens and widgets for mdns/bonjour/handshake/sessionid/protocolo/tcp/socket/hmac returns nothing | ✅ (inspection) |
| ROOM-53 | Two simultaneous requests both listed | `host_room_notifier_test.dart:186`; `room_create_screen_test.dart:218` - `expect(find.text('Pedindo para entrar · 2'), findsOneWidget)` | ✅ |
| ROOM-54 | 8th seat taken → request stays, "Aprovar" off | `host_room_notifier_test.dart:358` - 7 in + 1 connecting → `isFull`; `room_create_screen_test.dart` full → no approve call | ✅ |
| ROOM-55 | Taps during a request ignored | `join_room_notifier_test.dart:299` - `expect(rooms.asked, hasLength(1))`; `room_join_screen_test.dart:283` - tiles `onTap == null`, field disabled | ✅ |
| ROOM-56 | Same room twice → one tile | `join_room_notifier_test.dart:186` - `expect(state().rooms.map((r) => r.masterName), ['Marina', 'Bruno'])` | ✅ |
| ROOM-57 | iOS: hint + "Abrir ajustes" in "Nenhuma sala" | `room_join_screen_test.dart:216` - `expect(find.textContaining('Se você negou o acesso à rede local, libere nos ajustes.'), findsOneWidget)` + `expect(join.calls.last, 'settings')`; Android variant asserts both absent | ✅ |
| ROOM-58 | Same code in two rooms → request only to the first that takes it; banner names its master | `join_room_notifier_test.dart:232` and "the first room that takes the code stops the search" - `expect(rooms.asked.map((a) => a.$1), [_marina.id])` + `target.masterName == 'Marina'` | ✅ |

**Status**: 58/58 covered. ROOM-49 and ROOM-52 are verified by inspection (platform files and string literals have no meaningful unit test).

---

## Discrimination Sensor

Lightweight is the default; this feature touches the session protocol and admission (security-sensitive), so the sensor ran a full manual set: 73 behavior-level mutations over every new component, each against the tests of its own layer, in a temporary git worktree (`git worktree add`, removed afterwards; real-tree porcelain matched the baseline plus this validation's own two files).

| Mutation | Fault injected | Killed? |
| --- | --- | --- |
| R1 | blank name accepted | ✅ Killed |
| R2 | name limit off by one | ✅ Killed |
| R3 | empty remote name not replaced | ✅ Killed |
| R4 | control characters kept | ✅ Killed |
| R5 | unknown code blames the person | ✅ Killed |
| R6 | older version admitted | ✅ Killed |
| R7 | name lost on request | ✅ Killed |
| R8 | name lost after approval | ✅ Killed |
| R9 | legacy request decodes as current | ✅ Killed |
| R10 | name bytes not sent | ✅ Killed |
| R11 | advertise failure ignored | ✅ Killed |
| R12 | remote name not sanitized | ✅ Killed |
| R13 | refusal without reason | ✅ Killed |
| R14 | expiry without reason | ✅ Killed |
| R15 | stalled handshake told it expired | ✅ Killed |
| R16 | refusal races the tick | ✅ Killed |
| R17 | song change without re-announce | ✅ Killed |
| R18 | closed before answer hangs | ✅ Killed |
| R19 | no answer reported as lost | ✅ Killed |
| R20 | unreachable reported as lost | ✅ Killed |
| R21 | cancel keeps request on master | ✅ Killed |
| R22 | leaving reported as lost | ✅ Killed |
| R23 | lost room still asked | ✅ Killed |
| R24 | close does not wait for the write | ✅ Killed |
| R25 | song not cut to TXT limit | ✅ Killed |
| R26 | lost room still available | ✅ Killed |
| R27 | permission looks generic | ✅ Killed |
| R28 | missing version looks current | ✅ Killed |
| R29 | name stored wrong | ✅ Killed |
| R30 | upgrade misses local_profile | ✅ Killed |
| R31 | hosted room not active | ✅ Killed |
| R32 | search keeps hosted room | ✅ Killed |
| R33 | joined room has host role | ✅ Killed |
| R34 | close after dispose throws | ✅ Killed |
| R35 | connecting person listed as in | ✅ Killed |
| R36 | full off by one | ✅ Killed |
| R37 | permission looks generic | ✅ Killed |
| R38 | second screen creates a new room | ✅ Killed |
| R39 | resume claims a room | ✅ Killed |
| R40 | song change not announced | ✅ Killed |
| R41 | stops at the first wrong room | ✅ Killed |
| R42 | chosen room ignored | ✅ Killed |
| R43 | none found with rooms listed | ✅ Killed |
| R44 | lost room stays listed | ✅ Killed |
| R45 | submit with 3 digits / while waiting | ✅ Killed |
| R46 | Digitar de novo keeps the code | ✅ Killed |
| R47 | permission looks like none found | ✅ Killed |
| R48 | leaving the screen drops the joined room | ✅ Killed |
| R49 | code longer than 4 | ✅ Killed |
| R50 | lost room not flagged | ✅ Killed |
| R51 | selected border too thin | ✅ Killed |
| R52 | full room still approves | ✅ Killed |
| R53 | approve label without the name | ✅ Killed |
| R54 | copies nothing | ✅ Killed |
| R55 | letters in the code | ✅ Killed |
| R56 | synced pill looks neutral | ✅ Killed |
| R57 | rows merge for the screen reader | ✅ Killed |
| R58 | name saved untrimmed | ✅ Killed |
| R59 | no sentence for a long name | ✅ Killed |
| R60 | leaving with people asks nothing | ✅ Killed |
| R61 | start before ready | ✅ Killed |
| R62 | closing the name sheet leaves a blank screen | ✅ Killed |
| R63 | detail does not pass the song | ✅ Killed |
| R64 | route drops the song id | ✅ Killed |
| R65 | back with nobody asks | ✅ Killed |
| R66 | end without asking | ✅ Killed |
| R67 | iOS hint on Android | ✅ Killed |
| R68 | joined does not open the room | ✅ Killed |
| R69 | tiles react while waiting | ✅ Killed |
| R70 | Digitar de novo does not focus | ✅ Killed |
| R71 | no reason when the room ends | ✅ Killed |
| R72 | back does not leave | ✅ Killed |
| R73 | cancelling discovery does not call `stopDiscovery` (test added by this validation, ROOM-50) | ✅ Killed |

**Result**: 73/73 killed, 0 survived, 0 equivalent - PASS ✅

---

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ — one active room, screen notifiers map snapshots to views; no speculative options |
| Surgical changes | ✅ — Phase 3 classes extended additively; 9 discovery fakes changed only in signature |
| No scope creep | ✅ — Visitante, full master/singer rooms, "N pessoas" left out as the spec says |
| Matches patterns | ✅ — `Result`, ports in domain, drift repository pattern, Riverpod `StateNotifier`, `CantaeScaffold` screens |
| Spec-anchored outcome check | ✅ — asserted texts and codes are the spec's |
| Per-layer coverage | ✅ — domain 1:1, controller over loopback TCP, every screen state with its text and action |
| Every test maps to a requirement | ✅ — test names cite ROOM IDs or listed failure modes |
| Guidelines followed | `AGENTS.md` §3/§5/§7, `CLAUDE.md` testing rules, `docs/design/*` |

**Known limits (not gaps):**
- mDNS on real phones, the iOS permission prompt, "Abrir ajustes" on iOS (Swift not compiled on Windows) and a release build were not run on a device: `docs/device-test-room-entry.md`.
- Strings are still in the widgets, not a localization file (project-wide debt in STATE.md).

---

## Gate Check

- **Gate command**: `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test && python scripts/check_layers.py`
- **Result**: analyzer clean, format clean, 1177 passed, 0 failed, 0 skipped; layer check OK
- **Test count before feature**: 965 (`develop` at `03d0e64`)
- **Test count after feature**: 1177
- **Delta**: +212 new tests, none removed
- **Changed existing assertions**: the NET-01 TXT check (`txt == null` → keys `{m, v}`, decision D7), the router tests for `room-create`/`room-join` (ComingSoon → the new screens) and the Detalhe "Ensaiar em grupo" test (now asserts `songId=s1`); all follow spec changes, none weakens a check
- **Native code**: debug APK built (Kotlin compiles); Swift not compiled (Windows)

---

## Requirement Traceability Update

All 58 requirements move from Implementing to ✅ Verified in `spec.md`.

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 58/58 ACs matched the spec outcome (ROOM-49 and ROOM-52 by inspection)
**Sensor**: 73/73 mutations killed
**Gate**: 1177 passed

**What works**: name sheet; Criar sala with code, song, requests, approval, refusal, full room and leaving rules; Entrar em sala with the list, chosen room, code tried room by room, and every failure state; both temporary rooms; one room per device; protocol version check; reasons on refusal and expiry; no hang when the room closes or never answers.

**Issues found**: none open. Gap closed during validation: ROOM-50 had no test that stopping the search stops mDNS discovery; added to `nsd_room_discovery_test.dart` and confirmed by mutant R73.

**Next steps**: run `docs/device-test-room-entry.md` on two phones; merge after the user's go-ahead.

