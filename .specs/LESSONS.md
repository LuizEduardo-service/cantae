# LESSONS - auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation - do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-001 - When an acceptance criterion says every or all, assert the collection with more than one element instead of a single fake instance
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `tests` · harmful: 0
- features: session-networking
- evidence: NET-02 - test/infrastructure/network/nsd_room_discovery_test.dart:124 (tests)
- last seen: 2026-10-06T20:55:15Z

### L-002 - When asserting an event-triggered side effect that a periodic sweep also performs, bound the wait window well below the sweep interval so the sweep cannot satisfy the assertion
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `tests` · harmful: 0
- features: session-networking
- evidence: iteration-2 sensor mutation 3 - lib/data/session/room_session_controller.dart:185 (NET-06) (tests)
- last seen: 2026-10-06T20:55:30Z

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

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
