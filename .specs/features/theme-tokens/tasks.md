# Theme Tokens Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: inline (Medium scope per the skill's auto-sizing table — no separate `design.md`; design decisions live in `spec.md`'s Assumptions table)
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase (sampled `test/data/mappers/*_test.dart`, `test/domain/**/*_test.dart` for style/location conventions) and `AGENTS.md`/`CLAUDE.md` (no project-specific presentation-layer testing guideline found beyond "escreva testes de widget: renderização por estado, ação primária, semântica" in AGENTS.md §5 step 5 — applied below). Guidelines found: `AGENTS.md` §5, §7; `CLAUDE.md` Testing Rules (E2E-first, no post-hoc unit tests — N/A conflict note below).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Theme static data (color hex tables, spacing/radius constants, typography scale values) | none | Build gate only — these are literal-value tables transcribed from `DESIGN_SYSTEM.md`; a test re-asserting "field X equals the value I just wrote" proves nothing a reviewer diffing against the design doc doesn't already prove | — | build gate only |
| Theme resolution logic (brightness-based lookup, `radiusPill` computation, `VoicePartColors.of()`) | unit | Every branch (light vs. dark, each `VoicePart` enum value) exercised; 1:1 to the relevant spec AC | `test/presentation/theme/*_test.dart` | `flutter test test/presentation/theme/` |
| Theme-to-widget integration (`AppTheme.light`/`.dark` actually resolve through `Theme.of(context)` in a real `MaterialApp`, fonts actually load) | widget | One test per theme mode confirming `Theme.of(context).extension<CantaeColors>()` and `CantaeTypography` resolve to the documented values and font family strings | `test/presentation/theme/app_theme_test.dart` | `flutter test test/presentation/theme/app_theme_test.dart` |

**Note on `CLAUDE.md`'s "E2E-first, no post-hoc unit tests" rule:** this feature has no user-facing flow to E2E-test yet (no screens exist) — `spec.md`'s own Assumptions table already resolved this (row: "Visual regression check for this feature") by designating the widget test as this layer's E2E-equivalent: it drives a real `MaterialApp` + `Theme.of(context)` round trip, not an isolated unit mock. The remaining `unit` tests are failure-mode/branch tests written test-first per `CLAUDE.md` point 3 ("teste em isolamento: failure modes first"), not post-hoc description of code already written.

## Gate Check Commands

> Generated from `.specs/STATE.md` AD-007 and prior features' validation reports (same commands used for `session-networking` and `file-transfer-and-sync-playback`).

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task with only unit tests | `flutter test test/presentation/theme/` |
| Full | After a task with widget/integration tests | `flutter test test/presentation/theme/` (same command; this project has no separate widget-test runner) |
| Build | After the last task in the feature, or a config/no-test task | `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/` |

---

## Execution Plan

### Phase 1: Static tokens

Executed in listed order (T1, T2, T3, T4); only T4 has a real data dependency (on T1) — see Task Breakdown and the Phase Execution Map below for the exact dependency graph.

### Phase 2: Resolution layer + verification

Executed in listed order (T5, T6, T7); see the Phase Execution Map below for the exact dependency graph.

---

## Task Breakdown

### T1: Register Geist/Geist Mono font assets

**What**: Declare the `Geist` (400/500/600/700) and `Geist Mono` (400/500) local font families in `pubspec.yaml`, backed by the already-downloaded TTF files and OFL license under `assets/fonts/`.
**Where**: `pubspec.yaml`
**Depends on**: None
**Reuses**: N/A (new asset category)
**Requirement**: THEME-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `pubspec.yaml`'s `flutter.fonts` lists both families with the correct asset paths and weights
- [ ] `assets/fonts/geist/`, `assets/fonts/geist_mono/`, and `assets/fonts/OFL.txt` are present and match the official v1.9.2 release (already downloaded this session)
- [ ] Gate check passes: `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`

**Tests**: none
**Gate**: build

**Status**: ✅ Complete — `flutter analyze` 0 issues, `flutter test` 252/252, `check_layers.py` clean, `dart analyze lib/domain/` clean.

---

### T2: CantaeSpacing and CantaeRadii constants

**What**: `CantaeSpacing` (space1..space6, safeTop, safeBottom) and `CantaeRadii` (radiusXs..radiusPill, with `radiusPill(height)` as a function) as `static const`/`static` members on two small top-level classes.
**Where**: `lib/presentation/theme/cantae_spacing.dart`
**Depends on**: None
**Reuses**: N/A (first presentation-layer file)
**Requirement**: THEME-05

**Tools**:
- MCP: NONE
- Skill: `flutter-clean-architecture` (confirm file placement under `presentation/theme/`)

**Done when**:
- [ ] All DESIGN_SYSTEM §4/§5 values present with exact token names from the spec
- [ ] `CantaeRadii.radiusPill(double height)` returns `height / 2`, covered by a unit test
- [ ] Gate check passes: `flutter test test/presentation/theme/`
- [ ] Test count: 1+ new test (no silent deletions)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete — 2/2 tests pass (`flutter test test/presentation/theme/`).

---

### T3: CantaeColors ThemeExtension

**What**: `ThemeExtension<CantaeColors>` with all 23 light-mode and matching dark-mode color tokens from DESIGN_SYSTEM §2.1/§2.2, plus `lerp`/`copyWith` overrides `ThemeExtension` requires.
**Where**: `lib/presentation/theme/cantae_colors.dart`
**Depends on**: None
**Reuses**: N/A
**Requirement**: THEME-01, THEME-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `CantaeColors.light` and `CantaeColors.dark` static instances exist with every documented hex value
- [ ] A unit test asserts at least one token per theme (`accent`, `bg`) resolves to its documented hex, to catch a wrong-theme copy/paste
- [ ] Gate check passes: `flutter test test/presentation/theme/`
- [ ] Test count: 1+ new test (no silent deletions)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete — 5/5 tests pass (`flutter test test/presentation/theme/`). Two `SPEC_DEVIATION` markers added for `textDisabled`/`warningInline` dark-mode values, which DESIGN_SYSTEM.md §2.2 doesn't give a dedicated row for.

---

### T4: CantaeTypography

**What**: `CantaeTypography` exposing the 16 DESIGN_SYSTEM §3 styles as `TextStyle` getters (`display`, `titleHub`, ..., `mono`), each pinned to the documented family (`Geist`/`Geist Mono`), size, weight, letter-spacing, height.
**Where**: `lib/presentation/theme/cantae_typography.dart`
**Depends on**: T1 (font family names must match what's registered)
**Reuses**: N/A
**Requirement**: THEME-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] All 16 named getters present with documented family/size/weight/letterSpacing/height
- [ ] A unit test asserts `lyricActive.fontFamily == 'Geist'` and `mono.fontFamily == 'Geist Mono'` (the two tokens most likely to get the wrong family by copy/paste)
- [ ] Gate check passes: `flutter test test/presentation/theme/`
- [ ] Test count: 1+ new test (no silent deletions)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete — 8/8 tests pass (`flutter test test/presentation/theme/`).

---

### T5: VoicePartColors

**What**: `VoicePartColors.of(VoicePart part, Brightness brightness)` returning the documented color + required text color for each of `soprano`, `contralto`, `tenor`, `baixo`, `todos`, `semFaixa`, `visitante`.
**Where**: `lib/presentation/theme/voice_part_colors.dart`
**Depends on**: T3 (the `semFaixa`/`visitante` outline variants reference `CantaeColors.text2`)
**Reuses**: `CantaeColors` (T3)
**Requirement**: THEME-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] A `VoicePart` enum with the 7 documented values exists
- [ ] `VoicePartColors.of(...)` returns the correct documented value for every `(part, brightness)` pair — unit test enumerates all 14 combinations
- [ ] Gate check passes: `flutter test test/presentation/theme/`
- [ ] Test count: 14+ new assertions across test cases (no silent deletions)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete — 14/14 new assertions (all 7 parts × 2 brightness values), 22/22 total pass (`flutter test test/presentation/theme/`).

---

### T6: AppTheme assembly

**What**: `AppTheme.light`/`AppTheme.dark` static `ThemeData` getters that register the `CantaeColors` extension, wire the subset of `CantaeTypography` styles that have a direct `TextTheme` slot into `ThemeData.textTheme`, set `fontFamily: 'Geist'` as the default, and a top-level default of `ThemeMode.system` (exposed as a constant other code can read, e.g. in a future `MaterialApp(themeMode: ...)` wiring).
**Where**: `lib/presentation/theme/app_theme.dart`
**Depends on**: T2, T3, T4
**Reuses**: `CantaeSpacing`/`CantaeRadii` (T2), `CantaeColors` (T3), `CantaeTypography` (T4)
**Requirement**: THEME-01, THEME-02, THEME-03, THEME-07, THEME-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `AppTheme.light.extensions` and `AppTheme.dark.extensions` each contain the matching `CantaeColors` instance
- [ ] `AppTheme.light.textTheme.bodyLarge` (and at least one other mapped slot) resolves to the `CantaeTypography` style documented for it
- [ ] `AppTheme.defaultThemeMode == ThemeMode.system`
- [ ] Gate check passes: `flutter test test/presentation/theme/`
- [ ] Test count: 1+ new test (no silent deletions)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete — 5 new tests in `test/presentation/theme/app_theme_resolution_test.dart` (renamed from the template's `app_theme_test.dart` to avoid colliding with T7's widget-level test, which keeps that filename), 27/27 total pass (`flutter test test/presentation/theme/`).

---

### T7: Theme-to-widget integration test

**What**: A widget test that pumps a real `MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark)`, switches `ThemeMode`, and confirms `Theme.of(context).extension<CantaeColors>()!.accent` differs correctly between modes and that a rendered `Text` widget using `CantaeTypography.lyricActive` resolves `fontFamily == 'Geist'` at runtime (catches a `pubspec.yaml` font-registration mistake that a pure unit test on the `TextStyle` object wouldn't).
**Where**: `test/presentation/theme/app_theme_test.dart`
**Depends on**: T5, T6
**Reuses**: N/A (first integration-level test for this layer)
**Requirement**: THEME-01, THEME-02, THEME-03, THEME-04, THEME-07, THEME-08 (closes the spec's "Independent Test")

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Test asserts `accent` resolves to `0xFF0E5E4B` under light and `0xFF5FC4A3` under dark
- [ ] Test asserts the rendered `Text` widget's effective `TextStyle.fontFamily == 'Geist'`
- [ ] Gate check passes (BUILD, last task): `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`
- [ ] Test count: 2+ new tests; total suite count ≥ 252 (the count at this feature's start) + all new tests from T2-T7

**Tests**: widget
**Gate**: build

---

## Phase Execution Map

```
T1 -> T4
T3 -> T5
T2 -> T6
T3 -> T6
T4 -> T6
T5 -> T7
T6 -> T7
```

Dependency arrows only — matches every task's `Depends on` field below exactly. Tasks with `Depends on: None` (T1, T2, T3) have no incoming arrow. Within each phase, execution still proceeds in task-number order (T1 before T2 before T3 before T4; then T5 before T6 before T7) even where no data dependency forces it, since a single worker executes one task at a time in listed order.

Execution is strictly sequential — there is no intra-phase parallelism. 7 tasks total, single batch, executed inline (no sub-agent offer needed — well under the ~8-task threshold).

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Register fonts | 1 config change (pubspec + already-staged assets) | ✅ Granular |
| T2: CantaeSpacing/CantaeRadii | 2 small cohesive classes, 1 file | ✅ Granular (cohesive: both are pure layout-constant tokens, same file as DESIGN_SYSTEM §9 implies) |
| T3: CantaeColors | 1 class, 1 file | ✅ Granular |
| T4: CantaeTypography | 1 class, 1 file | ✅ Granular |
| T5: VoicePartColors | 1 enum + 1 class, 1 file | ✅ Granular |
| T6: AppTheme | 1 class, 1 file | ✅ Granular |
| T7: Integration test | 1 test file | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | (no incoming edge) | ✅ Match |
| T2 | None | (no incoming edge) | ✅ Match |
| T3 | None | (no incoming edge) | ✅ Match |
| T4 | T1 | `T1 -> T4` | ✅ Match |
| T5 | T3 | `T3 -> T5` | ✅ Match |
| T6 | T2, T3, T4 | `T2 -> T6`, `T3 -> T6`, `T4 -> T6` | ✅ Match |
| T7 | T5, T6 | `T5 -> T7`, `T6 -> T7` | ✅ Match |

No task depends on a later-phase task; every `Depends on` resolves to an earlier or same-phase task.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: Font registration | Theme static data (config) — matrix row "Theme static data (...)": none | none | none | ✅ OK |
| T2: CantaeSpacing/CantaeRadii | Theme resolution logic (`radiusPill` function) | unit | unit | ✅ OK |
| T3: CantaeColors | Theme resolution logic (two static instances, but the risk is data-copy, not resolution) — treated as static data with a spot-check unit test exceeding the floor | none (floor) / unit (chosen) | unit | ✅ OK (exceeds floor deliberately — see T3's `Done when`) |
| T4: CantaeTypography | Same as T3 — static data with a spot-check unit test exceeding the floor | none (floor) / unit (chosen) | unit | ✅ OK |
| T5: VoicePartColors | Theme resolution logic (`of()` branch per enum value) | unit | unit | ✅ OK |
| T6: AppTheme | Theme resolution logic (assembly + `textTheme` wiring) | unit | unit | ✅ OK |
| T7: Integration test | Theme-to-widget integration | widget | widget | ✅ OK |

No violations.

---

## MCPs and Skills

No project or user MCP servers are configured for this session beyond the ones already declared unavailable (`context7` needs auth, `context-mode` failed to connect). Every task lists `MCP: NONE`. `flutter-clean-architecture` is referenced once (T2, first presentation-layer file) to confirm placement; `flutter-ui-ux` already informed the spec's token-representation decision and needs no further per-task invocation since no widgets are built in this feature.
