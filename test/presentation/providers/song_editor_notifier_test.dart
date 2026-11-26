import 'dart:async';

import 'package:cantae/data/library/song_tracks_saver.dart';
import 'package:cantae/data/library/track_file_inspector.dart';
import 'package:cantae/data/repositories/drift_song_repository.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/library/audio_file_check.dart';
import 'package:cantae/domain/library/track_file_picker.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:cantae/presentation/providers/library_providers.dart';
import 'package:cantae/presentation/providers/song_editor_notifier.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/providers/track_upload_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (UPL-02..09, 11..15, 18..21, 23):
// - a new song does not start with the 4 naipes + Playback, or an existing
//   song loses its saved tracks, custom naipes or untouched tracks;
// - not found, a read error or a received song still lets the person edit;
// - a rejected file replaces the slot's current file, or shows no message;
// - cancelling the picker changes something; a picker failure is silent;
// - a slow first file finishes after a second one and wins;
// - a 5th custom naipe, a reserved or duplicate name gets added;
// - removing a custom naipe row deletes it from the device list;
// - the screen reports unsaved changes before any change, or not after one;
// - save is allowed with an invalid name or while a file is checked, runs
//   twice on a double tap, drops kept tracks, keeps a removed track, or
//   does not refresh the library;
// - a failed save is silent or clears the person's changes.
class FakePicker implements TrackFilePicker {
  final results = <Result<PickedTrackFile?, StorageFailure>>[];
  int released = 0;

  void next(String name) => results
      .add(Result.success(PickedTrackFile(path: '/in/$name', name: name)));

  @override
  Future<Result<PickedTrackFile?, StorageFailure>> pick() async =>
      results.removeAt(0);

  @override
  Future<void> releaseTemporaryFiles() async => released++;
}

class FakeInspector implements TrackFileInspector {
  final pending =
      <String, Completer<Result<InspectedTrackFile, ValidationFailure>>>{};
  final rejections = <String, String>{};
  bool holdAll = false;

  static InspectedTrackFile fileFor(String name) => InspectedTrackFile(
        sourcePath: '/in/$name',
        name: name,
        sizeBytes: 12 * 1024 * 1024 + 400 * 1024,
        sha256: 'sha-$name',
        format: AudioFormat.mp3,
      );

  void release(String name) =>
      pending.remove(name)!.complete(Result.success(fileFor(name)));

  @override
  Future<Result<InspectedTrackFile, ValidationFailure>> inspect(
    PickedTrackFile file,
  ) {
    final code = rejections[file.name];
    if (code != null) {
      return Future.value(Result.failure(ValidationFailure(code: code)));
    }
    if (!holdAll) return Future.value(Result.success(fileFor(file.name)));
    final completer =
        Completer<Result<InspectedTrackFile, ValidationFailure>>();
    pending[file.name] = completer;
    return completer.future;
  }
}

class FakeSaver implements SongTracksSaver {
  final requests = <SongSaveRequest>[];
  Failure? failWith;
  Completer<void>? gate;

  @override
  Future<Result<Song, Failure>> save(SongSaveRequest request) async {
    requests.add(request);
    if (gate != null) await gate!.future;
    final failure = failWith;
    if (failure != null) return Result.failure(failure);
    return Result.success(
      Song(id: request.songId, name: request.name, author: request.author),
    );
  }
}

const solista = CustomNaipe(id: 'n-solista', name: 'Solista');
const mezzo = CustomNaipe(id: 'n-mezzo', name: 'Mezzo');

const savedSoprano = SongTrack(
  id: 'sop',
  filePath: '/lib/sop.mp3',
  naipe: Naipe.soprano,
  startDelayMs: 400,
  fileName: 'soprano.mp3',
  fileSizeBytes: 2097152,
);
const savedTenor = SongTrack(
  id: 'ten',
  filePath: '/lib/ten.mp3',
  naipe: Naipe.tenor,
  startDelayMs: 900,
);
const savedSolista = SongTrack(
  id: 'sol',
  filePath: '/lib/sol.mp3',
  naipe: Naipe.custom,
  customNaipe: solista,
);
const metronome = SongTrack(
  id: 'legacy',
  filePath: '/lib/legacy.mp3',
  naipe: Naipe.custom,
);

Song aveSong({SongOrigin origin = SongOrigin.created}) => Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      origin: origin,
      tracks: const [savedSoprano, savedTenor, savedSolista, metronome],
      playbackTrack: const SongTrack(
        id: 'pb',
        filePath: '/lib/pb.mp3',
        naipe: Naipe.custom,
        isPlayback: true,
      ),
    );

const soprano = TrackSlot.standard(Naipe.soprano);
const tenor = TrackSlot.standard(Naipe.tenor);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late FakePicker picker;
  late FakeInspector inspector;
  late FakeSaver saver;
  late ProviderContainer container;
  var ids = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    picker = FakePicker();
    inspector = FakeInspector();
    saver = FakeSaver();
    ids = 0;
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      trackFilePickerProvider.overrideWithValue(picker),
      trackFileInspectorProvider.overrideWithValue(inspector),
      songTracksSaverProvider.overrideWithValue(saver),
      newIdProvider.overrideWithValue(() => 'new-${ids++}'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seed(Song song) async {
    await DriftSongRepository(db).save(song);
  }

  /// Keeps the autoDispose provider alive and waits until it settles.
  Future<SongEditorNotifier> open(String? songId) async {
    container.listen(songEditorProvider(songId), (_, __) {});
    for (var i = 0; i < 50; i++) {
      final state = container.read(songEditorProvider(songId));
      if (state.status != SongEditorStatus.loading &&
          state.customNaipesLoaded) {
        break;
      }
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(songEditorProvider(songId).notifier);
  }

  SongEditorState stateOf(String? songId) =>
      container.read(songEditorProvider(songId));

  TrackSlotState slotOf(String? id, TrackSlot slot) =>
      stateOf(id).slots.firstWhere((s) => s.slot == slot);

  group('loading', () {
    test('a new song starts ready with 4 empty naipes and the Playback',
        () async {
      await open(null);
      final state = stateOf(null);

      expect(state.status, SongEditorStatus.ready);
      expect(state.isNew, isTrue);
      expect(state.slots.map((s) => s.slot), [
        const TrackSlot.standard(Naipe.soprano),
        const TrackSlot.standard(Naipe.contralto),
        const TrackSlot.standard(Naipe.tenor),
        const TrackSlot.standard(Naipe.bass),
        const TrackSlot.playback(),
      ]);
      expect(state.slots.every((s) => s.current == null), isTrue);
      expect(state.isDirty, isFalse);
      expect(state.canSave, isFalse, reason: 'the name is still empty');
    });

    test('an existing song loads its tracks, Playback and custom naipes',
        () async {
      await seed(aveSong());
      await open('ave');
      final state = stateOf('ave');

      expect(state.status, SongEditorStatus.ready);
      expect(state.name, 'Ave Verum Corpus');
      expect(state.author, 'Mozart');
      expect(slotOf('ave', soprano).saved!.id, 'sop');
      expect(slotOf('ave', tenor).saved!.id, 'ten');
      expect(slotOf('ave', const TrackSlot.playback()).saved!.id, 'pb');
      expect(slotOf('ave', const TrackSlot.custom(solista)).saved!.id, 'sol');
      expect(state.isDirty, isFalse);
    });

    test('a missing song is notFound', () async {
      await open('sumiu');
      expect(stateOf('sumiu').status, SongEditorStatus.notFound);
    });

    test('a read error shows error', () async {
      await seed(aveSong());
      await db.close();
      await open('ave');
      expect(stateOf('ave').status, SongEditorStatus.error);
    });

    test('a received song is read-only', () async {
      await seed(aveSong(origin: SongOrigin.received));
      await open('ave');
      expect(stateOf('ave').status, SongEditorStatus.readOnly);
    });

    test('the device custom naipes not in the song are offered', () async {
      await seed(const Song(
        id: 'outra',
        name: 'Aleluia',
        author: '',
        tracks: [
          SongTrack(
            id: 'm',
            filePath: '/m.mp3',
            naipe: Naipe.custom,
            customNaipe: mezzo,
          ),
        ],
      ));
      await seed(aveSong());
      await open('ave');

      expect(stateOf('ave').addableCustomNaipes, [mezzo]);
    });
  });

  group('picking a file', () {
    test('a valid file goes checking → chosen and marks the song changed',
        () async {
      final notifier = await open(null);
      inspector.holdAll = true;
      picker.next('soprano.mp3');

      final picking = notifier.pickFor(soprano);
      await Future<void>.delayed(Duration.zero);
      expect(slotOf(null, soprano).checking, isTrue);

      inspector.release('soprano.mp3');
      await picking;
      expect(slotOf(null, soprano).checking, isFalse);
      expect(slotOf(null, soprano).chosen!.name, 'soprano.mp3');
      expect(stateOf(null).isDirty, isTrue);
    });

    for (final entry in {
      'track_file_unsupported':
          'Este arquivo não é um áudio aceito (MP3, M4A ou WAV).',
      'track_file_too_large': 'Arquivo maior que 100 MB.',
      'track_file_empty': 'Não foi possível ler este arquivo.',
      'track_file_unreadable': 'Não foi possível ler este arquivo.',
    }.entries) {
      test('${entry.key} keeps the current file and shows the message',
          () async {
        await seed(aveSong());
        final notifier = await open('ave');
        picker.next('ruim.mp3');
        inspector.rejections['ruim.mp3'] = entry.key;

        await notifier.pickFor(soprano);

        final slot = slotOf('ave', soprano);
        expect(slot.error, entry.value);
        expect(slot.saved!.id, 'sop');
        expect(slot.current, same(slot.saved));
        expect(slot.chosen, isNull);
        expect(stateOf('ave').isDirty, isFalse);
      });
    }

    test('cancelling the picker changes nothing', () async {
      final notifier = await open(null);
      picker.results.add(const Result.success(null));

      await notifier.pickFor(soprano);

      expect(slotOf(null, soprano).current, isNull);
      expect(slotOf(null, soprano).error, isNull);
      expect(stateOf(null).isDirty, isFalse);
    });

    test('a picker failure shows "Não foi possível abrir os arquivos."',
        () async {
      final notifier = await open(null);
      picker.results.add(Result.failure(StorageFailure(code: 'picker_failed')));

      await notifier.pickFor(soprano);

      expect(stateOf(null).pickerError, 'Não foi possível abrir os arquivos.');
      expect(slotOf(null, soprano).current, isNull);
    });

    test('a second file picked while the first is checked wins', () async {
      final notifier = await open(null);
      inspector.holdAll = true;
      picker
        ..next('primeiro.mp3')
        ..next('segundo.mp3');

      final first = notifier.pickFor(soprano);
      await Future<void>.delayed(Duration.zero);
      final second = notifier.pickFor(soprano);
      await Future<void>.delayed(Duration.zero);
      inspector.release('segundo.mp3');
      await second;
      inspector.release('primeiro.mp3');
      await first;

      expect(slotOf(null, soprano).chosen!.name, 'segundo.mp3');
      expect(slotOf(null, soprano).checking, isFalse);
    });
  });

  group('custom naipes', () {
    test('choosing an existing custom naipe adds an empty row', () async {
      await seed(const Song(
        id: 'outra',
        name: 'Aleluia',
        author: '',
        tracks: [
          SongTrack(
            id: 'm',
            filePath: '/m.mp3',
            naipe: Naipe.custom,
            customNaipe: mezzo,
          ),
        ],
      ));
      final notifier = await open(null);

      notifier.addCustomNaipe(mezzo);

      expect(slotOf(null, const TrackSlot.custom(mezzo)).current, isNull);
      expect(stateOf(null).addableCustomNaipes, isEmpty);
      expect(stateOf(null).isDirty, isTrue);
    });

    test('creating a valid name adds a row with a new id', () async {
      final notifier = await open(null);

      expect(notifier.createCustomNaipe('  Solista '), isNull);

      final custom = stateOf(null).slots.last.slot.customNaipe!;
      expect(custom.id, 'new-0');
      expect(custom.name, 'Solista');
    });

    test('invalid names are refused with the reason', () async {
      await seed(aveSong());
      final notifier = await open('ave');

      expect(notifier.createCustomNaipe(''), 'Informe o nome do naipe.');
      expect(notifier.createCustomNaipe('a' * 25), 'Use até 24 caracteres.');
      expect(
        notifier.createCustomNaipe('tenor'),
        'Esse nome é de um naipe padrão.',
      );
      expect(
        notifier.createCustomNaipe('SOLISTA'),
        'Já existe um naipe com esse nome.',
      );
      expect(
        stateOf('ave').slots.where((s) => s.slot.customNaipe != null),
        hasLength(1),
      );
    });

    test('a name created in this song but not saved is also a duplicate',
        () async {
      final notifier = await open(null);
      notifier.createCustomNaipe('Solista');

      expect(
        notifier.createCustomNaipe('solista'),
        'Já existe um naipe com esse nome.',
      );
    });

    test('a 5th custom naipe is refused', () async {
      final notifier = await open(null);
      for (final name in ['Solista', 'Mezzo', 'Barítono', 'Descante']) {
        expect(notifier.createCustomNaipe(name), isNull);
      }

      expect(stateOf(null).canAddCustomNaipe, isFalse);
      expect(
        notifier.createCustomNaipe('Quinto'),
        'Até 4 naipes extras por música.',
      );
      expect(
        stateOf(null).slots.where((s) => s.slot.customNaipe != null),
        hasLength(4),
      );
    });

    test('removing a custom row keeps the naipe in the device list', () async {
      await seed(aveSong());
      final notifier = await open('ave');

      notifier.removeCustomSlot(const TrackSlot.custom(solista));

      expect(
        stateOf('ave').slots.any((s) => s.slot.customNaipe == solista),
        isFalse,
      );
      expect(stateOf('ave').addableCustomNaipes, [solista]);
      expect(stateOf('ave').isDirty, isTrue);
    });
  });

  group('name and author', () {
    test('an empty or too long name blocks saving with its message', () async {
      final notifier = await open(null);

      notifier.setName('a' * 81);
      expect(stateOf(null).nameError, 'Use até 80 caracteres.');
      expect(stateOf(null).canSave, isFalse);

      notifier.setName('   ');
      expect(stateOf(null).nameError, 'Informe o nome da música.');
      expect(stateOf(null).canSave, isFalse);

      notifier.setName('Ave Verum Corpus');
      expect(stateOf(null).nameError, isNull);
      expect(stateOf(null).canSave, isTrue);
    });

    test('a too long author blocks saving', () async {
      final notifier = await open(null);
      notifier
        ..setName('Ave')
        ..setAuthor('a' * 81);

      expect(stateOf(null).authorError, 'Use até 80 caracteres.');
      expect(stateOf(null).canSave, isFalse);
    });

    test('saving is blocked while a file is checked', () async {
      final notifier = await open(null);
      notifier.setName('Ave');
      inspector.holdAll = true;
      picker.next('soprano.mp3');

      final picking = notifier.pickFor(soprano);
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(null).canSave, isFalse);

      inspector.release('soprano.mp3');
      await picking;
      expect(stateOf(null).canSave, isTrue);
    });
  });

  group('saving', () {
    test('a new song saves its new files and returns the new id', () async {
      final notifier = await open(null);
      notifier
        ..setName(' Ave Verum Corpus ')
        ..setAuthor('Mozart');
      picker.next('soprano.mp3');
      await notifier.pickFor(soprano);
      notifier.createCustomNaipe('Solista');
      final solistaSlot = stateOf(null).slots.last.slot;
      picker.next('solista.mp3');
      await notifier.pickFor(solistaSlot);

      final id = await notifier.save();

      expect(id, 'new-1');
      final request = saver.requests.single;
      expect(request.songId, 'new-1');
      expect(request.name, 'Ave Verum Corpus');
      expect(request.base, isNull);
      expect(request.tracks.map((t) => t.newFile!.name),
          ['soprano.mp3', 'solista.mp3']);
      expect(request.tracks.last.customNaipe!.name, 'Solista');
      expect(stateOf(null).isDirty, isFalse);
      expect(picker.released, 1);
    });

    test('an existing song keeps untouched tracks, replaces and removes',
        () async {
      await seed(aveSong());
      final notifier = await open('ave');
      picker.next('tenor-novo.mp3');
      await notifier.pickFor(tenor);
      notifier.removeTrack(const TrackSlot.playback());

      expect(await notifier.save(), 'ave');

      final request = saver.requests.single;
      expect(request.base!.id, 'ave');
      final kept = request.tracks
          .where((t) => t.kept != null)
          .map((t) => t.kept!.id)
          .toSet();
      expect(kept, {'sop', 'sol', 'legacy'});
      expect(
        request.tracks.singleWhere((t) => t.newFile != null).naipe,
        Naipe.tenor,
      );
      expect(request.tracks.any((t) => t.isPlayback), isFalse);
    });

    test('removing a saved track marks it removed until saved', () async {
      await seed(aveSong());
      final notifier = await open('ave');

      notifier.removeTrack(soprano);

      final slot = slotOf('ave', soprano);
      expect(slot.removed, isTrue);
      expect(slot.current, isNull);
      expect(stateOf('ave').isDirty, isTrue);
    });

    test('a successful save refreshes the library', () async {
      await seed(aveSong());
      container.listen(songsProvider, (_, __) {});
      expect((await container.read(songsProvider.future)), hasLength(1));
      final notifier = await open(null);
      notifier.setName('Aleluia');
      await DriftSongRepository(db)
          .save(const Song(id: 'new-0', name: 'Aleluia', author: ''));

      await notifier.save();

      expect(await container.read(songsProvider.future), hasLength(2));
    });

    test('a double tap saves once', () async {
      final notifier = await open(null);
      notifier.setName('Ave');
      saver.gate = Completer<void>();

      final first = notifier.save();
      final second = notifier.save();
      expect(stateOf(null).saving, isTrue);
      saver.gate!.complete();

      expect(await second, isNull);
      expect(await first, isNotNull);
      expect(saver.requests, hasLength(1));
    });

    test('a failed save shows the message and keeps the changes', () async {
      final notifier = await open(null);
      notifier.setName('Ave');
      picker.next('soprano.mp3');
      await notifier.pickFor(soprano);
      saver.failWith = StorageFailure(code: 'track_hash_mismatch');

      expect(await notifier.save(), isNull);

      expect(
        stateOf(null).saveError,
        'Não foi possível salvar a música. Tente de novo.',
      );
      expect(stateOf(null).saving, isFalse);
      expect(stateOf(null).isDirty, isTrue);
      expect(slotOf(null, soprano).chosen, isNotNull);
    });

    test('a read-only song never saves', () async {
      await seed(aveSong(origin: SongOrigin.received));
      final notifier = await open('ave');

      expect(await notifier.save(), isNull);
      expect(saver.requests, isEmpty);
    });
  });
}
