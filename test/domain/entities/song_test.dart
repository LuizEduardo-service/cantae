import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';

SongTrack _track(Naipe naipe, {bool isPlayback = false}) => SongTrack(
      id: 'track-${naipe.name}${isPlayback ? '-pb' : ''}',
      filePath: '${naipe.name}.mp3',
      naipe: naipe,
      isPlayback: isPlayback,
    );

void main() {
  group('Song.isComplete', () {
    test('all four standard naipes present returns true', () {
      final song = Song(
        id: 's1',
        name: 'Full',
        author: 'A',
        tracks: [
          _track(Naipe.soprano),
          _track(Naipe.contralto),
          _track(Naipe.tenor),
          _track(Naipe.bass),
        ],
      );
      expect(song.isComplete, isTrue);
    });

    test('missing soprano returns false', () {
      final song = Song(
        id: 's1',
        name: 'No S',
        author: 'A',
        tracks: [_track(Naipe.contralto), _track(Naipe.tenor), _track(Naipe.bass)],
      );
      expect(song.isComplete, isFalse);
    });

    test('missing contralto returns false', () {
      final song = Song(
        id: 's1',
        name: 'No C',
        author: 'A',
        tracks: [_track(Naipe.soprano), _track(Naipe.tenor), _track(Naipe.bass)],
      );
      expect(song.isComplete, isFalse);
    });

    test('missing tenor returns false', () {
      final song = Song(
        id: 's1',
        name: 'No T',
        author: 'A',
        tracks: [_track(Naipe.soprano), _track(Naipe.contralto), _track(Naipe.bass)],
      );
      expect(song.isComplete, isFalse);
    });

    test('missing bass returns false', () {
      final song = Song(
        id: 's1',
        name: 'No B',
        author: 'A',
        tracks: [_track(Naipe.soprano), _track(Naipe.contralto), _track(Naipe.tenor)],
      );
      expect(song.isComplete, isFalse);
    });

    test('custom naipe only returns false', () {
      final song = Song(
        id: 's1',
        name: 'Custom only',
        author: 'A',
        tracks: [_track(Naipe.custom)],
      );
      expect(song.isComplete, isFalse);
    });

    test('playback track does not count toward completeness', () {
      final song = Song(
        id: 's1',
        name: 'Pb only',
        author: 'A',
        tracks: [
          _track(Naipe.soprano, isPlayback: true),
          _track(Naipe.contralto, isPlayback: true),
          _track(Naipe.tenor, isPlayback: true),
          _track(Naipe.bass, isPlayback: true),
        ],
      );
      expect(song.isComplete, isFalse);
    });

    test('duplicate soprano but no tenor returns false', () {
      final song = Song(
        id: 's1',
        name: 'Dupe S',
        author: 'A',
        tracks: [
          _track(Naipe.soprano),
          SongTrack(id: 'track-s2', filePath: 's2.mp3', naipe: Naipe.soprano),
          _track(Naipe.contralto),
          _track(Naipe.bass),
        ],
      );
      expect(song.isComplete, isFalse);
    });

    test('empty track list returns false', () {
      const song = Song(id: 's1', name: 'Empty', author: 'A');
      expect(song.isComplete, isFalse);
    });
  });
}
