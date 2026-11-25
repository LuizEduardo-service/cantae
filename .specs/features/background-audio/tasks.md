# Áudio em segundo plano (background-audio) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/background-audio/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found:
> - `AGENTS.md` §5/§7: screen states, both themes, 130% font, semantics.
> - `CLAUDE.md`: failure-first for isolated systems; E2E with a reviewable artifact for features.
> - The user's standing rule: every bug gets a failing regression test in the same commit as its fix.
> - No coverage-threshold config.
>
> Sampled: `test/infrastructure/audio/multi_track_audio_engine_test.dart`, `test/infrastructure/audio/fakes/fake_just_audio_platform.dart`, `test/presentation/providers/solo_player_notifier_test.dart`, `test/presentation/screens/solo_player/solo_player_screen_test.dart`, `integration_test/file_transfer_and_sync_playback_test.dart`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Infrastructure (engine, interruptions, handler, bootstrap) | unit (failure modes listed first) | Each mapping and each failure path; no platform channel (`BaseAudioHandler` is plain Dart; session streams injected) | `test/infrastructure/audio/*_test.dart` | `flutter test test/infrastructure/audio` |
| Platform config | unit (file assertion) | `UIBackgroundModes: audio` in `Info.plist`; `mediaPlayback` service in the manifest | `test/infrastructure/audio/platform_config_test.dart` | `flutter test test/infrastructure/audio/platform_config_test.dart` |
| Presentation (notifier) | unit | 1:1 to BGA-04..BGA-14, BGA-19, with fake remote + fake interruptions | `test/presentation/providers/solo_player_notifier_test.dart` | `flutter test test/presentation/providers/solo_player_notifier_test.dart` |
| Presentation (screen) | widget (e2e-equivalent) | Toast on external pause, deferred until resumed; remote command reflected on screen | `test/presentation/screens/solo_player/*_test.dart` | `flutter test test/presentation/screens/solo_player/solo_player_screen_test.dart` |
| Device | integration (device-only, not run in this feature) | Compiles under `flutter analyze`; writes a log artifact when run | `integration_test/background_audio_test.dart` | `flutter test -d <device> integration_test/background_audio_test.dart` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After a task with tests in one area | `flutter test <changed test file(s)>` |
| Full | After a task that changes a shared contract (engine interface, `main`) | `flutter test` |
| Build | After phase completion | `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Contracts and infrastructure

```
T1 → T2 → T3 → T4
```

### Phase 2: Modo solo

```
T5 → T6 → T7
```

### Phase 3: Device verification artifacts

```
T8 → T9
```

Full cross-phase chain:

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9
```

---

## Task Breakdown

### T1: Engine ducking and no per-player interruption handling

**What**: Add `setDucked(bool)` to `AudioPlaybackEngine` and `MultiTrackAudioEngine` (gain × 0.5 on every track, click included; restore on `false`; applies to tracks added later). Default player factory becomes `AudioPlayer(handleInterruptions: false)`. The 7 test fakes implement `setDucked`.
**Where**: `lib/domain/audio/audio_playback_engine.dart`, `lib/infrastructure/audio/multi_track_audio_engine.dart`, test fakes
**Depends on**: None
**Reuses**: the existing `baseGain * volume` gain path
**Requirement**: BGA-12

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed in the test file header, then tests written first: ducked halves each track's volume; un-duck restores it; a volume change while ducked stays halved; a track added while ducked starts halved; mute stays 0
- [x] Gate check passes: `flutter test` (full: interface change touches every fake)
- [x] Test count: all existing + ≥ 4 new

**Tests**: unit
**Gate**: full
**Commit**: `feat(audio): duck the engine and stop per-player interruption handling`

---

### T2: `AudioInterruptions` contract + `AudioSessionInterruptions`

**What**: Domain enum + interface + `NoAudioInterruptions`; infrastructure mapping from the injected `audio_session` interruption and becoming-noisy streams (design's mapping table), plus `fromSession`.
**Where**: `lib/domain/audio/audio_interruptions.dart`, `lib/infrastructure/audio/audio_session_interruptions.dart`
**Depends on**: T1
**Reuses**: `audio_session` 0.1.25 `AudioInterruptionEvent`
**Requirement**: BGA-11, BGA-12, BGA-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first, then tests: each of the 6 event shapes maps as the design table says (`end`+`unknown` emits nothing); noisy → `headphonesDisconnected`; events after `dispose` are not emitted
- [x] `scripts/check_layers.py` passes (domain file has no plugin import)
- [x] Gate check passes: `flutter test test/infrastructure/audio/audio_session_interruptions_test.dart`
- [x] Test count: all existing + ≥ 7 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(audio): map OS audio interruptions to a domain stream`

---

### T3: `PlaybackRemote` contract + `CantaeAudioHandler`

**What**: Domain `PlaybackRemote`, `NowPlaying`, sealed `RemoteCommand`, `NoPlaybackRemote`; infrastructure `CantaeAudioHandler extends BaseAudioHandler implements PlaybackRemote` (publish → `mediaItem` + `playbackState`; `clear`; OS callbacks → commands).
**Where**: `lib/domain/audio/playback_remote.dart`, `lib/infrastructure/audio/cantae_audio_handler.dart`
**Depends on**: T2
**Reuses**: `audio_service` 0.18.19 `BaseAudioHandler`, `MediaItem`, `PlaybackState`, `MediaControl`, `MediaAction`
**Requirement**: BGA-05, BGA-06, BGA-07, BGA-08, BGA-09, BGA-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first, then tests: publish sets title, "Modo solo", duration; playing → controls `[pause]`, paused → `[play]`; `systemActions == {seek}` and nothing else; `updatePosition` matches; `clear` → `mediaItem` null + idle + not playing; `play`/`pause`/`seek`/`stop`/`onTaskRemoved` each emit the right command
- [x] `scripts/check_layers.py` passes
- [x] Gate check passes: `flutter test test/infrastructure/audio/cantae_audio_handler_test.dart`
- [x] Test count: all existing + ≥ 8 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(audio): add the lock-screen playback handler`

---

### T4: Bootstrap, providers, `main` and iOS background mode

**What**: `bootstrapBackgroundAudio` (configure session `.music()`, `AudioService.init`, interruptions; each failure caught and left at the no-op default) returning provider overrides; `background_audio_providers.dart` with no-op defaults; `main.dart` async calling it before `runApp`; `UIBackgroundModes: audio` in `ios/Runner/Info.plist`.
**Where**: `lib/infrastructure/audio/background_audio_bootstrap.dart`, `lib/presentation/providers/background_audio_providers.dart`, `lib/main.dart`, `ios/Runner/Info.plist`
**Depends on**: T3
**Reuses**: `AudioServiceConfig` (channel id/name, `androidStopForegroundOnPause` default)
**Requirement**: BGA-01, BGA-02, BGA-03, BGA-18

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Failure modes listed first, then tests: successful init → overrides resolve to the given handler and interruptions; init throws → `playbackRemoteProvider` is `NoPlaybackRemote`, and the call completes; session configure throws → init still attempted; interruptions throw → `NoAudioInterruptions`
- [x] Platform config test: `Info.plist` has `UIBackgroundModes` containing `audio`; manifest keeps the `AudioService` with `mediaPlayback`
- [x] Gate check passes: `flutter test` (full: `main` changes)
- [x] Test count: all existing + ≥ 6 new

**Tests**: unit
**Gate**: full
**Commit**: `feat(audio): start the background audio service at app launch`

---

### T5: Modo solo publishes state and obeys remote commands

**What**: `SoloPlayerNotifier` publishes `NowPlaying` at ready, play/pause, seek, loop jump and end; listens to `RemoteCommand` (play/pause only when they change state, seek, stop); clears the remote on stop and dispose.
**Where**: `lib/presentation/providers/solo_player_notifier.dart`
**Depends on**: T4
**Reuses**: `togglePlay`, `seekTo`, `_onPosition`
**Requirement**: BGA-04, BGA-05, BGA-06, BGA-07, BGA-08, BGA-10, BGA-19

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Tests written first with a fake `PlaybackRemote`: nothing published while loading; ready publishes title/"Modo solo"/duration paused at 0; play/pause/seek/loop jump/end each publish; `RemotePause` while playing pauses the engine and state; `RemotePause` while paused does nothing; `RemotePlay` after the end restarts from 0; `RemoteSeek` beyond the end clamps; `RemoteStop` pauses + clears; dispose clears; loop and metronome keep running with no lifecycle-driven pause
- [x] Gate check passes: `flutter test test/presentation/providers/solo_player_notifier_test.dart`
- [x] Test count: all existing + ≥ 11 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(solo-player): publish playback to the lock screen and obey its commands`

---

### T6: Modo solo pauses on interruptions and headphone loss

**What**: The notifier listens to `AudioInterruptions`: pause begin / headphones → pause all + `externalPause` + publish; pause end → nothing; duck → `setDucked`; engine pause failure → restore `playing`, no `externalPause`. Adds `acknowledgeExternalPause()`.
**Where**: `lib/presentation/providers/solo_player_notifier.dart`
**Depends on**: T5
**Reuses**: fake `AudioInterruptions` stream controller
**Requirement**: BGA-11, BGA-12, BGA-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tests written first: `pauseBegan` while playing → engine paused, `playing` false, `externalPause == interruption`, published paused; `pauseEnded` → no play; `headphonesDisconnected` → `externalPause == headphones`; headphones while paused → no `externalPause`; duck began/ended → `setDucked(true/false)`; engine pause throws → `playing` stays true, `externalPause` null; acknowledge clears it
- [ ] Gate check passes: `flutter test test/presentation/providers/solo_player_notifier_test.dart`
- [ ] Test count: all existing + ≥ 7 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(solo-player): pause on interruptions and when headphones disconnect`

---

### T7: Toast for an external pause + UI_SPEC

**What**: `SoloPlayerScreen` shows "Música pausada: outro áudio começou" / "Música pausada: fone desconectado" when `externalPause` is set — immediately if resumed, otherwise on the next resume — then acknowledges. UI_SPEC §6.12: replace "ainda não toca em segundo plano" with the background, notification and interruption behavior.
**Where**: `lib/presentation/screens/solo_player/solo_player_screen.dart`, `docs/design/UI_SPEC.md`
**Depends on**: T6
**Reuses**: `Toast.show`, `AppLifecycleListener`
**Requirement**: BGA-14

**Tools**:
- MCP: NONE
- Skill: flutter-ui-ux

**Done when**:
- [ ] Tests written first: interruption while resumed → toast now and button shows "Tocar"; headphones → its own text; interruption while paused (lifecycle `paused`) → no toast until `resumed`, then shown once; a remote `RemotePause` → screen shows "Tocar" without a toast; dark theme
- [ ] Gate check passes: `flutter test test/presentation/screens/solo_player/solo_player_screen_test.dart`
- [ ] Test count: all existing + ≥ 5 new

**Tests**: widget
**Gate**: build
**Commit**: `feat(solo-player): tell the singer why the music paused`

---

### T8: Device integration test

**What**: `integration_test/background_audio_test.dart`: writes 2 WAV tracks with `ClickTrackWav.encode`, pumps `SoloPlayerScreen` with overrides and a capturing `playerFactory`, taps "Tocar", waits 2 s, asserts both real players are playing and the position advanced ≥ 1500 ms, and writes the result log.
**Where**: `integration_test/background_audio_test.dart`
**Depends on**: T7
**Reuses**: `ClickTrackWav.encode`, the overrides pattern from the screen tests
**Requirement**: BGA-16

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `flutter analyze` passes with the file (compiles); not run (no device, per spec)
- [ ] The test writes `background_audio.log` (per-player `playing`, position delta) to the app documents dir and prints it with a fixed `BACKGROUND_AUDIO_LOG` prefix for `flutter test` output capture
- [ ] Gate check passes: `flutter analyze && flutter test` (desktop suite unchanged)

**Tests**: integration
**Gate**: build
**Commit**: `test(background-audio): add the device integration test`

---

### T9: Device test script + pending run in STATE.md

**What**: `docs/device-test-background-audio.md` (pt-BR, numbered steps with expected results: locked screen 5 min, app switch, notification play/pause/seek, call, short notification sound, headphones unplugged, close from recents, paused-in-background lifetime, notification permission on Android 13+, both tracks + clock via the integration test). STATE.md Handoff records that neither has run on a device, plus the two-handler debt.
**Where**: `docs/device-test-background-audio.md`, `.specs/STATE.md`
**Depends on**: T8
**Reuses**: spec P1–P3 acceptance criteria
**Requirement**: BGA-15, BGA-17

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Every P1–P3 acceptance criterion that needs the OS maps to at least one numbered step
- [ ] STATE.md lists the pending device run and the `BackgroundAudioHandler` debt
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test integration_test && flutter test`

**Tests**: none
**Gate**: build
**Commit**: `docs(background-audio): add the device test script`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 → T2 → T3 → T4
Phase 2:  T5 → T6 → T7
Phase 3:  T8 → T9
```

Execution is strictly sequential.

Total: 9 tasks → packs into 2 batches (Phases 1+2: 7, Phase 3: 2) → sub-agent offer applies; the user already chose sequential execution in the main session.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 | 1 engine member + factory default (+ compile-coupled fakes) | ✅ Granular |
| T2 | 1 contract + 1 mapper | ✅ Granular |
| T3 | 1 contract + 1 handler | ✅ Granular |
| T4 | 1 bootstrap function + its providers + call site + 1 plist key (one wiring unit) | ✅ Granular |
| T5 | 1 notifier extension (remote) | ✅ Granular |
| T6 | 1 notifier extension (interruptions) | ✅ Granular |
| T7 | 1 screen behavior + its UI_SPEC section | ✅ Granular |
| T8 | 1 integration test | ✅ Granular |
| T9 | 1 doc + handoff note | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1→T2 | ✅ Match |
| T3 | T2 | T2→T3 | ✅ Match |
| T4 | T3 | T3→T4 | ✅ Match |
| T5 | T4 | T4→T5 (cross-phase chain) | ✅ Match |
| T6 | T5 | T5→T6 | ✅ Match |
| T7 | T6 | T6→T7 | ✅ Match |
| T8 | T7 | T7→T8 (cross-phase chain) | ✅ Match |
| T9 | T8 | T8→T9 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Infrastructure (engine) + domain interface | unit | unit | ✅ OK |
| T2 | Infrastructure (interruptions) + domain | unit | unit | ✅ OK |
| T3 | Infrastructure (handler) + domain | unit | unit | ✅ OK |
| T4 | Infrastructure (bootstrap) + platform config | unit | unit | ✅ OK |
| T5 | Notifier | unit | unit | ✅ OK |
| T6 | Notifier | unit | unit | ✅ OK |
| T7 | Screen | widget | widget | ✅ OK |
| T8 | Device integration | integration | integration | ✅ OK |
| T9 | Docs | none | none | ✅ OK |
