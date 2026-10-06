# Audio Domain Specification

## Problem Statement

The stub entities from Phase 0 carry only the fields needed to compile fixtures. Phase 1 fills in the full domain model and adds the three pure-logic components that every later phase depends on: the shared-timeline converter, the loop controller, and the audio mix calculator. Without these, Phase 2 (persistence) cannot map a correct schema and Phase 4 (player) has no domain rules to delegate to.

## Goals

- [ ] All domain entities carry their full field set with validation invariants
- [ ] `Song.isComplete` correctly identifies songs missing standard-naipe tracks
- [ ] `TimelineConverter` correctly maps between timeline and track-local positions using `startDelayMs`
- [ ] `LoopController` validates loop bounds and repositions playhead at loop end
- [ ] `AudioMixCalculator` returns correct gain values for own-voice and choir tracks given a mix ratio
- [ ] `MetronomeConfig` validates BPM and time signature; `MetronomePulseGenerator` emits correct pulse timestamps with downbeat marking
- [ ] All domain logic covered by failure-first unit tests; zero Flutter imports in `lib/domain/`

## Out of Scope

| Feature | Reason |
|---------|--------|
| Audio file loading / actual duration | Phase 4 (requires just_audio) |
| SQLite persistence for entities | Phase 2 |
| Playback engine wiring | Phase 4 |
| Session sync / networked loop | Phase 3 |
| UI for mix slider or loop controls | Phase 5 |
| Custom naipe creation flow | Phase 5 (domain enum already has `custom`) |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|-----------------------|----------------|-----------|------------|
| Mix formula for AudioMixCalculator | Linear crossfade: `ownGain = mix`, `choirGain = 1.0 - mix` (both clamped 0.0..1.0) | Simple balance control; musical boost-both behavior deferred until UX is validated | y |
| Playback track treated as a naipe? | No — `SongTrack` has a `isPlayback` flag; playback track is excluded from `isComplete` check | PRD distinguishes playback track from voice naipes | y |
| Song.durationMs without audio files | Not computed in Phase 1 — `Song` has no `durationMs` field; `LoopController` receives `maxMs` as a parameter | Audio duration comes from the player (Phase 4), not the entity | y |
| MetronomeConfig BPM range | 30..300 inclusive | Standard musical range; outside it is a programming error | y |
| MetronomeConfig beatsPerMeasure range | 2..16 inclusive | Covers all practical time signatures | y |
| LyricLine dynamics field | Optional `String?` | PRD says "optional dynamics"; no enum defined yet — free text for now | y |
| SongTrack.filePath validation | Non-empty String (domain rule); file existence checked in infrastructure | Domain only validates structural correctness, not filesystem state | y |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Domain Entity Models ⭐ MVP

**User Story**: As a domain developer, I want fully-specified entity classes so that Phase 2 can derive a correct SQLite schema and Phase 4 can wire the player without guessing field shapes.

**Why P1**: Every downstream phase reads from these models; a wrong field shape forces a breaking migration or player rewrite.

**Acceptance Criteria**:

1. The system SHALL provide `Song` with fields: `id` (String, non-empty), `name` (String, non-empty), `author` (String), `version` (String), `tracks` (List\<SongTrack\>), `lyrics` (List\<LyricLine\>), `metronomeConfig` (MetronomeConfig?), `playbackTrack` (SongTrack?). <!-- AUDIO-01 -->
2. The system SHALL provide `SongTrack` with fields: `id` (String, non-empty), `filePath` (String, non-empty), `naipe` (Naipe), `startDelayMs` (int ≥ 0), `isPlayback` (bool, default false). <!-- AUDIO-02 -->
3. The system SHALL provide `LyricLine` with fields: `text` (String, non-empty), `onsetMs` (int ≥ 0), `naipe` (Naipe?), `dynamics` (String?). <!-- AUDIO-03 -->
4. The system SHALL provide `MetronomeConfig` with fields: `bpm` (int, 30..300), `beatsPerMeasure` (int, 2..16), `downbeatAccent` (bool), `enabledByDefault` (bool). <!-- AUDIO-04 -->
5. IF `Song.id` or `Song.name` is constructed as an empty string THEN the system SHALL throw an `AssertionError` in debug mode. <!-- AUDIO-05 -->
6. IF `SongTrack.id` or `SongTrack.filePath` is constructed as an empty string THEN the system SHALL throw an `AssertionError` in debug mode. <!-- AUDIO-06 -->
7. IF `LyricLine.text` is constructed as an empty string THEN the system SHALL throw an `AssertionError` in debug mode. <!-- AUDIO-07 -->
8. IF `SongTrack.startDelayMs` is constructed as a negative integer THEN the system SHALL throw an `AssertionError` in debug mode. <!-- AUDIO-08 -->
9. IF `LyricLine.onsetMs` is constructed as a negative integer THEN the system SHALL throw an `AssertionError` in debug mode. <!-- AUDIO-09 -->

**Independent Test**: Instantiate each entity with valid data → no error. Instantiate with each invalid field → `AssertionError`.

---

### P1: Song Completeness ⭐ MVP

**User Story**: As the domain, I want `Song.isComplete` to tell me whether all four standard naipes have at least one track, so that UI and session logic can block incomplete songs from being used in rehearsal.

**Why P1**: Sessions must only start with complete songs; this check is the single source of truth for that gate.

**Acceptance Criteria**:

10. WHEN `Song.isComplete` is called on a song with at least one track for each of `soprano`, `contralto`, `tenor`, and `bass` THEN it SHALL return `true`. <!-- AUDIO-10 -->
11. WHEN `Song.isComplete` is called on a song missing any one of the four standard naipes THEN it SHALL return `false`. <!-- AUDIO-11 -->
12. The system SHALL treat `Naipe.custom` and `isPlayback: true` tracks as irrelevant to `Song.isComplete`. <!-- AUDIO-12 -->
13. WHEN `Song.isComplete` is called on a song with zero tracks THEN it SHALL return `false`. <!-- AUDIO-13 -->

**Independent Test**: Build songs covering each missing-naipe case; assert `isComplete` matches expectation.

---

### P1: Shared Timeline — TimelineConverter ⭐ MVP

**User Story**: As the audio engine (Phase 4), I want a pure function that converts between timeline positions and track-local positions using `startDelayMs`, so that track scrubbing and lyric sync use a single, tested formula.

**Why P1**: Every component that touches position (loop, metronome, lyrics) depends on this conversion; a bug here silently desynchronises all of them.

**Acceptance Criteria**:

14. WHEN `TimelineConverter.toTrackLocal(timelineMs: 1000, startDelayMs: 300)` is called THEN it SHALL return `700`. <!-- AUDIO-14 -->
15. WHEN `TimelineConverter.toTimeline(trackLocalMs: 700, startDelayMs: 300)` is called THEN it SHALL return `1000`. <!-- AUDIO-15 -->
16. WHEN `TimelineConverter.toTrackLocal` is called with `timelineMs < startDelayMs` THEN it SHALL return `0` (track has not started yet). <!-- AUDIO-16 -->
17. The system SHALL guarantee `TimelineConverter.toTimeline(TimelineConverter.toTrackLocal(t, d), d) == t` for all `t >= d >= 0`. <!-- AUDIO-17, roundtrip invariant -->
18. IF `startDelayMs` is negative THEN `TimelineConverter` SHALL throw an `AssertionError`. <!-- AUDIO-18 -->

**Independent Test**: Call each converter function with the exact values from ACs 14–16; assert precise integer results.

---

### P1: LoopController ⭐ MVP

**User Story**: As the master device, I want `LoopController` to validate a loop region and tell me when to reposition the playhead, so that loop logic is tested in isolation before being wired into the player.

**Why P1**: Loop is a core rehearsal feature; an untested loop formula causes the choir to lose position mid-rehearsal.

**Acceptance Criteria**:

19. WHEN `LoopController` is constructed with `startMs: 1000, endMs: 5000, maxMs: 10000` THEN `isValid` SHALL return `true`. <!-- AUDIO-19 -->
20. IF `LoopController.startMs >= endMs` THEN `isValid` SHALL return `false`. <!-- AUDIO-20 -->
21. IF `LoopController.startMs < 0` THEN `isValid` SHALL return `false`. <!-- AUDIO-21 -->
22. IF `LoopController.endMs > maxMs` THEN `isValid` SHALL return `false`. <!-- AUDIO-22 -->
23. WHEN `LoopController.shouldReposition(currentMs: 5001)` is called on a valid loop (endMs: 5000) THEN it SHALL return `true`. <!-- AUDIO-23 -->
24. WHEN `LoopController.shouldReposition(currentMs: 4999)` is called on a valid loop (endMs: 5000) THEN it SHALL return `false`. <!-- AUDIO-24 -->
25. WHEN `LoopController.repositionTarget` is accessed on a valid loop THEN it SHALL return `startMs`. <!-- AUDIO-25 -->
26. IF `LoopController.isValid` is `false` THEN `LoopController.shouldReposition` SHALL always return `false`. <!-- AUDIO-26 -->

**Independent Test**: Construct loops for each boundary condition; assert `isValid`, `shouldReposition`, and `repositionTarget` independently.

---

### P1: AudioMixCalculator ⭐ MVP

**User Story**: As the singer's device, I want `AudioMixCalculator` to return the gain for my own-voice track and the choir tracks given a mix ratio, so that the player applies correct volume levels without embedding the formula in UI code.

**Why P1**: The mix formula is a domain invariant; if embedded in the UI or player it drifts per-screen.

**Acceptance Criteria**:

27. WHEN `AudioMixCalculator.ownGain(mix: 1.0)` is called THEN it SHALL return `1.0`. <!-- AUDIO-27 -->
28. WHEN `AudioMixCalculator.choirGain(mix: 1.0)` is called THEN it SHALL return `0.0`. <!-- AUDIO-28 -->
29. WHEN `AudioMixCalculator.ownGain(mix: 0.0)` is called THEN it SHALL return `0.0`. <!-- AUDIO-29 -->
30. WHEN `AudioMixCalculator.choirGain(mix: 0.0)` is called THEN it SHALL return `1.0`. <!-- AUDIO-30 -->
31. WHEN `AudioMixCalculator.ownGain(mix: 0.5)` is called THEN it SHALL return `0.5`. <!-- AUDIO-31 -->
32. The system SHALL guarantee `AudioMixCalculator.ownGain(m) + AudioMixCalculator.choirGain(m) == 1.0` for all `m` in `[0.0, 1.0]`. <!-- AUDIO-32 -->
33. IF `mix` is outside `[0.0, 1.0]` THEN `AudioMixCalculator` SHALL clamp it to the nearest bound without throwing. <!-- AUDIO-33 -->

**Independent Test**: Call each function at `0.0`, `0.5`, `1.0`, and out-of-range; assert exact float values.

---

### P1: MetronomeConfig & PulseGenerator ⭐ MVP

**User Story**: As the rehearsal engine, I want `MetronomeConfig` to validate musical parameters and `MetronomePulseGenerator` to emit pulse timestamps with downbeat marking, so that the click track is correct before the audio engine is built.

**Why P1**: Metronome timing is a hard real-time invariant; a wrong pulse list causes singers to rehearse at the wrong tempo.

**Acceptance Criteria**:

34. IF `MetronomeConfig.bpm` is constructed outside `[30, 300]` THEN the system SHALL throw an `AssertionError`. <!-- AUDIO-34 -->
35. IF `MetronomeConfig.beatsPerMeasure` is constructed outside `[2, 16]` THEN the system SHALL throw an `AssertionError`. <!-- AUDIO-35 -->
36. WHEN `MetronomePulseGenerator.generate(startMs: 0, durationMs: 2000, config: MetronomeConfig(bpm: 60, beatsPerMeasure: 4))` is called THEN it SHALL return exactly 2 pulses at positions `[0, 1000]` (one pulse per second at 60 BPM within 2000 ms, exclusive of end). <!-- AUDIO-36 -->
37. WHEN `MetronomePulseGenerator.generate` is called with `beatsPerMeasure: 4` THEN pulse at beat index 0 SHALL have `isDownbeat: true` and pulses at indices 1, 2, 3 SHALL have `isDownbeat: false`. <!-- AUDIO-37 -->
38. WHEN `MetronomePulseGenerator.generate` is called with `startMs: 500` THEN the first pulse position SHALL be the first beat boundary at or after 500 ms. <!-- AUDIO-38 -->
39. The system SHALL guarantee that consecutive pulse timestamps are spaced exactly `(60000 / bpm)` ms apart (integer ms, truncated). <!-- AUDIO-39 -->

**Independent Test**: Generate pulses for 60 BPM / 4 beats; assert count, positions, and downbeat flags.

---

## Edge Cases

- IF `Song.tracks` contains duplicate naipe entries for the same standard naipe THEN `Song.isComplete` SHALL still return `true` (duplicates count, they don't invalidate).
- IF `LoopController` is constructed with `startMs == 0` and `endMs == maxMs` THEN `isValid` SHALL return `true` (full-song loop is valid).
- IF `MetronomePulseGenerator.generate` is called with `durationMs: 0` THEN it SHALL return an empty list.
- IF `TimelineConverter.toTrackLocal` is called with `timelineMs == startDelayMs` THEN it SHALL return `0` (track starts exactly at this moment).
- WHEN `AudioMixCalculator` receives `mix: -0.1` THEN `ownGain` SHALL return `0.0` (clamped, not negative).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|----------------|-------|-------|--------|
| AUDIO-01 | P1: Entity Models | Tasks | Pending |
| AUDIO-02 | P1: Entity Models | Tasks | Pending |
| AUDIO-03 | P1: Entity Models | Tasks | Pending |
| AUDIO-04 | P1: Entity Models | Tasks | Pending |
| AUDIO-05 | P1: Entity Models | Tasks | Pending |
| AUDIO-06 | P1: Entity Models | Tasks | Pending |
| AUDIO-07 | P1: Entity Models | Tasks | Pending |
| AUDIO-08 | P1: Entity Models | Tasks | Pending |
| AUDIO-09 | P1: Entity Models | Tasks | Pending |
| AUDIO-10 | P1: Song Completeness | Tasks | Pending |
| AUDIO-11 | P1: Song Completeness | Tasks | Pending |
| AUDIO-12 | P1: Song Completeness | Tasks | Pending |
| AUDIO-13 | P1: Song Completeness | Tasks | Pending |
| AUDIO-14 | P1: TimelineConverter | Tasks | Pending |
| AUDIO-15 | P1: TimelineConverter | Tasks | Pending |
| AUDIO-16 | P1: TimelineConverter | Tasks | Pending |
| AUDIO-17 | P1: TimelineConverter | Tasks | Pending |
| AUDIO-18 | P1: TimelineConverter | Tasks | Pending |
| AUDIO-19 | P1: LoopController | Tasks | Pending |
| AUDIO-20 | P1: LoopController | Tasks | Pending |
| AUDIO-21 | P1: LoopController | Tasks | Pending |
| AUDIO-22 | P1: LoopController | Tasks | Pending |
| AUDIO-23 | P1: LoopController | Tasks | Pending |
| AUDIO-24 | P1: LoopController | Tasks | Pending |
| AUDIO-25 | P1: LoopController | Tasks | Pending |
| AUDIO-26 | P1: LoopController | Tasks | Pending |
| AUDIO-27 | P1: AudioMixCalculator | Tasks | Pending |
| AUDIO-28 | P1: AudioMixCalculator | Tasks | Pending |
| AUDIO-29 | P1: AudioMixCalculator | Tasks | Pending |
| AUDIO-30 | P1: AudioMixCalculator | Tasks | Pending |
| AUDIO-31 | P1: AudioMixCalculator | Tasks | Pending |
| AUDIO-32 | P1: AudioMixCalculator | Tasks | Pending |
| AUDIO-33 | P1: AudioMixCalculator | Tasks | Pending |
| AUDIO-34 | P1: MetronomeConfig | Tasks | Pending |
| AUDIO-35 | P1: MetronomeConfig | Tasks | Pending |
| AUDIO-36 | P1: MetronomeConfig | Tasks | Pending |
| AUDIO-37 | P1: MetronomeConfig | Tasks | Pending |
| AUDIO-38 | P1: MetronomeConfig | Tasks | Pending |
| AUDIO-39 | P1: MetronomeConfig | Tasks | Pending |

**Coverage:** 39 total, 0 mapped to tasks ⚠️ (tasks.md pending)

---

## Success Criteria

- [ ] `flutter test test/domain/` passes with zero failures
- [ ] `python scripts/check_layers.py --root .` exits 0
- [ ] `flutter analyze` exits 0
- [ ] All 39 ACs covered by at least one test with `file:line` evidence
