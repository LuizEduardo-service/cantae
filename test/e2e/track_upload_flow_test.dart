// End-to-end flow for track-upload (UPL-01, 04, 07, 15, 17, 19, 22).
//
// Real pieces: the app router, every screen and notifier, the drift
// database (in memory), the file inspector (Isolate.run + SHA-256) and the
// importer (copy + verify) on a temporary library folder. Only the system
// file chooser is replaced, since it needs a person.
//
// Artifact: the test prints the saved song and the library folder listing.
import 'dart:convert';
import 'dart:io';

import 'package:cantae/data/library/track_file_importer.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/library/track_file_picker.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/providers/track_upload_providers.dart';
import 'package:cantae/presentation/routing/app_router.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Hands out files from [dir] in order, like a person picking them.
class _QueuedPicker implements TrackFilePicker {
  _QueuedPicker(this.dir);

  final Directory dir;
  final queue = <String>[];

  @override
  Future<Result<PickedTrackFile?, StorageFailure>> pick() async {
    final name = queue.removeAt(0);
    return Result.success(
      PickedTrackFile(path: p.join(dir.path, name), name: name),
    );
  }

  @override
  Future<void> releaseTemporaryFiles() async {}
}

List<int> _mp3(int seed) =>
    [...ascii.encode('ID3'), 3, 0, ...List<int>.filled(4000, seed)];

List<int> _wav(int seed) => [
      ...ascii.encode('RIFF'),
      0x24, 0, 0, 0, //
      ...ascii.encode('WAVEfmt '),
      ...List<int>.filled(4000, seed),
    ];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
      'create a song, refuse a fake mp3, add Solista, then send the '
      'Tenor from the detail', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final temp = Directory.systemTemp.createTempSync('cantae_e2e_upload');
    addTearDown(() => temp.deleteSync(recursive: true));
    final picked = Directory(p.join(temp.path, 'picked'))..createSync();
    final library = Directory(p.join(temp.path, 'library', 'tracks'))
      ..createSync(recursive: true);
    final sopranoBytes = _mp3(1);
    final solistaBytes = _wav(2);
    final tenorBytes = _mp3(3);
    File(p.join(picked.path, 'coro.mp3'))
        .writeAsStringSync('Ave verum corpus, natum de Maria Virgine');
    File(p.join(picked.path, 'soprano.mp3')).writeAsBytesSync(sopranoBytes);
    File(p.join(picked.path, 'solista.wav')).writeAsBytesSync(solistaBytes);
    File(p.join(picked.path, 'tenor.mp3')).writeAsBytesSync(tenorBytes);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final picker = _QueuedPicker(picked);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      trackFilePickerProvider.overrideWithValue(picker),
      trackFileImporterProvider.overrideWithValue(
        TrackFileImporter(resolveRoot: () async => library),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: container.read(routerProvider),
      ),
    ));
    await _settle(tester, () => find.text('Cadastrar primeira música'));

    // Biblioteca vazia → Nova música (UPL-01).
    await _tap(tester, find.text('Cadastrar primeira música'));
    await _settle(tester, () => find.text('Nova música'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Nome'), 'Ave Verum Corpus');
    await tester.enterText(
        find.widgetWithText(TextField, 'Autor (opcional)'), 'Mozart');
    await tester.pump();

    // A text file named .mp3 is refused by content (UPL-07).
    picker.queue.add('coro.mp3');
    await _tap(tester, _action('soprano', 'Escolher arquivo'));
    await _settle(
      tester,
      () => find.text('Este arquivo não é um áudio aceito (MP3, M4A ou WAV).'),
    );

    // A real MP3 is accepted.
    picker.queue.add('soprano.mp3');
    await _tap(tester, _action('soprano', 'Escolher arquivo'));
    await _settle(tester, () => find.textContaining('soprano.mp3 · '));

    // A custom naipe with a WAV (UPL-13).
    await _tap(tester, find.text('Adicionar naipe'));
    await tester.pumpAndSettle(); // the sheet opens
    await tester.enterText(
        find.widgetWithText(TextField, 'Novo naipe'), 'Solista');
    await _tap(tester, find.text('Criar naipe'));
    await tester.pumpAndSettle(); // the sheet closes
    picker.queue.add('solista.wav');
    await _tap(tester, find.bySemanticsLabel('Escolher arquivo de Solista'));
    await _settle(tester, () => find.textContaining('solista.wav · '));

    // Save → Detalhe (UPL-04).
    await _tap(tester, find.text('Salvar música'));
    await _settle(tester, () => find.textContaining('Criada por você'));
    expect(find.text('Solista'), findsOneWidget);

    // Detalhe "Enviar faixa" on Tenor opens Faixas with the picker (UPL-17).
    picker.queue.add('tenor.mp3');
    // Missing: Contralto, Tenor, Baixo → the second one is Tenor.
    await _tap(tester, find.text('Enviar faixa').at(1));
    await _settle(tester, () => find.textContaining('tenor.mp3 · '));
    expect(find.text('Faixas'), findsOneWidget);
    await _tap(tester, find.text('Salvar música'));
    await _settle(tester, () => find.textContaining('Criada por você'));

    // The stored song and the library files (UPL-15, 19, 22).
    final song = await tester.runAsync(() async {
      final songs = await container.read(songRepositoryProvider).getAll();
      return songs.when(success: (l) => l.single, failure: (f) => null);
    });
    expect(song, isNotNull);
    final saved = song!;
    _printArtifact(saved, library);

    String sha(List<int> bytes) => sha256.convert(bytes).toString();
    final byNaipe = {
      for (final t in saved.tracks) t.customNaipe?.name ?? t.naipe.name: t,
    };
    expect(saved.name, 'Ave Verum Corpus');
    expect(saved.author, 'Mozart');
    expect(byNaipe.keys.toSet(), {'soprano', 'tenor', 'Solista'});
    expect(byNaipe['soprano']!.filePath,
        p.join(library.path, '${sha(sopranoBytes)}.mp3'));
    expect(byNaipe['Solista']!.filePath,
        p.join(library.path, '${sha(solistaBytes)}.wav'));
    expect(byNaipe['tenor']!.filePath,
        p.join(library.path, '${sha(tenorBytes)}.mp3'));
    expect(byNaipe['tenor']!.naipe, Naipe.tenor);
    expect(byNaipe['soprano']!.fileName, 'soprano.mp3');
    for (final track in saved.tracks) {
      expect(File(track.filePath).readAsBytesSync(),
          File(p.join(picked.path, track.fileName)).readAsBytesSync());
    }
    final files = library.listSync().map((e) => p.basename(e.path)).toList()
      ..sort();
    expect(files, hasLength(3), reason: 'the refused file never got in');
    expect(files.any((f) => f.endsWith('.part')), isFalse);

    final naipes = await tester.runAsync(
      () => container.read(customNaipeRepositoryProvider).getAll(),
    );
    expect(
      naipes!.when(success: (l) => l.map((n) => n.name), failure: (_) => []),
      ['Solista'],
    );

    // Unmount so autoDispose providers close before the database does.
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}

Finder _action(String slot, String label) =>
    find.byKey(ValueKey('action-$slot-$label'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.last);
  await tester.pump();
  await tester.tap(finder.last);
  await tester.pump();
}

/// Lets real file IO and isolates finish, pumping frames until [finder]
/// shows something.
Future<void> _settle(WidgetTester tester, Finder Function() finder) async {
  for (var i = 0; i < 200 && finder().evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(finder(), findsWidgets);
  await tester.pump(const Duration(milliseconds: 400));
}

void _printArtifact(Song song, Directory library) {
  final lines = <String>[
    'track-upload e2e artifact',
    'song: ${song.id} "${song.name}" by ${song.author} (${song.origin.name})',
    for (final t in song.tracks)
      '  track ${t.customNaipe?.name ?? t.naipe.name}: ${t.fileName} '
          '${t.fileSizeBytes} B, delay ${t.startDelayMs} ms -> '
          '${p.basename(t.filePath)}',
    'library/tracks:',
    for (final f in library.listSync()) '  ${p.basename(f.path)}',
  ];
  // ignore: avoid_print
  print(lines.join('\n'));
}
