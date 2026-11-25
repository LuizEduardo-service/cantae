import 'dart:async';

import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/screens/lyrics_editor/lyrics_editor_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:cantae/presentation/widgets/lyric_line_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  bool throwOnLoad = false;
  final List<String> calls = [];
  final _positionController = StreamController<int>.broadcast();

  void emitPosition(int ms) => _positionController.add(ms);

  @override
  Future<void> loadSong(Song song) async {
    if (throwOnLoad) throw Exception('load failed');
  }

  @override
  Future<void> playAt(DateTime scheduledStart) async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seekAllTo(int timelineMs) async => calls.add('seek:$timelineMs');

  @override
  Future<void> setTrackMuted(String trackId, bool muted) async {}

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async {}

  @override
  Future<void> setTrackVolume(String trackId, double volume) async {}

  @override
  Future<void> addTrack(SongTrack track, {bool exemptFromSolo = false}) async {}

  @override
  Future<void> setDucked(bool ducked) async {}

  @override
  Future<void> removeTrack(String trackId) async {}

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {}

  @override
  int? get durationMs => 180000;

  @override
  Stream<int> get positionMs => _positionController.stream;
}

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository({this.song});

  Song? song;
  bool failLoad = false;
  Result<Unit, StorageFailure>? saveResult;
  Song? savedSong;

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    if (failLoad) {
      return Result.failure(StorageFailure(code: 'read_failed'));
    }
    final current = savedSong ?? song;
    if (current == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }
    return Result.success(current);
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async {
    final result = saveResult ?? const Result.success(Unit());
    if (result.isSuccess) savedSong = song;
    return result;
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

const _soprano = SongTrack(
  id: 'soprano',
  filePath: '/tmp/soprano.mp3',
  naipe: Naipe.soprano,
);

Song _song({
  List<LyricLine> lyrics = const [
    LyricLine(text: 'Ave verum corpus', onsetMs: 1000, naipe: Naipe.soprano),
    LyricLine(text: 'natum de Maria Virgine', onsetMs: null),
  ],
  List<SongTrack> tracks = const [_soprano],
}) =>
    Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      tracks: tracks,
      lyrics: lyrics,
    );

GoRouter _router() => GoRouter(
      initialLocation: '/lyrics-editor/ave',
      routes: [
        GoRoute(
          path: '/',
          name: 'library',
          builder: (_, __) => const Text('route:library'),
        ),
        GoRoute(
          path: '/songs/:id',
          name: 'song-detail',
          builder: (_, state) =>
              Text('route:song-detail:${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/track-align/:id',
          name: 'track-align',
          builder: (_, state) =>
              Text('route:track-align:${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/lyrics-editor/:id',
          name: 'lyrics-editor',
          builder: (_, state) =>
              LyricsEditorScreen(songId: state.pathParameters['id']!),
        ),
      ],
    );

Widget _app(
  _FakeAudioPlaybackEngine engine,
  _FakeSongRepository repo, {
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      audioPlaybackEngineProvider.overrideWithValue(engine),
      songRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: _router(),
    ),
  );
}

Future<({_FakeAudioPlaybackEngine engine, _FakeSongRepository repo})> _open(
  WidgetTester tester, {
  Song? song,
  bool notFound = false,
  ThemeData? theme,
}) async {
  final engine = _FakeAudioPlaybackEngine();
  final repo = _FakeSongRepository(song: notFound ? null : (song ?? _song()));
  await tester.pumpWidget(_app(engine, repo, theme: theme));
  await tester.pumpAndSettle();
  return (engine: engine, repo: repo);
}

PrimaryButton _primary(WidgetTester tester, String label) =>
    tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, label));

Finder _textField(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    );

Future<void> _startPreviewAt(
  WidgetTester tester,
  _FakeAudioPlaybackEngine engine,
  int positionMs,
) async {
  await tester.tap(find.text('Ouvir com a letra'));
  await tester.pumpAndSettle();
  engine.emitPosition(positionMs);
  // The stream delivers in a microtask: one pump applies it to the state,
  // the next draws the frame that shows it.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('LyricsEditorScreen states (LYR-19)', () {
    testWidgets('loading shows a progress indicator and no footer',
        (tester) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(song: _song());
      await tester.pumpWidget(_app(engine, repo));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('not found offers going back to the Biblioteca',
        (tester) async {
      await _open(tester, notFound: true);

      expect(find.text('Música não encontrada'), findsOneWidget);
      await tester.tap(find.text('Voltar à Biblioteca'));
      await tester.pumpAndSettle();
      expect(find.text('route:library'), findsOneWidget);
    });

    testWidgets('load error shows a banner; "Tentar de novo" reloads',
        (tester) async {
      final engine = _FakeAudioPlaybackEngine();
      final repo = _FakeSongRepository(song: _song())..failLoad = true;
      await tester.pumpWidget(_app(engine, repo));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível abrir a letra'), findsOneWidget);

      repo.failLoad = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Letra'), findsOneWidget);
      expect(find.text('Não foi possível abrir a letra'), findsNothing);
    });

    testWidgets('loaded shows title, "X de Y marcadas", every line and Salvar',
        (tester) async {
      await _open(tester);

      expect(find.text('Letra'), findsOneWidget);
      expect(find.text('1 de 2 marcadas'), findsOneWidget);
      expect(find.byType(LyricLineRow), findsNWidgets(2));
      expect(find.text('Ave verum corpus'), findsOneWidget);
      expect(find.text('natum de Maria Virgine'), findsOneWidget);
      expect(find.text('Salvar letra'), findsOneWidget);
      expect(find.text('Marcar agora'), findsNothing);
    });
  });

  group('editing lines (LYR-01, LYR-12)', () {
    testWidgets('no lines: empty state, no footer; its action adds a line',
        (tester) async {
      await _open(tester, song: _song(lyrics: const []));

      expect(find.text('Nenhuma linha ainda'), findsOneWidget);
      expect(find.text('Salvar letra'), findsNothing);
      expect(find.text('Marcar agora'), findsNothing);

      await tester.tap(find.text('Acrescentar linha'));
      await tester.pumpAndSettle();

      expect(find.byType(LyricLineRow), findsOneWidget);
      expect(_textField('Texto da linha'), findsOneWidget);
      expect(find.text('Salvar letra'), findsOneWidget);
    });

    testWidgets('"Acrescentar linha" after the list adds an expanded line',
        (tester) async {
      await _open(tester);

      await tester.ensureVisible(find.text('Acrescentar linha'));
      await tester.tap(find.text('Acrescentar linha'));
      await tester.pumpAndSettle();

      expect(find.byType(LyricLineRow), findsNWidgets(3));
      expect(_textField('Texto da linha'), findsOneWidget);
      expect(find.text('1 de 3 marcadas'), findsOneWidget);
    });
  });

  group('no tracks (LYR-17, LYR-18)', () {
    testWidgets('banner points to track alignment; listening is disabled',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, song: _song(tracks: const []));

      expect(find.text('Sem faixas para ouvir'), findsOneWidget);
      final listen = tester.getSemantics(find.text('Ouvir com a letra'));
      expect(listen.flagsCollection.isEnabled.toBoolOrNull(), isFalse);

      await tester.tap(find.text('Ouvir com a letra'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar agora'), findsNothing);

      await tester.tap(find.text('Alinhar faixas'));
      await tester.pumpAndSettle();
      expect(find.text('route:track-align:ave'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('lines can still be added, edited and saved', (tester) async {
      final setup = await _open(tester, song: _song(tracks: const []));

      await tester.ensureVisible(find.text('Acrescentar linha'));
      await tester.tap(find.text('Acrescentar linha'));
      await tester.pumpAndSettle();
      await tester.enterText(_textField('Texto da linha'), 'vere passum');
      await tester.tap(find.text('Salvar letra'));
      await tester.pumpAndSettle();

      expect(setup.repo.savedSong!.lyrics.last.text, 'vere passum');
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('marking mode (LYR-03 to LYR-08, LYR-13)', () {
    testWidgets('footer shows the next line and the current time',
        (tester) async {
      final setup = await _open(tester);

      await _startPreviewAt(tester, setup.engine, 5300);

      expect(setup.engine.calls, ['seek:0', 'play']);
      expect(find.text('Próxima: natum de Maria Virgine'), findsOneWidget);
      expect(find.text('0:05.3'), findsOneWidget);
      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Salvar letra'), findsOneWidget,
          reason: 'saving stays available while marking');
    });

    testWidgets('"Marcar agora" marks the next line, then disables',
        (tester) async {
      final handle = tester.ensureSemantics();
      final setup = await _open(tester);
      await _startPreviewAt(tester, setup.engine, 5300);

      await tester.tap(find.text('Marcar agora'));
      await tester.pump();

      expect(find.text('2 de 2 marcadas'), findsOneWidget);
      expect(find.text('Todas as linhas marcadas'), findsOneWidget);
      expect(_primary(tester, 'Marcar agora').onPressed, isNull);
      final mark = tester.getSemantics(find.text('Marcar agora'));
      expect(mark.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      handle.dispose();
    });

    testWidgets('a mark before the previous marked line shows an error',
        (tester) async {
      final setup = await _open(tester);
      await _startPreviewAt(tester, setup.engine, 500);

      await tester.tap(find.text('Marcar agora'));
      await tester.pump();

      expect(find.text('Esse momento vem antes da linha anterior.'),
          findsOneWidget);
      expect(find.text('1 de 2 marcadas'), findsOneWidget);
    });

    testWidgets('"Pausar" keeps marking mode; "Continuar" resumes',
        (tester) async {
      final setup = await _open(tester);
      await _startPreviewAt(tester, setup.engine, 5300);

      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();

      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Próxima: natum de Maria Virgine'), findsOneWidget);
      expect(_primary(tester, 'Marcar agora').onPressed, isNull);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Pausar'), findsOneWidget);
      expect(setup.engine.calls, ['seek:0', 'play', 'pause', 'play']);
    });

    testWidgets('"Parar de ouvir" leaves marking mode and stops audio',
        (tester) async {
      final setup = await _open(tester);
      await _startPreviewAt(tester, setup.engine, 1000);

      await tester.tap(find.text('Parar de ouvir'));
      await tester.pumpAndSettle();

      expect(find.text('Marcar agora'), findsNothing);
      expect(find.text('Ouvir com a letra'), findsOneWidget);
      expect(setup.engine.calls.last, 'stop');
    });

    testWidgets('the line already sung is highlighted as "Linha atual"',
        (tester) async {
      final handle = tester.ensureSemantics();
      final setup = await _open(tester);

      await _startPreviewAt(tester, setup.engine, 1200);

      final rows = tester.widgetList<LyricLineRow>(find.byType(LyricLineRow));
      expect(rows.map((r) => r.isCurrent).toList(), [true, false]);
      expect(find.bySemanticsLabel(RegExp('Linha atual')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('loading the audio fails: error banner, editing still works',
        (tester) async {
      final setup = await _open(tester);
      setup.engine.throwOnLoad = true;

      await tester.tap(find.text('Ouvir com a letra'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível tocar as faixas desta música.'),
          findsOneWidget);
      expect(find.text('Marcar agora'), findsNothing);
      expect(find.text('Salvar letra'), findsOneWidget);
    });
  });

  group('saving and leaving (LYR-11, LYR-20, LYR-22)', () {
    testWidgets('success shows the "Letra salva" toast', (tester) async {
      final setup = await _open(tester);

      await tester.tap(find.text('Salvar letra'));
      await tester.pump();

      expect(find.text('Letra salva'), findsOneWidget);
      expect(setup.repo.savedSong, isNotNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('failure shows an error banner and keeps the edits',
        (tester) async {
      final setup = await _open(tester);
      setup.repo.saveResult = Result.failure(StorageFailure(code: 'disk_full'));
      await tester.ensureVisible(find.text('Acrescentar linha'));
      await tester.tap(find.text('Acrescentar linha'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar letra'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível salvar a letra.'), findsOneWidget);
      expect(find.byType(LyricLineRow), findsNWidgets(3));
      expect(find.text('Letra salva'), findsNothing);
    });

    testWidgets('back with unsaved changes asks first', (tester) async {
      await _open(tester);
      await tester.ensureVisible(find.text('Acrescentar linha'));
      await tester.tap(find.text('Acrescentar linha'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('‹ Ave Verum Corpus'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);

      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(LyricLineRow), findsNWidgets(3));

      await tester.tap(find.text('‹ Ave Verum Corpus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar alterações'));
      await tester.pumpAndSettle();
      expect(find.text('route:song-detail:ave'), findsOneWidget);
    });

    testWidgets('back with nothing changed goes straight to the song',
        (tester) async {
      await _open(tester);

      await tester.tap(find.text('‹ Ave Verum Corpus'));
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.text('route:song-detail:ave'), findsOneWidget);
    });

    testWidgets('leaving the screen while marking stops the audio',
        (tester) async {
      final setup = await _open(tester);
      await _startPreviewAt(tester, setup.engine, 1000);

      await tester.tap(find.text('‹ Ave Verum Corpus'));
      await tester.pumpAndSettle();

      expect(find.text('route:song-detail:ave'), findsOneWidget);
      expect(setup.engine.calls.last, 'stop');
    });
  });

  group('themes, font scale and semantics (AGENTS.md §7)', () {
    testWidgets('dark theme renders the loaded and marking states',
        (tester) async {
      final setup = await _open(tester, theme: AppTheme.dark);
      await _startPreviewAt(tester, setup.engine, 1000);

      expect(tester.takeException(), isNull);
      expect(find.text('Marcar agora'), findsOneWidget);
    });

    testWidgets('360 dp at 130% font: marking footer fits, targets >= 44 dp',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final setup = await _open(tester);
      await _startPreviewAt(tester, setup.engine, 1000);

      expect(tester.takeException(), isNull);
      for (final label in ['Marcar agora', 'Pausar', 'Salvar letra']) {
        expect(tester.getSize(find.text(label).first).height, greaterThan(0));
        final button = find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first;
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44),
            reason: label);
      }
    });

    testWidgets('the marked count is a live region for screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);

      final count = tester.getSemantics(find.text('1 de 2 marcadas'));
      expect(count.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });
}
