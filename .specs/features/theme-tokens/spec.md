# Theme Tokens Specification

## Problem Statement

`lib/presentation/` has no theme layer yet, and `docs/design/DESIGN_SYSTEM.md` forbids any widget from using a literal color, font size, spacing, or radius value. Every Phase 5 screen depends on this layer existing first. This feature builds the token layer only — no screens.

## Goals

- [ ] Every token in `DESIGN_SYSTEM.md` §2 (colors, light+dark), §3 (typography scale), §4 (spacing), §5 (radii), §2.3 (voice-part colors) exists as a named Dart constant/`ThemeExtension`, reachable from `Theme.of(context)` or a direct import — never a literal hex/px in a future widget.
- [ ] Geist and Geist Mono render on both Android and iOS without a network fetch (RNF‑UX‑03 / AGENTS.md "fonte Geist... empacotada").
- [ ] Light and dark `ThemeData` both build from the same token source with zero `if (isDark)` branching required in widget code (AGENTS.md: "funciona nos temas claro e escuro sem código condicional no widget").

## Out of Scope

| Feature | Reason |
| --- | --- |
| Any screen or widget beyond theme plumbing | Belongs to each screen's own future spec (library, song detail, room screens, etc.) |
| Persisting the user's theme preference (Claro/Escuro/Sistema) | Belongs to the Profile feature (DESIGN_SYSTEM §9: "`ThemeMode` controlado pela preferência do Perfil"); this feature only makes `ThemeMode.system` the default and exposes a way to override it in-memory |
| `reduzir movimento` (reduced-motion) animation gating | No animations exist yet; this is a per-widget concern for the screens that add motion (§8 of DESIGN_SYSTEM), not the token layer |
| GeistPixel / GeistSerif font families (bundled in the upstream release but unused) | Not referenced anywhere in DESIGN_SYSTEM.md's typography table |
| Contrast re-validation of the hex pairs themselves | DESIGN_SYSTEM §2.4 states the documented pairs already meet WCAG AA; this feature wires them verbatim, it does not re-derive color science |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Font file source | Static (non-variable) TTF weights 400/500/600/700 for Geist, 400/500 for Geist Mono, downloaded from the official `vercel/geist-font` v1.9.2 GitHub release (SIL OFL 1.1), stored under `assets/fonts/geist/` and `assets/fonts/geist_mono/` with `assets/fonts/OFL.txt` | User chose the "download now" option when asked. Static weights (not the variable `[wght]` font) match how `pubspec.yaml`'s `fonts:` block declares discrete weights, which is the simpler, more broadly-supported path in Flutter's font loader | y |
| Token representation | `ThemeExtension<CantaeColors>` for color tokens (per DESIGN_SYSTEM §9's own suggested filename), plain top-level classes with `static const` fields for `CantaeSpacing` (space/radius) and a `Map<VoicePart, VoicePartColor>`-shaped `VoicePartColors` helper; typography as a `CantaeTypography` class exposing `TextStyle` getters wired into `ThemeData.textTheme` where a direct `TextTheme` slot exists (`body`→`bodyLarge`, etc.) and as extra named getters for tokens with no `TextTheme` equivalent (`lyricActive`, `monoLarge`, …) | Matches `flutter-ui-ux` skill's rule that widgets read `Theme.of(context).textTheme`, while DESIGN_SYSTEM's scale has more named styles than `TextTheme` has slots (15, but semantically mismatched) — so a hybrid is more faithful than forcing every token into a `TextTheme` slot it doesn't semantically fit | y — user confirmed the hybrid explicitly |
| `monoLarge`/`monoInput`/`mono`/`lyric*` tokens that have no `TextTheme` counterpart | Exposed as named getters on `CantaeTypography`, not jammed into `TextTheme` | `TextTheme` only has 15 fixed slots (display/headline/title/body/label × large/medium/small); DESIGN_SYSTEM defines 13 differently-purposed styles that don't map 1:1 | y |
| `accentTrack`, `scrim`, `switchOff` (tokens not in a `ColorScheme` slot) | Included as extra fields on the `CantaeColors` `ThemeExtension`, same as every other color token | `ThemeExtension` is arbitrary-shaped by design; no reason to special-case these three | y |
| Visual regression check for this feature (no screens exist to view tokens in) | A tiny throwaway Flutter widget test renders both themes and asserts resolved values (not a golden image) — satisfies "both themes checked" without needing a real screen | Matches the project's E2E-first testing philosophy's exception for pure isolation code (AD-005/CLAUDE.md Testing Rules point 3): this is infrastructure with no user-facing behavior to E2E-test yet | y |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Token layer exists and is theme-switchable ⭐ MVP

**User Story**: As a developer building any Phase 5 screen, I want every visual constant (color, type, space, radius, voice-part color) available as a named Dart token from a single `AppTheme`, so that I never write a literal value in a widget and both themes work automatically.

**Why P1**: Every subsequent screen spec in Phase 5 depends on this existing — it is the hard gate AGENTS.md §3 and §7 checklist enforce ("Nenhum valor visual literal fora de `theme/`").

**Acceptance Criteria**:

1. WHEN `AppTheme.light` is built THEN the system SHALL return a `ThemeData` whose `extensions` include a `CantaeColors` instance with all 23 light-mode tokens from DESIGN_SYSTEM §2.1 set to their documented hex values.
2. WHEN `AppTheme.dark` is built THEN the system SHALL return a `ThemeData` whose `extensions` include a `CantaeColors` instance with all dark-mode tokens from DESIGN_SYSTEM §2.2 set to their documented hex values, including the 3 tokens with no light-mode-table row difference called out (`switchOff`, and any token DESIGN_SYSTEM §2.2 lists only once, inheriting the light value where §2.2 is silent on it — see Edge Cases).
3. WHEN a widget calls `Theme.of(context).extension<CantaeColors>()` THEN the system SHALL return the instance matching the currently active `Brightness` with no widget-level `if (brightness == dark)` branch required.
4. The system SHALL expose `CantaeTypography` with one `TextStyle`-returning member per row of DESIGN_SYSTEM §3's scale table (16 named styles: `display`, `titleHub`, `titlePage`, `titleRoom`, `titleSheet`, `lyricActive`, `lyricNext`, `lyricPast`, `listTitle`, `body`, `bodySmall`, `label`, `caption`, `monoLarge`, `monoInput`, `mono`), each with the documented font family (Geist or Geist Mono), size, weight, letter-spacing, and height.
5. The system SHALL expose `CantaeSpacing` with `space1`..`space6` (4/8/12/16/20/24), `safeTop`, `safeBottom` as `double` constants, and `CantaeRadii` with `radiusXs`..`radiusPill` per DESIGN_SYSTEM §5 (radiusPill computed as `height / 2`, exposed as a function not a constant, since it is relationally defined).
6. The system SHALL expose `VoicePartColors` mapping each of `soprano`, `contralto`, `tenor`, `baixo`, `todos`, `semFaixa`, `visitante` to a light-mode and dark-mode color pair plus the required text color, per DESIGN_SYSTEM §2.3.
7. WHEN the app starts with no explicit theme override THEN the system SHALL default to `ThemeMode.system`.
8. The system SHALL register the `Geist` font family (weights 400/500/600/700) and `Geist Mono` font family (weights 400/500) as local assets with no network dependency, per `pubspec.yaml`'s `fonts:` declaration added in this feature.

**Independent Test**: A widget test pumps a `MaterialApp` with `theme: AppTheme.light` and `darkTheme: AppTheme.dark`, reads `Theme.of(context).extension<CantaeColors>()!.accent` under each `ThemeMode`, and asserts the two different documented hex values; a second assertion reads `CantaeTypography.lyricActive.fontFamily` and confirms it resolves to `'Geist'`.

---

## Edge Cases

- IF DESIGN_SYSTEM §2.2 (dark table) does not explicitly re-list a token that §2.1 (light table) defines (none currently — every semantic color token has an explicit dark-mode row or an explicit "idem"/inherit note) THEN the system SHALL use the explicit value given; `textDisabled`, `accentBg`-style tokens not present in either table are out of scope (not yet defined by design) and SHALL NOT be invented.
- IF a future screen needs a token not in this spec's list THEN the system SHALL NOT have that token silently added here — DESIGN_SYSTEM.md is updated first (AGENTS.md §6), then this theme layer, in that screen's own task.
- WHEN system text-scale is set above 100% THEN `CantaeTypography`'s `TextStyle`s SHALL carry no hardcoded fixed `height` that defeats scaling — Flutter's default `MediaQuery.textScaler` application to `TextStyle.fontSize` is relied upon rather than re-implemented (no custom scaling logic in this layer).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| THEME-01 | P1 | Design (inline) | Implementing |
| THEME-02 | P1 | Design (inline) | Implementing |
| THEME-03 | P1 | Design (inline) | Implementing |
| THEME-04 | P1 | Design (inline) | Implementing |
| THEME-05 | P1 | Design (inline) | Implementing |
| THEME-06 | P1 | Design (inline) | Implementing |
| THEME-07 | P1 | Design (inline) | Implementing |
| THEME-08 | P1 | Design (inline) | Implementing |

**ID format:** `THEME-NN`, one per numbered AC under P1 (no P2/P3 — this feature has a single, non-splittable story).

**Coverage:** 8 total, 8 mapped to inline-design tasks below, 0 unmapped.

---

## Success Criteria

- [ ] `flutter analyze` and `flutter test` pass with the new theme files and their test in place.
- [ ] No file under `lib/presentation/theme/` contains a literal hex string, raw `px`/`pt` number outside the token definitions themselves, or a `Flutter`-only import leaking into `domain/` (N/A here — this feature never touches `domain/`, but `check_layers.py` still runs clean as a regression guard).
- [ ] A future screen can write `Theme.of(context).extension<CantaeColors>()!.accent`, `CantaeTypography.body`, `CantaeSpacing.space4`, `CantaeRadii.radiusLg`, and `VoicePartColors.of(VoicePart.soprano, Brightness.dark)` with no further theme-layer work required.
