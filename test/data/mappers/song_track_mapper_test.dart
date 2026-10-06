import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/mappers/song_track_mapper.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

void main() {
  group('SongTrackMapper', () {
    test('round trips a regular track (isPlaybackSlot: false)', () {
      const track = SongTrack(
        id: 'track-1',
        filePath: 'soprano.mp3',
        naipe: Naipe.soprano,
        startDelayMs: 350,
      );

      final companion = SongTrackMapper.toCompanion(
        track,
        songId: 'song-1',
        isPlaybackSlot: false,
      );
      final row = SongTracksTableData(
        id: companion.id.value,
        songId: companion.songId.value,
        filePath: companion.filePath.value,
        naipe: companion.naipe.value,
        startDelayMs: companion.startDelayMs.value,
        isPlayback: companion.isPlayback.value,
        isPlaybackSlot: companion.isPlaybackSlot.value,
      );
      final roundTripped = SongTrackMapper.fromRow(row);

      expect(roundTripped.id, equals(track.id));
      expect(roundTripped.filePath, equals(track.filePath));
      expect(roundTripped.naipe, equals(track.naipe));
      expect(roundTripped.startDelayMs, equals(track.startDelayMs));
      expect(roundTripped.isPlayback, equals(track.isPlayback));
      expect(row.isPlaybackSlot, isFalse);
    });

    test('round trips the designated playback-slot row (isPlaybackSlot: true)', () {
      const track = SongTrack(
        id: 'track-pb',
        filePath: 'playback.mp3',
        naipe: Naipe.custom,
        isPlayback: true,
      );

      final companion = SongTrackMapper.toCompanion(
        track,
        songId: 'song-1',
        isPlaybackSlot: true,
      );

      expect(companion.isPlaybackSlot.value, isTrue);
      expect(companion.isPlayback.value, isTrue);
    });

    test('isPlaybackSlot is driven by the caller flag, not SongTrack.isPlayback', () {
      const track = SongTrack(
        id: 'track-2',
        filePath: 'a.mp3',
        naipe: Naipe.tenor,
        isPlayback: true,
      );

      final notSlot = SongTrackMapper.toCompanion(
        track,
        songId: 'song-1',
        isPlaybackSlot: false,
      );

      expect(notSlot.isPlaybackSlot.value, isFalse);
      expect(notSlot.isPlayback.value, isTrue);
    });

    test('round trips every Naipe value', () {
      for (final naipe in Naipe.values) {
        final track = SongTrack(id: 'track-${naipe.name}', filePath: 'x.mp3', naipe: naipe);
        final companion = SongTrackMapper.toCompanion(
          track,
          songId: 'song-1',
          isPlaybackSlot: false,
        );
        final row = SongTracksTableData(
          id: companion.id.value,
          songId: companion.songId.value,
          filePath: companion.filePath.value,
          naipe: companion.naipe.value,
          startDelayMs: companion.startDelayMs.value,
          isPlayback: companion.isPlayback.value,
          isPlaybackSlot: companion.isPlaybackSlot.value,
        );

        expect(SongTrackMapper.fromRow(row).naipe, equals(naipe));
      }
    });
  });
}
