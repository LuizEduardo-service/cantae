# Áudio em segundo plano Context

**Gathered:** 2026-11-25
**Spec:** `.specs/features/background-audio/spec.md`
**Status:** Ready for design (after spec approval)

---

## Feature Boundary

This feature makes Modo solo keep playing with the screen locked or the app in the background (RF24). It adds lock-screen and notification controls and handles interruptions.

Room screens, Alinhamento and Editor de letra are out of scope.

---

## Implementation Decisions

### Notification controls
- Song title, "Modo solo" subtitle, Tocar/Pausar and a draggable position bar.
- Loop, metronome and mix stay in-app only.

### Device verification
- No physical device is available now.
- Deliver a numbered device test script in `docs/` and a ready-to-run `integration_test/` that writes a log artifact.
- Record the pending device run in `STATE.md`.

### Interruptions (from docs, not asked)
- Calls and focus loss pause without auto-resume (`docs/tasks-cantae-mvp-consolidado.md` T4.11).
- A short "duck" lowers the volume without pausing. Headphone unplug pauses.

---

## Deferred Ideas

- Background playback for room screens: lands with the room UI.
- Mini player when leaving Modo solo inside the app: not in the PRD.
