import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'fixture_songs.dart';

void main() {
  group('Fixture: completeSong', () {
    test('has exactly 4 tracks with one per standard naipe', () {
      final song = FixtureSongs.completeSong();
      expect(song.tracks.length, equals(4));
      final naipes = song.tracks.map((t) => t.naipe).toSet();
      expect(naipes, containsAll([Naipe.soprano, Naipe.contralto, Naipe.tenor, Naipe.bass]));
    });
  });

  group('Fixture: incompleteSong', () {
    test('has 3 tracks and no tenor', () {
      final song = FixtureSongs.incompleteSong();
      expect(song.tracks.length, equals(3));
      final naipes = song.tracks.map((t) => t.naipe).toList();
      expect(naipes, isNot(contains(Naipe.tenor)));
    });
  });

  group('Fixture: offsetSong', () {
    test('has at least one track with startDelayMs > 0', () {
      final song = FixtureSongs.offsetSong();
      final hasOffset = song.tracks.any((t) => t.startDelayMs > 0);
      expect(hasOffset, isTrue);
    });
  });

  group('Fixture: songWithLyrics', () {
    test('has at least 3 lyric lines each with onsetMs > 0', () {
      final song = FixtureSongs.songWithLyrics();
      expect(song.lyrics.length, greaterThanOrEqualTo(3));
      for (final line in song.lyrics) {
        expect(line.onsetMs, greaterThan(0),
            reason: 'All lyric lines must have a positive onset timestamp');
      }
    });
  });

  group('Fixture: invalidTrackSong', () {
    test('has at least one track with an empty filePath', () {
      final song = FixtureSongs.invalidTrackSong();
      final hasInvalid = song.tracks.any((t) => t.filePath.isEmpty);
      expect(hasInvalid, isTrue);
    });
  });

  group('All fixtures: no I/O or async required', () {
    test('all 5 fixtures instantiate synchronously without throwing', () {
      expect(() => FixtureSongs.completeSong(), returnsNormally);
      expect(() => FixtureSongs.incompleteSong(), returnsNormally);
      expect(() => FixtureSongs.offsetSong(), returnsNormally);
      expect(() => FixtureSongs.songWithLyrics(), returnsNormally);
      expect(() => FixtureSongs.invalidTrackSong(), returnsNormally);
    });
  });
}
