# Editor de letra (lyrics-editor) Validation

**Date**: 2026-11-24
**Spec**: `.specs/features/lyrics-editor/spec.md`
**Diff range**: `f2eabaf..39519bd` (branch `feature/phase-5-lyrics-editor`; `ed47ee2` is format-only). Iteration 1 covered `..ed6af35`; iteration 2 adds the test-only fixes `e268ad4` and `39519bd`
**Verifier**: standalone fallback. The author ran the fresh-eyes pass because the sub-agent call was blocked by auto mode, and the user approved this. Author ≠ verifier does **not** hold for this run.

**Verdict**: PASS ✅ (iteration 2 of 3)

Iteration 1 left 2 of 20 mutants alive (M2, M14). Both were fixed with test-only commits, and all 20 mutants are now killed.

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 | ✅ Done | `34df5e4` |
| T2 | ✅ Done | `c0ffac5`; upgrade-path test added in F1 |
| T3 | ✅ Done | `88087d4` |
| T4 | ✅ Done | `0c471e0` |
| T5 | ✅ Done | `416e81b`, plus regression fix `2ba116c` |
| T6 | ✅ Done | `1d811df` |
| T7 | ✅ Done | `0c7ffae` |
| T8 | ✅ Done | `ed6af35` |
| F1 | ✅ Done | `e268ad4`, kills M14 |
| F2 | ✅ Done | `39519bd`, kills M2 |

---

## Spec-Anchored Acceptance Criteria

| Req | Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --------- | -------------------- | ----------------------- | ------ |
| LYR-01 | P1 AC1: Acrescentar linha | new empty line (text '', onset/naipe/dinâmica null) at the end, expanded | `test/presentation/providers/lyrics_editor_notifier_test.dart:228-233`: `expect(added.text, '')`, `expect(added.onsetMs, isNull)`, `expect(state.expandedIndex, 1)`; `test/presentation/screens/lyrics_editor/lyrics_editor_screen_test.dart:286-287` | ✅ PASS |
| LYR-01 | ordem manual persisted | unmarked line keeps its place between marked ones | `test/data/repositories/drift_song_repository_test.dart:224-232`: `expect(loaded.lyrics.map((l) => l.onsetMs).toList(), [1000, null, 4000])` | ✅ PASS |
| LYR-01 | schema v3 accepts NULL `onset_ms` on an **upgraded** DB | upgraded v2 DB stores an unmarked line | `test/infrastructure/database/app_database_migration_test.dart:101-122`: `expect(rows.map((r) => r.onsetMs).toList(), [12500, isNull])` after upgrading a seeded v2 file | ✅ PASS (iteration 2) |
| LYR-02 | P1 AC2/AC3: texto 1–200, vazio rejeitado | keeps previous text; 200 accepted | `lyrics_editor_notifier_test.dart:245-253`: `expect(...lines[0].text, 'x' * 200)`; blur revert `test/presentation/widgets/lyric_line_row_test.dart:178`: `expect(_fieldText(tester, 'Texto da linha'), 'Ave')` | ✅ PASS |
| LYR-03 | P1 AC4: Ouvir com a letra | all tracks from 0 ms, marking mode | `lyrics_editor_notifier_test.dart:320-321`: `expect(s.engine.calls, ['load', 'seek:0', 'play'])`, `expect(...previewing, isTrue)` | ✅ PASS |
| LYR-04 | P1 AC5: rodapé | next line text + time `mm:ss.s` | `lyrics_editor_screen_test.dart:335-336`: `find.text('Próxima: natum de Maria Virgine')`, `find.text('0:05.3')` | ✅ PASS |
| LYR-05 | P1 AC6: Marcar agora | onset = current time on next unmarked line; "próxima" advances | `lyrics_editor_notifier_test.dart:420-422`: `expect(state.lines[1].onsetMs, 5300)`, `expect(state.nextUnmarkedIndex, 2)` | ✅ PASS |
| LYR-06 | P1 AC7: fora de ordem | reject when now **<** previous onset; inline error; no advance | `lyrics_editor_notifier_test.dart:442-444`; screen `lyrics_editor_screen_test.dart:367`: `find.text('Esse momento vem antes da linha anterior.')`. Equal instant accepted: `lyrics_editor_notifier_test.dart:450-467`: `expect(state.markError, isNull)`, `expect(state.lines[1].onsetMs, 8000)` | ✅ PASS (iteration 2) |
| LYR-07 | P1 AC8: nada a marcar | button disabled | `lyrics_editor_screen_test.dart:353`: `expect(_primary(tester, 'Marcar agora').onPressed, isNull)`; `lyrics_editor_notifier_test.dart:478` | ✅ PASS |
| LYR-08 | P1 AC9: Pausar/Continuar | stays in marking mode; resume without seek to 0 | `lyrics_editor_notifier_test.dart:362-369`: `expect(s.engine.seekAllToCalls, [0])`; `lyrics_editor_screen_test.dart:380-388` | ✅ PASS |
| LYR-09 | P1 AC10: tempo / "—" | `0:05.3` or "—" | `lyric_line_row_test.dart:74`, `:89`: `expect(find.text('—'), findsOneWidget)` | ✅ PASS |
| LYR-10 | P1 AC11: "X de Y marcadas" | exact count text | `lyrics_editor_screen_test.dart:252`: `find.text('1 de 2 marcadas')`; `:351`; notifier `:513` | ✅ PASS |
| LYR-11 | P1 AC12: Salvar | lines with text persisted in order; empty drafts skipped | `lyrics_editor_notifier_test.dart:567-572`: `expect(saved[1].onsetMs, isNull)`, `expect(saved[1].naipe, Naipe.contralto)` | ✅ PASS |
| LYR-12 | P1 AC13: estado vazio | EmptyState with action, no footer | `lyrics_editor_screen_test.dart:266-268`: `find.text('Nenhuma linha ainda')`, `find.text('Salvar letra'), findsNothing` | ✅ PASS |
| LYR-13 | P1 AC14: linha atual | greatest onset ≤ now; none before the first | `lyrics_editor_notifier_test.dart:530-542`: `expect(...currentLineIndex, isNull)` then `0`, `2`; screen `:412-413` (`Linha atual` semantics) | ✅ PASS |
| LYR-14 | P2 AC1–3: naipe | 4 naipes + Nenhum, preselected; null for Nenhum | `lyric_line_row_test.dart:136-139`, `:159`: `expect(calls.naipes, [Naipe.bass, null])`; notifier `:266-270` | ✅ PASS |
| LYR-15 | P2 AC4/AC5: dinâmica | ≤40 saved; empty → null | `lyrics_editor_notifier_test.dart:283-292`: `expect(...dynamics, isNull)`; row `:210-214` | ✅ PASS |
| LYR-16 | P2 AC6: selo + dinâmica | "Naipe · dinâmica", or selo only | `lyric_line_row_test.dart:77`: `find.text('Tenor · piano')`; `:90-91` | ✅ PASS |
| LYR-17 | P3 AC1: banner | banner with shortcut to Alinhamento | `lyrics_editor_screen_test.dart:298`, `:308`: `find.text('route:track-align:ave')` | ✅ PASS |
| LYR-18 | P3 AC2: controles desabilitados | listen/mark disabled; editing and saving still work | `lyrics_editor_screen_test.dart:300`: `isEnabled ... isFalse`; `:322`: `expect(setup.repo.savedSong!.lyrics.last.text, 'vere passum')` | ✅ PASS |
| LYR-19 | Edge: não encontrada | not-found state | `lyrics_editor_screen_test.dart:224`: `find.text('Música não encontrada')`; notifier `:199` | ✅ PASS |
| LYR-20 | Edge: sair com alterações | ConfirmSheet first | `lyrics_editor_screen_test.dart:468`: `find.text('Descartar alterações?')`; `:488` (no sheet when clean) | ✅ PASS |
| LYR-21 | Edge: parar ao sair | audio stopped | `lyrics_editor_notifier_test.dart:653`: `expect(s.engine.calls.last, 'stop')`; screen `:501` | ✅ PASS |
| LYR-22 | Edge: falha ao salvar | error shown; edits kept | `lyrics_editor_notifier_test.dart:634-637`: `expect(state.hasUnsavedChanges, isTrue)`; screen `:455-456` | ✅ PASS |
| T8 | Rota real | detail opens editor with the song id | `test/presentation/screens/song_detail/song_detail_screen_test.dart:307`: `find.text('route:lyrics-editor:s1')`; `test/presentation/routing/app_router_test.dart:149-155` | ✅ PASS |

**Status**: ✅ All ACs covered (iteration 2). There are no spec-precision gaps: every AC states a precise outcome.

---

## Discrimination Sensor

Scratch: temporary `git worktree` at HEAD `ed6af35`, with generated `.g.dart` copied in. The real tree's `git status --porcelain` was identical before and after (empty).

| # | File | Fault | Killed? |
| - | ---- | ----- | ------- |
| M1 | `lib/presentation/providers/lyrics_editor_notifier.dart:336` | out-of-order rejection removed | ✅ Killed |
| M2 | `lib/presentation/providers/lyrics_editor_notifier.dart:336` | `now < previousOnset` → `<=` (an equal onset is rejected) | ❌ Survived (iter. 1) → F2 → ✅ Killed (iter. 2) |
| M3 | `lib/presentation/providers/lyrics_editor_notifier.dart:373` | save also drops unmarked lines | ✅ Killed |
| M4 | `lib/presentation/providers/lyrics_editor_notifier.dart:315` | Continuar seeks back to 0 | ✅ Killed |
| M5 | `lib/presentation/providers/lyrics_editor_notifier.dart:313` | Pausar leaves marking mode | ✅ Killed |
| M6 | `lib/presentation/providers/lyrics_editor_notifier.dart:330` | markNow allowed while paused | ✅ Killed |
| M7 | `lib/presentation/providers/lyrics_editor_notifier.dart:120` | currentLineIndex `>` → `>=` | ✅ Killed |
| M8 | `lib/presentation/providers/lyrics_editor_notifier.dart:236` | text limit `>` → `>=` (200 rejected) | ✅ Killed |
| M9 | `lib/presentation/providers/lyrics_editor_notifier.dart:249` | empty dinâmica kept as `''` | ✅ Killed |
| M10 | `lib/presentation/providers/lyrics_editor_notifier.dart:408` | dispose no longer stops audio | ✅ Killed |
| M11 | `lib/presentation/providers/lyrics_editor_notifier.dart:195-197` | stale-lyrics guard removed | ✅ Killed |
| M12 | `lib/data/repositories/drift_song_repository.dart:82` | getById orders by onsetMs | ✅ Killed |
| M13 | `lib/data/repositories/drift_song_repository.dart:118` | getAll orders by onsetMs | ✅ Killed |
| M14 | `lib/infrastructure/database/app_database.dart:35` | v2→v3 `alterTable` removed (onset_ms stays NOT NULL on upgraded DBs) | ❌ Survived (iter. 1) → F1 → ✅ Killed (iter. 2) |
| M15 | `lib/data/mappers/lyric_line_mapper.dart:25` | null onset read back as 0 | ✅ Killed |
| M16 | `lib/presentation/widgets/lyric_line_row.dart:139` | invalid text not reverted on blur | ✅ Killed |
| M17 | `lib/presentation/screens/lyrics_editor/lyrics_editor_screen.dart:407` | Marcar agora enabled while paused | ✅ Killed |
| M18 | `lib/presentation/screens/lyrics_editor/lyrics_editor_screen.dart:228` | Ouvir enabled without tracks | ✅ Killed |
| M19 | `lib/presentation/screens/song_detail/song_detail_screen.dart` | wrong id passed to lyrics-editor | ✅ Killed |
| M20 | `lib/presentation/routing/app_router.dart` | router ignores `:id` | ✅ Killed |

**Sensor depth**: P0-full (manual, ≥5 per risky area; the migration is data integrity).
**Result**: iteration 1: 18/20 killed (M2 and M14 survived). Iteration 2: all 20 re-run at `39519bd` in a fresh worktree, **20/20 killed: PASS ✅**. The real tree's porcelain was identical before and after both runs.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ |
| Surgical changes | ✅. Shared-widget changes (`SegmentedOption.semanticLabel`, disabled `NavPill`) were needed and are documented in `COMPONENTS.md` |
| No scope creep | ✅ |
| Matches patterns | ✅ (mirrors `track-align-screen`) |
| Spec-anchored outcome check | ✅ (after F1/F2) |
| Per-layer Coverage Expectation met | ✅ (the upgrade path is proven by F1) |
| Every test maps to a spec requirement | ✅ |
| Documented guidelines followed: `AGENTS.md` §7, `CLAUDE.md` | ✅, except l10n, which is known project debt: strings are inline, as in every existing screen |

---

## Edge Cases

- [x] Não encontrada: `lyrics_editor_screen_test.dart:224`
- [x] Sair com alterações não salvas → ConfirmSheet: `lyrics_editor_screen_test.dart:468`
- [x] Parar reprodução ao sair: `lyrics_editor_screen_test.dart:501`
- [x] Falha ao salvar preserva alterações: `lyrics_editor_screen_test.dart:455-456`

---

## Gate Check

- **Gate command**: `flutter analyze && dart format --set-exit-if-changed lib test && flutter test`
- **Result**: iteration 1 at `ed6af35`: 546 passed. Iteration 2 at `39519bd`: analyze clean, format 0 changed, **548 passed**, 0 failed, 0 skipped
- **Test count after feature**: 548 (+2 from F1/F2)
- **Deleted tests**: one, replaced: the `lyrics-editor` entry of the ComingSoon loop in `app_router_test.dart` became the real-screen test (T8). LIB-15 was rewritten, not deleted (superseded by the user decision "ordem manual").
- **Known flaky (unrelated)**: `test/infrastructure/transfer/chunked_file_receiver_test.dart` uses wall-clock delays.

---

## Fix Plans (iteration 1, both done)

### Fix 1: the v2→v3 migration is not proven to allow NULL on an upgraded database

- **Root cause**: `app_database_migration_test.dart` checks only that an existing row survives the upgrade. If the `alterTable` step is deleted, `onset_ms` stays `NOT NULL` on every device that upgrades from v2, so saving any unmarked line fails there. No test notices.
- **Fix task**: in the v2→v3 group, after opening the seeded v2 DB with `AppDatabase`, insert a `lyric_lines` row with `onsetMs: Value(null)` and assert it reads back as null. The test must fail with M14 applied.
- **Priority**: Major (data integrity on real upgrades).

### Fix 2: the "same instant as the previous line" mark is not covered

- **Root cause**: AC7 rejects only when now < previous onset, so an equal instant must be accepted. No test pins the boundary.
- **Fix task**: add a notifier test where `currentPositionMs` equals the previous marked onset, and assert the mark is accepted (`onsetMs` equals that instant and `markError` is null). The test must fail with M2 applied.
- **Priority**: Minor.

---

## Requirement Traceability Update

| Requirement | New Status |
| ----------- | ---------- |
| LYR-01 to LYR-22 | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready.

**Spec-anchored check**: 22/22 requirements matched to the spec outcome.
**Sensor**: 20/20 mutations killed (iteration 2).
**Gate**: 548 passed.

**What works**: the full editor flow: add, edit, mark, pause/resume, save, the naipe/dinâmica fields, the no-tracks banner and every screen state. Schema v3 persists unmarked lines on fresh installs and on upgraded databases. The real route is wired from Detalhe da música.

**Issues found**: two weak tests (M14, M2), both fixed in F1 and F2.

**Next steps**: merging `feature/phase-5-lyrics-editor` into `develop` needs the user's go-ahead.
