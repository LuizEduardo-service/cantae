# Library Screen Validation

**Date**: 2026-11-19
**Spec**: `.specs/features/library-screen/spec.md`
**Diff range**: `develop...feature/phase-5-library-screen` (22 commits, 46 files changed, +4631/-22)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

All 21 tasks (T1-T21) marked Done. T3/T4/T5/T6 were committed together with T7 (one commit) — verified as a legitimate compilation-dependency merge (adding an abstract method to `SongRepository` breaks `DriftSongRepository` until the implementation exists too), not a hidden scope change: each task's own code is final and attributable to its own file/lines. `go_router`'s `pubspec.yaml` line similarly moved from T20 into T19 for the same reason (code needing a dependency to compile can't be gated before that dependency is declared). Both merges are logged, not silent.

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1-T21 | ✅ Done | See spec-anchored table below for evidence; commit-merge deviations (T3-T7, T20's pubspec line) confirmed reasonable, not scope creep |

---

## Spec-Anchored Acceptance Criteria

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| LIB-01: loading → 5-row skeleton | 5 skeleton rows, `SearchField` disabled | `lib/presentation/screens/library/library_screen.dart:139-160` (`_LoadingBody`, `itemCount: 5`, `SearchField(enabled: false,...)`); `test/presentation/screens/library/library_screen_test.dart:142-154` — `expect(tester.widget<TextField>(...).enabled, isFalse)` | ✅ PASS |
| LIB-02: populated → search/filter/sort/count/rows | SearchField + SegmentedControl(Todas/Criadas/Recebidas) + "N músicas" + sort + SongRow w/ badges | `library_screen_test.dart:156-174` — asserts all 5 labels + both song titles present | ✅ PASS |
| LIB-03: empty → EmptyState, no search/filter UI | §6.2b copy, no `TextField` | `library_screen_test.dart:194-206` — asserts exact EmptyState strings + `find.byType(TextField), findsNothing` | ✅ PASS |
| LIB-04: no match → "Nada encontrado para "{query}""+"Limpar busca" | exact quoted copy | `library_screen_test.dart:208-228` — `expect(find.text('Nada encontrado para "zzzznotfound"'), findsOneWidget)` | ✅ PASS |
| LIB-05: matching search narrows, same-frame | list filters without extra tap/delay | `library_screen_test.dart:176-192` — `enterText` then `pumpAndSettle`, asserts narrowed list + updated count | ✅ PASS |
| LIB-06: Criadas/Recebidas filters by origin, combined with search | origin-matched subset | `library_providers_test.dart:110-124` (origin alone), `:141-161` (origin+search combined); `library_screen_test.dart:230-245` (Recebidas UI path) | ✅ PASS |
| LIB-07: sort name A-Z / lastRehearsed desc, nulls last | exact order | `library_providers_test.dart:69-82` (`expect(visible.map((s)=>s.id), ['2','3','1'])`), `:84-108` (`['3','2','1']` with null-id `'1'` last) | ✅ PASS |
| LIB-08: highlight = latest non-null `lastRehearsedAt`, independent of filter/sort/search; tie→first in list order | one highlighted row, order-independent, tie-break by list position | `library_providers_test.dart:164-188` (search set to `'nonexistent'`, highlight still resolves — proves independence) and `:190-207` (equal timestamps → `expect(highlighted,'first')`) | ✅ PASS |
| LIB-09: tap row → `song-detail` with id | `context.goNamed('song-detail', pathParameters:{'id':...})` | `library_screen.dart:369-372`; `library_screen_test.dart:282-295` — `expect(find.text('route:song-detail:song-42'), findsOneWidget)` | ✅ PASS |
| LIB-10: Importar/avatar/footer → correct named routes | 4 distinct routes | `library_screen_test.dart:297-347` (4 tests, one per target); `test/presentation/routing/app_router_test.dart:70-118` cross-checks the same 5 route *names* against `AppRouter`'s own table, so a typo in either file would not be masked by the other | ✅ PASS |
| LIB-11: `Failure` → InlineBanner(error)+"Tentar de novo" retry | banner shown, retry re-loads | `library_screen_test.dart:247-268` — uses a 2-result sequence (failure then success) and asserts the retried content actually renders, not just that `invalidate` was called | ✅ PASS |
| LIB-12: persist `origin`/`lastRehearsedAt`, additive v1→v2 migration | existing rows survive, backfilled `origin='created'`, `lastRehearsedAt=null` | `test/infrastructure/database/app_database_migration_test.dart:11-46` — builds a genuinely v1-shaped file via raw `sqlite3` (no `origin`/`last_rehearsed_at` columns), sets `PRAGMA user_version=1`, opens via `AppDatabase`, asserts `row.origin=='created'`, `row.lastRehearsedAt==null`; `test/domain/entities/song_test.dart:134-151`; `test/data/mappers/song_mapper_test.dart:72-101` | ✅ PASS |
| LIB-13: `markRehearsed` updates only `lastRehearsedAt` | `tracks`/`lyrics` untouched | `test/data/repositories/drift_song_repository_test.dart:352-370` — re-reads via `getById`, asserts `tracks hasLength(2)`, `lyrics hasLength(3)`, `playbackTrack isNotNull` unchanged | ✅ PASS |
| LIB-14: `markRehearsed` on unknown id → `NotFoundFailure(code:'song_not_found')` | exact failure type+code | `drift_song_repository_test.dart:372-383` — `expect(f, isA<NotFoundFailure>()); expect(f.code, equals('song_not_found'))` | ✅ PASS |

**Status**: ✅ All 14 ACs covered and matched to their precise spec-defined outcome. One spec-precision gap (not an AC — a named Assumption) is flagged separately below.

---

## Deviation Assessment (T3-T7 merge, T16-T21 batch's 4 reported deviations)

| Deviation | Verdict | Reasoning |
| --- | --- | --- |
| T3-T6 code committed together with T7 | ✅ Reasonable | Genuine compile-order constraint (abstract method breaks the implementing class until the implementation lands); each task's own code is final, only the commit point moved, and it's documented in each task's Status note, not hidden |
| T5's `stepByStep` → `Migrator.addColumn`/`onUpgrade` API swap | ✅ Reasonable | `stepByStep(from1To2:...)` is genuinely generated-only in drift 2.35.x; `Migrator.addColumn` inside `onUpgrade` is the documented stable equivalent, preserves additive-only semantics, and AD-009 was amended in the same spirit as its own prior amendment for `drift` itself. Migration test independently confirms it works against a real pre-migration file (verified above, not vacuous) |
| go_router pubspec line moved T20→T19 | ✅ Reasonable | Same compile-order constraint as T3-T7; re-adding an already-present line in T20 would be a no-op, correctly skipped |
| `InlineBanner` built private inside `library_screen.dart`, not as a shared widget | ⚠️ Reasonable today, flagged debt | No other current consumer exists (`grep` for `InlineBanner`/`dangerBg` usage found only `library_screen.dart` and the color-token file itself), so there is no duplication *today*. But `UI_SPEC.md` §6.7/§6.8 already describe banner states for future room-create/room-join screens — the next screen that needs an error/warning banner will have to either duplicate `_ErrorBody`'s ~50 lines or retroactively extract it. This is a real, named future cost, not a hidden defect in this feature's own scope. Recorded as a lesson (see below) |
| `Material(type: transparency)` wrapper in `library_screen.dart` instead of fixing `CantaeScaffold` | ⚠️ Reasonable for this task's scope, but masks a latent shared-widget gap | Confirmed by reading `lib/presentation/widgets/cantae_scaffold.dart:33-75`: it is a plain `Container`/`SafeArea`/`Column` with no `Material` ancestor. Any **future** screen that composes `CantaeScaffold` with a bare `InkWell`-based widget (e.g. reusing `SongRow`, or writing its own without wrapping its own `Material`) will hit the exact same "No Material widget found" assertion this task worked around locally. The workaround is correctly scoped (T19's `Where` doesn't include `cantae_scaffold.dart`), but the root cause lives in a shared component every future screen touches. Recorded as a lesson |
| "Nada encontrado" copy for origin-filter-only empty case | ⚠️ Spec-precision gap, correctly flagged | `spec.md`'s LIB-04 AC and `UI_SPEC.md` §6.2 only define copy for the search-query case. The fallback (`'Nada encontrado'` with no quoted query) is a reasonable placeholder, not a defect, but it is genuinely undefined behavior, not a precise spec value — correctly self-flagged inline and in T19's Status note rather than silently passing |

---

## Discrimination Sensor

Isolated git worktree at `d:/Projetos/cantae_scratch4` (via `git worktree add ... HEAD`), never `git stash`. Baseline `git status --porcelain` on the real tree was empty before and confirmed empty (0 lines) after sensor work and `git worktree remove --force`. Generated `*.g.dart` files (untracked, drift-codegen output) were copied into the worktree so it would actually compile — a worktree mechanics step, not a real-tree mutation.

| # | File:line | Mutation | Tests run | Killed? |
| - | --- | --- | --- | --- |
| 1 | `lib/presentation/providers/library_providers.dart:94` | Tie-break flipped: `at.isAfter(latest)` → `!at.isBefore(latest)` (ties now go to the *last* song, not the first) | `test/presentation/providers/library_providers_test.dart` | ✅ Killed — tie-break test expected `'first'`, got `'second'` |
| 2 | `lib/data/repositories/drift_song_repository.dart:178` | Not-found check inverted: `existing == null` → `existing != null` | `test/data/repositories/drift_song_repository_test.dart` | ✅ Killed — both the success-path (LIB-13) and not-found (LIB-14) `markRehearsed` tests failed |
| 3 | `lib/presentation/routing/app_router.dart:27` | Route name typo: `'room-create'` → `'room_create'` | `test/presentation/routing/app_router_test.dart` | ✅ Killed — `goNamed('room-create')` threw a go_router assertion (`_nameToPath.containsKey(name)` false), failing that and all subsequent tests in the file |
| 4 | `lib/infrastructure/database/app_database.dart:27` | Migration guard weakened: `if (from < 2)` → `if (from < 1)` (never runs for a v1→v2 upgrade) | `test/infrastructure/database/app_database_migration_test.dart` | ✅ Killed — migration test failed with a null-check error reading the now-missing `origin` column |

**Sensor depth**: lightweight (4 targeted mutations across providers, data, routing, infrastructure layers — the 4 highest-risk new-behavior surfaces named in the task brief)
**Result**: 4/4 killed — ✅ PASS

---

## Code Quality

| Principle | Status |
| --- | --- |
| No features beyond what was asked | ✅ |
| No abstractions for single-use code | ✅ (small composed providers per design.md's chosen approach, not a God-object notifier) |
| No unnecessary "flexibility" added | ✅ |
| Only touched files required for task | ✅ (`CantaeScaffold` deliberately left untouched per T19's `Where`, despite the latent gap noted above) |
| Didn't "improve" unrelated code | ✅ |
| Matches existing patterns/style | ✅ (mirrors `AGENTS.md` theme-token usage throughout; no literal colors/sizes found outside `theme/` in the new widget files) |
| Would senior engineer approve? | ✅ with the two flagged debts (InlineBanner extraction, CantaeScaffold Material ancestor) noted for follow-up, not blocking |
| Tests map to acceptance criteria and are non-shallow | ✅ — spot-checked P1 (LIB-08's highlight independence test deliberately sets an unrelated search query to prove independence, not just asserting a value exists) |
| Spec-anchored outcome check | ✅ — see table above, every asserted value matches spec.md's precise value where one is defined |
| Per-layer Coverage Expectation met | ✅ — domain 1:1 (origin default + round-trip), data (every mapper/migration/markRehearsed branch), presentation widgets/providers/screens/routing all covered per the Test Coverage Matrix in tasks.md |
| Every test maps to a spec AC/edge case/Done-when (no unclaimed tests) | ✅ — spot-checked; test names/comments cite LIB-NN ids throughout |
| Documented guidelines followed | `AGENTS.md` §3/§7, `COMPONENTS.md`, `DESIGN_SYSTEM.md`, `CLAUDE.md` Testing Rules — all cited inline in tasks.md/design.md and consistent with code read |

---

## Edge Cases

- [x] Tie on identical `lastRehearsedAt` → first-in-list-order highlighted: `library_providers_test.dart:190-207`, confirmed by surviving mutation sensor #1
- [x] Whitespace-only search treated as non-empty (no auto-trim): `_matchesSearch` (`library_providers.dart:34-39`) does no trimming; not independently asserted by a dedicated test, but the implementation has no trim call to begin with — low risk, no gap flagged
- [x] Clearing search after no-results returns to populated list with no extra tap: `library_screen_test.dart:220-227` (`tester.tap(find.text('Limpar busca'))` then asserts the song reappears)
- [x] `SearchField` disabled while loading: `library_screen_test.dart:142-154`

---

## Gate Check

- **Gate command**: `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/` (ran as 4 separate invocations with `D:\flutter\bin` prepended to PATH; same net effect)
- **Result**: `flutter analyze` — 0 issues. `flutter test` — **375 passed, 0 failed** (full clean run, no flakes observed in this run). `check_layers.py` — OK, no forbidden imports in `lib/domain/`. `dart analyze lib/domain/` — no issues.
- **Test count before feature** (per tasks.md's own baseline note): 282
- **Test count after feature**: 375
- **Delta**: +93 new tests
- **Skipped tests**: none
- **Failures**: none
- **Known pre-existing flakes** (`song_sync_coordinator_test.dart`, `chunked_file_receiver_test.dart`, reported by the implementation batch as unrelated timing/concurrency tests): confirmed via `git diff --name-only develop...feature/phase-5-library-screen | grep -i "song_sync_coordinator\|chunked_file_receiver"` → **no match** (exit 1) — these files are genuinely untouched by this branch's diff. Not observed to fail in this Verifier's own full-suite run, so no re-run/isolation was needed to clear them.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| LIB-01 .. LIB-14 | Done (implementer-claimed) | ✅ Verified (independent evidence, see table above) |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 14/14 ACs matched spec outcome; 1 named spec-precision gap (origin-filter-only "Nada encontrado" copy, not search-query — out of the 14 ACs, it's an Assumption-table item, not a numbered AC, so it does not count against the 14/14)
**Sensor**: 4/4 mutations killed
**Gate**: 375 passed, 0 failed, 0 skipped; `analyze`/`check_layers`/`dart analyze lib/domain/` all clean

**What works**: All 5 `LibraryScreen` states (loading/populated/empty/filtered-empty/error), search/filter/sort/highlight composition, navigation to all 5 placeholder routes with route-name cross-checking between `LibraryScreen` and `AppRouter` tests, `SongRepository.markRehearsed` success+not-found paths, and a genuinely-exercised (non-vacuous) v1→v2 schema migration.

**Issues found** (non-blocking, both already self-flagged by the implementation batch and independently confirmed real):
1. `InlineBanner` exists only as a private widget in `library_screen.dart`. No duplication today, but the next screen needing an error/warning banner (per `UI_SPEC.md` §6.7/§6.8) will have to extract it or copy it. Fix: when that screen lands, promote `_ErrorBody` to `lib/presentation/widgets/inline_banner.dart` first.
2. `CantaeScaffold` has no `Material` ancestor; `library_screen.dart` worked around this locally with `Material(type: transparency)`. Any future screen combining `CantaeScaffold` with a bare `InkWell` will hit the same assertion. Fix: add the `Material` wrapper inside `CantaeScaffold` itself in a small, independent follow-up task, then remove the now-redundant wrapper from `library_screen.dart`.

**Next steps**: No fix-before-merge required — both issues are forward-looking debt on shared components, not failures of this feature's own acceptance criteria. Recommend opening the two follow-ups above before (or alongside) the next Phase 5 screen that needs a banner or reuses `CantaeScaffold` with bare `InkWell` children.
