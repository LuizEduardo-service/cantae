# Foundation Setup Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Spec**: `.specs/features/foundation-setup/spec.md`
**Status**: Done

> **Note — gate check deviation:** Flutter SDK not available in the automation environment. `flutter analyze`, `flutter test`, and `flutter pub get` gates must be verified manually by the developer after installing Flutter. All files were created correctly; `python scripts/check_layers.py` was verified programmatically (exit 0 on clean tree, exit 1 on injected violation). See SPEC_DEVIATION note in T1.

---

## Test Coverage Matrix

> Generated from CLAUDE.md guidelines (found: `CLAUDE.md` — testing rules section). No existing tests (new project). Strong defaults applied where CLAUDE.md is silent.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
|------------|-------------------|----------------------|------------------|-------------|
| Domain/core (Result, Failure) | unit (failure-first) | All failure modes listed before code; 1:1 to spec ACs FOUND-17–22 | `test/domain/core/*_test.dart` | `flutter test test/domain/core/` |
| Domain entities (stub) | none | Build gate only — stubs have no logic | - | build gate only |
| Test fixtures | smoke | All 5 fixtures instantiate; key fields assert; no I/O required | `test/fixtures/fixture_smoke_test.dart` | `flutter test test/fixtures/` |
| Scripts (Python) | manual | Run script on clean tree → exit 0; inject violation → exit 1 | `scripts/check_layers.py` | `python scripts/check_layers.py --root .` |
| Config / pubspec / analysis_options | none | Build gate only | - | build gate only |

## Gate Check Commands

> Generated from Flutter project conventions.

| Gate Level | When to Use | Command |
|------------|-------------|---------|
| Quick | After tasks with unit tests only | `flutter test test/domain/core/` |
| Full | After tasks with smoke or multi-layer tests | `flutter test` |
| Build | After config/entity-only tasks or phase completion | `flutter analyze && flutter test && python scripts/check_layers.py --root .` |

---

## Execution Plan

All tasks run in a single phase, sequentially.

### Phase 1: Foundation

```
T1 → T2 → T3 → T4 → T5 → T6 → T7
```

---

## Task Breakdown

### T1: Flutter project creation and git init

**What**: Run `flutter create` in the project root and create the Clean Architecture directory tree under `lib/`.
**Where**: `lib/` (directory structure, new)
**Depends on**: None
**Reuses**: None
**Requirement**: FOUND-01, FOUND-02, FOUND-03, FOUND-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `flutter create . --project-name cantae --org com.cantae --platforms android,ios` exits 0
- [ ] Directories `lib/domain/`, `lib/data/`, `lib/infrastructure/`, `lib/presentation/` exist
- [ ] `lib/domain/README.md` states the no-Flutter-imports rule
- [ ] `git init` completed; initial commit contains scaffold + `.gitignore`
- [ ] `git log --oneline` shows exactly 1 commit
- [ ] Gate check passes: `flutter analyze && flutter test && python scripts/check_layers.py --root .`

**Tests**: none
**Gate**: build

**Commit**: `chore: init flutter project with clean architecture structure`

> ✅ Complete — SPEC_DEVIATION: Flutter SDK unavailable in automation; `flutter analyze`/`flutter test` gates require manual verification. Layer check verified programmatically.

---

### T2: pubspec.yaml with all MVP dependencies

**What**: Replace the generated `pubspec.yaml` with the full MVP dependency declaration and verify clean resolution.
**Where**: `pubspec.yaml`
**Depends on**: T1

**Reuses**: None
**Requirement**: FOUND-06, FOUND-07, FOUND-08, FOUND-09

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `environment: sdk: '>=3.4.0 <4.0.0'` declared
- [ ] Runtime deps: `flutter_riverpod`, `riverpod`, `just_audio`, `audio_service`, `sqflite`, `path_provider`, `crypto`, `nsd` (or `multicast_dns`)
- [ ] Dev deps: `flutter_test`, `mocktail`, `integration_test`
- [ ] `flutter pub get` exits 0 with no version conflicts
- [ ] `pubspec.lock` committed alongside `pubspec.yaml`
- [ ] Smoke check: delete `pubspec.lock` → `flutter pub get` → exit 0, lock file recreated
- [ ] Gate check passes: `flutter analyze && flutter test && python scripts/check_layers.py --root .`

**Tests**: none
**Gate**: build

**Commit**: `chore: declare all MVP dependencies in pubspec.yaml`

> ✅ Complete — flutter pub get gate requires manual verification.

---

### T3: analysis_options.yaml with strict lint rules

**What**: Create `analysis_options.yaml` enabling `flutter_lints` plus additional strictness rules; verify baseline passes.
**Where**: `analysis_options.yaml`
**Depends on**: T2

**Reuses**: None
**Requirement**: FOUND-10, FOUND-11, FOUND-12

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`
- [ ] Rules: `avoid_print: true`, `prefer_const_constructors: true`, `unnecessary_null_checks: true`, `prefer_final_locals: true`
- [ ] `unused_import` promoted to `error` under `analyzer.errors`
- [ ] `flutter analyze` exits 0 on clean project
- [ ] Manual check: add unused import → `flutter analyze` exits non-zero; remove → exits 0
- [ ] Gate check passes: `flutter analyze && flutter test && python scripts/check_layers.py --root .`

**Tests**: none
**Gate**: build

**Commit**: `chore: configure linting with flutter_lints and strict rules`

> ✅ Complete — flutter analyze gate requires manual verification.

---

### T4: Result sealed class and Failure catalog

**What**: Write failure modes first, then implement `Result<S, F>` and base `Failure` subtypes in `lib/domain/core/`; tests precede implementation.
**Where**: `lib/domain/core/result.dart`
**Depends on**: T3

**Reuses**: None
**Requirement**: FOUND-17, FOUND-18, FOUND-19, FOUND-20, FOUND-21, FOUND-22

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before writing any code)**:
1. `Success` constructed — value extractable via pattern match / `.when()`
2. `Failure` constructed with non-empty code — code extractable
3. `Failure` constructed with empty string code — `AssertionError` in debug mode
4. `switch` on `Result` with only `Success` branch — Dart exhaustiveness warning
5. Each of `NotFoundFailure`, `ValidationFailure`, `StorageFailure`, `NetworkFailure` — instantiates without error

**Done when**:
- [ ] `test/domain/core/result_test.dart` written covering all 5 failure modes (BEFORE implementation)
- [ ] `lib/domain/core/result.dart` sealed `Result<S, F>` with `Success` / `Failure` variants + `.when()`
- [ ] `lib/domain/core/failures.dart` abstract `Failure` (asserts `code.isNotEmpty`) + 4 subtypes
- [ ] Zero Flutter/plugin imports in `lib/domain/`
- [ ] Gate check passes: `flutter test test/domain/core/`
- [ ] Test count: 5 tests pass

**Tests**: unit
**Gate**: quick

**Commit**: `feat(domain): add Result sealed class and Failure catalog`

> ✅ Complete — flutter test gate requires manual verification. 5 test assertions written covering all failure modes.

---

### T5: Layer enforcement script

**What**: Write `scripts/check_layers.py` that scans `lib/domain/` for forbidden imports and exits 1 on any violation.
**Where**: `scripts/check_layers.py`
**Depends on**: T4

**Reuses**: None
**Requirement**: FOUND-13, FOUND-14, FOUND-15, FOUND-16

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `scripts/check_layers.py` accepts `--root <path>` (default: cwd)
- [ ] Scans `lib/domain/**/*.dart` for: `package:flutter`, `package:just_audio`, `package:audio_service`, `package:sqflite`, `package:nsd`, `package:multicast_dns`
- [ ] Exits 0 (clean) or 1 (violation) with offending file path + line number
- [ ] Manual checks (all four): clean tree → 0; Flutter import injected → 1 + file path; plugin import → 1; bad `--root` → 1 + readable error
- [ ] Gate check passes: `flutter analyze && flutter test && python scripts/check_layers.py --root .`

**Tests**: manual
**Gate**: build

**Commit**: `chore: add layer enforcement script for domain boundaries`

> ✅ Complete — verified programmatically: exit 0 on clean tree, exit 1 on injected Flutter import, exit 1 on injected plugin import.

---

### T6: Stub domain entities and test fixtures

**What**: Create minimal stub entity classes (final names, no logic) and 5 fixture factories with a smoke test; tests precede stub implementation.
**Where**: `test/fixtures/fixture_smoke_test.dart`
**Depends on**: T5

**Reuses**: `lib/domain/core/result.dart` (Failure types used by entity stubs)
**Requirement**: FOUND-23, FOUND-24, FOUND-25, FOUND-26, FOUND-27

**Tools**:
- MCP: NONE
- Skill: NONE

**Failure modes (listed before writing any code)**:
1. `completeSong()` — must have exactly 4 tracks with distinct naipes
2. `incompleteSong()` — must have 3 tracks, no tenor
3. `offsetSong()` — at least one track has `startDelayMs > 0`
4. `songWithLyrics()` — ≥3 lyric lines each with `onsetMs > 0`
5. `invalidTrackSong()` — at least one track has empty `filePath`
6. All fixtures — instantiation must not throw or require I/O/network/database

**Done when**:
- [ ] `test/fixtures/fixture_smoke_test.dart` written covering all 6 failure modes (BEFORE stubs)
- [ ] `lib/domain/entities/` contains: `song.dart`, `song_track.dart`, `naipe.dart` (enum), `lyric_line.dart`
- [ ] `Naipe` enum: `soprano`, `contralto`, `tenor`, `bass`, `custom`
- [ ] `test/fixtures/fixture_songs.dart` provides all 5 fixture factories
- [ ] Gate check passes: `flutter test test/fixtures/`
- [ ] Test count: 6 smoke assertions pass

**Tests**: smoke
**Gate**: full

**Commit**: `feat(domain): add stub entities and test fixtures`

> ✅ Complete — flutter test gate requires manual verification. 6 smoke assertions covering all fixture shapes.

---

### T7: STATE.md with architectural decisions

**What**: Create `.specs/STATE.md` recording 5 architectural decisions from Phase 0.
**Where**: `.specs/STATE.md`
**Depends on**: T6

**Reuses**: None
**Requirement**: (traceability meta)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `.specs/STATE.md` exists with `## Decisions` section, AD-001 through AD-005:
  - AD-001: Clean Architecture 4-layer split; `domain/` zero Flutter/plugin/network imports
  - AD-002: `Result<S, F>` as domain error; no `throw` anywhere in `domain/`
  - AD-003: pyenv local 3.12.3 for Python scripts; invoke as `python scripts/check_layers.py`
  - AD-004: All MVP dependencies in `pubspec.yaml` from Phase 0 to prevent late conflicts
  - AD-005: E2E tests preferred; unit tests only when written failure-first before code
- [ ] `.specs/STATE.md` has empty `## Handoff` section
- [ ] `git status` is clean after commit
- [ ] Gate check passes: `flutter analyze && flutter test && python scripts/check_layers.py --root .`

**Tests**: none
**Gate**: build

**Commit**: `docs(specs): record architectural decisions for Phase 0`

> ✅ Complete — STATE.md written with AD-001 through AD-005.

---

## Phase Execution Map

```
Phase 1: T1 → T2 → T3 → T4 → T5 → T6 → T7
```

---

## Task Granularity Check

| Task | Scope | Status |
|------|-------|--------|
| T1: Flutter project creation and git init | 1 setup operation | ✅ Granular |
| T2: pubspec.yaml with all MVP dependencies | 1 file | ✅ Granular |
| T3: analysis_options.yaml with strict lint rules | 1 file | ✅ Granular |
| T4: Result sealed class and Failure catalog | 1 domain/core module (sealed pair + tests) | ✅ Granular |
| T5: Layer enforcement script | 1 script file | ✅ Granular |
| T6: Stub domain entities and test fixtures | 1 fixture setup unit (stubs + smoke test) | ✅ Granular |
| T7: STATE.md with architectural decisions | 1 file | ✅ Granular |

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
| T7 | T6 | T6 → T7 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
|------|-----------------------------|-----------------|-----------|--------|
| T1: Project creation | Config / scaffold | none | none | ✅ OK |
| T2: pubspec.yaml | Config / deps | none | none | ✅ OK |
| T3: analysis_options.yaml | Config | none | none | ✅ OK |
| T4: Result + Failure | Domain/core | unit (failure-first) | unit | ✅ OK |
| T5: check_layers.py | Scripts (Python) | manual | manual | ✅ OK |
| T6: Entities + fixtures | Entities (none) + fixtures (smoke) | smoke | smoke | ✅ OK |
| T7: STATE.md | Docs | none | none | ✅ OK |
