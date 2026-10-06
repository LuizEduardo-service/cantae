# Audio Domain Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Spec**: `.specs/features/audio-domain/spec.md`
**Status**: Approved

---

## Test Coverage Matrix

> Guidelines found: `CLAUDE.md` (testing rules section). No existing domain tests except Phase 0 fixtures and result_test. Strong defaults applied per CLAUDE.md: failure-first unit tests, written before implementation.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
|------------|-------------------|----------------------|------------------|-------------|
| Domain entities (with invariants) | unit (failure-first) | Every assert path + valid construction; 1:1 to AUDIO-01..09 edge cases | `test/domain/entities/*_test.dart` | `flutter test test/domain/entities/` |
| Song.isComplete | unit (failure-first) | All 4 ACs: full, each missing naipe, custom ignored, empty | `test/domain/entities/song_test.dart` | `flutter test test/domain/entities/song_test.dart` |
| TimelineConverter | unit (failure-first) | All 5 ACs including roundtrip invariant and boundary | `test/domain/audio/timeline_converter_test.dart` | `flutter test test/domain/audio/` |
| LoopController | unit (failure-first) | All 8 ACs: valid, each invalid bound, shouldReposition, repositionTarget | `test/domain/audio/loop_controller_test.dart` | `flutter test test/domain/audio/` |
| AudioMixCalculator | unit (failure-first) | All 7 ACs: 0.0, 0.5, 1.0, sum invariant, clamping | `test/domain/audio/audio_mix_calculator_test.dart` | `flutter test test/domain/audio/` |
| MetronomeConfig + PulseGenerator | unit (failure-first) | All 6 ACs: BPM/beat validation, pulse count, positions, downbeat, startMs offset | `test/domain/audio/metronome_test.dart` | `flutter test test/domain/audio/` |

## Gate Check Commands

| Gate Level | When to Use | Command |
|------------|-------------|---------|
| Quick | After tasks with unit tests only | `flutter test test/domain/` |
| Build | After last task or config-only tasks | `flutter analyze && flutter test test/domain/ && python scripts/check_layers.py --root .` |

---

## Execution Plan

### Phase 1: Audio Domain

```
T1 → T2 → T3 → T4 → T5 → T6
```

---

## Task Breakdown

### T1: Expand domain entity models

**What**: Replace stub entity classes with full field definitions and debug-mode asserts for all invariants.
**Where**: `lib/domain/entities/song.dart`
**Depends on**: None
**Reuses**: `lib/domain/entities/naipe.dart`, `lib/domain/core/failures.dart` (Failure base exists)
**Requirement**: AUDIO-01, AUDIO-02, AUDIO-03, AUDIO-04, AUDIO-05, AUDIO-06, AUDIO-07, AUDIO-08, AUDIO-09

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before code)**:
1. `Song` with empty `id` → `AssertionError`
2. `Song` with empty `name` → `AssertionError`
3. `SongTrack` with empty `id` → `AssertionError`
4. `SongTrack` with empty `filePath` → `AssertionError`
5. `SongTrack` with negative `startDelayMs` → `AssertionError`
6. `LyricLine` with empty `text` → `AssertionError`
7. `LyricLine` with negative `onsetMs` → `AssertionError`
8. `MetronomeConfig` with `bpm < 30` → `AssertionError`
9. `MetronomeConfig` with `bpm > 300` → `AssertionError`
10. `MetronomeConfig` with `beatsPerMeasure < 2` → `AssertionError`
11. `MetronomeConfig` with `beatsPerMeasure > 16` → `AssertionError`
12. All entities constructed with valid data → no error

**Done when**:
- [x] Tests in `test/domain/entities/entities_test.dart` written covering all 12 failure modes (BEFORE implementation)
- [x] `lib/domain/entities/song.dart` — `Song` has all fields: `id`, `name`, `author`, `version`, `tracks`, `lyrics`, `metronomeConfig`, `playbackTrack`
- [x] `lib/domain/entities/song_track.dart` — `SongTrack` has all fields: `id`, `filePath`, `naipe`, `startDelayMs`, `isPlayback`
- [x] `lib/domain/entities/lyric_line.dart` — `LyricLine` has all fields: `text`, `onsetMs`, `naipe`, `dynamics`
- [x] `lib/domain/entities/metronome_config.dart` — `MetronomeConfig` with `bpm`, `beatsPerMeasure`, `downbeatAccent`, `enabledByDefault`
- [x] All asserts present and verified by tests
- [x] Gate check passes: `flutter test test/domain/entities/`
- [x] Test count: ≥ 12 assertions pass

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): expand entity models with full fields and invariant asserts`

---

### T2: Song.isComplete

**What**: Add `isComplete` getter to `Song` that returns true iff all four standard naipes have at least one non-playback track.
**Where**: `lib/domain/entities/song.dart`
**Depends on**: T1
**Reuses**: `Naipe` enum, `SongTrack.isPlayback`
**Requirement**: AUDIO-10, AUDIO-11, AUDIO-12, AUDIO-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before code)**:
1. Song with soprano, contralto, tenor, bass tracks → `isComplete == true`
2. Song missing soprano → `isComplete == false`
3. Song missing contralto → `isComplete == false`
4. Song missing tenor → `isComplete == false`
5. Song missing bass → `isComplete == false`
6. Song with custom naipe only → `isComplete == false`
7. Song with playback track only → `isComplete == false`
8. Song with 2× soprano but no tenor → `isComplete == false`
9. Empty track list → `isComplete == false`

**Done when**:
- [x] Tests in `test/domain/entities/song_test.dart` written covering all 9 failure modes (BEFORE implementation)
- [x] `Song.isComplete` getter implemented
- [x] `Naipe.custom` and `isPlayback: true` tracks are excluded from the check
- [x] Gate check passes: `flutter test test/domain/entities/`
- [x] Test count: ≥ 9 assertions pass

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add Song.isComplete check for standard naipe coverage`

---

### T3: TimelineConverter

**What**: Implement `TimelineConverter` as a pure static class with `toTrackLocal` and `toTimeline` methods.
**Where**: `lib/domain/audio/timeline_converter.dart`
**Depends on**: T2
**Reuses**: None
**Requirement**: AUDIO-14, AUDIO-15, AUDIO-16, AUDIO-17, AUDIO-18

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before code)**:
1. `toTrackLocal(timelineMs: 1000, startDelayMs: 300)` → `700`
2. `toTimeline(trackLocalMs: 700, startDelayMs: 300)` → `1000`
3. `toTrackLocal(timelineMs: 200, startDelayMs: 300)` → `0` (track not started)
4. `toTrackLocal(timelineMs: 300, startDelayMs: 300)` → `0` (exact start)
5. Roundtrip: `toTimeline(toTrackLocal(t, d), d) == t` for `t >= d >= 0`
6. `toTrackLocal` with negative `startDelayMs` → `AssertionError`
7. `toTimeline` with negative `startDelayMs` → `AssertionError`

**Done when**:
- [x] Tests in `test/domain/audio/timeline_converter_test.dart` written covering all 7 failure modes (BEFORE implementation)
- [x] `lib/domain/audio/timeline_converter.dart` implemented with static methods
- [x] Gate check passes: `flutter test test/domain/audio/`
- [x] Test count: ≥ 7 assertions pass (including roundtrip parametric)

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add TimelineConverter for startDelayMs position mapping`

---

### T4: LoopController

**What**: Implement `LoopController` value class with `isValid`, `shouldReposition`, and `repositionTarget`.
**Where**: `lib/domain/audio/loop_controller.dart`
**Depends on**: T3
**Reuses**: None
**Requirement**: AUDIO-19, AUDIO-20, AUDIO-21, AUDIO-22, AUDIO-23, AUDIO-24, AUDIO-25, AUDIO-26

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before code)**:
1. `startMs: 1000, endMs: 5000, maxMs: 10000` → `isValid == true`
2. `startMs == endMs` → `isValid == false`
3. `startMs > endMs` → `isValid == false`
4. `startMs < 0` → `isValid == false`
5. `endMs > maxMs` → `isValid == false`
6. `endMs == maxMs` → `isValid == true` (full-song loop)
7. Valid loop, `currentMs == endMs` → `shouldReposition == true`
8. Valid loop, `currentMs > endMs` → `shouldReposition == true`
9. Valid loop, `currentMs < endMs` → `shouldReposition == false`
10. Invalid loop, any `currentMs` → `shouldReposition == false`
11. Valid loop → `repositionTarget == startMs`

**Done when**:
- [ ] Tests in `test/domain/audio/loop_controller_test.dart` written covering all 11 failure modes (BEFORE implementation)
- [ ] `lib/domain/audio/loop_controller.dart` implemented
- [ ] Gate check passes: `flutter test test/domain/audio/`
- [ ] Test count: ≥ 11 assertions pass

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add LoopController with validation and reposition logic`

---

### T5: AudioMixCalculator

**What**: Implement `AudioMixCalculator` as a pure static class with `ownGain` and `choirGain`.
**Where**: `lib/domain/audio/audio_mix_calculator.dart`
**Depends on**: T4
**Reuses**: None
**Requirement**: AUDIO-27, AUDIO-28, AUDIO-29, AUDIO-30, AUDIO-31, AUDIO-32, AUDIO-33

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before code)**:
1. `ownGain(1.0)` → `1.0`
2. `choirGain(1.0)` → `0.0`
3. `ownGain(0.0)` → `0.0`
4. `choirGain(0.0)` → `1.0`
5. `ownGain(0.5)` → `0.5`
6. `ownGain(m) + choirGain(m) == 1.0` for all m in [0.0, 1.0]
7. `ownGain(-0.1)` → `0.0` (clamped, no throw)
8. `ownGain(1.1)` → `1.0` (clamped, no throw)
9. `choirGain(-0.1)` → `1.0` (clamped)

**Done when**:
- [ ] Tests in `test/domain/audio/audio_mix_calculator_test.dart` written covering all 9 failure modes (BEFORE implementation)
- [ ] `lib/domain/audio/audio_mix_calculator.dart` implemented
- [ ] Gate check passes: `flutter test test/domain/audio/`
- [ ] Test count: ≥ 9 assertions pass

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add AudioMixCalculator with linear crossfade gain formula`

---

### T6: MetronomeConfig validation and MetronomePulseGenerator

**What**: Add assert validation to `MetronomeConfig` and implement `MetronomePulseGenerator` with `generate()`.
**Where**: `lib/domain/audio/metronome_pulse_generator.dart`
**Depends on**: T5
**Reuses**: `lib/domain/entities/metronome_config.dart` (from T1)
**Requirement**: AUDIO-34, AUDIO-35, AUDIO-36, AUDIO-37, AUDIO-38, AUDIO-39

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before code)**:
1. `MetronomeConfig(bpm: 29, ...)` → `AssertionError` (already in T1; reconfirm via pulse generator tests)
2. `MetronomeConfig(beatsPerMeasure: 1, ...)` → `AssertionError`
3. `generate(startMs: 0, durationMs: 2000, config: bpm=60, beatsPerMeasure=4)` → 2 pulses at [0, 1000]
4. Beat index 0 → `isDownbeat: true`; indices 1, 2, 3 → `isDownbeat: false`
5. `generate(startMs: 500, durationMs: 2000, bpm: 60)` → first pulse at ms 1000 (next beat boundary ≥ 500)
6. Consecutive pulses spaced exactly `(60000 / bpm)` ms apart
7. `generate(startMs: 0, durationMs: 0, ...)` → empty list

**Done when**:
- [ ] Tests in `test/domain/audio/metronome_test.dart` written covering all 7 failure modes (BEFORE implementation)
- [ ] `lib/domain/audio/metronome_pulse_generator.dart` implemented with `MetronomePulse` value class and `MetronomePulseGenerator.generate()`
- [ ] Gate check passes: `flutter analyze && flutter test test/domain/ && python scripts/check_layers.py --root .`
- [ ] Test count: ≥ 7 assertions pass

**Tests**: unit
**Gate**: build

**Commit**: `feat(domain): add MetronomePulseGenerator with downbeat marking`

---

## Phase Execution Map

```
Phase 1: T1 → T2 → T3 → T4 → T5 → T6
```

---

## Task Granularity Check

| Task | Scope | Status |
|------|-------|--------|
| T1: Expand entity models | 4 entity files + 1 test file | ✅ Granular (cohesive entity unit) |
| T2: Song.isComplete | 1 getter in song.dart + test | ✅ Granular |
| T3: TimelineConverter | 1 file | ✅ Granular |
| T4: LoopController | 1 file | ✅ Granular |
| T5: AudioMixCalculator | 1 file | ✅ Granular |
| T6: MetronomePulseGenerator | 1 file + MetronomePulse value class | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|------|------------------------|---------------|--------|
| T1 | None | Start of chain | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer | Matrix Requires | Task Says | Status |
|------|-----------|-----------------|-----------|--------|
| T1: Entity models | Domain entities | unit (failure-first) | unit | ✅ OK |
| T2: Song.isComplete | Domain entity logic | unit (failure-first) | unit | ✅ OK |
| T3: TimelineConverter | Domain audio logic | unit (failure-first) | unit | ✅ OK |
| T4: LoopController | Domain audio logic | unit (failure-first) | unit | ✅ OK |
| T5: AudioMixCalculator | Domain audio logic | unit (failure-first) | unit | ✅ OK |
| T6: MetronomePulseGenerator | Domain audio logic | unit (failure-first) | unit | ✅ OK |
