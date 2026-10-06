import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/mappers/song_mapper.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

SongsTableData _row(SongsTableCompanion companion) => SongsTableData(
      id: companion.id.value,
      name: companion.name.value,
      author: companion.author.value,
      version: companion.version.value,
      metronomeBpm: companion.metronomeBpm.present ? companion.metronomeBpm.value : null,
      metronomeBeatsPerMeasure: companion.metronomeBeatsPerMeasure.present
          ? companion.metronomeBeatsPerMeasure.value
          : null,
      metronomeDownbeatAccent: companion.metronomeDownbeatAccent.present
          ? companion.metronomeDownbeatAccent.value
          : null,
      metronomeEnabledByDefault: companion.metronomeEnabledByDefault.present
          ? companion.metronomeEnabledByDefault.value
          : null,
    );

void main() {
  group('SongMapper', () {
    test('round trips id/name/author/version with metronomeConfig null (LIB-10)', () {
      const song = Song(id: 's1', name: 'Song', author: 'Author', version: '1.0');

      final companion = SongMapper.toCompanion(song);
      final row = _row(companion);
      final roundTripped = SongMapper.fromRow(row, tracks: const [], lyrics: const [], playbackTrack: null);

      expect(roundTripped.id, equals(song.id));
      expect(roundTripped.name, equals(song.name));
      expect(roundTripped.author, equals(song.author));
      expect(roundTripped.version, equals(song.version));
      expect(roundTripped.metronomeConfig, isNull);
      expect(row.metronomeBpm, isNull);
      expect(row.metronomeBeatsPerMeasure, isNull);
      expect(row.metronomeDownbeatAccent, isNull);
      expect(row.metronomeEnabledByDefault, isNull);
    });

    test('round trips a present metronomeConfig with all 4 fields exact', () {
      const song = Song(
        id: 's2',
        name: 'Song 2',
        author: 'Author',
        metronomeConfig: MetronomeConfig(
          bpm: 90,
          beatsPerMeasure: 3,
          downbeatAccent: false,
          enabledByDefault: true,
        ),
      );

      final companion = SongMapper.toCompanion(song);
      final row = _row(companion);
      final roundTripped = SongMapper.fromRow(row, tracks: const [], lyrics: const [], playbackTrack: null);

      expect(roundTripped.metronomeConfig, isNotNull);
      expect(roundTripped.metronomeConfig!.bpm, equals(90));
      expect(roundTripped.metronomeConfig!.beatsPerMeasure, equals(3));
      expect(roundTripped.metronomeConfig!.downbeatAccent, isFalse);
      expect(roundTripped.metronomeConfig!.enabledByDefault, isTrue);
    });
  });
}
