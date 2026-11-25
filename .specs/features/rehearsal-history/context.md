# Ensaios anteriores Context

**Gathered:** 2026-11-25
**Spec:** `.specs/features/rehearsal-history/spec.md`
**Status:** Ready for design (after spec approval)

---

## Feature Boundary

This feature records Modo solo rehearsals (RF39) and adds the "Ensaios" screen (UI_SPEC §6.16), with deletion per song or for everything (RF40). Room rehearsals, the privacy screen and export are out of scope.

---

## Implementation Decisions

### Duration
- Only time with the music playing counts, both towards the duration and towards the PRD's 60 s minimum.

### Loops
- Each time the loop jumps back to the start of the section counts as 1.

### From the PRD (not asked)
- A rehearsal of 60 s or more is recorded by default.
- It stores the PRD's `RehearsalLog` fields only: no audio, lyrics or other people's data.

---

## Deferred Ideas

- Switching off rehearsal recording: no preferences screen exists yet.
- Room rehearsals: land with the room screens. The schema already has mode, role and participants.
