import 'dart:async';

import 'package:cantae/data/library/song_tracks_saver.dart';
import 'package:cantae/data/library/track_file_inspector.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/library/audio_file_check.dart';
import 'package:cantae/domain/library/track_file_picker.dart';
import 'package:cantae/domain/repositories/custom_naipe_repository.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/providers/track_upload_providers.dart';
import 'package:cantae/presentation/screens/song_editor/song_editor_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Screen states and flows (UI_SPEC §6.4, UPL-02..06, 11..14, 16, 18, 20, 21,
// 23). Failure modes: a state renders the wrong body; a rejection or picker
// failure is silent; "Salvar música" is enabled with an invalid name or
// accepts a second tap; save does not open the detail; the sheet adds an
// invalid or 5th naipe; Trocar/Remover skip the confirmation or ignore a
// cancel; leaving with changes does not ask; ?naipe= does not open the
// picker, or opens it twice; a received song offers file actions; the
// layout overflows at 360 dp and 130 %.
class _Picker implements TrackFilePicker {
  final results = <Result<PickedTrackFile?, StorageFailure>>[];
  int calls = 0;

  void next(String name) => results
      .add(Result.success(PickedTrackFile(path: '/in/$name', name: name)));

  @override
  Future<Result<PickedTrackFile?, StorageFailure>> pick() async {
    calls++;
    return results.isEmpty ? const Result.success(null) : results.removeAt(0);
  }

  @override
  Future<void> releaseTemporaryFiles() async {}
}

class _Inspector implements TrackFileInspector {
  final rejections = <String, String>{};
  Completer<void>? hold;

  @override
  Future<Result<InspectedTrackFile, ValidationFailure>> inspect(
    PickedTrackFile file,
  ) async {
    if (hold != null) await hold!.future;
    final code = rejections[file.name];
    if (code != null) return Result.failure(ValidationFailure(code: code));
    return Result.success(InspectedTrackFile(
      sourcePath: file.path,
      name: file.name,
      sizeBytes: 12 * 1024 * 1024 + 400 * 1024,
      sha256: 'sha-${file.name}',
      format: AudioFormat.mp3,
    ));
  }
}

class _Saver implements SongTracksSaver {
  final requests = <SongSaveRequest>[];
  bool fail = false;
  Completer<void>? hold;

  @override
  Future<Result<Song, Failure>> save(SongSaveRequest request) async {
    requests.add(request);
    if (hold != null) await hold!.future;
    if (fail) return Result.failure(StorageFailure(code: 'song_save_failed'));
    return Result.success(
        Song(id: request.songId, name: request.name, author: request.author));
  }
}

class _Songs implements SongRepository {
  Song? song;
  bool failRead = false;

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    if (failRead) return Result.failure(StorageFailure(code: 'read_failed'));
    final s = song;
    if (s == null || s.id != id) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }
    return Result.success(s);
  }

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      Result.success([if (song != null) song!]);

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

class _Naipes implements CustomNaipeRepository {
  List<CustomNaipe> list = const [];

  @override
  Future<Result<List<CustomNaipe>, StorageFailure>> getAll() async =>
      Result.success(list);
}

const solista = CustomNaipe(id: 'n-solista', name: 'Solista');
const mezzo = CustomNaipe(id: 'n-mezzo', name: 'Mezzo');

Song _ave({SongOrigin origin = SongOrigin.created}) => Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      origin: origin,
      tracks: const [
        SongTrack(
          id: 'sop',
          filePath: '/lib/sop.mp3',
          naipe: Naipe.soprano,
          startDelayMs: 400,
          fileName: 'soprano.mp3',
          fileSizeBytes: 2097152,
        ),
        SongTrack(id: 'ten', filePath: '/lib/ten.mp3', naipe: Naipe.tenor),
        SongTrack(
          id: 'sol',
          filePath: '/lib/sol.mp3',
          naipe: Naipe.custom,
          customNaipe: solista,
        ),
      ],
    );

class _Env {
  final picker = _Picker();
  final inspector = _Inspector();
  final saver = _Saver();
  final songs = _Songs();
  final naipes = _Naipes();
  var ids = 0;
}

Future<_Env> _open(
  WidgetTester tester, {
  String location = '/song-editor',
  Song? song,
  bool failRead = false,
  List<CustomNaipe> device = const [],
  ThemeData? theme,
  void Function(_Env env)? before,
  bool tall = true,
}) async {
  if (tall) {
    // Every row built at once; the 360 dp test keeps a phone-sized view.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final env = _Env();
  env.songs
    ..song = song
    ..failRead = failRead;
  env.naipes.list = device;
  before?.call(env);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      songRepositoryProvider.overrideWithValue(env.songs),
      customNaipeRepositoryProvider.overrideWithValue(env.naipes),
      trackFilePickerProvider.overrideWithValue(env.picker),
      trackFileInspectorProvider.overrideWithValue(env.inspector),
      songTracksSaverProvider.overrideWithValue(env.saver),
      newIdProvider.overrideWithValue(() => 'new-${env.ids++}'),
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/',
            name: 'library',
            builder: (_, __) => const Text('route:library'),
          ),
          GoRoute(
            path: '/songs/:id',
            name: 'song-detail',
            builder: (_, s) =>
                Text('route:song-detail:${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/song-editor',
            name: 'song-create',
            builder: (_, __) => const SongEditorScreen(),
          ),
          GoRoute(
            path: '/song-editor/:id',
            name: 'track-upload',
            builder: (_, s) => SongEditorScreen(
              songId: s.pathParameters['id'],
              initialNaipe: switch (s.uri.queryParameters['naipe']) {
                final String n => Naipe.values.byName(n),
                null => null,
              },
            ),
          ),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return env;
}

Finder _inRow(String slot, Finder finder) =>
    find.descendant(of: find.byKey(ValueKey('slot-$slot')), matching: finder);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.last);
  await tester.pumpAndSettle();
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text));

PrimaryButton _saveButton(WidgetTester tester) => tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Salvar música'),
    );

void main() {
  group('SongEditorScreen — Nova música', () {
    testWidgets('shows the fields, the 4 naipes, Playback and extras',
        (tester) async {
      await _open(tester);

      expect(find.text('‹ Biblioteca'), findsOneWidget);
      expect(find.text('Nova música'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Nome'), findsOneWidget);
      expect(
          find.widgetWithText(TextField, 'Autor (opcional)'), findsOneWidget);
      expect(find.text('Naipes'), findsOneWidget);
      for (final name in ['Soprano', 'Contralto', 'Tenor', 'Baixo']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Playback (opcional)'), findsOneWidget);
      expect(find.text('Naipes extras'), findsOneWidget);
      expect(find.text('Adicionar naipe'), findsOneWidget);
      expect(find.text('Sem faixa'), findsNWidgets(5));
      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('a chosen file shows its name and size in MB', (tester) async {
      final env = await _open(tester);
      env.picker.next('soprano.mp3');

      await _tap(tester, _inRow('soprano', find.text('Escolher arquivo')));

      expect(_inRow('soprano', find.text('soprano.mp3 · 12,4 MB')),
          findsOneWidget);
      expect(_inRow('soprano', find.text('Trocar')), findsOneWidget);
      expect(_inRow('soprano', find.text('Remover')), findsOneWidget);
    });

    testWidgets('while checking, the row says "Conferindo arquivo…"',
        (tester) async {
      final env = await _open(tester);
      env.picker.next('soprano.mp3');
      env.inspector.hold = Completer<void>();

      await tester.tap(_inRow('soprano', find.text('Escolher arquivo')));
      await tester.pump();
      await tester.pump();

      expect(
          _inRow('soprano', find.text('Conferindo arquivo…')), findsOneWidget);
      env.inspector.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Conferindo arquivo…'), findsNothing);
    });

    testWidgets('a refused file shows why in its row', (tester) async {
      final env = await _open(tester);
      env.picker.next('texto.mp3');
      env.inspector.rejections['texto.mp3'] = 'track_file_unsupported';

      await _tap(tester, _inRow('tenor', find.text('Escolher arquivo')));

      expect(
        _inRow(
          'tenor',
          find.text('Este arquivo não é um áudio aceito (MP3, M4A ou WAV).'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a picker failure shows a banner', (tester) async {
      final env = await _open(tester);
      env.picker.results
          .add(Result.failure(StorageFailure(code: 'picker_failed')));

      await _tap(tester, _inRow('soprano', find.text('Escolher arquivo')));

      expect(find.text('Não foi possível abrir os arquivos.'), findsOneWidget);
    });

    testWidgets('a name over 80 characters shows the limit and blocks saving',
        (tester) async {
      await _open(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'a' * 81);
      await tester.pumpAndSettle();

      expect(find.text('Use até 80 caracteres.'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('saving shows progress, then opens the new song',
        (tester) async {
      final env = await _open(tester);
      env.saver.hold = Completer<void>();
      await tester.enterText(
          find.widgetWithText(TextField, 'Nome'), 'Ave Verum Corpus');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salvar música'));
      await tester.tap(find.text('Salvar música'));
      await tester.pump();
      expect(_saveButton(tester).loading, isTrue);

      env.saver.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('route:song-detail:new-0'), findsOneWidget);
      expect(env.saver.requests, hasLength(1));
    });

    testWidgets('a failed save shows the message and stays', (tester) async {
      final env = await _open(tester);
      env.saver.fail = true;
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Ave');
      await tester.pumpAndSettle();

      await _tapText(tester, 'Salvar música');

      expect(find.text('Não foi possível salvar a música. Tente de novo.'),
          findsOneWidget);
      expect(find.text('Nova música'), findsOneWidget);
    });
  });

  group('Adicionar naipe', () {
    testWidgets('lists device naipes and adds the chosen one', (tester) async {
      await _open(tester, device: const [mezzo]);

      await _tapText(tester, 'Adicionar naipe');
      expect(find.text('Naipes já criados'), findsOneWidget);
      await _tapText(tester, 'Mezzo');

      expect(_inRow('custom-n-mezzo', find.text('Mezzo')), findsOneWidget);
      expect(_inRow('custom-n-mezzo', find.text('M')), findsOneWidget);
    });

    testWidgets('creates a new naipe with its initial badge', (tester) async {
      await _open(tester);

      await _tapText(tester, 'Adicionar naipe');
      await tester.enterText(
          find.widgetWithText(TextField, 'Novo naipe'), 'Solista');
      await _tapText(tester, 'Criar naipe');

      expect(_inRow('custom-new-0', find.text('Solista')), findsOneWidget);
      expect(_inRow('custom-new-0', find.text('S')), findsOneWidget);
    });

    testWidgets('an invalid name shows the reason and keeps the sheet open',
        (tester) async {
      await _open(tester);

      await _tapText(tester, 'Adicionar naipe');
      await tester.enterText(
          find.widgetWithText(TextField, 'Novo naipe'), 'tenor');
      await _tapText(tester, 'Criar naipe');

      expect(find.text('Esse nome é de um naipe padrão.'), findsOneWidget);
      expect(find.text('Criar naipe'), findsOneWidget);
    });

    testWidgets('after 4 extras the button is disabled and says why',
        (tester) async {
      await _open(tester);
      for (final name in ['Solista', 'Mezzo', 'Barítono', 'Descante']) {
        await _tapText(tester, 'Adicionar naipe');
        await tester.enterText(
            find.widgetWithText(TextField, 'Novo naipe'), name);
        await _tapText(tester, 'Criar naipe');
      }

      expect(find.text('Até 4 naipes extras por música.'), findsOneWidget);
      final button = tester.widget<SecondaryButton>(
        find.widgetWithText(SecondaryButton, 'Adicionar naipe'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('removing an extra row asks nothing for an empty row',
        (tester) async {
      await _open(tester, device: const [mezzo]);
      await _tapText(tester, 'Adicionar naipe');
      await _tapText(tester, 'Mezzo');

      await _tap(tester, _inRow('custom-n-mezzo', find.text('Tirar naipe')));

      expect(find.byKey(const ValueKey('slot-custom-n-mezzo')), findsNothing);
    });
  });

  group('Faixas de uma música existente', () {
    testWidgets('shows the song and its saved tracks', (tester) async {
      await _open(tester, location: '/song-editor/ave', song: _ave());

      expect(find.text('‹ Ave Verum Corpus'), findsOneWidget);
      expect(find.text('Faixas'), findsOneWidget);
      expect(
          _inRow('soprano', find.text('soprano.mp3 · 2,0 MB')), findsOneWidget);
      expect(_inRow('tenor', find.text('Faixa salva')), findsOneWidget);
      expect(_inRow('custom-n-solista', find.text('Solista')), findsOneWidget);
    });

    testWidgets('Remover asks first; cancel keeps, confirm removes',
        (tester) async {
      await _open(tester, location: '/song-editor/ave', song: _ave());

      await _tap(tester, _inRow('tenor', find.text('Remover')));
      expect(find.text('Remover a faixa de Tenor?'), findsOneWidget);
      await _tapText(tester, 'Cancelar');
      expect(_inRow('tenor', find.text('Faixa salva')), findsOneWidget);

      await _tap(tester, _inRow('tenor', find.text('Remover')));
      await _tapText(tester, 'Remover faixa');
      expect(_inRow('tenor', find.text('Sem faixa')), findsOneWidget);
    });

    testWidgets('Trocar asks first, then opens the picker', (tester) async {
      final env =
          await _open(tester, location: '/song-editor/ave', song: _ave());
      env.picker.next('tenor-novo.mp3');

      await _tap(tester, _inRow('tenor', find.text('Trocar')));
      expect(find.text('Trocar a faixa de Tenor?'), findsOneWidget);
      await _tapText(tester, 'Cancelar');
      expect(env.picker.calls, 0);

      await _tap(tester, _inRow('tenor', find.text('Trocar')));
      await _tapText(tester, 'Trocar faixa');
      expect(env.picker.calls, 1);
      expect(_inRow('tenor', find.text('tenor-novo.mp3 · 12,4 MB')),
          findsOneWidget);
    });

    testWidgets('leaving with changes asks; cancel stays, confirm leaves',
        (tester) async {
      await _open(tester, location: '/song-editor/ave', song: _ave());
      await tester.enterText(
          find.widgetWithText(TextField, 'Autor (opcional)'), 'W. A. Mozart');
      await tester.pumpAndSettle();

      await _tapText(tester, '‹ Ave Verum Corpus');
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await _tapText(tester, 'Continuar editando');
      expect(find.text('Faixas'), findsOneWidget);

      await _tapText(tester, '‹ Ave Verum Corpus');
      await _tapText(tester, 'Descartar alterações');
      expect(find.text('route:song-detail:ave'), findsOneWidget);
    });

    testWidgets('leaving without changes does not ask', (tester) async {
      await _open(tester, location: '/song-editor/ave', song: _ave());

      await _tapText(tester, '‹ Ave Verum Corpus');

      expect(find.text('route:song-detail:ave'), findsOneWidget);
    });

    testWidgets('?naipe=bass opens the picker once for that naipe',
        (tester) async {
      final env = await _open(
        tester,
        location: '/song-editor/ave?naipe=bass',
        song: _ave(),
        before: (env) => env.picker.next('baixo.mp3'),
      );

      expect(env.picker.calls, 1);
      expect(_inRow('bass', find.text('baixo.mp3 · 12,4 MB')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(env.picker.calls, 1);
    });

    testWidgets('a missing song shows "Música não encontrada"', (tester) async {
      await _open(tester, location: '/song-editor/sumiu');

      expect(find.text('Música não encontrada'), findsOneWidget);
      await _tapText(tester, 'Voltar à Biblioteca');
      expect(find.text('route:library'), findsOneWidget);
    });

    testWidgets('a read error offers "Tentar de novo"', (tester) async {
      final env = await _open(tester,
          location: '/song-editor/ave', song: _ave(), failRead: true);

      expect(find.text('Não foi possível carregar a música'), findsOneWidget);
      env.songs.failRead = false;
      await _tapText(tester, 'Tentar de novo');
      expect(find.text('Faixas'), findsOneWidget);
    });

    testWidgets('a received song is read-only and says why', (tester) async {
      await _open(tester,
          location: '/song-editor/ave',
          song: _ave(origin: SongOrigin.received));

      expect(
        find.text('Músicas recebidas de uma sala não podem ter as faixas '
            'trocadas.'),
        findsOneWidget,
      );
      expect(find.text('Escolher arquivo'), findsNothing);
      expect(find.text('Trocar'), findsNothing);
      expect(find.text('Salvar música'), findsNothing);
    });
  });

  group('acessibilidade e temas', () {
    testWidgets('row actions name their naipe for screen readers',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);

      expect(
          find.bySemanticsLabel('Escolher arquivo de Soprano'), findsOneWidget);
      expect(find.bySemanticsLabel('Escolher arquivo de Playback'),
          findsOneWidget);
      semantics.dispose();
    });

    testWidgets('renders under the dark theme', (tester) async {
      await _open(tester,
          location: '/song-editor/ave', song: _ave(), theme: AppTheme.dark);

      expect(tester.takeException(), isNull);
      expect(find.text('Faixas'), findsOneWidget);
    });

    testWidgets('360 dp at 130 %: no overflow, touch targets ≥ 44 dp',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _open(tester,
          location: '/song-editor/ave', song: _ave(), tall: false);

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.widgetWithText(PrimaryButton, 'Salvar música'))
            .height,
        greaterThanOrEqualTo(44),
      );
      final action = find.byKey(const ValueKey('action-tenor-Trocar'));
      await tester.scrollUntilVisible(
        action,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
    });
  });
}
