# Tela Detalhe da música Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/song-detail-screen/design.md`
**Status**: Done — all 5 tasks (T1-T5) complete. Full BUILD gate green (`flutter analyze` 0 issues, `flutter test` 410/410, `check_layers.py` OK, `dart analyze lib/domain/` clean). Awaiting independent Verifier pass.

---

## Test Coverage Matrix

> Generated from codebase sampling (`library-screen`/`theme-tokens` features) — no project-specific coverage-threshold tool exists (`AGENTS.md` §7 and the `flutter-quality-gates` skill set the bar qualitatively: widget tests per state + both themes + accessibility semantics). Guidelines found: `AGENTS.md`, `docs/design/COMPONENTS.md` ("Cada componente tem um teste de widget cobrindo: estados, tema escuro e semântica de acessibilidade.").

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Presentation shared widgets (`DestructiveButton`, `ConfirmSheet`) | widget | Per `COMPONENTS.md`: every variant/state, dark theme, accessibility semantics | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets/` |
| Presentation providers (`songByIdProvider`) | unit (`ProviderContainer`) | Every branch: success, `NotFoundFailure`, other `Failure` | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers/` |
| Presentation screens (`SongDetailScreen`) | widget | All spec states (carregando / não encontrada / erro / completa / incompleta / somente leitura) + exclusão (confirmar/cancelar/falha) + navegação para as 6 rotas placeholder, both themes spot-checked | `test/presentation/screens/**/*_test.dart` | `flutter test test/presentation/screens/` |
| Routing (`AppRouter`) | widget | `song-detail` renders `SongDetailScreen`; each of the 6 new named routes renders `ComingSoonScreen` | `test/presentation/routing/*_test.dart` | `flutter test test/presentation/routing/` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task with only unit tests | `flutter test test/presentation/providers/` |
| Full | After a task with widget tests | `flutter test test/presentation/widgets/ test/presentation/screens/ test/presentation/routing/` |
| Build | After the last task of the feature | `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/` |

---

## Execution Plan

Phases are ordered and run sequentially — each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Shared components

```
T1
T2
```

### Phase 2: Data access

```
T3
```

### Phase 3: Screen

```
T1 --> T4
T2 --> T4
T3 --> T4
```

### Phase 4: Routing

```
T4 --> T5
```

---

## Task Breakdown

### T1: `DestructiveButton`

**What**: New `DestructiveButton` widget with `tonal` (inicia o fluxo — `dangerBg`/`onDanger`) and `solid` (confirma — `dangerSolid`/branco) variants, per `COMPONENTS.md`.
**Where**: `lib/presentation/widgets/buttons.dart` (same file as `PrimaryButton`/`SecondaryButton` — same "fixed-height pill buttons" cohesion already documented there)
**Depends on**: None
**Reuses**: `PrimaryButton`'s structure (`Semantics(button: true)`, `Material`+`InkWell`, height 54, pill radius via `CantaeRadii.radiusPill`)
**Requirement**: DETAIL-17

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `tonal` variant renders with `dangerBg` background / `onDanger` text
- [x] `solid` variant renders with `dangerSolid` background / white text
- [x] Disabled (`onPressed: null`) renders with the same disabled treatment as `PrimaryButton`
- [x] `Semantics(button: true)` with the label on both variants
- [x] Widget tests: both variants render + tap fires `onPressed` + disabled doesn't + one dark-theme spot-check
- [x] Gate check passes: `flutter test test/presentation/widgets/`
- [x] Test count: 4+ new tests

**Tests**: widget
**Gate**: full
**Status**: ✅ Complete. 4/4 new tests pass (59/59 `test/presentation/widgets/`).

---

### T2: `ConfirmSheet`

**What**: New `ConfirmSheet.show(...)` static helper that opens a `showModalBottomSheet` with `CantaeColors.scrim`, supporting 1 or 2 steps and an optional `typedConfirmation`, per `COMPONENTS.md`. Returns `true` only on final confirmation; `false`/`null` on any cancel/dismiss.
**Where**: `lib/presentation/widgets/confirm_sheet.dart` (new file)
**Depends on**: None
**Reuses**: `CantaeColors.scrim`, `DestructiveButton` (T1) for the sheet's destructive action, `SecondaryButton` for the safe action
**Requirement**: DETAIL-18 (component capability; wired into the screen by T4)

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `steps: 1` (this feature's only consumer): shows `title`, `message`, a safe action (`safeLabel`) and a destructive action (`destructiveLabel`); tapping destructive resolves `show()` to `true`, tapping safe/dismissing resolves to `false`
- [x] `steps: 2` + `typedConfirmation`: second step's final button stays disabled until the typed text matches (case-insensitive), per `UI_GUIDELINES.md` §11 — exercised even though this feature's own consumer (T4) only uses `steps: 1`, since the component itself must match the full `COMPONENTS.md` shape (see design.md's Tech Decisions)
- [x] Widget tests: 1-step confirm, 1-step cancel, 2-step typed-confirmation gating (disabled until match, case-insensitive), one dark-theme spot-check
- [x] Gate check passes: `flutter test test/presentation/widgets/`
- [x] Test count: 4+ new tests

**Tests**: widget
**Gate**: full
**Status**: ✅ Complete. 4/4 new tests pass (63/63 `test/presentation/widgets/`).

---

### T3: `songByIdProvider`

**What**: New `FutureProvider.family<Result<Song, Failure>, String>` that calls `SongRepository.getById(id)` and returns the `Result` unchanged (no throw) — see design.md's Approach Exploration (Approach A).
**Where**: `lib/presentation/providers/song_detail_providers.dart` (new file)
**Depends on**: None
**Reuses**: `songRepositoryProvider`
**Requirement**: DETAIL-02, DETAIL-04, DETAIL-05

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] Resolves `AsyncData(Result.success(song))` when the repository finds the song
- [x] Resolves `AsyncData(Result.failure(NotFoundFailure))` when the repository returns `NotFoundFailure` (never surfaces as `AsyncError`)
- [x] Resolves `AsyncData(Result.failure(other))` for any other `Failure` (same: stays `AsyncData`, not `AsyncError` — only a thrown exception from the repository call itself would produce `AsyncError`, which doesn't happen in the real `DriftSongRepository`)
- [x] Unit tests (`ProviderContainer`, fake `SongRepository`): one per branch above
- [x] Gate check passes: `flutter test test/presentation/providers/`
- [x] Test count: 3+ new tests

**Tests**: unit
**Gate**: quick
**Status**: ✅ Complete. 3/3 new tests pass (13/13 `test/presentation/providers/`).

---

### T4: `SongDetailScreen`

**What**: Assembles `CantaeScaffold` + header (nome/autor/origem) + 4 `VoicePartBadge` naipe rows + "Preparar" section + rodapé, wired to `songByIdProvider` (T3), covering all spec states and both origin modes, plus the exclusão flow via `ConfirmSheet` (T2) + `DestructiveButton` (T1).
**Where**: `lib/presentation/screens/song_detail/song_detail_screen.dart` (new file)
**Depends on**: T1, T2, T3
**Reuses**: `CantaeScaffold`, `NavPill`, `VoicePartBadge`, `PrimaryButton`/`SecondaryButton`, `InlineBanner`, `EmptyState`, `DestructiveButton` (T1), `ConfirmSheet` (T2), `songByIdProvider` (T3), `songRepositoryProvider`, `songsProvider` (invalidated after a successful delete)
**Requirement**: DETAIL-01 through DETAIL-21 (all of P1)

**Tools**: MCP: NONE · Skill: `flutter-ui-ux` (final screen-assembly pass — layout/accessibility checklist)

**Done when**:
- [x] Carregando: esqueleto, sem naipes/rodapé (DETAIL-03)
- [x] Não encontrada (`id` inexistente ou `'new'`): `EmptyState` + ação "Voltar à Biblioteca", sem cabeçalho/naipes/rodapé (DETAIL-04)
- [x] Erro (falha de repositório que não seja `NotFoundFailure`): `InlineBanner` erro + "Tentar de novo" invalidando `songByIdProvider(id)` (DETAIL-05)
- [x] Populada: cabeçalho "Autor · Origem"; 4 `VoicePartBadge` (preenchido/tracejado por naipe real); naipe faltante mostra "Enviar faixa" → `goNamed('track-upload')` (DETAIL-02, 06, 07)
- [x] Seção "Preparar" (4 linhas) → `goNamed` para `studio`/`track-align`/`lyrics-editor`/`song-history` respectivamente (DETAIL-08, 09)
- [x] Rodapé: `SecondaryButton` "Ensaiar só" → `goNamed('solo-player')`; `PrimaryButton` "Ensaiar em grupo" → `goNamed('room-create')` (DETAIL-10, 11, 12, 13)
- [x] `origin == received`: oculta "Preparar" por completo e a ação "Enviar faixa" (selo tracejado continua visível); mantém "Ensaiar só"/"Ensaiar em grupo"/"Apagar desta música" (DETAIL-14, 15, 16)
- [x] "Apagar desta música" (`DestructiveButton` tonal) → `ConfirmSheet.show(steps: 1)`; confirmar chama `songRepositoryProvider.delete(id)`; sucesso invalida `songsProvider` e navega para `library`; falha mantém a tela e mostra `InlineBanner` erro; cancelar não chama `delete` (DETAIL-17, 18, 19, 20, 21)
- [x] Widget tests: uma por estado acima + exclusão (confirmar/cancelar/falha) + pelo menos uma navegação de cada seção + um spot-check em tema escuro — usando um `GoRouter` de teste com builders stub (mesmo padrão de `library_screen_test.dart`), não um stack de navegação real
- [x] Gate check passes: `flutter test test/presentation/screens/`
- [x] Test count: 12+ new tests

**Tests**: widget
**Gate**: full
**Status**: ✅ Complete. 15/15 new tests pass (added a test for the P2 Exportar `NavPill`, implemented alongside the rest of the hub since it's trivial wiring — DETAIL-22/23 were otherwise implemented but untested). Section headers ("Naipes"/"Preparar") rendered as a small private `_SectionLabel` (caption/text2) rather than a new shared `SectionLabel` widget — `COMPONENTS.md` documents one, but it wasn't in design.md's Components list for this feature and is a 1-line `Text`; same for the "Preparar" rows (plain `InkWell` rows, not a new `GroupedList`/`ListRow` component). Both deferred to whichever future screen first needs a second consumer, consistent with the naipe-mapping duplication risk already accepted in design.md. `flutter test` required `scrollUntilVisible` (not `ensureVisible`) for the delete button in the 3 exclusão tests — `CantaeScaffold`'s `body` is a plain (eager) `ListView`, but Flutter's sliver viewport still only *mounts* elements within the viewport + cache extent, so a finder for an off-screen item matches zero elements until scrolled.

---

### T5: `AppRouter` — rotas novas + `song-detail` real

**What**: Adiciona 6 `GoRoute`s novos (`solo-player`, `studio`, `track-align`, `lyrics-editor`, `song-history`, `track-upload`, todos `ComingSoonScreen`) e troca o builder de `song-detail` do `ComingSoonScreen` placeholder para `SongDetailScreen(songId: state.pathParameters['id']!)`.
**Where**: `lib/presentation/routing/app_router.dart`
**Depends on**: T4
**Reuses**: `SongDetailScreen` (T4), `ComingSoonScreen`
**Requirement**: DETAIL-02, DETAIL-09, DETAIL-11, DETAIL-13

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `song-detail` resolve para `SongDetailScreen` com o `id` da rota
- [x] Os 6 novos nomes de rota resolvem para `ComingSoonScreen` com um título apropriado cada
- [x] Widget test: pumping a `MaterialApp.router` com este router — `goNamed('song-detail', pathParameters: {'id': ...})` mostra `SongDetailScreen`; `goNamed` em cada uma das 6 novas mostra `ComingSoonScreen`
- [x] Gate check passes (último task da feature): `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`
- [x] Test count: 7+ new tests; suíte total ≥ 377 (contagem no início desta feature) + todos os testes novos de T1-T5

**Tests**: widget
**Gate**: build
**Status**: ✅ Complete. 12/12 new/changed tests pass in `test/presentation/routing/`. Full BUILD gate green: `flutter analyze` 0 issues, `flutter test` 410/410 clean on a fresh run (two timing-sensitive tests in `room_session_controller_test.dart`/`song_sync_coordinator_test.dart` flaked once mid-feature — confirmed untouched by this branch via `git diff --stat develop...HEAD`, confirmed passing in isolation, and the full suite reran green), `check_layers.py` + `dart analyze lib/domain/` clean.

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4

Phase 1:  T1    T2
Phase 2:  T3
Phase 3:  T1,T2,T3 ------→ T4
Phase 4:  T4 ------→ T5
```

Execution is strictly sequential — there is no intra-phase parallelism. 5 tasks total fits a single batch (≤ ~8); no sub-agent dispatch — executed inline.

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: `DestructiveButton` | 1 component (2 variants, same file as its siblings) | ✅ Granular |
| T2: `ConfirmSheet` | 1 component | ✅ Granular |
| T3: `songByIdProvider` | 1 provider | ✅ Granular |
| T4: `SongDetailScreen` | 1 screen component (all its states/modes — same precedent as `library-screen`'s T19) | ✅ Granular |
| T5: `AppRouter` update | 1 file change (route table) | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | — | ✅ Match |
| T2 | None | — | ✅ Match |
| T3 | None | — | ✅ Match |
| T4 | T1, T2, T3 | T1→T4 (via Phase 1→3 sequencing), T2→T4, T3→T4 | ✅ Match |
| T5 | T4 | T4→T5 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: `DestructiveButton` | Presentation shared widget | widget | widget | ✅ OK |
| T2: `ConfirmSheet` | Presentation shared widget | widget | widget | ✅ OK |
| T3: `songByIdProvider` | Presentation provider | unit | unit | ✅ OK |
| T4: `SongDetailScreen` | Presentation screen | widget | widget | ✅ OK |
| T5: `AppRouter` update | Routing | widget | widget | ✅ OK |

---
