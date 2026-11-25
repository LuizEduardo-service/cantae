# Áudio em segundo plano (background-audio) Validation

**Date**: 2026-11-25
**Spec**: `.specs/features/background-audio/spec.md`
**Diff range**: `22e04a4..1e74947` (branch `feature/phase-5-background-audio`; spec at `1b963a1`, design/tasks at `22e04a4`)
**Verifier**: standalone fallback, run by the author. The sub-agent call is blocked by auto mode because the `context-mode` plugin rewrites Agent prompts; the user approved the same fallback for the earlier features. Author ≠ verifier does **not** hold for this run.

**Verdict**: PASS ✅ (iteration 1). Desktop-verifiable scope only; the device run is pending by user decision (BGA-17).

---

## Task Completion

| Task | Status | Commit |
| ---- | ------ | ------ |
| T1 engine duck + no per-player interruption handling | ✅ Done | `ca18356` |
| T2 `AudioInterruptions` + `AudioSessionInterruptions` | ✅ Done | `dfb1f4c` |
| T3 `PlaybackRemote` + `CantaeAudioHandler` | ✅ Done | `70e261e` |
| T4 bootstrap, providers, `main`, iOS background mode | ✅ Done | `d04f68c` |
| T5 Modo solo publishes and obeys remote commands | ✅ Done | `2780fae` |
| T6 Modo solo pauses on interruptions / headphones | ✅ Done | `2a9bd51` |
| T7 toast for an external pause + UI_SPEC | ✅ Done | `9749c74` |
| T8 device integration test | ✅ Done (compiles; not run) | `1d06faa` |
| T9 device test script + STATE.md | ✅ Done | `1e74947` |

---

## Spec-Anchored Acceptance Criteria

| Req | Evidence (`file:line` — assertion) | Spec outcome | Result |
| --- | ---------------------------------- | ------------ | ------ |
| BGA-01 | `test/infrastructure/audio/background_audio_bootstrap_test.dart:33` — `expect(audio.remote, same(remote))`; `lib/main.dart` awaits `bootstrapBackgroundAudio()` before `runApp` | Service registered once at launch | ✅ (real `AudioService.init` is device-only) |
| BGA-02 | `background_audio_bootstrap_test.dart:33` — `expect(order.first, 'session')` | Session configured before anything plays | ✅ (category `.music()` effect is device-only) |
| BGA-03 | `test/infrastructure/audio/platform_config_test.dart:9` — `expect(modes!.group(1), contains('<string>audio</string>'))`; `:21` — `mediaPlayback` service + permission | iOS background audio declared; Android service kept | ✅ |
| BGA-04 | `test/presentation/providers/solo_player_notifier_test.dart:1073` — after `AppLifecycleState.paused`, `expect(s.engine.calls, isNot(contains('pause')))`, `expect(s.engine.calls.last, 'seek:41000')`; `:970` end → `playing` false at 180000 | Keeps playing with loop in background; end pauses at the end | ✅ (OS keeping the process alive is device-only) |
| BGA-05 | `solo_player_notifier_test.dart:901` — `info.title == 'Ave Verum Corpus'`, `subtitle == 'Modo solo'`, `durationMs == 180000`; `cantae_audio_handler_test.dart:34` — `item.title`, `item.artist == 'Modo solo'`, `item.duration` | Title, "Modo solo", duration | ✅ |
| BGA-06 | `solo_player_notifier_test.dart:915` (play/pause), `:942` (seek 41000), `:953` (loop jump 41000, playing), `:970` (end); `:929` plain tick does not publish; `cantae_audio_handler_test.dart:43` — `updatePosition == 41000 ms`, `playing` | State and position published on each event | ✅ |
| BGA-07 | `solo_player_notifier_test.dart:981` — `RemotePause` → `playing` false, `calls.last == 'pause'`; `:994` paused → unchanged; `:1006` `RemotePlay` → `'play'`, again → unchanged; `:1022` after the end → `['seek:0','play']`; `cantae_audio_handler_test.dart:85/91` OS play/pause → commands; screen `solo_player_screen_test.dart:808` shows "Tocar" | Same effect as in-app Tocar/Pausar | ✅ |
| BGA-08 | `solo_player_notifier_test.dart:1035` — `'seek:41000'`, then clamped `'seek:180000'`; `cantae_audio_handler_test.dart:97` — `positionMs == 41500` | Same effect as dragging the in-app bar | ✅ |
| BGA-09 | `cantae_audio_handler_test.dart:43` — `controls == [MediaControl.pause]`, `systemActions == {MediaAction.seek}`; `:55` — `[MediaControl.play]` | Only Tocar/Pausar and the bar | ✅ |
| BGA-10 | `solo_player_notifier_test.dart:1050` — `RemoteStop` → `'pause'`, `clears == 1`; `:1064` dispose → `clears == 1`; `cantae_audio_handler_test.dart:109` — `onTaskRemoved` → `RemoteStop`; `:72` — `clear` → `mediaItem` null, idle | Leaving or closing from recents stops and removes the notification | ✅ |
| BGA-11 | `solo_player_notifier_test.dart:1098` — `'pause'`, `externalPause == interruption`, published paused; `:1112` pause end → calls unchanged; `audio_session_interruptions_test.dart:48/53/58/63` mapping | Pause, no auto-resume | ✅ (`handleInterruptions: false` itself is device-only, see Gaps) |
| BGA-12 | `multi_track_audio_engine_test.dart:199` — ×0.5 on every track incl. click, restored; `:221/:231/:241`; `solo_player_notifier_test.dart:1153` — `'ducked:true'`/`'ducked:false'`, still playing; `audio_session_interruptions_test.dart:67/72` | Volume lowers and returns, no pause | ✅ |
| BGA-13 | `solo_player_notifier_test.dart:1126` — `'pause'`, `externalPause == headphones`; `audio_session_interruptions_test.dart:77` | Headphones disconnected pauses | ✅ |
| BGA-14 | `solo_player_screen_test.dart:758` — "Tocar" + "Música pausada: outro áudio começou"; `:770` — "Música pausada: fone desconectado"; `:782` — deferred until resumed, shown once; `:808` remote pause → no toast; `solo_player_notifier_test.dart:1170` — pause failure → `playing` true, `externalPause` null | Toast with the right text after an external pause; P3-AC6 | ✅ |
| BGA-15 | `docs/device-test-background-audio.md` — 14 numbered steps + coverage table mapping every OS-dependent criterion | Device script in `docs/` | ✅ |
| BGA-16 | `integration_test/background_audio_test.dart` — `expect(playing, everyElement(isTrue))`, `advancedMs >= 1500`, writes `background_audio.log`; compiles under `flutter analyze` | Integration test with a log artifact | ✅ (not run: no device) |
| BGA-17 | `.specs/STATE.md` Handoff — "Pending device run (BGA-17)" | Pending run recorded | ✅ |
| BGA-18 | `background_audio_bootstrap_test.dart:57` — service throws → `isA<NoPlaybackRemote>()`; `:68` session throws → service still started; `:80` interruptions throw → `NoAudioInterruptions` | App opens without notification controls | ✅ |
| BGA-19 | `solo_player_notifier_test.dart:893` — notFound → `published` empty; one owner: only `SoloPlayerNotifier` subscribes to `PlaybackRemote.commands` (`lib/presentation/providers/solo_player_notifier.dart`) | No notification before a song is ready; one owner at a time | ✅ (one-owner by construction) |

**Status**: ✅ All 19 requirements covered at the level the desktop can prove.

---

## Discrimination Sensor

Run in a temporary `git worktree` under the scratchpad (with `app_database.g.dart` copied), never `git stash`. Each mutant ran the test files of its area. Kill reasons were re-checked: none is a compile error. 30 fail an `expect`; B12 (`commands.single` on an empty list) and B14–B16 (the rethrown bootstrap error) fail by an exception inside the test.

| ID | Mutation | Result |
| -- | -------- | ------ |
| B1–B3 | engine: duck ignored / never ducks / factor 0.8 | 3 killed |
| B4–B7 | interruptions: duck→pause, unknown end→pauseEnded, pause→duck, noisy→pause | 4 killed |
| B8–B13 | handler: controls never flip, no seek action, wrong subtitle, clear keeps item, recents ignored, seek in seconds | 6 killed |
| B14–B16 | bootstrap: service / session / interruptions failure escapes | 3 killed |
| B17 | `Info.plist` without `audio` | killed |
| B18–B24 | notifier: wrong subtitle, pause while paused plays, play while playing pauses, stop keeps notification, dispose keeps notification, loop jump / seek not published | 7 killed |
| B25–B31 | notifier: auto-resume, wrong headphones reason, reason while paused, pause failure ignored, duck pauses, stale reason after play, playing never published | 7 killed |
| B32–B34 | screen: toast in background, toast repeats, wrong headphones text | 3 killed |

**Result**: **34/34 killed: PASS ✅**. Real tree porcelain matched the pre-sensor baseline (empty) after the worktree was removed.

**Not mutated (device-only):** `MultiTrackAudioEngine.defaultPlayer`'s `handleInterruptions: false`. `AudioPlayer` exposes no getter and `flutter test` has no audio session, so a regression back to `true` would pass CI. Guarded by device script steps 8–9.

---

## Code Quality

- `scripts/check_layers.py`: OK. The new domain files (`audio_interruptions.dart`, `playback_remote.dart`) import nothing.
- SPEC_DEVIATION (recorded in `background_audio_bootstrap.dart`): the bootstrap returns the two domain contracts and `main.dart` builds the overrides, instead of the bootstrap returning Riverpod overrides. Keeps infrastructure from importing presentation.
- Remote commands reuse `togglePlay` / `seekTo`; there is no second playback path.

---

## Gaps (not failures)

1. **Device run pending** (user decision): BGA-01..04 OS effects, BGA-11 `handleInterruptions: false`, BGA-12 real duck events, the Android 13+ notification-permission assumption and the solo-metronome T1/T2 fixes. All mapped to steps in `docs/device-test-background-audio.md`.
2. **Two `audio_service` handlers** in the code: recorded as debt in STATE.md.

---

## Gate Check

- `flutter analyze`: no issues.
- `dart format --set-exit-if-changed lib test integration_test`: clean.
- `flutter test`: **758 passed** (701 before the feature, +57).

---

## Requirement Traceability Update

BGA-01 to BGA-19: Implementing → Verified.

---

## Summary

**Overall**: ✅ Ready to merge, with the device run pending.

**Spec-anchored check**: 19/19 requirements matched to the spec outcome.
**Sensor**: 34/34 mutations killed.
**Gate**: 758 passed.

**Next steps**: merging `feature/phase-5-background-audio` into `develop` needs the user's go-ahead; then run the device script.
