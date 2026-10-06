# Audio Domain — Verifier Report

**Result**: PASS

**Diff range**: `952e910` → `b4777b3`  
**Branch**: `feat/phase-1-audio-domain`  
**Tests run**: 71 passed, 0 failed  
**Gate**: `flutter analyze` clean, `check_layers.py` clean

---

## Per-AC Evidence

| AC | Test file:line | Assertion | Verdict |
|----|---------------|-----------|---------|
| AUDIO-01 | entities_test.dart:12 | `const Song(id: 's1', name: 'Test Song', author: 'Author')` returnsNormally | PASS |
| AUDIO-02 | entities_test.dart:29 | `const SongTrack(id: 't1', filePath: 'soprano.mp3', naipe: Naipe.soprano)` returnsNormally | PASS |
| AUDIO-03 | entities_test.dart:69 | `const LyricLine(text: 'First line', onsetMs: 1000)` returnsNormally | PASS |
| AUDIO-04 | entities_test.dart:93 | `const MetronomeConfig(bpm: 120, beatsPerMeasure: 4)` returnsNormally | PASS |
| AUDIO-05 | entities_test.dart:19,24 | `Song(id: '', ...)` and `Song(name: '', ...)` throw AssertionError | PASS |
| AUDIO-06 | entities_test.dart:39,47 | `SongTrack(id: '', ...)` and `SongTrack(filePath: '', ...)` throw AssertionError | PASS |
| AUDIO-07 | entities_test.dart:78 | `LyricLine(text: '', ...)` throws AssertionError | PASS |
| AUDIO-08 | entities_test.dart:55 | `SongTrack(..., startDelayMs: -1)` throws AssertionError | PASS |
| AUDIO-09 | entities_test.dart:83 | `LyricLine(text: 'Line', onsetMs: -1)` throws AssertionError | PASS |
| AUDIO-10 | song_test.dart:15 | song with all 4 naipes → `isComplete` equals `true` | PASS |
| AUDIO-11 | song_test.dart:30,40,50,60 | each missing naipe → `isComplete` equals `false` | PASS |
| AUDIO-12 | song_test.dart:70,80 | custom naipe only → false; 4× isPlayback tracks → false | PASS |
| AUDIO-13 | song_test.dart:110 | `const Song(id: 's1', name: 'Empty', author: 'A').isComplete` equals `false` | PASS |
| AUDIO-14 | timeline_converter_test.dart:7 | `toTrackLocal(1000, 300)` equals `700` | PASS |
| AUDIO-15 | timeline_converter_test.dart:29 | `toTimeline(700, 300)` equals `1000` | PASS |
| AUDIO-16 | timeline_converter_test.dart:11,15 | `toTrackLocal(200, 300)` equals `0`; boundary `toTrackLocal(300, 300)` equals `0` | PASS |
| AUDIO-17 | timeline_converter_test.dart:41 | roundtrip parametric over 4 cases, `back == t` each | PASS |
| AUDIO-18 | timeline_converter_test.dart:21,34 | negative `startDelayMs` throws AssertionError in both directions | PASS |
| AUDIO-19 | loop_controller_test.dart:7 | `LoopController(1000, 5000, 10000).isValid` equals `true` | PASS |
| AUDIO-20 | loop_controller_test.dart:11,16 | `startMs == endMs` and `startMs > endMs` → `isValid false` | PASS |
| AUDIO-21 | loop_controller_test.dart:21 | `startMs: -1` → `isValid false` | PASS |
| AUDIO-22 | loop_controller_test.dart:26 | `endMs: 11000, maxMs: 10000` → `isValid false` | PASS |
| AUDIO-23 | loop_controller_test.dart:44 | `shouldReposition(5001)` on loop(endMs:5000) equals `true` | PASS |
| AUDIO-24 | loop_controller_test.dart:49 | `shouldReposition(4999)` equals `false` | PASS |
| AUDIO-25 | loop_controller_test.dart:62 | `repositionTarget` equals `1000` (startMs) | PASS |
| AUDIO-26 | loop_controller_test.dart:54 | invalid loop `shouldReposition(5000)` equals `false` | PASS |
| AUDIO-27 | audio_mix_calculator_test.dart:7 | `ownGain(1.0)` equals `1.0` | PASS |
| AUDIO-28 | audio_mix_calculator_test.dart:29 | `choirGain(1.0)` equals `0.0` | PASS |
| AUDIO-29 | audio_mix_calculator_test.dart:11 | `ownGain(0.0)` equals `0.0` | PASS |
| AUDIO-30 | audio_mix_calculator_test.dart:33 | `choirGain(0.0)` equals `1.0` | PASS |
| AUDIO-31 | audio_mix_calculator_test.dart:15 | `ownGain(0.5)` equals `0.5` | PASS |
| AUDIO-32 | audio_mix_calculator_test.dart:43 | `ownGain(m) + choirGain(m) closeTo 1.0` for 7 values | PASS |
| AUDIO-33 | audio_mix_calculator_test.dart:18,37 | `ownGain(-0.1)` equals `0.0`; `ownGain(1.1)` equals `1.0`; `choirGain(-0.1)` equals `1.0` | PASS |
| AUDIO-34 | entities_test.dart:100,109 | `bpm: 29` and `bpm: 301` throw AssertionError | PASS |
| AUDIO-35 | entities_test.dart:124,131 | `beatsPerMeasure: 1` and `beatsPerMeasure: 17` throw AssertionError | PASS |
| AUDIO-36 | metronome_test.dart:7 | `generate(0, 2000, bpm=60, beats=4)` → length 2, positions [0, 1000] | PASS |
| AUDIO-37 | metronome_test.dart:20 | `pulses[0].isDownbeat` true, indices 1-3 false | PASS |
| AUDIO-38 | metronome_test.dart:33 | `generate(startMs: 500, ...)` first pulse at `1000` | PASS |
| AUDIO-39 | metronome_test.dart:44 | consecutive pulses spaced `60000 ~/ 120 == 500` ms, 8 intervals verified | PASS |

---

## Discrimination Sensor

4 mutations applied and tested. All killed.

| # | File | Mutation | Result |
|---|------|----------|--------|
| M1 | `loop_controller.dart:13` | `endMs > startMs` → `endMs >= startMs` | KILLED — `startMs equal to endMs returns false` failed |
| M2 | `song.dart:31` | `!t.isPlayback` → `t.isPlayback` | KILLED — `all four standard naipes present returns true` and `playback track does not count` failed |
| M3 | `audio_mix_calculator.dart:2` | `mix.clamp(0.0, 1.0)` → `mix` | KILLED — clamping tests for `-0.1` and `1.1` failed |
| M4 | `metronome_pulse_generator.dart:33` | `beatIndex % beats == 0` → `beatIndex % beats == 1` | KILLED — downbeat flag tests failed |

---

## Gaps

**Minor (unnumbered edge case, not a numbered AC):**  
The spec Edge Cases section states "duplicate naipe entries... `Song.isComplete` SHALL still return `true`" but no test exercises the positive case (e.g. 2× soprano + all 4 naipes → true). The implementation is correct (`.toSet()` handles duplicates), but there is no test asserting this path. Recommend adding a test case in a follow-up.

**spec.md not committed to git** — `.specs/features/audio-domain/spec.md` appears as untracked. Should be staged and committed.

---

## Conclusion

39/39 ACs covered with `file:line` evidence. 4/4 mutations killed. No surviving mutants. One minor coverage gap (unnumbered edge case). Feature is ready to merge.
