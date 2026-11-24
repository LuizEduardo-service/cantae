import 'dart:async';

import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/screens/track_align/track_align_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  bool throwOnLoad = false;
  int? durationMsValue = 10000;
  final _positionController = StreamController<int>.broadcast();

  @override
  Future<void> loadSong(Song song) async {
    if (throwOnLoad) throw Exception('load failed');
  }

  @override
  Future<void> playAt(DateTime scheduledStart) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seekAllTo(int timelineMs) async {}

  @override
  Future<void> setTrackMuted(String trackId, bool muted) async {}

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async {}

  @override
  Future<void> setTrackVolume(String trackId, double volume) async {}

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {}

  @override
  int? get durationMs => durationMsValue;

  @override
  Stream<int> get positionMs => _positionController.stream;
}

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository({this.initialSong, this.saveResult});

  Song? initialSong;
  Result<Unit, StorageFailure>? saveResult;
  Song? savedSong;

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    final song = initialSong;
    if (song == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }
    return Result.success(song);
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async {
    savedSong = song;
    return saveResult ?? const Result.success(Unit());
  }

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      const Result.success(<Song>[]);

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

Song _songWith({int sopranoDelayMs = 0, List<SongTrack>? tracks}) => Song(
      id: 'song-1',
      name: 'Ave Maria',
      author: 'Caccini',
      tracks: tracks ??
          [
            SongTrack(
              id: 'soprano',
              filePath: '/tmp/soprano.mp3',
              naipe: Naipe.soprano,
              startDelayMs: sopranoDelayMs,
            ),
            const SongTrack(
              id: 'contralto',
              filePath: '/tmp/contralto.mp3',
              naipe: Naipe.contralto,
            ),
          ],
    );

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/track-align/song-1',
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (context, state) => const Text('route:library'),
      ),
      GoRoute(
        path: '/songs/:id',
        name: 'song-detail',
        builder: (context, state) =>
            Text('route:song-detail:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/track-align/:id',
        name: 'track-align',
        builder: (context, state) =>
            TrackAlignScreen(songId: state.pathParameters['id']!),
      ),
      for (final name in ['studio', 'track-upload'])
        GoRoute(
          path: '/$name',
          name: name,
          builder: (context, state) => Text('route:$name'),
        ),
    ],
  );
}

Widget _wrap({
  required _FakeAudioPlaybackEngine engine,
  required _FakeSongRepository repo,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      audioPlaybackEngineProvider.overrideWithValue(engine),
      songRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: _buildRouter(),
    ),
  );
}

void main() {
  group('TrackAlignScreen', () {
    testWidgets('carregando: esqueleto, sem TrackAlignRow nem rodapé', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('sem faixas: EmptyState com ações para studio e track-upload', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo =
          _FakeSongRepository(initialSong: _songWith(tracks: const []));
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Sem faixas'), findsOneWidget);

      await tester.tap(find.text('Cortar áudio no Studio'));
      await tester.pumpAndSettle();
      expect(find.text('route:studio'), findsOneWidget);
    });

    testWidgets(
      'não encontrada: EmptyState "não encontrada" + voltar à Biblioteca',
      (tester) async {
        final engine = _FakeAudioPlaybackEngine();
        final repo = _FakeSongRepository();
        await tester.pumpWidget(_wrap(engine: engine, repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('Música não encontrada'), findsOneWidget);

        await tester.tap(find.text('Voltar à Biblioteca'));
        await tester.pumpAndSettle();

        expect(find.text('route:library'), findsOneWidget);
      },
    );

    testWidgets('erro ao carregar o motor: InlineBanner erro + Tentar de novo',
        (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine()..throwOnLoad = true;
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Tentar de novo'), findsOneWidget);

      engine.throwOnLoad = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets(
      'carregado: um TrackAlignRow por naipe com faixa, campos de trecho e rodapé',
      (tester) async {
        final engine = _FakeAudioPlaybackEngine();
        final repo = _FakeSongRepository(initialSong: _songWith());
        await tester.pumpWidget(_wrap(engine: engine, repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('Soprano'), findsOneWidget);
        expect(find.text('Contralto'), findsOneWidget);
        expect(find.text('Tenor'), findsNothing);
        expect(find.text('Início'), findsOneWidget);
        expect(find.text('Fim'), findsOneWidget);
        expect(find.text('Ouvir em loop'), findsOneWidget);
        expect(find.text('Salvar atrasos'), findsOneWidget);
      },
    );

    testWidgets('editar o atraso reflete no provider e na linha', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '0:01.5');
      await tester.pump();

      expect(find.text('0:01.5'), findsOneWidget);
    });

    testWidgets('tocar mudo/solo reflete visualmente na linha', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'M').first);
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.25);
    });

    testWidgets('"Ouvir em loop" vira "Parar" enquanto testando', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ouvir em loop'));
      await tester.pumpAndSettle();

      expect(find.text('Parar'), findsOneWidget);

      await tester.tap(find.text('Parar'));
      await tester.pumpAndSettle();

      expect(find.text('Ouvir em loop'), findsOneWidget);
    });

    testWidgets('"Salvar atrasos" bem-sucedido mostra Toast "Atrasos salvos"', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar atrasos'));
      await tester.pump();

      expect(find.text('Atrasos salvos'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2600));
    });

    testWidgets('"Salvar atrasos" com falha mostra erro inline', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(
        initialSong: _songWith(),
        saveResult: Result.failure(StorageFailure(code: 'save_failed')),
      );
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar atrasos'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível salvar'), findsOneWidget);
    });

    testWidgets(
      'voltar com alterações não salvas abre ConfirmSheet; confirmando navega',
      (tester) async {
        final engine = _FakeAudioPlaybackEngine();
        final repo = _FakeSongRepository(initialSong: _songWith());
        await tester.pumpWidget(_wrap(engine: engine, repo: repo));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '0:01.5');
        await tester.pump();

        await tester.tap(find.text('‹ Ave Maria'));
        await tester.pumpAndSettle();

        expect(find.text('Descartar alterações?'), findsOneWidget);

        await tester.tap(find.text('Descartar alterações'));
        await tester.pumpAndSettle();

        expect(find.text('route:song-detail:song-1'), findsOneWidget);
      },
    );

    testWidgets(
      'voltar com alterações não salvas; cancelar no ConfirmSheet mantém a tela',
      (tester) async {
        final engine = _FakeAudioPlaybackEngine();
        final repo = _FakeSongRepository(initialSong: _songWith());
        await tester.pumpWidget(_wrap(engine: engine, repo: repo));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '0:01.5');
        await tester.pump();

        await tester.tap(find.text('‹ Ave Maria'));
        await tester.pumpAndSettle();

        expect(find.text('Descartar alterações?'), findsOneWidget);

        await tester.tap(find.text('Continuar editando'));
        await tester.pumpAndSettle();

        expect(find.text('Descartar alterações?'), findsNothing);
        expect(find.text('route:song-detail:song-1'), findsNothing);
        expect(find.text('0:01.5'), findsOneWidget);
      },
    );

    testWidgets('voltar sem alterações navega direto, sem confirmação', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(_wrap(engine: engine, repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('‹ Ave Maria'));
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.text('route:song-detail:song-1'), findsOneWidget);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(initialSong: _songWith());
      await tester.pumpWidget(
        _wrap(engine: engine, repo: repo, theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('Soprano'), findsOneWidget);
    });
  });
}
