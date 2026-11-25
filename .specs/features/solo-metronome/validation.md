# Metrônomo solo (solo-metronome) Validation

**Date**: 2026-11-24
**Spec**: `.specs/features/solo-metronome/spec.md`
**Diff range**: `b898e9f..99dd198` (branch `feature/phase-5-solo-metronome`; spec/design/tasks at `be9dc61`, `ddc2e8f`, `b898e9f`)
**Verifier**: standalone fallback, run by the author. The sub-agent call is blocked by auto mode because the `context-mode` plugin rewrites Agent prompts; the same fallback was approved for lyrics-editor. Author ≠ verifier does **not** hold for this run.

**Verdict**: PASS ✅ (iteration 1)

---

## Task Completion

| Task | Status | Commit |
| ---- | ------ | ------ |
| T1 `playAt` starts every track | ✅ Done | `7581e53` (fix, red-first) |
| T2 continuous position | ✅ Done | `f867a55` (fix, red-first) |
| T3 drift-free pulses | ✅ Done | `0cff19d` (fix, red-first) |
| T4 `addTrack` / `removeTrack` | ✅ Done | `f1534d2` |
| T5 `ClickTrackWav` | ✅ Done | `86f6ed2` |
| T6 `ClickTrackBuilder` | ✅ Done | `a2b94a0` |
| T7 notifier | ✅ Done | `dbb74cb` |
| T8 `MixTrackRow.showSolo` | ✅ Done | `e8b2d0a` |
| T9 `TempoSheet` | ✅ Done | `670b543` |
| T10 screen | ✅ Done | `99dd198` |

---

## Spec-Anchored Acceptance Criteria

| Req | Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --------- | -------------------- | ----------------------- | ------ |
| MET-01 | P1-AC1/AC2 play starts every track, returns without a pause | both players get `play`; `playAt` completes | `test/infrastructure/audio/multi_track_audio_engine_test.dart:418`: `expect(fakePlatform.created[1].playCalls, hasLength(1))` with `holdPlayUntilPause`; `:435`: `expectLater(engine.playAt(...).timeout(1s), completes)` | ✅ PASS |
| MET-02 | P1-AC3 continuous position (≤ 200 ms) | position advances with no new event | `multi_track_audio_engine_test.dart:360`: `expect(events.where((ms) => ms >= 100), isNotEmpty)` after 400 ms of playback | ✅ PASS |
| MET-03 | P1-AC4 pulse n at `round(n·60000/bpm)` | pulse 216 = 180000 ms at 72 BPM; every pulse within 1 ms | `test/domain/audio/metronome_test.dart:65`: `expect(pulses[216].positionMs, 180000)`; `:80` mid-song grid | ✅ PASS |
| MET-04 | P2-AC1 "Metrônomo ♩ BPM" | label with the BPM | `test/presentation/screens/solo_player/solo_player_screen_test.dart:543`: `_tonal(tester, 'Metrônomo ♩ 72')` | ✅ PASS |
| MET-05 | P2-AC2/AC3 on/off; off keeps the voices | on → positive + click track; off → only `remove:metronome`, still playing | screen `:543`; `test/presentation/providers/solo_player_notifier_test.dart:634`: `expect(s.engine.calls, ['remove:metronome'])`, `expect(...playing, isTrue)` | ✅ PASS |
| MET-06 | P2-AC4 click on every beat, accent on beat 1 | beeps at pulse samples; downbeat higher; accent off → same pitch | `test/infrastructure/audio/click_track_wav_test.dart` (each beep at its pulse sample; downbeat more zero crossings); `test/infrastructure/audio/file_click_track_builder_test.dart` (accent off → equal crossings); `metronome_test.dart` downbeat every `beatsPerMeasure` | ✅ PASS |
| MET-07 | P2-AC5 click aligned through pause/seek/loop | click is a timeline track moved by `seekAllTo` | `multi_track_audio_engine_test.dart:207`: `expect(clickPlatform.seekCalls.last.position, 41000 ms)`; notifier `:600`: `expect(s.engine.calls.last, 'seek:41000')` | ✅ PASS |
| MET-08 | P2-AC6 ligar ao abrir | on after ready | notifier `:695`: `expect(_state(...).metronomeOn, isTrue)`; screen `:663` | ✅ PASS |
| MET-09 | P2-AC7 click build failure | off, "Não foi possível preparar o metrônomo.", music untouched | notifier `:650`: `expect(s.engine.calls, isEmpty)`, `expect(...playing, isTrue)`; `:668` unreadable file resumes play; screen `:650` | ✅ PASS |
| MET-10 | P3-AC1/AC2 "Andamento" sheet; defaults 72/4/accent; prefilled when saved | values shown | screen `:583`: `expect(...field('BPM')...text, '72')`; `:602`: `'88'`, `'3'`; `test/presentation/widgets/tempo_sheet_test.dart` (initial values) | ✅ PASS |
| MET-11 | P3-AC3 limits 30–300 / 2–16 | limit text + save disabled | `tempo_sheet_test.dart`: `find.text('Entre 30 e 300')`, `find.text('Entre 2 e 16')`, `expect(_save(tester).onPressed, isNull)` | ✅ PASS |
| MET-12 | P3-AC4 save: persist, keep `enabledByDefault`, turn on, toast | repo has the config; "Metrônomo ♩ 96" on; "Andamento salvo" | notifier `:712`: `expect(config.enabledByDefault, isTrue)`, `expect(...metronomeOn, isTrue)`; screen `:583`: `find.text('Andamento salvo')`, `expect(setup.repo.savedSong!.metronomeConfig!.bpm, 96)` | ✅ PASS |
| MET-13 | P3-AC5 save failure | sheet stays open, values kept, message; metronome unchanged | `tempo_sheet_test.dart` (error keeps sheet + typed `'120'`); notifier `:765`: `expect(...tempoSaveError, 'Não foi possível salvar o andamento.')`, `expect(s.builder.builds, isEmpty)` | ✅ PASS |
| MET-14 | P3-AC6/AC7 received song | no tempo → disabled + sentence; never "Ajustar andamento"; cannot save | screen `:625`: `expect(_tonal(tester, 'Metrônomo').onPressed, isNull)` + sentence; `:636`: `find.text('Ajustar andamento'), findsNothing`; notifier `:781`: `expect(s.repo.savedSong, isNull)` | ✅ PASS |
| MET-15 | P4-AC1/AC2 metronome row, volume only on the click | row with M, no S; volume reaches `metronome` | screen `:559`: S `findsNothing`, `expect(setup.engine.volumes['metronome'], 0.0)`; notifier `:793`: `expect(s.engine.volumes, {'metronome': 0.4})` | ✅ PASS |
| MET-16 | P4-AC3 M on the metronome | mutes only the click | notifier `:793`: `expect(s.engine.mutes, {'metronome': true})` | ✅ PASS |
| MET-17 | P4-AC4 session only | fresh screen 100 %, unmuted | notifier `:822` | ✅ PASS |
| MET-18 | Edge: on while playing / tempo change while on aligns to now | pause → add → seek → play; swap removes then adds | notifier `:619`: `['seek:5000', 'play']`; `:747`: `expect(s.engine.calls.first, 'remove:metronome')` | ✅ PASS |
| MET-19 | Edge: click prepared off the UI thread | WAV synthesized in another isolate | Structural: `lib/infrastructure/audio/file_click_track_builder.dart:35`: `await Isolate.run(...)`. `flutter test` cannot observe threads | ✅ PASS (structural) |

**Status**: ✅ All 19 requirements covered.
- MET-19 is evidenced structurally.
- The spec gained one assumption during T4: soloing a voice does not silence the click. This filled a design gap and is covered by `multi_track_audio_engine_test.dart:223` and notifier `:600` (`exemptFromSolo`).

---

## Discrimination Sensor

Scratch: a temporary `git worktree` at `99dd198`, with generated `.g.dart` copied in. The real tree's `git status --porcelain` matched the baseline afterwards.

| # | Target | Fault | Result |
| - | ------ | ----- | ------ |
| X1 | `lib/infrastructure/audio/multi_track_audio_engine.dart` `playAt` | `await player.play()` per track again | ✅ Killed |
| X2 | `multi_track_audio_engine.dart:72` | position from `playbackEventStream` | ✅ Killed |
| X3 | `lib/domain/audio/metronome_pulse_generator.dart` | integer interval (drift) | ✅ Killed |
| X4 | `metronome_pulse_generator.dart` | downbeat off by one | ✅ Killed |
| X5 | `multi_track_audio_engine.dart` `_effectiveVolume` | solo silences the click | ✅ Killed |
| X6 | `multi_track_audio_engine.dart` `removeTrack` | player not disposed | ✅ Killed |
| X7 | `lib/infrastructure/audio/click_track_wav.dart` | downbeat same pitch | ✅ Killed |
| X8 | `click_track_wav.dart` | beep 10 ms late | ✅ Killed |
| X9 | `click_track_wav.dart` | wrong data size | ✅ Killed |
| X10 | `lib/infrastructure/audio/file_click_track_builder.dart:63` | accent off ignored | ✅ Killed |
| X11 | `file_click_track_builder.dart` | builder throws instead of failure | ✅ Killed |
| X12 | `file_click_track_builder.dart` | wrong file name | ✅ Killed |
| X13 | `lib/presentation/providers/solo_player_notifier.dart` | click not aligned to now | ✅ Killed |
| X14 | `solo_player_notifier.dart` | click not solo-exempt | ✅ Killed |
| X15 | `solo_player_notifier.dart` | no pause before adding while playing | ✅ Killed |
| X16 | `solo_player_notifier.dart:385` | turning off pauses the voices | ✅ Killed |
| X17 | `solo_player_notifier.dart` | save drops `enabledByDefault` | ✅ Killed |
| X18 | `solo_player_notifier.dart` | received song tempo saved | ✅ Killed |
| X19 | `solo_player_notifier.dart` | "ligar ao abrir" ignored | ✅ Killed |
| X20 | `solo_player_notifier.dart` | volume not applied on add | ✅ Killed |
| X21 | `solo_player_notifier.dart` | metronome volume not clamped | ✅ Killed |
| X22 | `solo_player_notifier.dart` | failure without message | ✅ Killed |
| X23 | `lib/presentation/screens/solo_player/solo_player_screen.dart` | button never shows on | ✅ Killed |
| X24 | `solo_player_screen.dart` | received song can open the sheet | ✅ Killed |
| X25 | `solo_player_screen.dart` | metronome row shows S | ✅ Killed |
| X26 | `solo_player_screen.dart` | "Ajustar andamento" shown for received | ✅ Killed |
| X27 | `lib/presentation/widgets/tempo_sheet.dart` | BPM max not enforced | ✅ Killed |
| X28 | `tempo_sheet.dart` | beats min not enforced | ✅ Killed |
| X29 | `tempo_sheet.dart:95` | sheet closes on save error | ✅ Killed |
| X30 | `lib/presentation/widgets/mix_track_row.dart:74` | `showSolo` ignored | ✅ Killed |

**Sensor depth**: P0-full manual. The fixes touch every playback path, so all three are included.
**Result**: **30/30 killed: PASS ✅**.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ Click track reuses the engine (no timer scheduler); `StatusPill` and other widgets untouched |
| Surgical changes | ✅ Engine (3 designed changes), generator fix, 7 fakes (interface), `MixTrackRow` prop, solo notifier/screen |
| No scope creep | ✅ Room metronome, pickup offset, `enabledByDefault` editing deferred |
| Matches patterns | ✅ `Result` for the builder (AD-002), provider overrides, `_View` + `select` on the screen |
| Spec-anchored outcome check | ✅ |
| Per-layer Coverage Expectation met | ✅ |
| Every test maps to a requirement | ✅ |
| Documented guidelines followed: `AGENTS.md` §5/§7, `CLAUDE.md` | ✅, except l10n, which is known project debt |

---

## Edge Cases

- [x] On while playing aligns before sounding: notifier `:619`
- [x] Tempo change while on swaps the click: notifier `:747`
- [x] Click prepared off the UI thread: `file_click_track_builder.dart:35`
- [x] Leaving stops the click: SOLO-07 `engine.stop()` stops every player, including added ones (`multi_track_audio_engine.dart` `stop`)

---

## Gate Check

- **Gate command**: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test` (+ `scripts/check_layers.py`)
- **Result**: analyze clean; format 0 changed; layers OK; **701 passed**, 0 failed (two consecutive full runs at `99dd198`)
- **Test count before feature**: 644 (solo-player merge)
- **Test count after feature**: 701 (+57)
- **Flaky (pre-existing, unrelated)**: `test/data/transfer/song_sync_coordinator_test.dart` failed in 2 of 4 full runs, each time on a different test, under load. It passes alone (4/4). It uses real sockets with 100 ms – 5 s timeouts and is already listed in STATE.md as debt.

---

## Requirement Traceability Update

| Requirement | New Status |
| ----------- | ---------- |
| MET-01 to MET-19 | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready.

**Spec-anchored check**: 19/19 requirements matched to the spec outcome.
**Sensor**: 30/30 mutations killed.
**Gate**: 701 passed.

**What works**:
- Three audio fixes, proven against the documented `just_audio` contract:
  - every track starts;
  - the clock moves continuously;
  - pulses do not drift.
- A metronome on the shared timeline as a click track: on/off, accent, solo-exempt, aligned through pause/seek/loop.
- The tempo is defined in the "Andamento" sheet and saved to the song. A received song is read-only.
- Click volume and M in the mix.
- "Ligar ao abrir" is honored.

**Not verified on a device**: T1/T2 rely on the documented `just_audio` contract. Confirming them on hardware belongs to the background-playback feature.

**Next steps**: merging `feature/phase-5-solo-metronome` into `develop` needs the user's go-ahead.
