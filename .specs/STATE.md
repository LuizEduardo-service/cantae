# Cantaê — Project State

## Decisions

### AD-001 — Clean Architecture 4-layer split with domain purity rule
**Decision:** The project is structured as four strict layers: `presentation/`, `domain/`, `data/`, `infrastructure/`. The `domain/` layer must have zero imports of `package:flutter`, any plugin, or any network library.
**Enforced by:** `scripts/check_layers.py --root .` — exits 1 on any violation.
**Rationale:** Domain logic must be independently testable without the Flutter SDK. This is the core architectural invariant that makes the audio business rules portable and verifiable.

---

### AD-002 — Result<S, F> as domain error pattern; no throw in domain
**Decision:** All domain functions return `Result<S, F extends Failure>`. No `throw` statements anywhere under `lib/domain/`. Failures carry a typed `Failure` subclass with a non-empty `code` string.
**Rationale:** Exceptions cross layer boundaries invisibly. `Result` makes error paths explicit in the type system, forcing callers to handle failures at compile time.

---

### AD-003 — pyenv local 3.12.3 for Python scripts
**Decision:** The project pins Python 3.12.3 via `.python-version`. All Python scripts (layer check, spec validation) are invoked as `python scripts/check_layers.py` from the project root.
**Rationale:** Consistent Python version prevents `pyenv: no version set` errors across environments.

---

### AD-004 — All MVP dependencies declared in pubspec.yaml from Phase 0
**Decision:** `pubspec.yaml` declares all runtime and dev dependencies from Phase 0, including dependencies not used until Phase 4 (`just_audio`, `audio_service`, `nsd`).
**Rationale:** Late dependency additions risk version conflicts after the lock file is established. Declaring everything up front catches incompatibilities early, when they're cheap to fix.
**Amended (Phase 2):** `sqflite` was replaced by `drift` + `sqlite3_flutter_libs` (runtime) and `drift_dev` + `build_runner` (dev) — see AD-009/AD-010. The "declare up front" principle still holds; the local-database package choice changed before any schema code was written.

---

### AD-005 — E2E tests preferred; unit tests only failure-first before code
**Decision:** E2E tests are the primary verification mechanism. Unit tests are only written when testing a system in isolation, and only when: (1) failure modes are listed first, (2) tests are written before the implementation.
**Rationale:** Post-hoc unit tests are low-signal — they describe existing behavior rather than guarding against regressions that E2E tests would catch. Failure-first isolation tests prevent testing the wrong thing.

---

### AD-006 — const constructors on all domain entities
**Decision:** All domain entity constructors are `const`. Assert conditions use `field.length > 0` (integer comparison) rather than `field.isNotEmpty` for compile-time const compatibility.
**Rationale:** `const` entities allow fixtures and tests to be evaluated at compile time, and is required for the `prefer_const_constructors` lint rule to pass. Tests that intentionally trigger invalid-input asserts omit `const` and add `// ignore: prefer_const_constructors`.

---

### AD-007 — Flutter SDK path: D:\flutter\bin
**Decision:** Flutter SDK lives at `D:\flutter\bin` (user-level PATH, not system PATH). Automation shells must prepend this to PATH before invoking `flutter`.
**Rationale:** Flutter is installed under the user profile, not a system-wide location, so it is absent from the automation shell's inherited PATH.

---

### AD-008 — `Unit` type for void-like `Result` success values
**Decision:** `lib/domain/core/unit.dart` defines a single-value `Unit` type. Repository/use-case methods with nothing to return on success use `Result<Unit, F>` instead of `Result<void, F>`.
**Rationale:** `void` is not a usable generic type argument in the existing sealed `Result<S, F>` pattern; `Unit` is the smallest addition that fits it without changing `Result` itself.

---

### AD-009 — `drift` as the local database ORM, with `stepByStep` additive-only migrations
**Decision:** The project uses `drift` (not raw `sqflite`) for all local persistence. Tables are declared as Dart `Table` classes under `lib/infrastructure/database/tables/`; the generated database class lives in `lib/infrastructure/database/app_database.dart` (`part 'app_database.g.dart'`, built via `build_runner`). Schema evolution uses drift's `MigrationStrategy` with `stepByStep(from1To2: ..., from2To3: ...)` — each step is additive only (new tables/columns), never edits a prior step.
**Rationale:** Superseded the original raw-`sqflite` plan (see AD-004 amendment) after comparing both: `drift` gives compile-time-checked queries, generated row classes, reactive `watch()` streams (useful for the Phase 5 library UI), and built-in, testable migration tooling (`verifySelf`) — all of which a hand-rolled `Map<String, Object?>` mapper + SQL-string migration list would have to rebuild manually. The trade-off (an extra `build_runner` codegen step) was judged worth it before any schema code existed.

---

### AD-010 — `NativeDatabase.memory()` for repository-layer tests
**Decision:** Repository implementations that use `drift` are tested under plain `flutter test` by constructing the generated database with `NativeDatabase.memory()` (from `drift/native.dart`), not mocked and not deferred to integration tests.
**Rationale:** Unlike raw `sqflite`, `drift`'s native/FFI backend runs an in-memory SQLite instance with no platform channel, so real SQL (real constraint/cascade/transaction behavior) is exercised at unit-test speed — consistent with the project's failure-first isolation-testing rule (AD-005). No `sqflite_common_ffi` dependency is needed.

---

## Handoff

Phase 1 (Audio Domain) complete and verified on branch `feat/phase-1-audio-domain`.
- 72 domain tests passing (all of `test/domain/`)
- `flutter analyze`: 0 issues
- Layer purity: clean (`check_layers.py`)
- Verifier: PASS — 39/39 ACs, 4/4 mutations killed

**Next:** merge `feat/phase-1-audio-domain` → `develop`, then start Phase 2 (Local Persistence — SQLite schema, library repo, CRUD).
