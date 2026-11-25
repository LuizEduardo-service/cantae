# Modo solo (solo-player) Validation

**Date**: 2026-11-24
**Spec**: `.specs/features/solo-player/spec.md`
**Diff range**: `05357c9..b7d49ba` (branch `feature/phase-5-solo-player`; spec/design/tasks docs at `cc56ba1`, `5460436`, `05357c9`)
**Verifier**: standalone fallback, run by the author. The sub-agent call is blocked by auto mode because the `context-mode` plugin rewrites Agent prompts; the same fallback was approved for lyrics-editor. Author ≠ verifier does **not** hold for this run.

**Verdict**: PASS ✅ (iteration 2 of 3)

Iteration 1 left 1 of 25 mutants alive (S9). It was fixed with test-only commit `b7d49ba`, and all 25 mutants are now killed.

---

## Task Completion

| Task | Status | Commit |
| ---- | ------ | ------ |
| T1 `LyricCursor` | ✅ Done | `17d94f4` |
| T2 per-track volume | ✅ Done | `ec24abd` |
| T3 position follows the longest track | ✅ Done | `752b82d` (fix with a red-first regression test) |
| T4 `MuteSoloToggle` | ✅ Done | `a38f4eb` (also adds the toggled semantics missing from `TrackAlignRow`) |
| T5 `TonalButton` | ✅ Done | `670c5fd` |
| T6 `StatusPill` | ✅ Done | `c89fd89` |
| T7 `PlaybackProgress` | ✅ Done | `0ccc72a` |
| T8 `LyricView` | ✅ Done | `d25c242` |
| T9 `MixTrackRow` | ✅ Done | `2b12030` |
| T10 `SoloPlayerNotifier` | ✅ Done | `9f1f7db` |
| T11 `SoloPlayerScreen` | ✅ Done | `320c1c6` |
| T12 route | ✅ Done | `0603c58` |
| F1 loop end while paused | ✅ Done | `b7d49ba` (kills S9) |

---

## Spec-Anchored Acceptance Criteria

| Req | Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --------- | -------------------- | ----------------------- | ------ |
| SOLO-01 | P1-AC1 "Ensaiar só" opens Modo solo | route with the song id | `test/presentation/screens/song_detail/song_detail_screen_test.dart:358`: `find.text('route:solo-player:s1')`; `test/presentation/routing/app_router_test.dart:168` | ✅ PASS |
| SOLO-02 | P1-AC2 load every track, paused at `0:00.0`, total duration | ready, position 0, duration from the engine; naipes then Playback | `test/presentation/providers/solo_player_notifier_test.dart:196-200`: `expect(state.positionMs, 0)`, `expect(state.durationMs, 180000)`; `:208` mix order; screen `test/presentation/screens/solo_player/solo_player_screen_test.dart:296-297`: `find.text('0:00.0')`, `find.text('3:05.0')` | ✅ PASS |
| SOLO-03 | P1-AC3/AC4 Tocar/Pausar | play from the current position → "Pausar"; pause → "Tocar"; no seek | `solo_player_notifier_test.dart:272-278`: `expect(s.engine.calls.where((c) => c.startsWith('seek')), isEmpty)`; screen `:305-313` | ✅ PASS |
| SOLO-04 | P1-AC5 time follows playback, `m:ss.s` | clock shows the position | screen `:309`: `find.text('0:05.3')`; `test/infrastructure/audio/multi_track_audio_engine_test.dart:293-295` (clock follows the longest track) | ✅ PASS |
| SOLO-05 | P1-AC6 seek | all tracks to the instant, keeps playing; clamp 0..duration | `solo_player_notifier_test.dart:313-315`: `expect(s.engine.calls.last, 'seek:60000')`, `expect(...playing, isTrue)`; `:324-327` clamp; `test/presentation/widgets/playback_progress_test.dart:59`: `expect(seeks, [60000])` once, on release | ✅ PASS |
| SOLO-06 | P1-AC7 end of song | stop, "Tocar", next play restarts from 0 | `solo_player_notifier_test.dart:336-345`: `expect(...ended, isTrue)`, then `['seek:0', 'play']` | ✅ PASS |
| SOLO-07 | P1-AC8 leaving stops audio | `stop` | `solo_player_notifier_test.dart:355`: `expect(s.engine.calls.last, 'stop')`; screen `:373-374` | ✅ PASS |
| SOLO-08 | P1-AC9 works with no network | no state depends on the network | Structural: `grep -rln "network\|nsd\|multicast\|Socket\|http"` over every solo-player file returns nothing; the screen shows `StatusPill` "Funciona offline" (screen `:291`) | ✅ PASS (structural: an absence has no behavioral assertion) |
| SOLO-09 | P2-AC1/AC6 one row per track; state not by color only | selo + name / "Playback"; M/S toggled in semantics | `test/presentation/widgets/mix_track_row_test.dart:48-57`; `:100-101`: `expect(mute.flagsCollection.isToggled.toBoolOrNull(), isTrue)`; screen `:294` (4 rows) | ✅ PASS |
| SOLO-10 | P2-AC2 volume per track | only that track, 0..1 | `solo_player_notifier_test.dart:377-383`: `expect(s.engine.volumes, {'tenor': 0.3})`, clamp → `1.0`; engine `multi_track_audio_engine_test.dart:126`: `closeTo(0.3, 1e-9)` | ✅ PASS |
| SOLO-11 | P2-AC3 mute and unmute | silence, then the chosen volume | `solo_player_notifier_test.dart:392-397`; engine `multi_track_audio_engine_test.dart:141-152` (muted stays 0, unmute → 0.4) | ✅ PASS |
| SOLO-12 | P2-AC4/AC5 exclusive solo, undo | only the soloed track plays at its volume; S again undoes | `solo_player_notifier_test.dart:407-414`: `expect(s.engine.soloCalls, ['soprano:true', 'tenor:true', 'tenor:false'])`; engine `:154-172` | ✅ PASS |
| SOLO-13 | P2-AC7 mix only for the session | fresh screen: 100 %, no mute or solo | `solo_player_notifier_test.dart:366-368`, `:427`: `expect(_state(second.container).mix['tenor']!.volume, 1.0)`; engine `:182` (reload resets to 1.0) | ✅ PASS |
| SOLO-14 | P3-AC1/AC2/AC7 mark start; disabled while paused | start = current instant; no marking while paused | `solo_player_notifier_test.dart:440`: `expect(...loopStartMs, 41000)`; `:452` paused → null; `:469-470` end while paused ignored; screen `:395`, `:409`: `onPressed, isNull` | ✅ PASS |
| SOLO-15 | P3-AC3/AC4 mark end; refuse end ≤ start | loop on; else inline error, start kept | `solo_player_notifier_test.dart:485-488`; `:500-502`: `expect(...loopError, 'O fim do trecho precisa vir depois do início.')`; screen `:443` | ✅ PASS |
| SOLO-16 | P3-AC5 repeat the section | at the end → seek to start, keep playing | `solo_player_notifier_test.dart:519-521`: `expect(s.engine.calls.last, 'seek:41000')`; screen `:427` | ✅ PASS |
| SOLO-17 | P3-AC6 turn off, no jump | loop off, position kept, no engine call | `solo_player_notifier_test.dart:540-542`: `expect(s.engine.calls.length, callsBefore)`; screen `:430-431` | ✅ PASS |
| SOLO-18 | P3-AC8 section on the progress bar | `accentTrack` region between start/end | `playback_progress_test.dart:81-83`: `closeTo(0.41, 1e-9)`, `loopColor == accentTrack`; caption screen `:423`: `find.text('Repetindo trecho 0:41–1:12')` | ✅ PASS |
| SOLO-19 | P4-AC1/AC2 previous/current/next | greatest onset ≤ position; before first → first is next | `test/domain/audio/lyric_cursor_test.dart:38`: `(previous: null, current: null, next: 0)`; `:81` ties → later line; `test/presentation/widgets/lyric_view_test.dart:42-62` | ✅ PASS |
| SOLO-20 | P4-AC3 selo + "Naipe · dinâmica"; dinâmica alone without naipe | exact text | `lyric_view_test.dart:69-70`: `find.text('Tenor · piano')`; `:79-87` | ✅ PASS |
| SOLO-21 | P4-AC4 no timed lyrics | message instead of the view | screen `:333-334`: `find.text('Esta música ainda não tem letra sincronizada')` | ✅ PASS |
| SOLO-22 | P4-AC5 live region | current line is a live region | `lyric_view_test.dart:97`: `expect(node.flagsCollection.isLiveRegion, isTrue)` | ✅ PASS |
| SOLO-23 | Edge: not found / read error | "Música não encontrada"; error + retry re-reads | screen `:237-240`, `:246-254`; notifier `:219`, `:228-235`: `expect(s.repo.getByIdCount, 2)` | ✅ PASS |
| SOLO-24 | Edge: no tracks | EmptyState + "Enviar faixa", no player, engine not loaded | screen `:261-265`; notifier `:244-245`: `expect(s.engine.loadCount, 0)` | ✅ PASS |
| SOLO-25 | Edge: audio load failure | "Não foi possível tocar as faixas desta música." + retry reloads | screen `:271-280`; notifier `:254-261` | ✅ PASS |

**Status**: ✅ All 25 requirements covered.
- SOLO-08 is evidenced structurally, because it asserts an absence.
- The edge case "rapid Tocar/Pausar taps" is covered at `solo_player_notifier_test.dart:301-302`.
- The edge case "drag past the loop end" follows the same reposition rule as SOLO-16 (`_onPosition`).

---

## Discrimination Sensor

Scratch: a temporary `git worktree` (iteration 1 at `0603c58`, iteration 2 at `b7d49ba`), with generated `.g.dart` copied in. The real tree's `git status --porcelain` matched the pre-sensor baseline after both runs.

| # | Target | Fault | Iteration 1 | Iteration 2 |
| - | ------ | ----- | ----------- | ----------- |
| S1 | `lib/domain/audio/lyric_cursor.dart:20` | tie picks the earlier line | ✅ Killed | ✅ Killed |
| S2 | `lib/domain/audio/lyric_cursor.dart:30` | no "Próxima" before the first line | ✅ Killed | ✅ Killed |
| S3 | `lib/infrastructure/audio/multi_track_audio_engine.dart:158` | per-track volume ignored | ✅ Killed | ✅ Killed |
| S4 | `lib/infrastructure/audio/multi_track_audio_engine.dart:73` | position follows `tracks.first` | ✅ Killed | ✅ Killed |
| S5 | `lib/presentation/providers/solo_player_notifier.dart:245` | play after the end does not restart from 0 | ✅ Killed | ✅ Killed |
| S6 | `lib/presentation/providers/solo_player_notifier.dart:210` | end detection `>=` → `>` | ✅ Killed | ✅ Killed |
| S7 | `lib/presentation/providers/solo_player_notifier.dart:204` | loop never repositions | ✅ Killed | ✅ Killed |
| S8 | `lib/presentation/providers/solo_player_notifier.dart` `clearLoop` | turning off jumps to the loop start | ✅ Killed | ✅ Killed |
| S9 | `lib/presentation/providers/solo_player_notifier.dart:293` | loop end markable while paused | ❌ Survived → F1 | ✅ Killed |
| S10 | `lib/presentation/providers/solo_player_notifier.dart:82` | loop start markable while paused | ✅ Killed | ✅ Killed |
| S11 | `lib/presentation/providers/solo_player_notifier.dart:278` | S again never undoes | ✅ Killed | ✅ Killed |
| S12 | `lib/presentation/providers/solo_player_notifier.dart:259` | volume not clamped | ✅ Killed | ✅ Killed |
| S13 | `lib/presentation/providers/solo_player_notifier.dart:252` | seek stops playback | ✅ Killed | ✅ Killed |
| S14 | `lib/presentation/providers/solo_player_notifier.dart:325` | leaving does not stop audio | ✅ Killed | ✅ Killed |
| S15 | `lib/presentation/providers/solo_player_notifier.dart:167` | no-tracks state never shown | ✅ Killed | ✅ Killed |
| S16 | `lib/presentation/providers/solo_player_notifier.dart:183` | load failure shown as read error | ✅ Killed | ✅ Killed |
| S17 | `lib/presentation/screens/solo_player/solo_player_screen.dart:399` | loop start button enabled while paused | ✅ Killed | ✅ Killed |
| S18 | `lib/presentation/screens/solo_player/solo_player_screen.dart:70` | whole screen rebuilds on every position tick | ✅ Killed | ✅ Killed |
| S19 | `lib/presentation/widgets/playback_progress.dart:86` | seek on every drag update | ✅ Killed | ✅ Killed |
| S20 | `lib/presentation/widgets/lyric_view.dart:89` | current line not a live region | ✅ Killed | ✅ Killed |
| S21 | `lib/presentation/widgets/mix_track_row.dart:87` | volume announced wrong | ✅ Killed | ✅ Killed |
| S22 | `lib/presentation/widgets/mute_solo_toggle.dart:33` | M/S state only by color | ✅ Killed | ✅ Killed |
| S23 | `lib/presentation/routing/app_router.dart:57` | router ignores `:id` | ✅ Killed | ✅ Killed |
| S24 | `lib/presentation/screens/song_detail/song_detail_screen.dart:303` | "Ensaiar só" passes the wrong id | ✅ Killed | ✅ Killed |
| S25 | `lib/presentation/widgets/mix_track_row.dart` | volume slider does nothing | ✅ Killed | ✅ Killed |

F1 was also proven against a screen-level mutant: "Marcar fim do loop" always enabled was killed by `solo_player_screen_test.dart:409`.

**Sensor depth**: P0-full manual (25 mutants across domain, engine, notifier, screen, widgets, routing).
**Result**: iteration 1: 24/25 killed (S9 survived). Iteration 2: **25/25 killed: PASS ✅**.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ `StatusPill` built with the neutral variant only; no shared "playback session" controller (design approach C rejected) |
| Surgical changes | ✅ Touched beyond new files: the engine (two designed changes), `TrackAlignRow` (toggle extraction, its tests unchanged), five test fakes (interface member), route + "Ensaiar só" |
| No scope creep | ✅ Metronome, background playback and history stay deferred |
| Matches patterns | ✅ Mirrors `LyricsEditorNotifier` / `LyricsEditorScreen` (`_View` + `select`, `autoDispose` stop) |
| Spec-anchored outcome check | ✅ |
| Per-layer Coverage Expectation met | ✅ |
| Every test maps to a requirement | ✅ |
| Documented guidelines followed: `AGENTS.md` §5/§7, `CLAUDE.md` | ✅, except l10n, which is known project debt: strings are inline, as in every existing screen |

**Known duplication (recorded, not fixed):** the naipe → name / selo mapping exists as private copies in `TrackAlignRow`, `LyricLineRow` and `SongRow`. The new widgets use the shared `naipe_labels.dart`. Consolidating the old copies is outside this feature.

---

## Edge Cases

- [x] Not found: screen `:237`
- [x] Read error + retry: screen `:246-254`
- [x] No tracks: screen `:261-265`
- [x] Audio load failure + retry: screen `:271-280`
- [x] Drag past the loop end: same `shouldReposition` rule as SOLO-16 (`solo_player_notifier_test.dart:519`)
- [x] Rapid Tocar/Pausar: `solo_player_notifier_test.dart:301-302`

---

## Gate Check

- **Gate command**: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test` (+ `scripts/check_layers.py`)
- **Result**: analyze clean; format 0 changed; layers OK; **644 passed**, 0 failed, 0 skipped (at `b7d49ba`)
- **Test count before feature**: 548 (lyrics-editor merge)
- **Test count after feature**: 644 (+96)
- **Deleted tests**: one, replaced: the `solo-player` entry of the ComingSoon loop in `app_router_test.dart` became the real-screen test (T12).

---

## Fix Plans (iteration 1, done)

### Fix 1 (F1): loop end marking while paused was untested

- **Root cause**: the only paused-state test covered `markLoopStart`. Dropping the `playing` guard from `markLoopEnd` (or enabling its button) passed every test.
- **Fix task**: notifier test plus screen test, each proven red against its mutant (`b7d49ba`).
- **Priority**: Minor.

---

## Requirement Traceability Update

| Requirement | New Status |
| ----------- | ---------- |
| SOLO-01 to SOLO-25 | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready.

**Spec-anchored check**: 25/25 requirements matched to the spec outcome.
**Sensor**: 25/25 mutations killed (iteration 2).
**Gate**: 644 passed.

**What works**:
- Modo solo from "Ensaiar só": play, pause, seek and end of song.
- A per-track mix (volume, M, S), including the Playback track.
- A loop marked with start and end, with the section shown on the bar.
- Compact synced lyrics.
- All error and empty states.
- No network dependency; audio stops on leaving.

**Issues found**: one weak spot (S9), fixed in F1.

**Next steps**: merging `feature/phase-5-solo-player` into `develop` needs the user's go-ahead.
