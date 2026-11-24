# Modo solo (solo-player) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/solo-player/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `AGENTS.md` §5/§7 (a widget test per component covering states, dark theme and semantics; screen states per UI_SPEC; 130% font; ≥ 44 dp), `CLAUDE.md` (testing rules: failure-first for isolation, E2E-equivalent widget tests for features), the user's standing rule (every bug gets a failing regression test in the same commit as its fix). No coverage-threshold config (`analysis_options.yaml` holds lint rules only). Sampled: `test/domain/entities/lyric_line_test.dart`, `test/infrastructure/audio/multi_track_audio_engine_test.dart`, `test/presentation/providers/lyrics_editor_notifier_test.dart`, `test/presentation/providers/track_align_notifier_test.dart`, `test/presentation/widgets/lyric_line_row_test.dart`, `test/presentation/widgets/track_align_row_test.dart`, `test/presentation/screens/lyrics_editor/lyrics_editor_screen_test.dart`, `test/presentation/routing/app_router_test.dart`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Domain (`LyricCursor`) | unit | All branches; 1:1 to spec P4-AC2 (before first line, exact onset, between lines, after last, ties) | `test/domain/audio/*_test.dart` | `flutter test test/domain/audio/lyric_cursor_test.dart` |
| Infrastructure (audio engine) | unit (with `FakeJustAudioPlatform`) | Each new rule: volume × base gain, clamping, interaction with mute and with solo; reference track = longest | `test/infrastructure/audio/*_test.dart` | `flutter test test/infrastructure/audio/multi_track_audio_engine_test.dart` |
| Presentation (notifier) | unit | 1:1 to spec ACs P1-P3 + every edge case (statuses, play/pause, seek clamp, end of song, mix, loop marking/validation/reposition/clear, dispose stops) | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers/solo_player_notifier_test.dart` |
| Presentation (shared widgets) | unit (widget) | Per AGENTS.md: every state of the component, callbacks, dark theme, semantics, ≥ 44 dp where tappable | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets/<widget>_test.dart` |
| Presentation (screen) | widget (e2e-equivalent per AGENTS.md) | Every status body, the ready layout, primary action, loop flow, mix, lyric view, both themes, 360 dp at 130%, semantics | `test/presentation/screens/solo_player/*_test.dart` | `flutter test test/presentation/screens/solo_player/solo_player_screen_test.dart` |
| Routing | widget | Route builds the real screen with the id; Detalhe passes the id | `test/presentation/routing/app_router_test.dart`, `test/presentation/screens/song_detail/song_detail_screen_test.dart` | `flutter test test/presentation/routing test/presentation/screens/song_detail` |

## Gate Check Commands

> Generated from codebase - confirm before Execute. Same commands as previous features (no CI workflow file in the repo).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After a task with unit/widget tests in one area | `flutter test <changed test file(s)>` |
| Full | After a task that changes a shared contract (engine interface, shared widget used elsewhere) | `flutter test` |
| Build | After phase completion | `flutter analyze && dart format --set-exit-if-changed lib test && flutter test` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Domain + audio engine

```
T1 → T2 → T3
```

### Phase 2: Shared widgets

```
T4 → T5 → T6 → T7 → T8 → T9
```

### Phase 3: Notifier, screen, route

```
T10 → T11 → T12
```

Full cross-phase chain:

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11 → T12
```

---

## Task Breakdown

### T1: `LyricCursor` domain function

**What**: Pure function returning `(previous, current, next)` indexes of timed lyric lines at a position, per design.md.
**Where**: `lib/domain/audio/lyric_cursor.dart`
**Depends on**: None
**Reuses**: The `currentLineIndex` rule of `LyricsEditorState` (`lib/presentation/providers/lyrics_editor_notifier.dart:115-127`)
**Requirement**: SOLO-19

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture` (domain stays Flutter/plugin-free)

**Done when**:
- [x] Failure modes listed first in the test file header (CLAUDE.md rule 3): empty list, position before first onset, exactly on an onset, between lines, after last line, two lines with the same onset
- [x] `test/domain/audio/lyric_cursor_test.dart` covers each failure mode with the exact expected record
- [x] `scripts/check_layers.py` passes (domain purity)
- [x] Gate check passes: `flutter test test/domain/audio/lyric_cursor_test.dart`
- [x] Test count: ≥ 6 tests pass

**Tests**: unit
**Gate**: quick
**Commit**: `feat(solo-player): add LyricCursor`

---

### T2: Per-track volume in the audio engine

**What**: Add `setTrackVolume(trackId, volume)` to `AudioPlaybackEngine` and implement it in `MultiTrackAudioEngine` (clamp 0..1, effective = base gain × volume under the existing mute/solo rules); give the five test fakes a recording implementation.
**Where**: `lib/infrastructure/audio/multi_track_audio_engine.dart` (plus the one-line interface member in `lib/domain/audio/audio_playback_engine.dart` and the five `implements AudioPlaybackEngine` fakes under `test/`, which must change in the same commit to compile)
**Depends on**: T1
**Reuses**: `_effectiveVolume` / `_applyVolume`; `FakeJustAudioPlatform` in `test/infrastructure/audio/fakes/`
**Requirement**: SOLO-10, SOLO-11, SOLO-12

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [x] Tests in `multi_track_audio_engine_test.dart`: volume 0.3 → player volume 0.3; volume > 1 and < 0 clamp; muted track stays 0 after a volume change and returns to its volume on unmute; with another track soloed the track stays 0; the soloed track plays at its own volume
- [x] All existing engine tests unchanged and passing
- [x] Gate check passes: `flutter test` (full: interface change)
- [x] Test count: all existing + ≥ 5 new

**Tests**: unit
**Gate**: full
**Commit**: `feat(solo-player): add per-track volume to the audio engine`

---

### T3: Position follows the longest track

**What**: `MultiTrackAudioEngine.loadSong` picks as the position reference the loaded track with the greatest `startDelayMs + file duration` (Risks row 1).
**Where**: `lib/infrastructure/audio/multi_track_audio_engine.dart`
**Depends on**: T2
**Reuses**: `durationMs` computation in the same file
**Requirement**: SOLO-04, SOLO-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Regression test written first and failing on the current code: two tracks, the first one shorter; events from the longer track's player drive `positionMs`, events from the shorter do not
- [x] Existing "emits the reference track's position" test still passes (single-track/first-is-longest case)
- [x] Gate check passes: `flutter test` (full: the room's playback also reads `positionMs`)
- [x] Test count: all existing + ≥ 1 new

**Tests**: unit
**Gate**: full
**Commit**: `fix(audio): follow the longest track for the timeline position`

---

### T4: `MuteSoloToggle` shared widget

**What**: Extract `TrackAlignRow._ToggleButton` into the public `MuteSoloToggle`, switch `TrackAlignRow` to it, and add it to `COMPONENTS.md`.
**Where**: `lib/presentation/widgets/mute_solo_toggle.dart` (and the import swap in `lib/presentation/widgets/track_align_row.dart`, plus `docs/design/COMPONENTS.md`)
**Depends on**: T3
**Reuses**: `lib/presentation/widgets/track_align_row.dart:228` verbatim
**Requirement**: SOLO-09

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] `test/presentation/widgets/mute_solo_toggle_test.dart`: off/on rendering, tap callback, semantics (button, label, toggled state), ≥ 44 dp, dark theme
- [ ] `track_align_row_test.dart` and `track_align_screen_test.dart` pass **unchanged**
- [ ] Gate check passes: `flutter test test/presentation/widgets test/presentation/screens/track_align`
- [ ] Test count: all existing + ≥ 4 new

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `refactor(widgets): extract MuteSoloToggle from TrackAlignRow`

---

### T5: `TonalButton`

**What**: Add `TonalButton` (neutral `fillOnSurface` / positive `accentSoft`, height 44) to the buttons file and to `COMPONENTS.md` usage notes.
**Where**: `lib/presentation/widgets/buttons.dart`
**Depends on**: T4
**Reuses**: `SecondaryButton` structure in the same file
**Requirement**: SOLO-14, SOLO-17

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] Tests in `test/presentation/widgets/buttons_test.dart`: neutral and positive colors from tokens, disabled state (`onPressed: null`), ≥ 44 dp, semantics button + enabled flag, dark theme
- [ ] Gate check passes: `flutter test test/presentation/widgets/buttons_test.dart`
- [ ] Test count: existing + ≥ 4 new

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `feat(widgets): add TonalButton`

---

### T6: `StatusPill` (neutral variant)

**What**: Add `StatusPill` with the neutral variant only (label, height 44, live region) and its `COMPONENTS.md` note.
**Where**: `lib/presentation/widgets/status_pill.dart`
**Depends on**: T5
**Reuses**: `NavPill` measurements and tokens
**Requirement**: SOLO-08

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] `test/presentation/widgets/status_pill_test.dart`: renders label, height 44, live region semantics, dark theme
- [ ] Gate check passes: `flutter test test/presentation/widgets/status_pill_test.dart`
- [ ] Test count: ≥ 3 tests pass

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `feat(widgets): add StatusPill neutral variant`

---

### T7: `PlaybackProgress`

**What**: Shared progress bar per design.md (times in mono, accent slider, seek on drag end, loop region, caption) and its `COMPONENTS.md` update.
**Where**: `lib/presentation/widgets/playback_progress.dart`
**Depends on**: T6
**Reuses**: `TrackAlignDuration.format`; tokens `accent`, `accentTrack`, `mono`
**Requirement**: SOLO-04, SOLO-05, SOLO-18

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-widget-performance`

**Done when**:
- [ ] `test/presentation/widgets/playback_progress_test.dart`: shows `0:05.3` / total; dragging calls `onSeek` once, on drag end, with the dropped time; the loop region is painted only when both loop bounds are set; caption shown when given; slider semantics label "Posição da música"; dark theme; 360 dp at 130% without overflow
- [ ] Gate check passes: `flutter test test/presentation/widgets/playback_progress_test.dart`
- [ ] Test count: ≥ 6 tests pass

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `feat(widgets): add PlaybackProgress`

---

### T8: `LyricView`

**What**: Shared compact lyric view (past / active card / "Próxima") driven by a `LyricCursorResult`, with the active line as a live region, and its `COMPONENTS.md` update.
**Where**: `lib/presentation/widgets/lyric_view.dart`
**Depends on**: T7
**Reuses**: `LyricCursor` (T1); `VoicePartBadge`; typography `lyricPast`/`lyricActive`/`lyricNext`; the "Naipe · dinâmica" text rule of `LyricLineRow`
**Requirement**: SOLO-19, SOLO-20, SOLO-22

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] `test/presentation/widgets/lyric_view_test.dart`: before the first line only "Próxima" + first line; middle: past, active, next; last line: no "Próxima"; active line with naipe + dinâmica shows selo + "Tenor · piano"; naipe only → selo only; dinâmica only → dinâmica text; active line is a live region; dark theme; 360 dp at 130%
- [ ] Gate check passes: `flutter test test/presentation/widgets/lyric_view_test.dart`
- [ ] Test count: ≥ 7 tests pass

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `feat(widgets): add LyricView`

---

### T9: `MixTrackRow`

**What**: One mix row (selo + name, volume slider, M and S via `MuteSoloToggle`) and its `COMPONENTS.md` entry.
**Where**: `lib/presentation/widgets/mix_track_row.dart`
**Depends on**: T8
**Reuses**: `MuteSoloToggle` (T4), `VoicePartBadge`
**Requirement**: SOLO-09, SOLO-10, SOLO-11, SOLO-12

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`

**Done when**:
- [ ] `test/presentation/widgets/mix_track_row_test.dart`: naipe row shows selo + "Tenor"; playback row shows "Playback"; slider reports the new volume; semantics "Volume do Tenor" with value "30 %"; M and S callbacks; M/S toggled state in semantics (not only color); ≥ 44 dp; dark theme; 360 dp at 130%
- [ ] Gate check passes: `flutter test test/presentation/widgets/mix_track_row_test.dart`
- [ ] Test count: ≥ 7 tests pass

**Tests**: unit (widget)
**Gate**: quick
**Commit**: `feat(widgets): add MixTrackRow`

---

### T10: `SoloPlayerNotifier` + `SoloPlayerState`

**What**: The notifier and its `autoDispose.family` provider exactly as in design.md (statuses, play/pause, seek, end of song, mix, loop, dispose).
**Where**: `lib/presentation/providers/solo_player_notifier.dart`
**Depends on**: T9
**Reuses**: `TrackAlignNotifier` (loop reposition, non-awaited `cancel()`, `dispose` → `stop`), `LyricsEditorNotifier._onSongResult` (incl. the `isLoading && hasValue` guard), `LoopController`
**Requirement**: SOLO-02 to SOLO-07, SOLO-10 to SOLO-17, SOLO-23 to SOLO-25

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture`

**Done when**:
- [ ] `test/presentation/providers/solo_player_notifier_test.dart`, 1:1 to ACs: loaded → `ready`, position 0, duration from engine; `notFound`; repository error → `error`, `retry` re-reads; no tracks → `noTracks` and the engine is never loaded; `loadSong` throws → `audioError`, `retry` reloads; togglePlay play/pause and rapid double tap ends in the last state; seekTo clamps to 0..duration and keeps playing state; reaching duration pauses, sets `ended`, next play seeks to 0; setVolume clamps and calls the engine; toggleMute; toggleSolo exclusive and undo; mix starts at 100 % unmuted on a fresh provider; markLoopStart only while playing; markLoopEnd valid → loop on; end ≤ start → `loopError`, start kept; reaching loop end seeks to start; clearLoop keeps position (no seek); dispose stops the engine
- [ ] Gate check passes: `flutter test test/presentation/providers/solo_player_notifier_test.dart`
- [ ] Test count: ≥ 20 tests pass

**Tests**: unit
**Gate**: quick
**Commit**: `feat(solo-player): add SoloPlayerNotifier`

---

### T11: `SoloPlayerScreen`

**What**: The full screen per design.md (all status bodies, ready layout, loop flow, scoped position rebuilds) plus the UI_SPEC §6.12 update ("Funciona offline", metronome deferred, states).
**Where**: `lib/presentation/screens/solo_player/solo_player_screen.dart` (plus `docs/design/UI_SPEC.md` §6.12)
**Depends on**: T10
**Reuses**: `lyrics_editor_screen.dart` state bodies and `_View`/`select` pattern; widgets from T4–T9
**Requirement**: SOLO-02 to SOLO-25 (integration point)

**Tools**:
- MCP: NONE
- Skill: `flutter-ui-ux`, `flutter-widget-performance`

**Done when**:
- [ ] `test/presentation/screens/solo_player/solo_player_screen_test.dart`: loading / notFound (back to Biblioteca) / error + retry / noTracks + "Enviar faixa" / audioError + retry; ready shows title, author, "Funciona offline", lyric view, one mix row per track, `0:00.0` and total; "Tocar" ↔ "Pausar"; loop flow "Marcar início do loop" → "Marcar fim do loop" → "Desligar loop" with caption "Repetindo trecho 0:41–1:12"; loop error banner; loop buttons disabled while paused; song without timed lyrics shows the message; leaving stops audio; single primary action; dark theme; 360 dp at 130% with targets ≥ 44 dp; position ticks do not rebuild mix rows
- [ ] UI_SPEC §6.12 updated in the same commit
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test`
- [ ] Test count: ≥ 15 tests pass

**Tests**: widget
**Gate**: build
**Commit**: `feat(solo-player): add SoloPlayerScreen`

---

### T12: Wire the real route

**What**: `/solo-player/:id` builds `SoloPlayerScreen`; "Ensaiar só" passes the song id.
**Where**: `lib/presentation/routing/app_router.dart` (plus the one-line call in `lib/presentation/screens/song_detail/song_detail_screen.dart:302`)
**Depends on**: T11
**Reuses**: The `lyrics-editor` route shape (T8 of lyrics-editor)
**Requirement**: SOLO-01

**Tools**:
- MCP: NONE
- Skill: `flutter-routing`

**Done when**:
- [ ] Tests written first and failing: `app_router_test.dart` "solo-player renders SoloPlayerScreen with the route id" (replacing the ComingSoon entry); `song_detail_screen_test.dart` "Ensaiar só" expects `route:solo-player:s1`
- [ ] Gate check passes: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test`
- [ ] Test count: full suite, 0 regressions

**Tests**: widget
**Gate**: build
**Commit**: `feat(solo-player): wire SoloPlayerScreen into song detail and router`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 → T2 → T3
Phase 2:  T4 → T5 → T6 → T7 → T8 → T9
Phase 3:  T10 → T11 → T12
```

Execution is strictly sequential - there is no intra-phase parallelism.

Total: 12 tasks → packs into 3 batches (Phase 1: 3, Phase 2: 6, Phase 3: 3) → sub-agent offer applies.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1: `LyricCursor` | 1 function | ✅ Granular |
| T2: `setTrackVolume` | 1 method (interface + impl + fakes must compile together) | ✅ Granular |
| T3: reference track | 1 rule in `loadSong` | ✅ Granular |
| T4: `MuteSoloToggle` | 1 widget (extraction) | ✅ Granular |
| T5: `TonalButton` | 1 widget | ✅ Granular |
| T6: `StatusPill` | 1 widget | ✅ Granular |
| T7: `PlaybackProgress` | 1 widget | ✅ Granular |
| T8: `LyricView` | 1 widget | ✅ Granular |
| T9: `MixTrackRow` | 1 widget | ✅ Granular |
| T10: `SoloPlayerNotifier` | 1 notifier + provider | ✅ Granular |
| T11: `SoloPlayerScreen` | 1 screen + its UI_SPEC section | ✅ Granular |
| T12: route | 2 one-line wiring changes (cohesive) | ✅ Granular |

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
| T7 | T6 | T6→T7 | ✅ Match |
| T8 | T7 | T7→T8 | ✅ Match |
| T9 | T8 | T8→T9 | ✅ Match |
| T10 | T9 | T9→T10 (cross-phase chain) | ✅ Match |
| T11 | T10 | T10→T11 | ✅ Match |
| T12 | T11 | T11→T12 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Domain | unit | unit | ✅ OK |
| T2 | Infrastructure (engine) + domain interface | unit | unit | ✅ OK |
| T3 | Infrastructure (engine) | unit | unit | ✅ OK |
| T4 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T5 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T6 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T7 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T8 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T9 | Shared widget | unit (widget) | unit (widget) | ✅ OK |
| T10 | Notifier | unit | unit | ✅ OK |
| T11 | Screen | widget | widget | ✅ OK |
| T12 | Routing | widget | widget | ✅ OK |
