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

### AD-013 — `file_picker` added for choosing audio files, behind a domain port
**Decision:** The project adds `file_picker` (`^13.4.1`) as a runtime dependency. It is used only in `lib/infrastructure/files/`, behind the domain port `TrackFilePicker`; screens and notifiers never import the plugin.
**Rationale:** Amends AD-004 the same way AD-009 and AD-011 did: creating a song (RF13) needs the system file chooser, which was not foreseen in the Phase 0 list. The user chose `file_picker` over writing a platform channel. The port keeps tests free of the plugin.

---

## Handoff

Phase 5 (UI): **theme-tokens**, **library-screen**, **song-detail-screen**, **track-align-screen**, **lyrics-editor**, **solo-player** and **solo-metronome** are merged to `develop`, pushed to `origin` up to `0487781`. **background-audio** (RF24) and **stabilize-flaky-tests** are merged to `develop` (pushed up to `dda2959`). **rehearsal-history** (Ensaios anteriores, RF39/RF40) is complete and verified on branch `feature/phase-5-rehearsal-history` (not yet merged).

- **rehearsal-history:** 8 tasks + 1 fix, executed inline in sequence.
  - Domain `RehearsalLog` + pure `RehearsalSessionTracker` (playing time only, loop jumps, 60 s minimum).
  - `rehearsal_logs` table (schema v4, FK cascade from songs), `DriftRehearsalRepository`, hand-rolled `uuidV4`.
  - App-scoped `RehearsalRecorder`: saves, marks the song rehearsed, refreshes the Library and the counts. `SoloPlayerNotifier` feeds it via a `state` setter override and records on dispose.
  - Ensaios screen (UI_SPEC §6.16) with `StatTile` (new `monoStat` token), route `/song-history/:id`, detail row "Ensaios anteriores (N)". A received song keeps that row in its own "Ensaios" section (PRD > UI_SPEC).
  - Verifier: author fallback; 19/19 requirements, 39/39 mutants (R8 re-run in generated code), 829 tests. Report: `.specs/features/rehearsal-history/validation.md`.
  - Bug found and fixed red-first: `StatTile` tiles merged into one screen-reader item inside a list item (`39541d9`).
  - Known limit: a rehearsal is lost if the OS kills the app before leaving Modo solo.

- **stabilize-flaky-tests:** the wall-clock "flaky" tests had four root causes; three were production bugs, each fixed with a red-first regression test:
  - `RoomSessionController.dispose()` left the transport subscriptions alive; late frames hit a closed stream (`a32a458`).
  - `TcpSessionTransport.close()/destroy()` kept reading the socket (`1f735b0`).
  - `PlaybackCommandHandler.dispose()` left scheduled Timers running: a handler that left the room still called `engine.playAt` (`ff34073`).
  - `ChunkedFileReceiver.receiveTrack` dropped messages that arrived during the dedup disk check, stalling the transfer (`c308cab`); the check is now injectable.
  - Test-only: two playback handler tests read the phase too early; they now await the published snapshot (`2931a81`, `02623a5`).
  - Evidence: before, 4 of 13 full runs failed; after, 15 of 15 passed (765 tests). Project follows **Gitflow**.

- **background-audio scope:** 9 tasks, executed inline in sequence.
  - **Engine:** `setDucked` (×0.5 on every track, click included); players built with `handleInterruptions: false` (`MultiTrackAudioEngine.defaultPlayer`).
  - **Contracts (domain):** `AudioInterruptions` (pause/duck/headphones) and `PlaybackRemote` (`NowPlaying` out, `RemoteCommand` in), each with a no-op default.
  - **Infrastructure:** `AudioSessionInterruptions`, `CantaeAudioHandler` (the single `audio_service` handler: title, "Modo solo", Tocar/Pausar + seek), `bootstrapBackgroundAudio` (session `.music()`, `AudioService.init`, never throws). `main.dart` runs it before `runApp`. iOS declares `UIBackgroundModes: audio`.
  - **Modo solo:** publishes on ready/play/pause/seek/loop jump/end; lock-screen commands run the in-app paths; stop and leaving clear the notification; interruptions and headphones pause all without auto-resume; duck lowers the volume; toast on return.
- **User decisions:** notification has Tocar/Pausar + the position bar; no device available now, so a device script and an integration test are delivered but not run.
- **Verifier:** standalone fallback by the author (sub-agent blocked by `context-mode`). 19/19 requirements, 34/34 mutants killed in iteration 1, 758 tests. Report: `.specs/features/background-audio/validation.md`.
- **Pending device run (BGA-17):** neither `docs/device-test-background-audio.md` nor `integration_test/background_audio_test.dart` has run on a device. They also cover the solo-metronome T1/T2 fixes, still unverified on a device. The Android 13+ notification permission exemption is an unconfirmed assumption (script step 2).
- **Known debt:**
  - two `audio_service` handlers in the code: only `CantaeAudioHandler` is registered; the phase-4 room `BackgroundAudioHandler` (used by its integration test) must fold into `PlaybackRemote` when the room screens land;
  - `handleInterruptions: false` is not observable under `flutter test`; only the device script (steps 8–9) guards it;
  - no l10n;
  - the naipe name/selo mapping is duplicated in `TrackAlignRow`, `LyricLineRow` and `SongRow`;
  - each `room_session_controller_test` test takes ~5 s when the file runs alone (also on `develop`; the join itself takes ~70 ms); cause not found, no failures.

**Next:** merging `feature/phase-5-rehearsal-history` into `develop` needs the user's go-ahead. Candidates after that:
- run the device script;
- **Enviar faixa**;
- **Studio**.
