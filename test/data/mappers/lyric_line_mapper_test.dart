import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/mappers/lyric_line_mapper.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

LyricLinesTableData _row(LyricLinesTableCompanion companion) => LyricLinesTableData(
      rowId: 1,
      songId: companion.songId.value,
      lyricText: companion.lyricText.value,
      onsetMs: companion.onsetMs.value,
      naipe: companion.naipe.present ? companion.naipe.value : null,
      dynamics: companion.dynamics.present ? companion.dynamics.value : null,
    );

void main() {
  group('LyricLineMapper', () {
    test('round trips a line with naipe and dynamics present', () {
      const line = LyricLine(
        text: 'First line of the song',
        onsetMs: 1000,
        naipe: Naipe.soprano,
        dynamics: 'forte',
      );

      final companion = LyricLineMapper.toCompanion(line, songId: 'song-1');
      final roundTripped = LyricLineMapper.fromRow(_row(companion));

      expect(roundTripped.text, equals(line.text));
      expect(roundTripped.onsetMs, equals(line.onsetMs));
      expect(roundTripped.naipe, equals(line.naipe));
      expect(roundTripped.dynamics, equals(line.dynamics));
    });

    test('round trips a line with both nullable fields null', () {
      const line = LyricLine(text: 'No naipe, no dynamics', onsetMs: 500);

      final companion = LyricLineMapper.toCompanion(line, songId: 'song-1');
      final roundTripped = LyricLineMapper.fromRow(_row(companion));

      expect(roundTripped.naipe, isNull);
      expect(roundTripped.dynamics, isNull);
      expect(roundTripped.text, equals(line.text));
      expect(roundTripped.onsetMs, equals(line.onsetMs));
    });

    test('round trips naipe null with dynamics present', () {
      const line = LyricLine(text: 'Only dynamics', onsetMs: 200, dynamics: 'piano');

      final companion = LyricLineMapper.toCompanion(line, songId: 'song-1');
      final roundTripped = LyricLineMapper.fromRow(_row(companion));

      expect(roundTripped.naipe, isNull);
      expect(roundTripped.dynamics, equals('piano'));
    });
  });
}
