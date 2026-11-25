# Metrônomo solo Context

**Gathered:** 2026-11-24
**Spec:** `.specs/features/solo-metronome/spec.md`
**Status:** Ready for design (after spec approval)

---

## Feature Boundary

This feature fixes three audio bugs and adds the metronome to Modo solo. The bugs:
- only the first track starts on a device;
- the clock does not advance during playback;
- the metronome pulses drift.

The metronome part covers:
- turning it on and off;
- defining or adjusting the tempo (saved to the song);
- the click volume in the mix.

---

## Implementation Decisions

### Songs without a tempo
- Modo solo opens an "Andamento" sheet (BPM, tempos por compasso, acento) and saves the result to the song (RF50).
- Received songs are read-only for the tempo.

### Metronome volume
- A "Metrônomo" row in "Mix por naipe", with volume and M (no S).
- The footer button turns it on and off and shows "♩ BPM".

### Audio bugs
- They are the first tasks of this feature, each with a red-first regression test, in separate `fix(...)` commits.

### Agent's Discretion
- How the click is produced. The design proposes a click track loaded in the engine as one more track, so it follows play, pause, seek and loop on the same timeline.
- The sheet layout, following the design tokens and the existing components.

### Declined / Undiscussed Gray Areas → Assumptions
All are logged in the spec's Assumptions table:
- received-song behavior;
- the click sound;
- the first beat at 0 ms;
- the bounds;
- `enabledByDefault` honored but not editable;
- the click volume lasting the session only.

---

## Specific References

- `just_audio` 0.9.46 `AudioPlayer.play()` docs: "The Future returned by this method completes when the playback completes or is paused or stopped."
- `just_audio` `positionStream`: emits every 16–200 ms while playing. `playbackEventStream` emits only on events.
- UI_SPEC §6.12: "Metrônomo ♩ 72" in the footer.

---

## Deferred Ideas

- Room metronome (RF51/RF52) reusing the click track.
- Pickup / first-beat offset.
- Editing "ligar ao abrir".
- Device verification of the audio fixes (background-playback feature).
