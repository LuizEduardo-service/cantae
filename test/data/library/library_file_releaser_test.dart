import 'dart:io';

import 'package:cantae/data/library/library_file_releaser.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Failure modes (library files no track uses any more):
// - a file another song still uses (track or Playback) is deleted;
// - a file outside the library folder (the user's own file) is deleted;
// - a file that is already gone raises an error;
// - one file that cannot be deleted stops the others from being deleted;
// - the songs cannot be read, and files are deleted without knowing who
//   uses them;
// - the library folder cannot be found, and the error reaches the save
//   that already succeeded.
class _Songs implements SongRepository {
  _Songs(this.result);
  Result<List<Song>, StorageFailure> result;

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Song _song(String id, {List<String> tracks = const [], String? playback}) =>
    Song(
      id: id,
      name: id,
      author: '',
      tracks: [
        for (final (i, path) in tracks.indexed)
          SongTrack(id: '$id-$i', filePath: path, naipe: Naipe.soprano),
      ],
      playbackTrack: playback == null
          ? null
          : SongTrack(
              id: '$id-pb',
              filePath: playback,
              naipe: Naipe.soprano,
              isPlayback: true,
            ),
    );

void main() {
  late Directory dir;
  late Directory root;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cantae_releaser');
    root = Directory(p.join(dir.path, 'library', 'tracks'))
      ..createSync(recursive: true);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String libraryFile(String name) =>
      (File(p.join(root.path, name))..writeAsStringSync(name)).path;

  LibraryFileReleaser releaser(
    _Songs songs, {
    Future<void> Function(File file)? deleteFile,
  }) =>
      LibraryFileReleaser(
        repository: songs,
        resolveRoot: () async => root,
        deleteFile: deleteFile,
      );

  test('deletes a library file no song uses', () async {
    final old = libraryFile('aaa.mp3');
    final songs = _Songs(Result.success([_song('s1')]));

    expect(await releaser(songs).release([old]), 1);
    expect(File(old).existsSync(), isFalse);
  });

  test('keeps a file another song still uses as a track or Playback', () async {
    final shared = libraryFile('shared.mp3');
    final playback = libraryFile('pb.mp3');
    final songs = _Songs(Result.success([
      _song('s2', tracks: [shared], playback: playback),
    ]));

    expect(await releaser(songs).release([shared, playback]), 0);
    expect(File(shared).existsSync(), isTrue);
    expect(File(playback).existsSync(), isTrue);
  });

  test('keeps a file outside the library folder', () async {
    final outside =
        (File(p.join(dir.path, 'minha.mp3'))..writeAsStringSync('x')).path;
    final sneaky = p.join(root.path, '..', 'escape.mp3');
    File(sneaky).writeAsStringSync('x');
    final songs = _Songs(const Result.success([]));

    expect(await releaser(songs).release([outside, sneaky]), 0);
    expect(File(outside).existsSync(), isTrue);
    expect(File(sneaky).existsSync(), isTrue);
  });

  test('ignores a file that is already gone', () async {
    final songs = _Songs(const Result.success([]));

    expect(
      await releaser(songs).release([p.join(root.path, 'gone.mp3')]),
      0,
    );
  });

  test('one file that cannot be deleted does not stop the others', () async {
    final stuck = libraryFile('stuck.mp3');
    final other = libraryFile('other.mp3');
    final songs = _Songs(const Result.success([]));

    final count = await releaser(songs, deleteFile: (file) async {
      if (file.path == stuck) {
        throw const FileSystemException('locked');
      }
      await file.delete();
    }).release([stuck, other]);

    expect(count, 1);
    expect(File(stuck).existsSync(), isTrue);
    expect(File(other).existsSync(), isFalse);
  });

  test('deletes nothing when the songs cannot be read', () async {
    final old = libraryFile('aaa.mp3');
    final songs = _Songs(
      Result.failure(StorageFailure(code: 'song_read_failed')),
    );

    expect(await releaser(songs).release([old]), 0);
    expect(File(old).existsSync(), isTrue);
  });

  test(
      'deletes nothing and does not throw when the library folder cannot '
      'be found', () async {
    final old = libraryFile('aaa.mp3');
    final releaser = LibraryFileReleaser(
      repository: _Songs(const Result.success([])),
      resolveRoot: () async => throw Exception('no documents folder'),
    );

    expect(await releaser.release([old]), 0);
    expect(File(old).existsSync(), isTrue);
  });
}
