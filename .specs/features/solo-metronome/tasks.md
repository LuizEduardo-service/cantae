# Metrônomo solo (solo-metronome) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/solo-metronome/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found:
> - `AGENTS.md` §5/§7: a widget test per component (states, dark theme, semantics); screen states; 130% font; ≥ 44 dp.
> - `CLAUDE.md`: failure-first for isolated systems; E2E-equivalent widget tests for features.
> - The user's standing rule: every bug gets a failing regression test in the same commit as its fix.
> - No coverage-threshold config.
>
> Sampled: `test/domain/audio/metronome_test.dart`, `test/infrastructure/audio/multi_track_audio_engine_test.dart`, `test/infrastructure/audio/fakes/fake_just_audio_platform.dart`, `test/presentation/providers/solo_player_notifier_test.dart`, `test/presentation/widgets/mix_track_row_test.dart`, `test/presentation/screens/solo_player/solo_player_screen_test.dart`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Domain (`MetronomePulseGenerator`) | unit | Regression for drift + every existing branch kept | `test/domain/audio/*_test.dart` | `flutter test test/domain/audio/metronome_test.dart` |
| Infrastructure (engine, WAV, builder) | unit (with `FakeJustAudioPlatform` / temp dir) | Each fix has a red-first regression test; WAV header + click positions/frequencies; builder success, failure → `Result.failure` | `test/infrastructure/audio/*_test.dart` | `flutter test test/infrastructure/audio` |
| Presentation (notifier) | unit | 1:1 to MET-04..MET-18 + edge cases | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers/solo_player_notifier_test.dart` |
| Presentation (shared widgets) | unit (widget) | Every state, callbacks, dark theme, semantics, ≥ 44 dp, 360 dp at 130% | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets/<widget>_test.dart` |
| Presentation (screen) | widget (e2e-equivalent) | Metronome on/off, tempo sheet flow, received-song rules, mix row, failure banners, themes, 130% | `test/presentation/screens/solo_player/*_test.dart` | `flutter test test/presentation/screens/solo_player/solo_player_screen_test.dart` |

## Gate Check Commands

> Same commands as previous features.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After a task with tests in one area | `flutter test <changed test file(s)>` |
| Full | After a task that changes a shared contract (engine interface/behavior, shared widget) | `flutter test` |
| Build | After phase completion | `flutter analyze && dart format --set-exit-if-changed lib test && flutter test` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Audio fixes

```
T1 → T2 → T3
```

### Phase 2: Engine tracks + click track

```
T4 → T5 → T6
```

### Phase 3: Modo solo metronome

```
T7 → T8 → T9 → T10
```

Full cross-phase chain:

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10
```

---

## Task Breakdown

### T1: `playAt` starts every track without waiting

**What**: Send `play()` to every player without awaiting each one (`unawaited`, errors swallowed per player). Add `holdPlayUntilPause` to the fake platform to mimic Android.
**Where**: `lib/infrastructure/audio/multi_track_audio_engine.dart`
**Depends on**: None
**Reuses**: `test/infrastructure/audio/fakes/fake_just_audio_platform.dart`
**Requirement**: MET-01

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Regression test written first and failing on the current code: with `holdPlayUntilPause`, `playAt` on a 2-track song sends `play` to both players, and the `playAt` future completes without a pause
- [x] Gate check passes: `flutter test` (full: every screen and the room use `playAt`)
- [x] Test count: all existing + ≥ 2 new

**Tests**: unit
**Gate**: full
**Commit**: `fix(audio): start every track without waiting for the previous one`

---

### T2: Position from the continuous `positionStream`

**What**: Feed `positionMs` from the reference player's `positionStream` instead of `playbackEventStream`.
**Where**: `lib/infrastructure/audio/multi_track_audio_engine.dart`
**Depends on**: T1
**Reuses**: `_longestTrack`, `TimelineConverter.toTimeline`
**Requirement**: MET-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Regression test written first and failing on the current code: after `playAt`, with no new playback event, `positionMs` emits a value ≥ 100 ms within 400 ms
- [x] Existing position tests updated only where they emitted events to fake the clock (behavior kept: timeline conversion, longest-track reference)
- [x] Gate check passes: `flutter test` (full)
- [x] Test count: all existing + ≥ 1 new

**Tests**: unit
**Gate**: full
**Commit**: `fix(audio): read the timeline position from the continuous position stream`

---

### T3: Pulses without cumulative drift

**What**: Pulse `n` at `(n * 60000 / bpm).round()`; first pulse = smallest `n` with position ≥ `startMs`.
**Where**: `lib/domain/audio/metronome_pulse_generator.dart`
**Depends on**: T2
**Reuses**: existing `metronome_test.dart`
**Requirement**: MET-03

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [ ] Regression test written first and failing on the current code: at 72 BPM, pulse 216 is at 180000 ms; no pulse is more than 1 ms from `n * 60000 / 72`
- [ ] Mid-beat start still aligns to the global grid (existing test passes)
- [ ] `scripts/check_layers.py` passes
- [ ] Gate check passes: `flutter test test/domain/audio/metronome_test.dart`
- [ ] Test count: existing + ≥ 2 new

**Tests**: unit
**Gate**: quick
**Commit**: `fix(metronome): place pulses without cumulative drift`

---

### T4: `addTrack` / `removeTrack` on the engine

**What**: Add both members to `AudioPlaybackEngine` and implement them in `MultiTrackAudioEngine`; update the 7 test fakes.
**Where**: `lib/infrastructure/audio/multi_track_audio_engine.dart` (plus the interface in `lib/domain/audio/audio_playback_engine.dart` and the 7 `implements AudioPlaybackEngine` fakes, which must change in the same commit to compile)
**Depends on**: T3
**Reuses**: per-track setup in `loadSong`, `_disposeAllPlayers`
**Requirement**: MET-05, MET-07

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [ ] Tests: `addTrack` creates one more player at volume 1.0 without reloading the others; `seekAllTo` then moves it too; `setTrackVolume`/`setTrackMuted` apply to it; `removeTrack` disposes only that player; unknown id is a no-op; the position reference does not change
- [ ] Gate check passes: `flutter test` (full: interface change)
- [ ] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: full
**Commit**: `feat(audio): add and remove a single track on the engine`

---

### T5: `ClickTrackWav` encoder

**What**: Pure function encoding pulses into a RIFF/WAVE PCM 16-bit mono file (30 ms beeps, 1500 Hz downbeat / 1000 Hz beat, silence elsewhere).
**Where**: `lib/infrastructure/audio/click_track_wav.dart`
**Depends on**: T4
**Reuses**: `MetronomePulse`
**Requirement**: MET-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Failure modes listed first in the test header (CLAUDE.md rule 3): wrong header sizes; samples off by the pulse position; beep past the end of the file; downbeat not distinguishable; zero duration
- [ ] `test/infrastructure/audio/click_track_wav_test.dart`: header fields (RIFF/WAVE/fmt/data, 22050 Hz, 16-bit, mono, data size = samples × 2); length = `durationMs × 22050 / 1000` samples; silence before the first pulse and between pulses; non-zero samples starting at each pulse's sample index; downbeat beep has more zero crossings than a regular beep; a pulse near the end is truncated without error; `durationMs: 0` → header only
- [ ] Gate check passes: `flutter test test/infrastructure/audio/click_track_wav_test.dart`
- [ ] Test count: ≥ 7 tests pass

**Tests**: unit
**Gate**: quick
**Commit**: `feat(metronome): encode the click track as WAV`

---

### T6: `ClickTrackBuilder` + `FileClickTrackBuilder` + provider

**What**: Domain interface returning `Result<String, Failure>`; file implementation (pulses + encode in `Isolate.run`, write to the temp dir, accent off → no downbeats, exceptions → `PlaybackFailure`); `clickTrackBuilderProvider`.
**Where**: `lib/infrastructure/audio/file_click_track_builder.dart` (plus the one-file domain interface `lib/domain/audio/click_track_builder.dart` and the provider file)
**Depends on**: T5
**Reuses**: `MetronomePulseGenerator`, `ClickTrackWav`, `audioPlaybackEngineProvider` shape
**Requirement**: MET-06, MET-09, MET-19

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [ ] Tests with an injected temp directory: success writes `metronome_<songId>.wav` and returns its path; with accent off, the file has no downbeat beeps; a second build overwrites the same file; an unwritable directory returns `Result.failure(PlaybackFailure)` without throwing
- [ ] `scripts/check_layers.py` passes (domain interface is plugin-free)
- [ ] Gate check passes: `flutter test test/infrastructure/audio/file_click_track_builder_test.dart`
- [ ] Test count: ≥ 4 tests pass

**Tests**: unit
**Gate**: quick
**Commit**: `feat(metronome): build the click track file off the UI thread`

---

### T7: Metronome in `SoloPlayerNotifier`

**What**: State, `toggleMetronome`, `saveTempo`, `setMetronomeVolume`, `toggleMetronomeMute`, "ligar ao abrir", per design.md.
**Where**: `lib/presentation/providers/solo_player_notifier.dart`
**Depends on**: T6
**Reuses**: `LyricsEditorNotifier.save` pattern; existing mix logic
**Requirement**: MET-04 to MET-09, MET-12 to MET-18

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [ ] Tests (fake builder + fake engine), 1:1 to ACs:
  - **toggle on:** builds and adds the `metronome` track, then seeks to the current position;
  - **on while playing:** pause → add → seek → play;
  - **toggle off:** removes only the click track, with no pause or seek of the voices;
  - **build failure:** off + `metronomeError`; music state unchanged;
  - **`addTrack` throws:** same as a build failure;
  - **no config:** toggle does nothing;
  - **`enabledByDefault`:** turns on after ready;
  - **`saveTempo` success:** saves the config with `enabledByDefault` preserved, updates the song, turns the metronome on, and rebuilds the click when it was already on;
  - **`saveTempo` failure:** `tempoSaveError`, metronome unchanged, returns false;
  - **received song:** `saveTempo` does nothing;
  - **volume and mute:** reach the `metronome` track only;
  - **fresh screen:** metronome volume 100 %, unmuted.
- [ ] Gate check passes: `flutter test test/presentation/providers/solo_player_notifier_test.dart`
- [ ] Test count: existing + ≥ 14 new

**Tests**: unit
**Gate**: quick
**Commit**: `feat(solo-metronome): add the metronome to SoloPlayerNotifier`

---

### T8: `MixTrackRow.showSolo`

**What**: Optional `showSolo` (default true); false hides the S toggle. COMPONENTS.md updated.
**Where**: `lib/presentation/widgets/mix_track_row.dart`
**Depends on**: T7
**Reuses**: —
**Requirement**: MET-15

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Tests: `showSolo: false` renders M only; default still renders M and S; 360 dp at 130% without overflow
- [ ] Gate check passes: `flutter test test/presentation/widgets/mix_track_row_test.dart`
- [ ] Test count: existing + ≥ 2 new

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `feat(widgets): let MixTrackRow hide the solo toggle`

---

### T9: `TempoSheet`

**What**: Bottom sheet "Andamento" (BPM, tempos por compasso, Com/Sem acento, "Salvar andamento", limit messages, save error), and its COMPONENTS.md entry.
**Where**: `lib/presentation/widgets/tempo_sheet.dart`
**Depends on**: T8
**Reuses**: `ConfirmSheet` sheet styling; `SegmentedControl`; `PrimaryButton`; `InlineBanner`
**Requirement**: MET-10, MET-11, MET-12, MET-13

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Tests:
  - prefilled values shown;
  - BPM 29 or 301 → "Entre 30 e 300" and save disabled; beats 1 or 17 → "Entre 2 e 16" and save disabled;
  - valid values → `onSave` receives `MetronomeConfig(bpm, beatsPerMeasure, downbeatAccent)` and the sheet closes on null;
  - `onSave` returning an error keeps the sheet open with the typed values and shows the message;
  - semantics labels on the fields;
  - dark theme;
  - 360 dp at 130%.
- [ ] Gate check passes: `flutter test test/presentation/widgets/tempo_sheet_test.dart`
- [ ] Test count: ≥ 7 tests pass

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `feat(widgets): add TempoSheet`

---

### T10: Metronome on `SoloPlayerScreen`

**What**: Two-row footer with the metronome button, the "Metrônomo" mix row, the tempo caption with "Ajustar andamento", received-song rules, error banner and toast, plus the UI_SPEC §6.12 update.
**Where**: `lib/presentation/screens/solo_player/solo_player_screen.dart` (plus `docs/design/UI_SPEC.md` §6.12)
**Depends on**: T9
**Reuses**: widgets from T8/T9; existing screen structure
**Requirement**: MET-04, MET-05, MET-08 to MET-17

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-widget-performance`

**Done when**:
- [ ] Screen tests:
  - "Metrônomo ♩ 72" toggles on/off (positive when on); the "Metrônomo" mix row appears only when on, with M and no S, and its volume reaches the engine;
  - created song without config → "Metrônomo" opens the sheet; saving shows "Metrônomo ♩ 96", the toast "Andamento salvo", and the repository has the config;
  - received song without config → button disabled + the explanatory sentence; received song with config → toggles, but no "Ajustar andamento";
  - "Ajustar andamento" opens the prefilled sheet;
  - build failure → "Não foi possível preparar o metrônomo.";
  - "ligar ao abrir" → on when the screen opens;
  - still one primary action; dark theme; 360 dp at 130% with all footer targets ≥ 44 dp.
- [ ] UI_SPEC §6.12 updated in the same commit
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test`
- [ ] Test count: existing + ≥ 10 new

**Tests**: widget
**Gate**: build
**Commit**: `feat(solo-metronome): add the metronome to SoloPlayerScreen`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 → T2 → T3
Phase 2:  T4 → T5 → T6
Phase 3:  T7 → T8 → T9 → T10
```

Execution is strictly sequential.

Total: 10 tasks → packs into 2 batches (Phases 1+2: 6, Phase 3: 4) → sub-agent offer applies.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 | 1 method (`playAt`) + test double flag | ✅ Granular |
| T2 | 1 subscription source | ✅ Granular |
| T3 | 1 function | ✅ Granular |
| T4 | 2 cohesive engine members (+ compile-coupled fakes) | ✅ Granular |
| T5 | 1 pure function | ✅ Granular |
| T6 | 1 interface + 1 implementation + 1 provider (cohesive, one contract) | ✅ Granular |
| T7 | 1 notifier extension | ✅ Granular |
| T8 | 1 widget prop | ✅ Granular |
| T9 | 1 widget | ✅ Granular |
| T10 | 1 screen + its UI_SPEC section | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1→T2 | ✅ Match |
| T3 | T2 | T2→T3 | ✅ Match |
| T4 | T3 | T3→T4 (cross-phase chain) | ✅ Match |
| T5 | T4 | T4→T5 | ✅ Match |
| T6 | T5 | T5→T6 | ✅ Match |
| T7 | T6 | T6→T7 (cross-phase chain) | ✅ Match |
| T8 | T7 | T7→T8 | ✅ Match |
| T9 | T8 | T8→T9 | ✅ Match |
| T10 | T9 | T9→T10 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Infrastructure (engine) | unit | unit | ✅ OK |
| T2 | Infrastructure (engine) | unit | unit | ✅ OK |
| T3 | Domain | unit | unit | ✅ OK |
| T4 | Infrastructure (engine) + domain interface | unit | unit | ✅ OK |
| T5 | Infrastructure (WAV) | unit | unit | ✅ OK |
| T6 | Infrastructure (builder) + domain interface | unit | unit | ✅ OK |
| T7 | Notifier | unit | unit | ✅ OK |
| T8 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T9 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T10 | Screen | widget | widget | ✅ OK |
