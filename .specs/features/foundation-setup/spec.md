# Foundation Setup Specification

## Problem Statement

The Cantaê project directory contains only documentation. Without an established architectural skeleton, every subsequent phase risks introducing silent layer-dependency violations, inconsistent error handling, and test fixtures that don't match the domain model. This spec defines the structural, tooling, and pattern foundation that all later phases depend on.

## Goals

- [ ] Flutter project created with enforced Clean Architecture layer structure (presentation, domain, data, infrastructure)
- [ ] Domain layer compiles with zero Flutter or plugin imports — violation fails CI
- [ ] `Result<S, F>` error pattern available in domain/core with typed Failure catalog
- [ ] Linting and static analysis configured with zero warnings on a clean project
- [ ] All planned MVP dependencies declared and resolved in pubspec.yaml
- [ ] Five reusable test fixtures cover the core song/track/lyrics shapes used in domain tests

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Any domain business logic (mix, loop, sync) | Phase 1 |
| SQLite schema or repository implementations | Phase 2 |
| Networking, mDNS, or TCP code | Phase 3 |
| Audio engine or player wiring | Phase 4 |
| UI widgets or screens | Phase 5 |
| CI pipeline (GitHub Actions / Fastlane) | Phase 6 |
| Freezed or build_runner codegen setup | Not needed for sealed Result class |

---

## Assumptions & Open Questions

Every ambiguity is resolved or recorded here — nothing is left silently unclear.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|-----------------------|----------------|-----------|------------|
| Minimum Flutter SDK version | Flutter 3.22+ / Dart 3.4+ | Required by just_audio ≥0.9 and audio_service ≥0.18; implies Android API 26+/iOS 14+ | y |
| All phase dependencies in pubspec.yaml from day 0 vs. lazy | All declared now | Prevents version conflicts discovered late; lock file generated once | y |
| Layer enforcement mechanism | Python script checked in CI + `analysis_options.yaml` import rules | Dart lint rules can't enforce cross-package import constraints expressively enough | y |
| `freezed` for Result type | No — manual sealed class | `freezed` requires codegen; a 2-variant sealed class is simpler and sufficient | y |
| `Result` failure variant carries exception vs. typed Failure | Typed `Failure` subclass only | Exceptions are infrastructure concerns; domain should never expose stack traces | y |
| git initialization | Initialize in T1 alongside project creation | Atomic commits per task require git; .specs/ is versioned | y |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Flutter Project Structure ⭐ MVP

**User Story**: As a developer joining the project, I want a Flutter project with explicit Clean Architecture folders so that I can place new code in the right layer without guessing.

**Why P1**: Every subsequent phase adds files to one of the four layers; without the structure, files end up wherever is convenient.

**Acceptance Criteria** (FOUND-01 through FOUND-05):

1. WHEN `flutter create` completes THEN the system SHALL produce a runnable app with directories `lib/domain/`, `lib/data/`, `lib/infrastructure/`, and `lib/presentation/` present. <!-- FOUND-01, ubiquitous -->
2. The system SHALL include a `lib/domain/README.md` stating "No Flutter, plugin, or network imports allowed." <!-- FOUND-02, ubiquitous -->
3. WHEN `flutter run` is executed on a connected device THEN the system SHALL launch without runtime errors on the default counter scaffold. <!-- FOUND-03, event-driven -->
4. The system SHALL have `git init` completed with an initial commit containing only the project scaffold and `.gitignore`. <!-- FOUND-04, ubiquitous -->

**Independent Test**: Run `flutter run` on device/emulator — app opens. `git log --oneline` shows exactly one commit.

---

### P1: Dependency Declaration ⭐ MVP

**User Story**: As a developer, I want all planned MVP dependencies declared and resolved in `pubspec.yaml` so that version conflicts are discovered now, not mid-phase.

**Why P1**: Late dependency additions risk breaking the existing lock file and delaying a phase.

**Acceptance Criteria** (FOUND-06 through FOUND-09):

5. WHEN `flutter pub get` runs on a clean cache THEN the system SHALL resolve all dependencies with exit code 0 and no version conflicts. <!-- FOUND-06, event-driven -->
6. The system SHALL declare (at minimum): `flutter_riverpod`, `riverpod`, `just_audio`, `audio_service`, `sqflite`, `path_provider`, `crypto`, `nsd` or `multicast_dns`. <!-- FOUND-07, ubiquitous -->
7. The system SHALL declare dev dependencies: `flutter_test`, `mocktail`, `integration_test`. <!-- FOUND-08, ubiquitous -->
8. IF `pubspec.lock` is absent THEN the system SHALL regenerate it deterministically from `pubspec.yaml` with no manual steps. <!-- FOUND-09, unwanted-behavior -->

**Independent Test**: Delete `pubspec.lock`, run `flutter pub get`, verify exit 0 and lock file recreated.

---

### P1: Linting & Static Analysis ⭐ MVP

**User Story**: As a developer, I want `flutter analyze` to pass with zero issues on a fresh project so that every future addition starts from a clean baseline.

**Why P1**: A lint baseline established at project start prevents accumulated warnings becoming technical debt.

**Acceptance Criteria** (FOUND-10 through FOUND-12):

9. WHEN `flutter analyze` runs on the project THEN the system SHALL exit 0 with zero issues. <!-- FOUND-10, event-driven -->
10. The system SHALL have `analysis_options.yaml` that enables `flutter_lints` and adds rules: `avoid_print: true`, `prefer_const_constructors: true`, `unnecessary_null_checks: true`. <!-- FOUND-11, ubiquitous -->
11. IF a Dart file contains an unused import THEN `flutter analyze` SHALL report it as an error (not a warning). <!-- FOUND-12, unwanted-behavior -->

**Independent Test**: Add `import 'dart:io';` unused to any file — `flutter analyze` exits non-zero.

---

### P1: Layer Enforcement ⭐ MVP

**User Story**: As a developer, I want a check that fails if any file inside `lib/domain/` imports Flutter or a plugin so that architectural boundaries are enforced automatically.

**Why P1**: Without enforcement, a single convenience import silently couples domain logic to the framework.

**Acceptance Criteria** (FOUND-13 through FOUND-16):

12. WHEN the layer-check script runs on a clean project THEN the system SHALL exit 0. <!-- FOUND-13, event-driven -->
13. IF a file in `lib/domain/` contains `import 'package:flutter` THEN the layer-check script SHALL exit non-zero and print the offending file path and line number. <!-- FOUND-14, unwanted-behavior -->
14. IF a file in `lib/domain/` contains `import 'package:just_audio` or any other plugin package THEN the layer-check script SHALL exit non-zero. <!-- FOUND-15, unwanted-behavior -->
15. The system SHALL include a `scripts/check_layers.py` that can be invoked as `python3 scripts/check_layers.py --root <project_root>` with exit code 0 (clean) or 1 (violation). <!-- FOUND-16, ubiquitous -->

**Independent Test**: Add `import 'package:flutter/material.dart';` to `lib/domain/core/result.dart` — script exits 1 with the file name printed. Remove it — script exits 0.

---

### P1: Result Pattern ⭐ MVP

**User Story**: As a domain developer, I want a `Result<S, F>` sealed class with typed `Failure` subclasses so that domain functions return errors as values, never exceptions.

**Why P1**: Every domain function from Phase 1 onward returns `Result`; the type must exist and be stable before any domain code is written.

**Acceptance Criteria** (FOUND-17 through FOUND-22):

16. The system SHALL provide `lib/domain/core/result.dart` with a sealed class `Result<S, F extends Failure>` having exactly two subtypes: `Success<S, F>` and `Failure<S, F>` (or equivalent `Ok`/`Err` naming). <!-- FOUND-17, ubiquitous -->
17. WHEN `Result.success(value)` is constructed THEN the system SHALL allow pattern-matching via `switch` or `.when()` to extract the success value. <!-- FOUND-18, event-driven -->
18. WHEN `Result.failure(failure)` is constructed THEN the system SHALL carry a `Failure` subclass with a non-empty `code` String field. <!-- FOUND-19, event-driven -->
19. IF `Failure.code` is constructed as an empty string THEN the system SHALL throw an `AssertionError` in debug mode. <!-- FOUND-20, unwanted-behavior -->
20. The system SHALL provide `lib/domain/core/failures.dart` with at least these base subtypes: `ValidationFailure`, `NotFoundFailure`, `StorageFailure`, `NetworkFailure`. <!-- FOUND-21, ubiquitous -->
21. The system SHALL have zero `throw` statements in any file under `lib/domain/`. <!-- FOUND-22, ubiquitous -->

**Independent Test**: Write a function that returns `Result.failure(NotFoundFailure(code: 'song.not_found'))`, pattern-match it, assert `failure.code == 'song.not_found'`. Test passes.

---

### P1: Test Fixtures ⭐ MVP

**User Story**: As a domain test author, I want five pre-built fixture objects covering the main song/track shapes so that I don't re-declare them in every test file.

**Why P1**: Fixtures are used starting in Phase 1; without them, every domain test author duplicates setup code inconsistently.

**Acceptance Criteria** (FOUND-23 through FOUND-27):

22. The system SHALL provide `test/fixtures/` with a `FixtureSongs` class (or top-level functions) returning five fixtures: `completeSong` (4 tracks, one per standard naipe), `incompleteSong` (missing tenor track), `offsetSong` (tracks with non-zero `startDelayMs`), `songWithLyrics` (≥3 lyric lines with onset timestamps), `invalidTrackSong` (one track with null/empty file path). <!-- FOUND-23, ubiquitous -->
23. WHEN any fixture is instantiated in a test THEN the system SHALL not require file I/O, network access, or a database connection. <!-- FOUND-24, event-driven -->
24. The system SHALL have all fixture entities defined using the same `Song`, `SongTrack`, `Naipe`, and `LyricLine` domain entity classes that Phase 1 will use. <!-- FOUND-25, ubiquitous -->
25. IF a fixture field is updated to reflect a domain entity change THEN `flutter test test/fixtures/` SHALL continue to pass with no other changes. <!-- FOUND-26, unwanted-behavior -->
26. WHEN `flutter test test/fixtures/fixture_smoke_test.dart` runs THEN the system SHALL pass with all 5 fixtures instantiated and their key fields asserted. <!-- FOUND-27, event-driven -->

**Independent Test**: Run `flutter test test/fixtures/fixture_smoke_test.dart` — all assertions pass, no exceptions.

---

## Edge Cases

- IF `flutter create` is run in a non-empty directory THEN the agent SHALL abort and report the conflict rather than overwriting existing files.
- IF `pubspec.yaml` declares two packages with incompatible version constraints THEN `flutter pub get` SHALL fail with a clear error (not silently degrade).
- IF the layer-check script is run on a path that does not exist THEN it SHALL exit non-zero with a human-readable error message.
- WHEN `Result.failure` is pattern-matched in a `switch` THEN the Dart compiler SHALL produce an exhaustiveness warning if the `Success` branch is unhandled.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|----------------|-------|-------|--------|
| FOUND-01 | P1: Project Structure | Tasks | Pending |
| FOUND-02 | P1: Project Structure | Tasks | Pending |
| FOUND-03 | P1: Project Structure | Tasks | Pending |
| FOUND-04 | P1: Project Structure | Tasks | Pending |
| FOUND-05 | P1: Project Structure | Tasks | Pending |
| FOUND-06 | P1: Dependency Declaration | Tasks | Pending |
| FOUND-07 | P1: Dependency Declaration | Tasks | Pending |
| FOUND-08 | P1: Dependency Declaration | Tasks | Pending |
| FOUND-09 | P1: Dependency Declaration | Tasks | Pending |
| FOUND-10 | P1: Linting | Tasks | Pending |
| FOUND-11 | P1: Linting | Tasks | Pending |
| FOUND-12 | P1: Linting | Tasks | Pending |
| FOUND-13 | P1: Layer Enforcement | Tasks | Pending |
| FOUND-14 | P1: Layer Enforcement | Tasks | Pending |
| FOUND-15 | P1: Layer Enforcement | Tasks | Pending |
| FOUND-16 | P1: Layer Enforcement | Tasks | Pending |
| FOUND-17 | P1: Result Pattern | Tasks | Pending |
| FOUND-18 | P1: Result Pattern | Tasks | Pending |
| FOUND-19 | P1: Result Pattern | Tasks | Pending |
| FOUND-20 | P1: Result Pattern | Tasks | Pending |
| FOUND-21 | P1: Result Pattern | Tasks | Pending |
| FOUND-22 | P1: Result Pattern | Tasks | Pending |
| FOUND-23 | P1: Test Fixtures | Tasks | Pending |
| FOUND-24 | P1: Test Fixtures | Tasks | Pending |
| FOUND-25 | P1: Test Fixtures | Tasks | Pending |
| FOUND-26 | P1: Test Fixtures | Tasks | Pending |
| FOUND-27 | P1: Test Fixtures | Tasks | Pending |

**Coverage:** 27 total, 0 mapped to tasks ⚠️ (tasks.md pending)

---

## Success Criteria

- [ ] `flutter analyze` exits 0 with zero issues on the new project
- [ ] `flutter test test/fixtures/fixture_smoke_test.dart` passes
- [ ] `python3 scripts/check_layers.py` exits 0 on clean project; exits 1 when a domain file imports Flutter
- [ ] `flutter pub get` resolves all dependencies on a clean cache
- [ ] `Result.failure(NotFoundFailure(code: 'x'))` compiles, pattern-matches, and asserts correctly in a test
