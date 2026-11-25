# Modo solo Context

**Gathered:** 2026-11-24
**Spec:** `.specs/features/solo-player/spec.md`
**Status:** Ready for design (after spec approval)

---

## Feature Boundary

The Modo solo screen plays a song from the local library with no room and no network. It covers:
- play, pause and seek;
- a per-track mix (volume, mute, solo);
- a loop marked with a start and an end;
- a compact synced lyric view.

It is reached from "Ensaiar só" on Detalhe da música.

---

## Implementation Decisions

### Metronome
- Not in this feature. It becomes a feature of its own (RF54), reusable by the room's collective metronome (RF51/RF52).
- The "Metrônomo ♩ 72" button from UI_SPEC §6.12 is omitted until then.

### Loop
- Marked during playback: "Marcar início do loop", then "Marcar fim do loop".
- The section repeats until "Desligar loop"; turning it off continues from the current position (RF10).

### Mix
- Volume, M and S per track. `AudioPlaybackEngine` gains a per-track volume.
- Settings last only while the screen is open.

### Background playback
- Not in this feature (RF24 becomes its own feature, which needs real-device testing).
- Audio stops when leaving the screen.

### Agent's Discretion
- Layout and spacing of the mix rows, following UI_SPEC §6.12 and the design tokens.
- Name and shape of the new shared components (`LyricView`, `PlaybackProgress`, mix row), registered in `COMPONENTS.md`.

### Declined / Undiscussed Gray Areas → Assumptions
All are logged in the spec's Assumptions table:
- end-of-song behavior;
- seeking;
- loop marking disabled while paused;
- turning the loop off discards the section;
- unmarked lyric lines hidden;
- compact lyric view = previous, current and next line;
- neutral top label "Funciona offline";
- empty state for songs with no tracks.

---

## Specific References

- UI_SPEC §6.12 and UX §6.12: Modo solo.
- COMPONENTS.md: `LyricView`, `PlaybackProgress`, `TonalButton`.
- `track-align-screen`: precedent for M/S per track and `autoDispose` stopping audio on unmount.

---

## Deferred Ideas

- Metrônomo solo (RF54) and its shared click player.
- Background and lock-screen playback for Modo solo (RF24).
- Remembering the mix between sessions.
- Recording solo rehearsals in Histórico.
