---
name: flutter-quality-gates
description: Use before committing or claiming a Flutter task is complete — running analyzer/lint, formatting, and the existing test suite, and interpreting failures — and when wiring or updating CI checks for this repo.
---

# Flutter Quality Gates

## Overview

Automates the *verification* cycle (lint, analyze, run existing tests) before a commit — it does not decide *what* tests to write. That's governed by root `CLAUDE.md` → Testing Rules (E2E-first, failure-modes-first for isolated units, never unit-tests-after-the-fact). This skill assumes those tests already exist or were just written per that policy, and its job is to run them and gate on the result.

## Gate Order (fail fast, cheapest first)

1. `dart format --output=none --set-exit-if-changed .` — formatting
2. `flutter analyze` — static analysis, must be zero issues (cyclomatic complexity ≤15 is enforced here per `analysis_options.yaml`)
3. `flutter test` — unit/widget tests (domain + isolated-failure-mode tests per `CLAUDE.md`)
4. `flutter test integration_test/` (or the project's E2E runner) — the primary verification per `CLAUDE.md`'s E2E-first rule; confirm the test produced its required artifact (log/screenshot/assertion output), don't just check exit code 0

Stop at the first failing gate — don't run later gates "to see the full picture"; fix and re-run from gate 1.

## Domain-Layer Specific Check

Because `domain/` must compile without the Flutter SDK (`CLAUDE.md`), periodically verify it independently:

```bash
dart analyze lib/domain/
```

A `package:flutter` or plugin import inside `domain/` that `flutter analyze` doesn't flag (because the whole project pulls in Flutter) will show up here as an unresolvable import — that's the CI-blocking violation `CLAUDE.md` calls out.

## Reading Failures

| Signal | Likely cause |
|---|---|
| `flutter analyze` flags high cyclomatic complexity | Function doing too much — extract, don't suppress the lint |
| Widget test fails only in CI, passes locally | Golden/timing dependency — check for unmocked `Timer`/animation ticks, not a flaky-test retry |
| E2E test passes but produced no artifact | Test isn't wired to capture logs/screenshots — fix the harness before trusting the pass |
| `domain/` file fails `dart analyze lib/domain/` | A Flutter/plugin import leaked in — move the logic to `data/`/`infrastructure/` |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Writing a new unit test for code you just finished writing, "for coverage" | Forbidden by `CLAUDE.md` — if the logic needs isolated coverage, list failure modes first, per that rule |
| Skipping `dart format` because "it's just whitespace" | Run it — CI treats formatting diffs as a failing gate |
| Re-running `flutter test` in a retry loop on flaky failure | Diagnose the root cause (timer/async) instead of retrying until green |
| Marking a task done because `flutter analyze` is clean but tests weren't run | All gates must pass; analyzer-clean is gate 2 of 4, not the finish line |

**REQUIRED BACKGROUND:** Root `CLAUDE.md` Testing Rules govern what gets tested and how — read that before this skill if the task involves writing new tests, not just running existing ones.
