import 'package:cantae/data/repositories/drift_custom_naipe_repository.dart';
import 'package:cantae/data/repositories/drift_song_repository.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (UPL-15, UPL-16, UPL-19):
// - the custom naipe of a track is lost on reload (name blank);
// - the picked file name and size are not stored;
// - using the same custom naipe in two songs stores it twice, or the second
//   save fails on the unique name;
// - the device list loses a custom naipe when its last song is deleted;
// - the device list comes back unsorted;
// - getAll resolves custom naipes for the first song only;
// - a database error escapes as an exception instead of a StorageFailure.
const solista = CustomNaipe(id: 'n-solista', name: 'Solista');
const mezzo = CustomNaipe(id: 'n-mezzo', name: 'Mezzo');

Song _song(String id, {List<CustomNaipe> extras = const [solista]}) => Song(
      id: id,
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      tracks: [
        SongTrack(
          id: 'sop-$id',
          filePath: '/library/tracks/a.mp3',
          naipe: Naipe.soprano,
          startDelayMs: 400,
          fileName: 'soprano.mp3',
          fileSizeBytes: 2097152,
        ),
        for (final extra in extras)
          SongTrack(
            id: '${extra.id}-$id',
            filePath: '/library/tracks/b.mp3',
            naipe: Naipe.custom,
            customNaipe: extra,
            fileName: '${extra.name.toLowerCase()}.mp3',
            fileSizeBytes: 1024,
          ),
      ],
    );

T valueOf<T>(Result<T, Failure> r) =>
    r.when(success: (v) => v, failure: (f) => throw StateError(f.code));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftSongRepository songs;
  late DriftCustomNaipeRepository naipes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    songs = DriftSongRepository(db);
    naipes = DriftCustomNaipeRepository(db);
  });

  tearDown(() => db.close());

  test('a custom naipe track round-trips its naipe, file name and size',
      () async {
    expect((await songs.save(_song('ave'))).isSuccess, isTrue);

    final song = valueOf(await songs.getById('ave'));
    final soprano = song.tracks.firstWhere((t) => t.naipe == Naipe.soprano);
    expect(soprano.customNaipe, isNull);
    expect(soprano.fileName, 'soprano.mp3');
    expect(soprano.fileSizeBytes, 2097152);
    expect(soprano.startDelayMs, 400);

    final extra = song.tracks.firstWhere((t) => t.naipe == Naipe.custom);
    expect(extra.customNaipe, solista);
    expect(extra.customNaipe!.name, 'Solista');
    expect(extra.fileName, 'solista.mp3');
    expect(extra.fileSizeBytes, 1024);
  });

  test('the same custom naipe in two songs is stored once', () async {
    expect((await songs.save(_song('ave'))).isSuccess, isTrue);
    expect((await songs.save(_song('aleluia'))).isSuccess, isTrue);

    final rows = await db.select(db.customNaipesTable).get();
    expect(rows.map((r) => r.id), ['n-solista']);
    expect(rows.single.nameKey, 'solista');
  });

  test('saving a song again keeps its custom naipe', () async {
    await songs.save(_song('ave'));
    expect((await songs.save(_song('ave'))).isSuccess, isTrue);

    final song = valueOf(await songs.getById('ave'));
    expect(song.tracks.where((t) => t.customNaipe == solista), hasLength(1));
  });

  test('the device list is sorted by name and outlives deleted songs',
      () async {
    await songs.save(_song('ave', extras: const [solista, mezzo]));
    await songs.delete('ave');

    final list = valueOf(await naipes.getAll());
    expect(list.map((n) => n.name), ['Mezzo', 'Solista']);
  });

  test('getAll resolves the custom naipes of every song', () async {
    await songs.save(_song('ave'));
    await songs.save(_song('aleluia', extras: const [mezzo]));

    final all = valueOf(await songs.getAll());
    final byId = {for (final s in all) s.id: s};
    String extraName(String id) => byId[id]!
        .tracks
        .firstWhere((t) => t.naipe == Naipe.custom)
        .customNaipe!
        .name;
    expect(extraName('ave'), 'Solista');
    expect(extraName('aleluia'), 'Mezzo');
  });

  test('a database error is a StorageFailure, never an exception', () async {
    // Open the database first: closing one that never opened lets the next
    // query open a fresh, empty one.
    await naipes.getAll();
    await db.close();

    final result = await naipes.getAll();
    expect(
      result.when(success: (_) => null, failure: (f) => f),
      isA<StorageFailure>()
          .having((f) => f.code, 'code', 'custom_naipe_read_failed'),
    );
  });
}
