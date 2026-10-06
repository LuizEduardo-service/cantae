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

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
