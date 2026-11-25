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

### AD-009 — `drift` as the local database ORM, with additive-only migrations
**Decision:** The project uses `drift` (not raw `sqflite`) for all local persistence. Tables are declared as Dart `Table` classes under `lib/infrastructure/database/tables/`; the generated database class lives in `lib/infrastructure/database/app_database.dart` (`part 'app_database.g.dart'`, built via `build_runner`). Schema evolution uses drift's `MigrationStrategy` with a hand-written `onUpgrade: (Migrator m, int from, int to)` callback that calls `Migrator.addColumn`/etc. directly, versioned by `from` — each step is additive only (new tables/columns), never edits a prior step.
**Rationale:** Superseded the original raw-`sqflite` plan (see AD-004 amendment) after comparing both: `drift` gives compile-time-checked queries, generated row classes, reactive `watch()` streams (useful for the Phase 5 library UI), and built-in, testable migration tooling (`verifySelf`) — all of which a hand-rolled `Map<String, Object?>` mapper + SQL-string migration list would have to rebuild manually. The trade-off (an extra `build_runner` codegen step) was judged worth it before any schema code existed.
**Amended (library-screen feature, first real migration):** The originally-planned `stepByStep(from1To2: ...)` free-function helper no longer exists as a hand-callable API in the installed drift version (`2.35.x`) — it is now generated-only (`VersionedSchema.stepByStepHelper`), requiring a `drift_dev schema generate` snapshot-export workflow this project has never adopted. `Migrator.addColumn` called directly inside a plain `onUpgrade` callback is the stable, non-deprecated equivalent and is what's actually implemented in `app_database.dart`. The additive-only guarantee is unchanged; only the specific API name is corrected here to match reality.

---

### AD-010 — `NativeDatabase.memory()` for repository-layer tests
**Decision:** Repository implementations that use `drift` are tested under plain `flutter test` by constructing the generated database with `NativeDatabase.memory()` (from `drift/native.dart`), not mocked and not deferred to integration tests.
**Rationale:** Unlike raw `sqflite`, `drift`'s native/FFI backend runs an in-memory SQLite instance with no platform channel, so real SQL (real constraint/cascade/transaction behavior) is exercised at unit-test speed — consistent with the project's failure-first isolation-testing rule (AD-005). No `sqflite_common_ffi` dependency is needed.

---

### AD-011 — `cryptography` package added for X25519 ECDH + HKDF handshake
**Decision:** The project adds the `cryptography` pub package (pure Dart, no platform channel) as a runtime dependency, used only inside `lib/domain/session/` for the ephemeral X25519 key exchange and HKDF-SHA256 session-key derivation in the Session & Networking feature. HMAC-SHA-256 for envelope authentication continues to use the already-declared `crypto` package — `cryptography` is not a replacement for it, only an addition for the asymmetric/KDF primitives `crypto` doesn't provide.
**Enforced by:** `check_layers.py` (domain-purity rule, AD-001) — `cryptography` has no Flutter/plugin/`dart:io` surface, so importing it in `domain/` does not trip the layer-purity check.
**Rationale:** Amends AD-004's "all MVP dependencies declared in `pubspec.yaml` from Phase 0" — this need was not foreseen when that list was written, the same way AD-009 amended it for `drift`. Confirmed with the user during Session & Networking's Discuss step (ECDH X25519 ephemeral handshake chosen over a PSK derived from the 4-digit code).

---

### AD-012 — `go_router` adopted as the project's router, named routes only
**Decision:** `go_router` (`^18.1.4`) is the project's router from the `library-screen` feature onward. One `GoRouter` instance, exposed via a Riverpod `Provider<GoRouter>` (`routerProvider`), created once and never rebuilt per navigation. Routes are always named (`context.goNamed(...)`), never raw path strings. `main.dart`'s `MaterialApp` becomes `MaterialApp.router`.
**Rationale:** The project's own `flutter-routing` skill already documented this exact shape before any screen existed to use it; adopting it now (at the first screen) avoids re-plumbing navigation when the second screen lands. Room-code "deep links" are a 4-digit code typed by the user, not a URL scheme, so no `app_links`/platform-channel URI handling is added alongside this.

---

## Handoff

Phase 5 (UI): **theme-tokens**, **library-screen**, **song-detail-screen**, **track-align-screen** and **lyrics-editor** are merged to `develop`, which is pushed to `origin` up to `0b4cad4`. **solo-player** (Modo solo) is complete and verified on branch `feature/phase-5-solo-player` (not yet merged). Project follows **Gitflow**.

- **solo-player scope:** 12 tasks (T1–T12) plus fix F1, executed inline in sequence (user: "seguir com as tarefas em sequência realizando os commits").
  - **Domain:** new `LyricCursor`.
  - **Audio engine:**
    - `setTrackVolume` added; the 5 test fakes are updated.
    - Fix: the timeline position now follows the track that ends last, not `tracks.first`. This affects room playback too.
  - **New shared widgets** (all in `COMPONENTS.md`):
    - `MuteSoloToggle` (extracted from `TrackAlignRow`, now with toggled semantics);
    - `TonalButton`;
    - `StatusPill` (neutral variant only);
    - `PlaybackProgress`;
    - `LyricView`;
    - `MixTrackRow`;
    - helper `naipe_labels.dart`.
  - **Screen and route:** `SoloPlayerNotifier` and `SoloPlayerScreen` (UI_SPEC §6.12 rewritten); route `/solo-player/:id` from "Ensaiar só".
- **User decisions:**
  - metronome and background/lock-screen playback are separate features;
  - the loop is marked with start and end during playback;
  - the mix has volume + M + S per track and lasts the session only.
- **Verifier:** standalone fallback by the author (sub-agent blocked by auto mode, `context-mode` plugin).
  - Iteration 1: 24/25 mutants killed; S9 (loop end while paused) survived.
  - Iteration 2 after F1: 25/25, 644 tests, gate clean.
  - Lesson L-018 recorded as a candidate.
  - Report: `.specs/features/solo-player/validation.md`.
- **Known debt:**
  - no l10n (inline pt-BR strings);
  - naipe name/selo mapping still duplicated privately in `TrackAlignRow`, `LyricLineRow` and `SongRow`;
  - wall-clock flaky tests (`chunked_file_receiver_test`, `song_sync_coordinator_test`, `playback_command_handler_test`).
- **Not verified on a device:** the last position may stop a few ms short of `durationMs` on real hardware (design Risks row 2). Check it in the background-playback feature.

**Next:** merging `feature/phase-5-solo-player` into `develop` needs the user's go-ahead. Candidate next features: **Metrônomo solo (RF54)**, **background playback for Modo solo (RF24)**, **Ensaios anteriores**, **Enviar faixa**, **Studio**.
