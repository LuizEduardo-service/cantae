import 'dart:io';

import 'package:cantae/data/library/song_tracks_saver.dart';
import 'package:cantae/data/library/track_file_importer.dart';
import 'package:cantae/data/library/track_file_inspector.dart';
import 'package:cantae/data/repositories/drift_song_repository.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/library/audio_file_check.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Failure modes (UPL-04, UPL-10, UPL-15, UPL-19):
// - a new song is saved as received, or without its Playback / custom naipe;
// - a kept track loses its delay, or a replaced track keeps the old delay;
// - saving an existing song drops its lyrics, metronome, origin or last
//   rehearsal;
// - the second import fails but the first copy stays in the library;
// - the repository fails but the copies stay in the library;
// - the same file for two naipes is copied twice;
// - a new track has no file name or size.
class _FailingSongRepository implements SongRepository {
  _FailingSongRepository(this._inner);
  final SongRepository _inner;

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async =>
      Result.failure(StorageFailure(code: 'song_save_failed'));

  @override
  dynamic noSuchMethod(Invocation invocation) => _inner;
}

const solista = CustomNaipe(id: 'n-solista', name: 'Solista');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late Directory root;
  late AppDatabase db;
  late DriftSongRepository repository;
  var ids = 0;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cantae_saver');
    root = Directory(p.join(dir.path, 'library', 'tracks'))
      ..createSync(recursive: true);
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftSongRepository(db);
    ids = 0;
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  InspectedTrackFile file(String name, int seed) {
    final bytes = [...'ID3'.codeUnits, ...List<int>.filled(500, seed)];
    final source = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    return InspectedTrackFile(
      sourcePath: source.path,
      name: name,
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      format: AudioFormat.mp3,
    );
  }

  SongTracksSaver saver({
    SongRepository? repo,
    Future<String> Function(String)? hashFile,
  }) =>
      SongTracksSaver(
        repository: repo ?? repository,
        importer: TrackFileImporter(
          resolveRoot: () async => root,
          hashFile: hashFile ?? sha256OfFile,
        ),
        newId: () => 'id-${ids++}',
      );

  Song saved(Result<Song, Failure> r) =>
      r.when(success: (s) => s, failure: (f) => fail(f.code));

  List<String> libraryFiles() =>
      root.listSync().map((e) => p.basename(e.path)).toList();

  test('a new song is saved as created with Soprano, Playback and Solista',
      () async {
    final sop = file('soprano.mp3', 1);
    final result = await saver().save(SongSaveRequest(
      songId: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      base: null,
      tracks: [
        TrackChoice.newFile(naipe: Naipe.soprano, file: sop),
        TrackChoice.newFile(
          naipe: Naipe.custom,
          isPlayback: true,
          file: file('playback.mp3', 2),
        ),
        TrackChoice.newFile(
          naipe: Naipe.custom,
          customNaipe: solista,
          file: file('solista.mp3', 3),
        ),
      ],
    ));

    saved(result);
    final song = (await repository.getById('ave'))
        .when(success: (s) => s, failure: (f) => fail(f.code));
    expect(song.name, 'Ave Verum Corpus');
    expect(song.author, 'Mozart');
    expect(song.origin, SongOrigin.created);
    expect(song.tracks, hasLength(2));
    final soprano = song.tracks.firstWhere((t) => t.naipe == Naipe.soprano);
    expect(soprano.filePath, p.join(root.path, '${sop.sha256}.mp3'));
    expect(soprano.startDelayMs, 0);
    expect(soprano.fileName, 'soprano.mp3');
    expect(soprano.fileSizeBytes, sop.sizeBytes);
    expect(
      song.tracks.firstWhere((t) => t.naipe == Naipe.custom).customNaipe,
      solista,
    );
    expect(song.playbackTrack!.isPlayback, isTrue);
    expect(libraryFiles(), hasLength(3));
  });

  test(
      'an existing song keeps kept delays, zeroes replaced ones and keeps '
      'lyrics, metronome, origin and last rehearsal', () async {
    final rehearsed = DateTime(2026, 11, 20, 19);
    final base = Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      version: '2',
      lastRehearsedAt: rehearsed,
      metronomeConfig: const MetronomeConfig(bpm: 72, beatsPerMeasure: 4),
      lyrics: const [LyricLine(text: 'Ave verum corpus', onsetMs: 1200)],
      tracks: const [
        SongTrack(
          id: 'sop',
          filePath: '/old/sop.mp3',
          naipe: Naipe.soprano,
          startDelayMs: 400,
        ),
        SongTrack(
          id: 'ten',
          filePath: '/old/ten.mp3',
          naipe: Naipe.tenor,
          startDelayMs: 900,
        ),
      ],
    );
    await repository.save(base);

    saved(await saver().save(SongSaveRequest(
      songId: 'ave',
      name: 'Ave Verum Corpus',
      author: 'W. A. Mozart',
      base: base,
      tracks: [
        TrackChoice.kept(base.tracks[0]),
        TrackChoice.newFile(naipe: Naipe.tenor, file: file('tenor2.mp3', 4)),
      ],
    )));

    final song = (await repository.getById('ave'))
        .when(success: (s) => s, failure: (f) => fail(f.code));
    final soprano = song.tracks.firstWhere((t) => t.naipe == Naipe.soprano);
    final tenor = song.tracks.firstWhere((t) => t.naipe == Naipe.tenor);
    expect(soprano.id, 'sop');
    expect(soprano.startDelayMs, 400);
    expect(tenor.id, isNot('ten'));
    expect(tenor.startDelayMs, 0);
    expect(tenor.fileName, 'tenor2.mp3');
    expect(song.author, 'W. A. Mozart');
    expect(song.version, '2');
    expect(song.lyrics.single.text, 'Ave verum corpus');
    expect(song.metronomeConfig!.bpm, 72);
    expect(song.lastRehearsedAt, rehearsed);
    expect(song.origin, SongOrigin.created);
  });

  test(
      'when the second import fails, the first copy is removed and nothing '
      'is saved', () async {
    final sop = file('soprano.mp3', 1);
    final ten = file('tenor.mp3', 2);
    final result = await saver(
      hashFile: (path) async =>
          path.contains(ten.sha256) ? 'corrompido' : sha256OfFile(path),
    ).save(SongSaveRequest(
      songId: 'ave',
      name: 'Ave Verum Corpus',
      author: '',
      base: null,
      tracks: [
        TrackChoice.newFile(naipe: Naipe.soprano, file: sop),
        TrackChoice.newFile(naipe: Naipe.tenor, file: ten),
      ],
    ));

    expect(result.isFailure, isTrue);
    expect(libraryFiles(), isEmpty);
    expect((await repository.getById('ave')).isFailure, isTrue);
  });

  test('when the repository fails, the copies are removed', () async {
    final result = await saver(repo: _FailingSongRepository(repository)).save(
      SongSaveRequest(
        songId: 'ave',
        name: 'Ave Verum Corpus',
        author: '',
        base: null,
        tracks: [
          TrackChoice.newFile(
            naipe: Naipe.soprano,
            file: file('soprano.mp3', 1),
          ),
        ],
      ),
    );

    expect(
      result.when(success: (_) => null, failure: (f) => f.code),
      'song_save_failed',
    );
    expect(libraryFiles(), isEmpty);
  });

  test('the same file for two naipes is stored once', () async {
    final same = file('coro.mp3', 9);
    saved(await saver().save(SongSaveRequest(
      songId: 'ave',
      name: 'Ave Verum Corpus',
      author: '',
      base: null,
      tracks: [
        TrackChoice.newFile(naipe: Naipe.soprano, file: same),
        TrackChoice.newFile(naipe: Naipe.contralto, file: same),
      ],
    )));

    expect(libraryFiles(), ['${same.sha256}.mp3']);
    final song = (await repository.getById('ave'))
        .when(success: (s) => s, failure: (f) => fail(f.code));
    expect(song.tracks.map((t) => t.filePath).toSet(), hasLength(1));
  });
}
