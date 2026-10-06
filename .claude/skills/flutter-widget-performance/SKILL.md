---
name: flutter-widget-performance
description: Use when writing or reviewing a StatefulWidget/setState, a widget rebuilt on every audio-position or playback tick, or any widget tree in the hot path (singer player, master room, timeline) — checking for missing const, unnecessary rebuild scope, or main-thread heavy work.
---

# Flutter Widget Performance

## Overview

Cantaê's playback screens rebuild on every audio-position tick (lyrics highlight, loop markers, timeline cursor) — this is the highest-risk area for dropped frames and must stay under the project's ≤100ms sync-delta and 60fps targets.

## const Discipline

- Every widget constructor call with no runtime-varying arguments gets `const`. Run `dart fix --apply` for mechanical `prefer_const_constructors` fixes, but verify by eye in hot-path widgets — the linter catches syntax, not whether a parent's rebuild still forces a child's `build()` despite `const` (it won't, if `const` is correct).
- A `const` child inside a non-const parent still skips rebuild *only if* the child's constructor args are themselves const — check for a non-const default value (e.g. `DateTime.now()`) accidentally making a "const-looking" widget rebuild every time.

## Rebuild Scope

- Audio-position-driven UI (lyrics line, loop marker, timeline cursor) listens via `ValueListenableBuilder`/narrow `Consumer(builder: ...)` scoped to the single widget that changes — never wrap the whole screen's `build()` in a position listener.
- `setState` calls justify themselves by what they rebuild: if a `setState` inside a 500-widget screen only changes a 20px badge, that's a sign the badge needs its own state holder (`ValueNotifier`, or split widget + `Consumer`), not a top-level `setState`.
- `ref.watch` in Riverpod should be as narrow as the data needed — watch a derived/select provider (`ref.watch(provider.select((s) => s.isPlaying))`) instead of the whole state object when only one field drives the rebuild.

## Off-Main-Thread Work

Per `CLAUDE.md`: hashing, parsing, large file I/O run in an `Isolate`/`compute`. In practice this means:
- File hash validation (library visibility gate) — never on the UI thread, always `compute()` or a dedicated isolate.
- Audio file parsing/chunked transfer assembly (Phase 4) — isolate, not `await` on the main isolate.
- Mixing/gain calculations in `AudioMixCalculator` are cheap pure math and fine on the UI thread *unless* called per-sample in a tight loop — profile before moving simple math to an isolate; isolate hand-off has its own overhead.

## Common Mistakes

| Mistake | Fix |
|---|---|
| `ListView` of tracks rebuilding all items when one track's volume changes | Key each item, scope volume state per-item (`Consumer`/`select`) |
| `setState(() {})` with an empty closure "to force a repaint" | Find what state actually changed and model it explicitly |
| Heavy hash/parse called with plain `await` on the UI isolate | Wrap in `compute()` so it runs off the UI thread |
| Non-const `EdgeInsets.all(8)` repeated across a widget tree | Hoist to a `static const` or project spacing constant |

**REQUIRED BACKGROUND:** `flutter-ui-ux` for the animation/layout patterns this performance discipline sits underneath.
