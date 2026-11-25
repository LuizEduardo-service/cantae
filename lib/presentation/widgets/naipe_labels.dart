import '../../domain/entities/naipe.dart';
import 'voice_part_badge.dart';

/// pt-BR display name of a naipe ("Baixo", not "bass"). `custom` has no
/// fixed name.
///
/// Shared by the solo-player widgets. `TrackAlignRow`, `LyricLineRow` and
/// `SongRow` still keep private copies of this mapping (known duplication).
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
      return '';
  }
}

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
