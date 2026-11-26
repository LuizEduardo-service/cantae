# Cadastrar música e enviar faixas Context

**Gathered:** 2026-11-25
**Spec:** `.specs/features/track-upload/spec.md`
**Status:** Ready for design (after spec approval)

---

## Feature Boundary

One screen creates a song (name, author) and manages its tracks: the 4 standard naipes, an optional Playback and up to 4 custom naipes. The same screen edits the tracks of an existing song the person created.

Files are validated by content and size, hashed off the UI thread and copied into the content-addressed library. The Studio, recording and custom-naipe list management are out of scope.

---

## Implementation Decisions

### Scope
- Create the song and its tracks. Existing songs open the same screen for their tracks.

### File picker
- Add the `file_picker` package. This amends AD-004 and needs a new AD entry at Design.

### Extras
- Playback is optional, one per song.
- Custom naipes take a free name and are reusable across songs (a device-level list).
- Custom naipes use a neutral badge with the initial.

---

## Deferred Ideas

- Rename or delete custom naipes from the device list.
- Let a custom naipe own lyric lines.
- Per-custom-naipe colours.
- Clean up library files no track uses (Privacy screen).
