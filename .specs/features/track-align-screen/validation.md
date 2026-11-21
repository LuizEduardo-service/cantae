# Tela Alinhamento de faixas Validation

## Validation: track-align-screen - FAIL ❌

**Date**: 2026-11-21
**Spec**: `.specs/features/track-align-screen/spec.md`
**Diff range**: `ca584bb..381a859` (branch point from `develop` → `feature/phase-5-track-align-screen` HEAD)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status  | Notes |
| ---- | ------- | ----- |
| T1   | ✅ Done | `FakeJustAudioPlatform` self-tested, 3 tests |
| T2   | ✅ Done | Engine extension, 11 tests, all assertions precise |
| T3   | ✅ Done | `audioPlaybackEngineProvider`, 2 tests |
| T4   | ✅ Done | `TrackAlignNotifier`, 15 tests |
| T5   | ✅ Done | `TrackAlignRow`, 10 tests |
| T6   | ✅ Done | `Toast`, 3 tests |
| T7   | ✅ Done | `TrackAlignScreen`, 12 tests — but see gaps below (notFound state, ConfirmSheet cancel branch not exercised) |
| T8   | ✅ Done | Routing + nav wiring, 1 new + 1 updated test |

---

## Spec-Anchored Acceptance Criteria

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| ALIGN-01: tap "Alinhar entradas" → navigate `track-align` with `id` | route reached carries the song's `id` as path param | `test/presentation/screens/song_detail/song_detail_screen_test.dart:264-280` — `expect(find.text('route:track-align:s1'), findsOneWidget)`; `test/presentation/routing/app_router_test.dart:127-137` — `expect(tester.widget<TrackAlignScreen>(...).songId, 'abc')` | ✅ PASS |
| ALIGN-02: carregando → loading state, no row/footer | no `TrackAlignRow`/`PrimaryButton` while loading | `test/presentation/screens/track_align/track_align_screen_test.dart:167-177` — `expect(find.byType(CircularProgressIndicator), findsOneWidget); expect(find.byType(PrimaryButton), findsNothing)` | ✅ PASS |
| ALIGN-03: sem faixas → `EmptyState` with studio/track-upload, no row/footer | `EmptyState` text + both actions present, navigates to `studio` | `track_align_screen_test.dart:179-192` — `expect(find.text('Sem faixas'), findsOneWidget)`; tap → `find.text('route:studio')` | ✅ PASS |
| ALIGN-04: one `TrackAlignRow` per naipe with track, never for a naipe without one | Soprano/Contralto shown, Tenor (no track) absent | `track_align_screen_test.dart:211-227` — `expect(find.text('Soprano'), findsOneWidget); expect(find.text('Tenor'), findsNothing)`; row content: `test/presentation/widgets/track_align_row_test.dart:14-35` | ✅ PASS |
| ALIGN-05: tracks load successfully → enable offset/loop fields + "Ouvir em loop" | fields/footer render only once `status == loaded` | `track_align_screen_test.dart:167-177` (absent while loading) + `:211-227` (present once loaded) | ✅ PASS (by state-gating; no separate "enabled" attribute asserted — acceptable, spec only requires the controls to become usable) |
| ALIGN-06: engine load fails → `InlineBanner` erro + "Tentar de novo", no lock | banner + retry button, retry recovers | `track_align_screen_test.dart:194-209` — `expect(find.text('Tentar de novo'), findsOneWidget)` → after retry `findsNothing` | ✅ PASS |
| ALIGN-07: valid offset edit updates `startDelayMs` in memory + shifts waveform | draft map updated to exact ms value; engine notified | `test/presentation/providers/track_align_notifier_test.dart:219-231` — `expect(state.startDelayMsByTrackId['soprano'], 1500); expect(setup.engine.startDelayCalls['soprano'], 1500)` | ⚠️ Spec-precision gap — the `startDelayMs` update itself is PASS; the waveform's *visual shift* (`_Waveform.shiftPx` in `lib/presentation/widgets/track_align_row.dart:296`) has no test asserting the rendered shift changes with `offsetMs` (only that the formatted-time text updates, `track_align_screen_test.dart:229-241`) |
| ALIGN-08: invalid/negative offset rejected, last valid kept, never negative | malformed text / negative value → no callback / no mutation | `track_align_row_test.dart:61-83` — `expect(called, isFalse)`; `track_align_notifier_test.dart:233-244` — `expect(state.startDelayMsByTrackId['soprano'], 0)` | ✅ PASS |
| ALIGN-09: any unsaved offset edit → marks screen as having unsaved changes | `hasUnsavedChanges == true` after one edit | `track_align_notifier_test.dart:229` — `expect(state.hasUnsavedChanges, isTrue)` | ✅ PASS |
| ALIGN-10: Mudo stops that track's audio, leaves others, dims waveform 25% | volume→0 for muted track only; `Opacity.opacity == 0.25` | `test/infrastructure/audio/multi_track_audio_engine_test.dart:55-65`; `track_align_row_test.dart:131-148` | ✅ PASS |
| ALIGN-11: Solo plays only that track (regardless of its mute), accent border | other tracks volume→0; soloed track's own mute state doesn't block it; `Border` color == `accent` | `multi_track_audio_engine_test.dart:79-89`, `:104-116`; `track_align_row_test.dart:150-171` | ✅ PASS |
| ALIGN-12: Solo is exclusive — activating on a 2nd track clears the 1st | 1st track's volume restored, 2nd silences the rest; store holds only one `soloTrackId` | `multi_track_audio_engine_test.dart:91-102`; `track_align_notifier_test.dart:263-275` — `expect(state.soloTrackId, 'contralto')` | ✅ PASS |
| ALIGN-13: mark start/end, "Ouvir em loop" plays from start, loops at end until "Parar" | `seekAllTo(start)` + `playAt`; reposition to `start` on reaching `end`; continues until stop | `track_align_notifier_test.dart:303-322` (seek+play), `:324-338` (`seekAllToCalls.last == 500` on reaching end); screen-level button swap `track_align_screen_test.dart:258-275` | ✅ PASS |
| ALIGN-14: end ≤ start OR end > known duration → reject, keep last valid | both branches rejected, `loopEndMs` unchanged | `track_align_notifier_test.dart:279-289` (end≤start) and `:291-301` (end>duration) | ✅ PASS |
| ALIGN-15: while testing, button shows "Parar" | label swap | `track_align_screen_test.dart:258-275` | ✅ PASS |
| ALIGN-16: "Parar" stops playback, button reverts, keeps edited offsets | `stop()` called, `testing=false`, label reverts | `track_align_notifier_test.dart:318-322` (`engine.stopped==true`, `testing==false`); `track_align_screen_test.dart:271-275` (label reverts) | ⚠️ Spec-precision gap — "mantendo os atrasos editados" (offsets preserved after stop) is never independently re-asserted post-`toggleTest()`; relies on the reader confirming `_stopTest()` never touches `startDelayMsByTrackId` |
| ALIGN-17: "Salvar atrasos" → `SongRepository.save` with updated tracks; success → `Toast` + clear unsaved | exact track `startDelayMs` persisted; toast text shown; `hasUnsavedChanges` cleared | `track_align_notifier_test.dart:341-358` — `expect(savedTrack.startDelayMs, 1500); expect(state.hasUnsavedChanges, isFalse)`; `track_align_screen_test.dart:277-290` — `expect(find.text('Atrasos salvos'), findsOneWidget)` | ✅ PASS |
| ALIGN-18: save failure → stay, no nav, unsaved flag intact, show error | `hasUnsavedChanges` stays true, `saveError` set; inline error shown | `track_align_notifier_test.dart:360-374`; `track_align_screen_test.dart:292-307` — `expect(find.text('Não foi possível salvar'), findsOneWidget)` | ✅ PASS |
| ALIGN-19: back w/ unsaved → `ConfirmSheet`; confirm → nav to `song-detail` w/o saving; cancel → stay | both branches of the sheet must be exercised | `track_align_screen_test.dart:309-330` covers the **confirm** branch only (`expect(find.text('route:song-detail:song-1'), findsOneWidget)`) | ❌ GAP — the **cancel** branch ("Continuar editando" → stay on screen, no navigation, unsaved flag intact) has **no `file:line` citation** anywhere in the test suite for this screen |
| ALIGN-20: back w/o unsaved → navigate direct, no confirmation | no `ConfirmSheet`, direct nav | `track_align_screen_test.dart:332-345` — `expect(find.text('Descartar alterações?'), findsNothing); expect(find.text('route:song-detail:song-1'), findsOneWidget)` | ✅ PASS |
| ALIGN-21: save succeeds, then back → navigate direct, no confirmation | the *specific sequence* edit→save→back must show no confirmation | No test performs this sequence; ALIGN-20's test never edits/saves first — it asserts the same code path from the "never touched" state, not the "saved-then-cleared" state | ⚠️ Spec-precision gap — behavior is implied by shared `hasUnsavedChanges` flag logic (tested separately in ALIGN-09/17) but the literal AC sequence has no direct citation |

**Status**: ❌ Gaps present (ALIGN-19's cancel branch uncovered; three spec-precision gaps on ALIGN-07/16/21)

---

## Edge Cases

- [x] `id` não encontrado → `EmptyState` "não encontrada" + voltar à Biblioteca — notifier state transition tested (`track_align_notifier_test.dart:185-193`, `status == notFound`), **but the screen's rendering of this state is never exercised** — no widget test pumps a not-found song and asserts `find.text('Música não encontrada')` or the "Voltar à Biblioteca" action against `lib/presentation/screens/track_align/track_align_screen.dart:147-160` (`_NotFoundBody`). **GAP.**
- [x] Sair da tela com teste ativo → para a reprodução — `track_align_notifier_test.dart:397-418` (`autoDispose` group): closing the listener while `testing == true` asserts `engine.stopped == true`.
- [ ] Música com exatamente 1 faixa cadastrada → testar/editar/salvar funcionam normalmente — **not tested**; every test fixture uses 2 tracks (`soprano` + `contralto`). Low risk (no code path special-cases track count), but no direct evidence.

---

## Discrimination Sensor

Isolated in a temporary `git worktree` at `../cantae-scratch-verify` (never the real tree); generated `*.g.dart` drift files (gitignored, needed to compile) were copied in from the real tree for compilation only, then the whole worktree was discarded.

| # | File:line | Description | Killed? |
| - | --- | --- | --- |
| 1 | `lib/infrastructure/audio/multi_track_audio_engine.dart:134` | Inverted solo-exclusivity volume logic (`trackId == _soloTrackId ? baseGain : 0.0` → `? 0.0 : baseGain`) | ✅ Killed — 2 tests in `multi_track_audio_engine_test.dart` failed |
| 2 | `lib/presentation/providers/track_align_notifier.dart:170` | Weakened negative-offset guard (`< 0` → `< -999999`) | ✅ Killed — `track_align_notifier_test.dart` "a negative value is rejected" failed |
| 3 | `lib/presentation/widgets/track_align_row.dart:215` | Inverted mute/opacity logic (`muted ? 0.25 : 1.0` → `muted ? 1.0 : 0.25`) | ✅ Killed — `track_align_row_test.dart` "muted renders the waveform at 25% opacity" failed |
| 4 | `lib/presentation/screens/track_align/track_align_screen.dart:37` | Inverted `ConfirmSheet` gating (`if (state.hasUnsavedChanges)` → `if (!state.hasUnsavedChanges)`) | ✅ Killed — 2 tests in `track_align_screen_test.dart` failed (both the "with changes" and "without changes" back-navigation tests) |
| 5 | `lib/presentation/providers/track_align_notifier.dart:233` | Broke loop-reposition target (`controller.repositionTarget` → `controller.endMs`) | ✅ Killed — `track_align_notifier_test.dart` "reaching the loop end repositions to the loop start" failed (`Expected: <500> Actual: <2000>`) |

**Sensor depth**: lightweight (default tier)
**Result**: 5/5 killed — sensor is discriminating ✅

**Isolation check**: `git status --porcelain` on the real tree was empty before sensor work and empty after `git worktree remove --force`. Baseline matched; no `git stash` used.

---

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ |
| Surgical changes | ✅ |
| No scope creep | ✅ |
| Matches patterns | ✅ (same state-notifier/screen-states precedent as `SongDetailScreen`/`LibraryScreen`) |
| Spec-anchored outcome check (asserted values match spec) | ⚠️ 17/21 PASS, 1 GAP (ALIGN-19 cancel branch), 3 spec-precision gaps (ALIGN-07, 16, 21) |
| Per-layer Coverage Expectation met (domain/infra 1:1 on new engine members; screen covers happy+edge+error) | ⚠️ Infra/provider layers fully met; screen layer missing the `notFound` render state and the `ConfirmSheet` cancel branch |
| Every test maps to a spec requirement — no unclaimed tests | ✅ |
| Documented guidelines followed | `AGENTS.md` §7, `docs/design/COMPONENTS.md` (Toast/TrackAlignRow component tests) |

---

## Gate Check

- **Gate command**: `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`
- **Result**: `flutter analyze` — 0 issues. `flutter test` — 472/472 passed. `check_layers.py` — OK. `dart analyze lib/domain/` — no issues.
- **Test count before feature**: 414 (per tasks.md T8)
- **Test count after feature**: 472
- **Delta**: +58
- **Skipped tests**: none
- **Failures**: none (one historically-flaky unrelated test, `test/data/transfer/song_sync_coordinator_test.dart`, passed cleanly on this run)

---

## Fix Plans

### Fix 1: ALIGN-19 cancel branch has no test coverage

- **Root cause**: `track_align_screen_test.dart`'s "voltar com alterações não salvas" test only exercises the `ConfirmSheet`'s destructive ("Descartar alterações") action; it never taps the safe action ("Continuar editando") to verify the screen stays put with `hasUnsavedChanges` intact.
- **Fix task**: Add a widget test in `test/presentation/screens/track_align/track_align_screen_test.dart` that: edits an offset, taps "‹ <nome>", taps "Continuar editando" in the `ConfirmSheet`, and asserts (a) the `TrackAlignScreen` is still shown (no `route:song-detail:...` text), and (b) the offset edit is still reflected (e.g. the field still shows the edited value).
- **Priority**: Major (explicit spec AC, half the branch untested)

### Fix 2: `track-align`'s "não encontrada" state has zero screen-level test coverage

- **Root cause**: Only the notifier's `status == notFound` transition is tested (`track_align_notifier_test.dart:185-193`); no widget test ever renders `TrackAlignScreen` with a not-found song id to exercise `_NotFoundBody` (`track_align_screen.dart:147-160`).
- **Fix task**: Add a widget test using a `_FakeSongRepository` with `initialSong: null` (mirrors `songNotFound: true` pattern from the notifier test), asserting `find.text('Música não encontrada')` and that tapping "Voltar à Biblioteca" navigates to `route:library`.
- **Priority**: Major (documented Edge Case requirement, fully unverified at the screen layer)

### Fix 3 (minor, optional): spec-precision gaps on ALIGN-07/16/21

- **Root cause**: Three ACs are functionally covered by the existing design (shared state flags, same code paths) but have no test asserting the *exact literal scenario* the spec describes (waveform pixel shift on offset change; offsets surviving a stop; the edit→save→back sequence specifically).
- **Fix task** (optional, lower priority): add three small assertions — (1) compare `_Waveform`'s computed padding/shift via `tester.widget` before/after an offset change, (2) assert `state.startDelayMsByTrackId` unchanged immediately after `toggleTest()` stops, (3) chain edit→save→back in one screen test and assert no `ConfirmSheet` appears.
- **Priority**: Minor

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| ALIGN-01 through ALIGN-06 | Implementing | ✅ Verified |
| ALIGN-07 | Implementing | ⚠️ Verified with spec-precision gap (waveform visual shift untested) |
| ALIGN-08, ALIGN-09 | Implementing | ✅ Verified |
| ALIGN-10 through ALIGN-15 | Implementing | ✅ Verified |
| ALIGN-16 | Implementing | ⚠️ Verified with spec-precision gap (post-stop offset preservation untested) |
| ALIGN-17, ALIGN-18 | Implementing | ✅ Verified |
| ALIGN-19 | Implementing | ❌ Needs Fix (cancel branch uncovered) |
| ALIGN-20 | Implementing | ✅ Verified |
| ALIGN-21 | Implementing | ⚠️ Verified with spec-precision gap (literal sequence untested) |

---

## Summary

**Overall**: ❌ Not Ready (FAIL)

**Spec-anchored check**: 17/21 ACs cleanly matched spec outcome; 1 real gap (ALIGN-19 cancel branch, zero evidence); 3 spec-precision gaps (ALIGN-07, ALIGN-16, ALIGN-21) where the behavior is implied by shared, separately-tested logic but the literal AC scenario has no direct citation.

**Sensor**: 5/5 mutations killed — the test suite reliably detects behavior-level regressions in solo exclusivity, offset validation, mute/opacity, ConfirmSheet gating, and loop-reposition targeting.

**Gate**: 472/472 passed, `flutter analyze`/`check_layers.py`/`dart analyze lib/domain/` all clean.

**What works**: All 5 new `AudioPlaybackEngine` members are precisely tested against spec-defined values (not just "an assertion exists"). The notifier's state machine, offset/mute/solo/loop validation, save success/failure, and the screen's loading/no-tracks/error/loaded states are all solidly evidenced. The discrimination sensor found no weak tests in the areas it probed.

**Issues found**:
1. ALIGN-19's `ConfirmSheet` cancel path is unverified at the screen level (Fix 1).
2. The "não encontrada" edge-case screen rendering is unverified (Fix 2).
3. Three minor spec-precision gaps (Fix 3, optional).

**Next steps**: Route Fix 1 and Fix 2 back to an implementer as test-only fix tasks (no production code changes expected — both appear correctly implemented, just unverified); Fix 3 is optional polish. Re-run this Verifier after those two tests land to promote spec.md's traceability from "Verified" to fully closed, then re-run `validate_state.py`.
