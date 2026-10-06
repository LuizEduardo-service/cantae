---
name: flutter-clean-architecture
description: Use when creating or placing Dart/Flutter files, adding a dependency, wiring Riverpod providers, or deciding which layer (presentation/domain/data/infrastructure) a piece of logic belongs in — prevents business logic leaking into widgets or Flutter/plugin imports leaking into domain/.
---

# Flutter Clean Architecture

## Overview

Cantaê uses 4 layers: `presentation/ → domain/ → data/ → infrastructure/`. This skill is the enforcement guide for that structure — see root `CLAUDE.md` for the canonical rules (domain purity, `Result<S,F>`, no `throw` in domain). This skill adds the *placement* and *wiring* patterns the project guide doesn't spell out.

## Dependency Direction (one-way)

```
presentation  --depends on-->  domain
data          --depends on-->  domain
infrastructure --implements-->  domain interfaces
```

`domain/` never imports from `data/`, `infrastructure/`, or `presentation/`. `domain/` defines repository **interfaces**; `data/` provides the implementation; `infrastructure/` provides the raw I/O (SQLite, TCP, mDNS) that `data/` wraps.

## Where does this code go?

| Symptom | Layer |
|---|---|
| Widget, `ConsumerWidget`, `Navigator`, theming | `presentation/` |
| Entity, value object, use case, `Result<S,F>` logic, pure calculation (mix levels, loop math, timeline mapping) | `domain/` |
| Repository implementation, DTO ↔ entity mapper, caching policy | `data/` |
| `sqflite` calls, `just_audio` engine, socket/TCP, mDNS, Keystore/Keychain | `infrastructure/` |

**Quick test:** if the file needs `import 'package:flutter/...'` or any plugin package to compile, it is not `domain/`.

## Riverpod Wiring Pattern

- One provider per repository interface, overridden in `infrastructure/`/`data/` composition root — never instantiate a concrete infra class inside a widget.
- Use case / domain service providers depend on repository providers, never on infra providers directly.
- Prefer `Notifier`/`AsyncNotifier` over raw `StateProvider` once state has more than one field or a lifecycle (loading/error/data).

```dart
// domain/ — interface only
abstract class SongRepository {
  Future<Result<List<Song>, LibraryFailure>> loadAll();
}

// data/ — implementation, knows about infra
class SqliteSongRepository implements SongRepository { ... }

// presentation/ — provider wiring, composition root
final songRepositoryProvider = Provider<SongRepository>(
  (ref) => SqliteSongRepository(ref.watch(sqliteDbProvider)),
);
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Widget calls `sqflite` directly for a "quick fix" | Route through a repository interface, even for reads |
| Domain entity has a `toJson()`/`fromMap()` | Put mapping in `data/` DTOs, keep entities plain Dart |
| New feature's use case throws on failure | Return `Failure` subclass with a `code`; no `throw` in domain |
| Provider instantiates `SqliteSongRepository()` inline in a widget | Define it once in the composition root provider file |

**REQUIRED BACKGROUND:** Testing conventions for this layering are owned by root `CLAUDE.md` → Testing Rules (E2E-first, no post-hoc unit tests) — this skill does not override them.
