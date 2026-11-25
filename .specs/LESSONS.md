# LESSONS - auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation - do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-003 - When a design doc specifies that one component sends a message another component reacts to, verify both the sender and the receiver exist in production code, not just a unit test that hand-constructs the message for the receiver.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `data/playback` · harmful: 0
- features: file-transfer-and-sync-playback
- evidence: spec.md SYNC-06; lib/data/playback/playback_command_handler.dart:94-103 (data/playback)
- last seen: 2026-11-18T01:28:08Z

### L-004 - When a mid-implementation production bug is fixed (e.g. a race between object construction and the next stream event), add a regression test that reproduces the exact ordering that caused the bug, not just tests that already avoid that ordering.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `data/playback` · harmful: 0
- features: file-transfer-and-sync-playback
- evidence: lib/data/playback/playback_command_broadcaster.dart constructor (currentSnapshot seeding); test/data/playback/playback_command_broadcaster_test.dart (data/playback)
- last seen: 2026-11-18T01:28:09Z

### L-005 - A test asserting a no-op success on an empty/degenerate input does not prove a role-gate rejection; assert on the actual Failure/rejection path the spec describes, even when a structural shortcut also happens to produce the same observable outcome.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `data/transfer` · harmful: 0
- features: file-transfer-and-sync-playback
- evidence: test/data/transfer/song_sync_coordinator_test.dart:379-414 (XFER-09) (data/transfer)
- last seen: 2026-11-18T01:28:10Z

### L-006 - When a spec AC states an exact token/field count, recount the referenced design-doc table before writing it down; a miscounted prose number creates a false discrepancy signal for the Verifier even when the implementation is correct.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `presentation/theme` · harmful: 0
- features: theme-tokens
- evidence: THEME-01 (presentation/theme)
- last seen: 2026-11-19T08:21:43Z

### L-007 - When a design doc gives a size/weight range instead of a single value for a token, the spec AC should say 'within the documented range' explicitly, or pin one exact value, so the Verifier isn't left guessing whether a point value chosen by the implementer is a faithful reading or a silent narrowing.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `presentation/theme` · harmful: 0
- features: theme-tokens
- evidence: THEME-04 (presentation/theme)
- last seen: 2026-11-19T08:21:43Z

### L-008 - When a color-token design doc omits a dark-mode row for a token, reuse the nearest semantically-equivalent token's dark value (not an invented hex) and mark it with a SPEC_DEVIATION comment naming the exact row that's missing, so a future design-doc update can fill the gap deliberately instead of silently diverging further.
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `presentation/theme` · harmful: 0
- features: theme-tokens
- evidence: lib/presentation/theme/cantae_colors.dart:112-115 (textDisabled) (presentation/theme)
- last seen: 2026-11-19T08:21:44Z

### L-009 - Two independent tokens missing the same kind of dark-mode row (textDisabled, warningInline) is a signal to flag the gap in DESIGN_SYSTEM.md itself as a follow-up, not just patch each call site with its own SPEC_DEVIATION comment.
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `presentation/theme` · harmful: 0
- features: theme-tokens
- evidence: lib/presentation/theme/cantae_colors.dart:123-125 (warningInline) (presentation/theme)
- last seen: 2026-11-19T08:21:45Z

### L-010 - When a spec defines exact empty-result copy only for the search-query case, explicitly define the origin/filter-only empty-result copy too, instead of leaving it to a silent fallback.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `presentation` · harmful: 0
- features: library-screen
- evidence: LIB-04 / lib/presentation/screens/library/library_screen.dart:396-397 (presentation)
- last seen: 2026-11-20T01:53:56Z

### L-011 - Give shared scaffold/shell widgets a Material ancestor up front so every screen's bare InkWell-based children work without a per-screen Material wrapper workaround.
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `presentation` · harmful: 0
- features: library-screen
- evidence: lib/presentation/widgets/cantae_scaffold.dart:33-75 (worked around in lib/presentation/screens/library/library_screen.dart:37-38) (presentation)
- last seen: 2026-11-20T01:53:57Z

### L-012 - Build a component named in COMPONENTS.md as its own shared widget file as soon as a second screen will plausibly need it, not as a screen-private widget, to avoid future duplication.
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `presentation` · harmful: 0
- features: library-screen
- evidence: lib/presentation/screens/library/library_screen.dart (private _ErrorBody, T19 Status note) (presentation)
- last seen: 2026-11-20T01:53:58Z

### L-013 - When a screen has two symmetric footer/row actions wired the same way (e.g. two buttons both calling goNamed), write a navigation-assertion test for each one individually, not just the first — identical wiring does not excuse skipping the test for its sibling.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `presentation/screens` · harmful: 0
- features: song-detail-screen
- evidence: DETAIL-12/DETAIL-13 (presentation/screens)
- last seen: 2026-11-20T17:40:42Z

### L-014 - When a spec requires N identically-shaped rows/actions (e.g. a 4-row 'Preparar' section), test navigation for every row individually, not just one representative row — rendering/presence checks do not substitute for a per-row tap-and-navigate assertion.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `presentation/screens` · harmful: 0
- features: song-detail-screen
- evidence: DETAIL-08/DETAIL-09 (presentation/screens)
- last seen: 2026-11-20T17:40:53Z

### L-015 - When a notifier exposes N status/branch values (e.g. an error-state enum, a confirm/cancel pair), write a screen-level test for every one of them individually — implementing a branch and testing only its sibling or the underlying state transition is not evidence the branch itself renders or navigates correctly.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `presentation/screens` · harmful: 0
- features: track-align-screen
- evidence: ALIGN-19 ConfirmSheet cancel branch; não encontrada screen state (presentation/screens)
- last seen: 2026-11-21T15:56:52Z

### L-016 - A schema migration test must exercise the new constraint on the upgraded database, not only that existing rows survive
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `database` · harmful: 0
- features: lyrics-editor
- evidence: validation.md M14 (lib/infrastructure/database/app_database.dart:35) (database)
- last seen: 2026-11-24T22:58:04Z

### L-017 - Pin every comparison boundary from an acceptance criterion with a test at the exact equal value
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `presentation` · harmful: 0
- features: lyrics-editor
- evidence: validation.md M2 (lib/presentation/providers/lyrics_editor_notifier.dart:336) (presentation)
- last seen: 2026-11-24T22:58:06Z

### L-018 - When a guard applies to several actions, test it on each action, not only the first
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `presentation` · harmful: 0
- features: solo-player
- evidence: validation.md S9 (lib/presentation/providers/solo_player_notifier.dart:293) (presentation)
- last seen: 2026-11-25T00:37:50Z

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
