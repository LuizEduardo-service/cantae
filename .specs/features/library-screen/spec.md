# Library Screen Specification

## Problem Statement

`lib/presentation/` has a theme layer (done) but no screens, no router, and no Riverpod wiring between `SongRepository` and any widget. This feature builds the Biblioteca (library) screen — the app's home screen per `docs/prd-cantae-ux-telas.md` §5's nav map — plus the router and shared widgets every later Phase 5 screen will reuse, and the two domain/data fields the screen's own spec in `docs/design/UI_SPEC.md` §6.2 requires that don't exist yet (song origin, last-rehearsed timestamp).

## Goals

- [ ] A person opening the app for the first time (with songs already in the library) sees the Biblioteca screen matching `UI_SPEC.md` §6.2/§6.2b: search, Todas/Criadas/Recebidas filter, sort, song list with naipe badges, and all four required states (populated/empty/loading/filtered-empty).
- [ ] `SongRepository` gains `origin` (created/received) and `lastRehearsedAt`, with a `markRehearsed` mutator, so a future rehearsal-ending feature has a real method to call instead of the screen inventing a workaround.
- [ ] `go_router` is adopted project-wide (first use), with the Biblioteca as the real initial route and named placeholder routes for every screen the Biblioteca links to that doesn't exist yet.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Song detail, song editor, room create/join, profile, package import — their actual content | Each is its own future Phase 5 feature per `AGENTS.md` §4's screen inventory. This feature's router points at them by name with a placeholder "Em breve" screen only. |
| Writing `markRehearsed` from a real rehearsal session | No room/session screen exists yet to call it from (confirmed with user). The method exists, is tested, and is read by this screen; wiring a caller is each future room screen's own task. |
| Package-import flow that would actually produce a `received`-origin song | `package_import` screen doesn't exist yet (same reasoning as origin's default). Every song created in this feature's scope (fixtures, tests) uses `SongOrigin.created`; `received` is a real, usable enum value with no current producer. |
| Studio draft banner, "Preparar" section, naipe management — anything from `UI_SPEC.md` §6.3 (Detalhe da música) | Different screen, different feature. |
| Sorting by anything beyond name and last-rehearsed | User confirmed scope: name (A-Z) and last-rehearsed-first only. |
| Any network/mDNS-backed state for the Biblioteca itself | The library list is 100% local (`SongRepository`); "Entrar em sala"/"Criar sala" buttons route to placeholders, no network call happens in this feature. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| `SongOrigin` field default/mutability | New `enum SongOrigin { created, received }`; `Song.origin` defaults to `SongOrigin.created` (named, optional param — like `version`) so every existing call site (fixtures, mappers, other tests) keeps compiling unchanged; immutable once set (assigned once, at creation/import time, never reassigned) | A required new constructor param would break ~10 existing call sites across `lib/` and `test/` for no behavioral reason yet (no production code assigns `received` in this feature's scope) | y |
| `lastRehearsedAt` write path | Add `SongRepository.markRehearsed(String id, DateTime at)` now, with a `DriftSongRepository` implementation and tests, even though no caller exists in this feature's scope | User explicitly chose this over deferring the method — it is a complete, independently-useful capability (not a speculative abstraction with an undefined shape), and the Biblioteca's own "último ensaio destacado" requirement needs the read side to mean something eventually | y — user confirmed explicitly |
| Schema migration | `schemaVersion` 1→2 via drift's `stepByStep(from1To2: ...)` adding two nullable/defaulted columns (`origin` as a `TextColumn` storing the enum name, `last_rehearsed_at` as a nullable `DateTimeColumn`) — additive only, per AD-009 | Matches the project's established additive-only migration decision; no existing row loses data | y |
| Sort options | Name (A-Z, default) and "último ensaio" (most recent first) | User confirmed explicitly | y |
| Routing | Adopt `go_router` now as the project's router (first use). Real route: `library` (`/`). Named placeholder routes for every linked-but-unbuilt screen (`song-detail`, `room-create`, `room-join`, `profile`, `package-import`), each rendering a single shared `ComingSoonScreen(title: ...)` widget | User confirmed explicitly over a callback-only approach, to avoid redoing routing when the second real screen lands | y — user confirmed explicitly |
| `ComingSoonScreen` scope | One small shared widget (`CantaeScaffold` + `EmptyState`-style "Em breve" message + a "Voltar" `NavPill`), built as part of this feature since the router needs *something* at those routes | Minimal placeholder, not a stand-in for any real feature's spec; each future screen replaces its own placeholder route's builder | y |
| "Status" text in `SongRow` | Derived from `Song.isComplete`/missing naipes: when incomplete, show "Falta {Naipe}" (singular) or "Faltam {N} naipes" (plural) in `warningInline`; when complete, no status text (just the title) | `UI_SPEC.md` §6.2 only says "subtítulo 'Autor · status'" without defining the exact missing-naipe copy; this matches the doc's own "falta Tenor" example and `UI_GUIDELINES.md`'s "diga o que aconteceu" rule | y — user confirmed explicitly |
| "Último ensaio" highlight | The single song with the most recent non-null `lastRehearsedAt` across the whole list (ties broken by insertion order) gets the highlighted `SongRow` treatment (`surface` background) described in `COMPONENTS.md`'s `SongRow`; if no song has ever been rehearsed (`lastRehearsedAt` all null, the common case until a room feature exists), no row is highlighted | Directly matches `UI_SPEC.md` §6.2 ("o último ensaio aparece destacado") without inventing additional UI for the current real-world case of zero rehearsal history | y |
| Search scope | Case-insensitive substring match against `Song.name` and `Song.author`, applied client-side over the already-loaded list (no new repository method) | `SearchField`'s placeholder is literally "Buscar música ou autor" (`COMPONENTS.md`) — this is precise, not a gap | y |
| "Criadas"/"Recebidas" filter semantics | Filters the already-loaded list by `song.origin`; "Recebidas" will show empty today (no producer of `received` exists yet) — this is a real, correct empty-filter state (covered by the Filtro-sem-resultado spec state), not a bug | Matches the project's own precedent (AD-004: declaring a capability before every consumer exists) | y |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: See and find songs in the library ⭐ MVP

**User Story**: As anyone opening the app (any role, before joining or starting a room), I want to see my songs, search/filter/sort them, and immediately notice which one I rehearsed most recently, so I can get into a rehearsal with the right song in a few seconds.

**Why P1**: This is the app's home screen (`docs/prd-cantae-ux-telas.md` §5's nav map starts here) and the hard dependency for every other Phase 5 screen's navigation entry point.

**Acceptance Criteria**:

1. WHEN the Biblioteca screen loads and `SongRepository.getAll()` has not yet resolved THEN the system SHALL render a 5-row skeleton list (per `UI_SPEC.md` §6.2 "Carregando — esqueleto de 5 linhas").
2. WHEN `SongRepository.getAll()` resolves with one or more songs THEN the system SHALL render: a `SearchField`, a `SegmentedControl` with "Todas"/"Criadas"/"Recebidas", a count label ("N músicas"), a sort control, and one `SongRow` per song showing title, status subtitle, and up to 4 `VoicePartBadge`s (filled for present naipes, dashed `missing` for absent standard naipes).
3. WHEN `SongRepository.getAll()` resolves with zero songs THEN the system SHALL render the `EmptyState` from `UI_SPEC.md` §6.2b ("Nenhuma música ainda" + "Cadastrar primeira música" primary + "Abrir pacote .cantae" secondary + the "Entrar em sala" card) instead of the search/filter/list UI.
4. WHEN the user types into `SearchField` and no song's name or author contains the (case-insensitive) query THEN the system SHALL render "Nada encontrado para "{query}"" plus a "Limpar busca" action, per `UI_SPEC.md` §6.2.
5. WHEN the user types into `SearchField` and at least one song matches THEN the system SHALL filter the visible list to only matching songs with no additional navigation or delay (same frame as the keystroke's rebuild).
6. WHEN the user selects "Criadas" or "Recebidas" in the `SegmentedControl` THEN the system SHALL show only songs whose `origin` matches (`created`/`received` respectively), combined with any active search query.
7. WHEN the user selects "Nome (A-Z)" sort THEN the system SHALL order the visible list alphabetically by `Song.name` (case-insensitive); WHEN the user selects "Último ensaio" sort THEN the system SHALL order by `lastRehearsedAt` descending, with songs that have never been rehearsed (`null`) sorted after all rehearsed songs.
8. The system SHALL visually highlight (via the `SongRow` "destacado" treatment) exactly the one song with the latest non-null `lastRehearsedAt` in the full (unfiltered) list, independent of the current sort/filter/search selection; IF no song has a non-null `lastRehearsedAt` THEN the system SHALL highlight none.
9. WHEN the user taps a `SongRow` THEN the system SHALL navigate to the `song-detail` named route with that song's id.
10. WHEN the user taps the "Importar" `NavPill` or the avatar THEN the system SHALL navigate to the `package-import` or `profile` named route respectively; WHEN the user taps the footer's "Entrar em sala" or "Criar sala" THEN the system SHALL navigate to `room-join`/`room-create` respectively. All five currently render the shared placeholder screen (see Assumptions).
11. IF `SongRepository.getAll()` returns a `Failure` THEN the system SHALL render an `InlineBanner` (variant `error`) with a "Tentar de novo" action that re-triggers the load, per `UI_GUIDELINES.md` §5's Erro row.

**Independent Test**: Seed the in-memory `SongRepository` (via a fake/test double) with 3 songs (one complete, one missing a naipe, one with a recent `lastRehearsedAt`), pump `LibraryScreen` inside a `MaterialApp`, and verify: the recently-rehearsed song's row is highlighted, the incomplete song shows its missing-naipe status text, typing a non-matching query shows the no-results state, and switching to "Recebidas" shows the empty-filter state (since none of the 3 fixtures are `received`).

---

### P2: SongRepository carries origin and last-rehearsed data

**User Story**: As the app's persistence layer, I want every song to remember whether it was created locally or received from someone else, and when it was last rehearsed, so the Biblioteca (and later screens) can show that without guessing.

**Why P2**: Pure infrastructure with no independent user-visible behavior of its own — it only matters through P1's UI, but is listed separately because its "Independent Test" doesn't require any widget.

**Acceptance Criteria**:

1. The system SHALL persist `Song.origin` (`created`/`received`) and `Song.lastRehearsedAt` (nullable) across app restarts, via an additive `schemaVersion` 1→2 drift migration that preserves all existing rows' data.
2. WHEN `SongRepository.markRehearsed(id, at)` is called for an existing song THEN the system SHALL update only that song's `lastRehearsedAt` to `at`, leaving every other field (including `tracks`/`lyrics`) untouched.
3. IF `SongRepository.markRehearsed(id, at)` is called for a non-existent `id` THEN the system SHALL return `Result.failure(NotFoundFailure(code: 'song_not_found'))`, matching the existing `getById`/`delete` not-found convention.

**Independent Test**: `NativeDatabase.memory()`-backed repository test (per AD-010): save a song with no `origin` specified, confirm it reads back as `SongOrigin.created`; call `markRehearsed`, confirm `lastRehearsedAt` updates and `tracks` are unchanged; run the migration from a v1 schema fixture and confirm a pre-existing row survives with `origin = created` and `lastRehearsedAt = null`.

---

## Edge Cases

- IF two songs share the exact same (non-null) `lastRehearsedAt` millisecond THEN the system SHALL highlight whichever appears first in `SongRepository.getAll()`'s returned order (ties broken by list order, not re-sorted) — an edge case with no real-world likelihood but a defined, testable outcome.
- IF the search query contains only whitespace THEN the system SHALL treat it as a non-empty query (whitespace is not auto-trimmed to "show all") — matching literal substring-match semantics, since `UI_GUIDELINES.md` doesn't call out trimming.
- WHEN the user clears the search field after a no-results state THEN the system SHALL return to the normal populated/filtered list with no extra tap needed beyond clearing the text.
- IF `SongRepository.getAll()` is still loading when the user attempts to type into `SearchField` THEN the system SHALL disable `SearchField` interaction until the first load resolves (there is nothing to filter yet) — matches the skeleton state having no interactive controls.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| LIB-01 | P1 | Design | Pending |
| LIB-02 | P1 | Design | Pending |
| LIB-03 | P1 | Design | Pending |
| LIB-04 | P1 | Design | Pending |
| LIB-05 | P1 | Design | Pending |
| LIB-06 | P1 | Design | Pending |
| LIB-07 | P1 | Design | Pending |
| LIB-08 | P1 | Design | Pending |
| LIB-09 | P1 | Design | Pending |
| LIB-10 | P1 | Design | Pending |
| LIB-11 | P1 | Design | Pending |
| LIB-12 | P2 | Design | Pending |
| LIB-13 | P2 | Design | Pending |
| LIB-14 | P2 | Design | Pending |

**ID format:** `LIB-NN`, numbered across both stories in document order (LIB-01..11 = P1's 11 ACs, LIB-12..14 = P2's 3 ACs).

**Coverage:** 14 total, 0 mapped yet (Design/Tasks not yet written), 14 unmapped ⚠️ (expected at this stage).

---

## Success Criteria

- [ ] `flutter analyze` and `flutter test` pass with all new/modified files in place; `check_layers.py` and `dart analyze lib/domain/` stay clean (the domain additions carry no Flutter/plugin imports).
- [ ] A person can go from a cold app start to tapping a specific song's row in under 3 interactions (open app → optionally type a search term → tap row).
- [ ] Every one of the 5 UI_SPEC §6.2 states (populated, empty, loading, filtered-empty, error) renders correctly in both light and dark themes with no widget-level `if (dark)` branch, per `AGENTS.md` §3/§7.
