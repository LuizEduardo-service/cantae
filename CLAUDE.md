# Cantaê — Project Guide for AI Agents

## What is Cantaê?

Flutter mobile app for vocal groups to rehearse together with synchronized, per-section audio tracks. **Local-first**: all data lives on-device; rehearsal sessions run peer-to-peer over local Wi-Fi with no cloud backend required.

**Platforms:** Android API 26+ (Android 8.0) / iOS 14+

---

## Tech Stack

| Concern | Library / Approach |
|---------|-------------------|
| Framework | Flutter / Dart |
| State & DI | Riverpod |
| Audio playback | `just_audio` (per-track) |
| Background audio | `audio_service` |
| Local database | `sqflite` (SQLite, additive-only migrations) |
| Network discovery | mDNS/Bonjour (`nsd` or `multicast_dns`) |
| Session transport | Authenticated TCP (HMAC-SHA-256 envelopes) |
| Secrets storage | Keystore (Android) / Keychain (iOS) |

---

## Architecture — Clean Architecture (4 Layers)

```
presentation/     → Flutter widgets, Riverpod providers, navigation
domain/           → Pure business logic. ZERO dependencies on Flutter, plugins, or network
data/             → Repository implementations, DTOs, mappers
infrastructure/   → SQLite, TCP, mDNS, filesystem, crypto, audio engine
```

**Hard rule:** `domain/` must compile with `dart compile` (no Flutter SDK). Any import of `package:flutter`, a plugin, or a network library inside `domain/` is a CI-blocking violation.

---

## Domain Error Handling

- Use `Result<S, F>` (sealed class with `Success` / `Failure` variants) throughout the domain.
- **No `throw` in domain code.** Exceptions are infrastructure concerns only.
- Every failure carries a typed `Failure` subclass with a non-empty `code` string.
- UI maps `Failure` codes to user-facing messages; the domain never knows about localization.

```dart
// Correct
Result<Song, SongFailure> loadSong(SongId id) { ... }

// Never in domain
Song loadSong(SongId id) throws SongNotFoundException { ... }
```

---

## Testing Rules

**These rules are non-negotiable. Read before writing any test.**

1. **Never write unit tests after writing code.** Tests written to describe code already written are low-signal and duplicate coverage without guarding against real regressions.

2. **Prefer E2E tests as the primary verification mechanism.** Use them to confirm complex features work end-to-end. Every E2E test must produce a verifiable, repeatable artifact (log, screenshot, assertion output) that can be reviewed without re-running the test.

3. **If you must test a system in isolation:** First write down every way it could fail (failure modes list), then write the code to handle those failures, then write the test that exercises them. Test-first for isolation, E2E-first for features.

---

## Code Conventions

- Cyclomatic complexity ≤ 15 per function (enforced by `analysis_options.yaml`).
- No N+1 queries — batch all library loads.
- Heavy operations (hashing, parsing, large file I/O) run off the UI thread (Isolates or `compute`).
- Commits follow **Conventional Commits**: `feat:`, `fix:`, `chore:`, `test:`, `refactor:`, `docs:`.
- One atomic commit per task. Never batch tasks into one commit.
- SOLID without speculation — no abstractions for hypothetical future use.

---

## Session Security Model

- Room discovery: mDNS/Bonjour (LAN only).
- Entry: 4-digit visual code (not authentication — just discovery).
- Authentication: ephemeral key handshake on join approval.
- All post-handshake messages: HMAC-SHA-256 + monotonic sequence + replay detection.
- Max 8 participants per room. Session TTL: 30 min inactivity.
- All audio and metadata stored in app sandbox only.

---

## Build Phases

| Phase | Scope |
|-------|-------|
| 0 | Foundation: project structure, CI, error handling, test fixtures |
| 1 | Audio domain: entities, mix calculator, loop controller, timeline |
| 2 | Local persistence: SQLite schema, library repo, CRUD |
| 3 | Session & networking: mDNS, state machine, handshake, envelope auth |
| 4 | File transfer & real audio: chunked transfer, multi-track player, sync |
| 5 | UI: library, song editor, master room, singer player, lyrics, themes |
| 6 | Quality / release: CI gates, security checklist, platform testing |

**Studio (Audio Cutting)** lands after Phase 2 (requires: SQLite, part/track CRUD, file validation).

---

## Out of Scope (MVP)

- Real-time voice transposition
- Live singer-to-singer audio (Walkie-talkie mode)
- Automatic master election
- Advanced clock synchronization algorithms
- Desktop / notebook clients
- Cloud storage or server backend
- Account registration / login

---

## Key Acceptance Criteria (Phase Gates)

- Up to 8 approved devices join a room and hear synchronized audio (≤100 ms delta).
- Visitor role cannot control playback or auto-download audio.
- Forged / replayed / unauthorized messages do not alter app state.
- Loop, lyrics, and metronome operate on the same shared timeline.
- A file only becomes visible in the library after its final hash validates.
- Background audio works on both Android and iOS (locked screen, tray controls).
- Full local data deletion is possible without a server call.
