---
name: flutter-ui-ux
description: Use when building or reviewing a Flutter screen or widget tree — layout, spacing, animation, or accessibility — especially before marking UI work in Phase 5 (library, song editor, master room, singer player, lyrics, themes) as done.
---

# Flutter UI/UX Quality

## Overview

Prevents "prototype-looking" widget trees: inconsistent spacing, missing semantics, animations that drop frames. Mobile-first for Android 8.0+/iOS 14+ phones — no tablet/desktop breakpoints unless asked.

## Layout Checklist

- Spacing uses a fixed scale (e.g. 4/8/12/16/24/32), never arbitrary magic numbers (`SizedBox(height: 13)`).
- No `Expanded`/`Flexible` misuse causing "unbounded height" exceptions in `Column`/`ListView` nesting — wrap scrollable children, don't nest two scrollables without `shrinkWrap`/slivers.
- Text styles come from `Theme.of(context).textTheme`, never hardcoded `TextStyle(fontSize: 16)` — themes (light/dark, per `CLAUDE.md` Phase 5) must propagate automatically.
- Touch targets ≥ 48x48 logical pixels (singer player's loop/skip controls are tapped mid-rehearsal, often one-handed).

## Accessibility

- Every `IconButton`/custom tappable without visible text gets `Semantics(label: ...)` or `tooltip:`.
- Color is never the only signal for state (e.g. "muted track" needs an icon change, not just a color dim) — check contrast against WCAG AA (4.5:1 for text).
- Respect `MediaQuery.textScaler` — layouts must not clip or overflow at 1.3x text scale; test with a quick visual check, not assumption.

## Animation (60fps target)

- Drive animations with `AnimationController` + `Tween`/`AnimatedBuilder`, or implicit widgets (`AnimatedContainer`, `AnimatedOpacity`) for simple state transitions — avoid rebuilding large subtrees every frame via `setState` in a ticker callback.
- Anything synced to playback position (lyrics highlight, loop markers) listens to the audio position stream and repaints only the affected widget (`ValueListenableBuilder`/narrow `Consumer`), not the whole screen.
- Prefer `const` constructors for static subtrees so animated parents don't force rebuilds of children that never change — see `flutter-widget-performance`.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Hardcoded `Colors.grey` / hex values in widgets | Pull from `ThemeData.colorScheme` so themes (Phase 5) work |
| `GestureDetector` wrapping an icon with no semantic label | Add `Semantics`/`tooltip`, or use `IconButton` with `tooltip:` |
| Full-screen `setState` on every audio position tick | Scope the listener to the smallest widget (lyrics line, loop marker) |
| Spacing via nested empty `Container(height: ...)` | Use `SizedBox` + the project's spacing scale |

**REQUIRED BACKGROUND:** `flutter-widget-performance` for rebuild/const discipline underneath these UI patterns.
