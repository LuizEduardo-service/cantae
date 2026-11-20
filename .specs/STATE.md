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

Phase 5 (UI): **theme-tokens** and **library-screen** are merged to `develop`. **song-detail-screen** (the Detalhe da música hub) is complete and verified, on branch `feature/phase-5-song-detail-screen` (not yet merged to `develop`), HEAD `18d79d0`. Project follows **Gitflow**: `develop` is integration, `master` only receives `release/*`/`hotfix/*`.
- `song-detail-screen`: 5 tasks (T1-T5), single batch, executed inline (no sub-agent delegation needed). Adds `DestructiveButton` (tonal/solid, in `buttons.dart`), `ConfirmSheet` (new, 1-/2-step + typed-confirmation gating), `songByIdProvider` (new, returns the repository's `Result` unchanged rather than throwing — "not found" and "other failure" stay distinct business-state branches), `SongDetailScreen` (new — header, 4-naipe group, "Preparar" links, rodapé, read-only mode for `origin == received`, the delete flow), and 6 new `go_router` placeholder routes (`solo-player`, `studio`, `track-align`, `lyrics-editor`, `song-history`, `track-upload`) plus `song-detail` now resolving to the real screen. No domain/schema changes (duration and rehearsal-count were explicitly kept out of scope per user decision).
- Verifier: **2 iterations**. Iteration 1 FAIL — 20/23 ACs covered, but DETAIL-12/13 ("Ensaiar em grupo") had zero direct test evidence (evidence-or-zero gap), plus 2 minor gaps (3 of 4 "Preparar" rows individually untested; a `tracks: []` edge case untested). Fixed with a test-only follow-up commit (no production code changed). Iteration 2 PASS — 23/23 ACs matched spec outcome, 414/414 tests (up from 410 at T5's close), 3/3 discrimination-sensor mutations killed (carried over from iteration 1 since the fix touched no `lib/` file), gate clean (`flutter analyze` 0 issues, `check_layers.py` + `dart analyze lib/domain/` clean).
- Report: `.specs/features/song-detail-screen/validation.md`.
- Documented scope calls the Verifier reviewed and accepted: naipe-name/`VoicePart` mapping duplicated from `song_row.dart` (4-case switch, low churn risk); section headers ("Naipes"/"Preparar") and "Preparar" rows built as small private widgets instead of new shared `SectionLabel`/`GroupedList`/`ListRow` components (not in design.md's Components list for this feature); `ConfirmSheet`'s 2-step + typed-confirmation path built and tested even though this feature's own screen only calls `steps: 1` (future "apagar todos os dados" flow).
- 2 new candidate lessons recorded (L-013 ac_gap, L-014 spec_precision_gap) — both about the evidence-or-zero gap pattern (implemented-but-untested navigation actions). Not yet promoted (needs a second corroborating feature).
- `lib/presentation/` gains `screens/song_detail/` (1 file) and 2 new widgets (`confirm_sheet.dart`, `DestructiveButton` inside the existing `buttons.dart`) plus `providers/song_detail_providers.dart`. No new dependencies.
- Not yet done, deliberately out of scope: visually running the app on a device/emulator (only automated widget tests ran this session, same gap as prior UI features); the Studio/Alinhamento/Letra/Histórico/Modo-solo/Enviar-faixa screens themselves (all still `ComingSoonScreen` placeholders).

**Next:** Merge `feature/phase-5-song-detail-screen` → `develop` needs explicit go-ahead (Gitflow convention). After that, per `docs/prd-cantae-ux-telas.md` §5's nav map, the next candidate screen is one of the Detalhe da música's own "em breve" targets (**Alinhamento de faixas**, **Letra sincronizada**, or **Modo solo**), or the **Studio** (corte de áudio) feature, eligible since Phase 2, if UI is deprioritized.
