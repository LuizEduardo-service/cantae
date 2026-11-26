import 'package:flutter/widgets.dart';

import '../../domain/entities/custom_naipe.dart';
import '../../domain/entities/naipe.dart';
import '../../domain/entities/song_track.dart';
import 'voice_part_badge.dart';

/// pt-BR display name of a naipe ("Baixo", not "bass"). A `custom` naipe
/// without a name (the metronome click) reads "Outro naipe".
///
/// The app's only naipe → name mapping (track-upload T9).
String naipeDisplayName(Naipe naipe) {
  switch (naipe) {
    case Naipe.soprano:
      return 'Soprano';
    case Naipe.contralto:
      return 'Contralto';
    case Naipe.tenor:
      return 'Tenor';
    case Naipe.bass:
      return 'Baixo';
    case Naipe.custom:
      return 'Outro naipe';
  }
}

/// A naipe's name, preferring the custom naipe's own name.
String naipeLabel(Naipe naipe, {CustomNaipe? customNaipe}) =>
    customNaipe?.name ?? naipeDisplayName(naipe);

/// A track's name: "Playback", the custom naipe's name or the naipe's.
String trackDisplayName(SongTrack track) => track.isPlayback
    ? 'Playback'
    : naipeLabel(track.naipe, customNaipe: track.customNaipe);

/// The [VoicePart] whose color and letter a [VoicePartBadge] shows.
VoicePart voicePartForNaipe(Naipe naipe) {
  switch (naipe) {
    case Naipe.soprano:
      return VoicePart.soprano;
    case Naipe.contralto:
      return VoicePart.contralto;
    case Naipe.tenor:
      return VoicePart.tenor;
    case Naipe.bass:
      return VoicePart.baixo;
    case Naipe.custom:
      return VoicePart.todos;
  }
}

/// The badge for a naipe: the standard naipe's color and letter, or the
/// neutral badge with the custom naipe's initial (UPL-16).
class NaipeBadge extends StatelessWidget {
  const NaipeBadge({
    super.key,
    required this.naipe,
    this.customNaipe,
    this.missing = false,
    this.size = 22,
  });

  final Naipe naipe;
  final CustomNaipe? customNaipe;

  /// Dashed "no track yet" outline (standard naipes only).
  final bool missing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final custom = customNaipe;
    if (custom != null) {
      return VoicePartBadge(
        variant: VoicePartBadgeVariant.custom,
        glyph: custom.name.trim().characters.first.toUpperCase(),
        size: size,
      );
    }
    return VoicePartBadge(
      variant: missing
          ? VoicePartBadgeVariant.missing
          : VoicePartBadgeVariant.filled,
      part: voicePartForNaipe(naipe),
      size: size,
    );
  }
}
