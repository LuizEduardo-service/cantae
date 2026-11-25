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
import 'package:cantae/presentation/screens/solo_player/solo_player_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:cantae/presentation/widgets/lyric_view.dart';
import 'package:cantae/presentation/widgets/mix_track_row.dart';
import 'package:cantae/presentation/widgets/mute_solo_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  bool throwOnLoad = false;
  int loadCount = 0;
  final List<String> calls = [];
  final Map<String, double> volumes = {};
  final _positionController = StreamController<int>.broadcast();

  void emitPosition(int ms) => _positionController.add(ms);

  @override
  Future<void> loadSong(Song song) async {
    if (throwOnLoad) throw Exception('file missing');
    loadCount++;
    calls.add('load');
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
  Future<void> setTrackMuted(String trackId, bool muted) async =>
      calls.add('mute:$trackId:$muted');

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async =>
      calls.add('solo:$trackId:$solo');

  @override
  Future<void> setTrackVolume(String trackId, double volume) async =>
      volumes[trackId] = volume;

  @override
  Future<void> addTrack(SongTrack track, {bool exemptFromSolo = false}) async {}

  @override
  Future<void> removeTrack(String trackId) async {}

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {}

  @override
  int? get durationMs => 185000;

  @override
  Stream<int> get positionMs => _positionController.stream;
}

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository({this.song, this.failure});

  Song? song;
  Failure? failure;

  @override
  Future<Result<Song, Failure>> getById(String id) async {
    final failure = this.failure;
    if (failure != null) return Result.failure(failure);
    final song = this.song;
    if (song == null) {
      return Result.failure(NotFoundFailure(code: 'song_not_found'));
    }
    return Result.success(song);
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

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

const _tracks = [
  SongTrack(id: 'soprano', filePath: '/tmp/s.mp3', naipe: Naipe.soprano),
  SongTrack(id: 'contralto', filePath: '/tmp/c.mp3', naipe: Naipe.contralto),
  SongTrack(id: 'tenor', filePath: '/tmp/t.mp3', naipe: Naipe.tenor),
  SongTrack(id: 'baixo', filePath: '/tmp/b.mp3', naipe: Naipe.bass),
];

const _lyrics = [
  LyricLine(text: 'Ave verum corpus', onsetMs: 2000),
  LyricLine(
    text: 'natum de Maria Virgine',
    onsetMs: 5000,
    naipe: Naipe.tenor,
    dynamics: 'piano',
  ),
  LyricLine(text: 'vere passum immolatum', onsetMs: 9000),
];

Song _song({
  List<SongTrack> tracks = _tracks,
  List<LyricLine> lyrics = _lyrics,
}) =>
    Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      tracks: tracks,
      lyrics: lyrics,
    );

GoRouter _router() => GoRouter(
      initialLocation: '/solo-player/ave',
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
          path: '/track-upload',
          name: 'track-upload',
          builder: (_, __) => const Text('route:track-upload'),
        ),
        GoRoute(
          path: '/solo-player/:id',
          name: 'solo-player',
          builder: (_, state) =>
              SoloPlayerScreen(songId: state.pathParameters['id']!),
        ),
      ],
    );

Future<({_FakeAudioPlaybackEngine engine, _FakeSongRepository repo})> _open(
  WidgetTester tester, {
  Song? song,
  bool notFound = false,
  Failure? failure,
  bool throwOnLoad = false,
  ThemeData? theme,
}) async {
  final engine = _FakeAudioPlaybackEngine()..throwOnLoad = throwOnLoad;
  final repo = _FakeSongRepository(
    song: notFound ? null : (song ?? _song()),
    failure: failure,
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      audioPlaybackEngineProvider.overrideWithValue(engine),
      songRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: _router(),
    ),
  ));
  await tester.pumpAndSettle();
  return (engine: engine, repo: repo);
}

/// The stream delivers in a microtask: one pump applies it to the state,
/// the next draws the frame that shows it.
Future<void> _emit(
  WidgetTester tester,
  _FakeAudioPlaybackEngine engine,
  int positionMs,
) async {
  engine.emitPosition(positionMs);
  await tester.pump();
  await tester.pump();
}

TonalButton _tonal(WidgetTester tester, String label) =>
    tester.widget<TonalButton>(find.widgetWithText(TonalButton, label));

/// The body is a lazy ListView: rows below the fold are not built until
/// scrolled to.
Future<Finder> _scrollTo(WidgetTester tester, String trackId) async {
  final row = find.byKey(ValueKey('mix-$trackId'));
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  return row;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  group('states (SOLO-23, SOLO-24, SOLO-25)', () {
    testWidgets('not found offers going back to the Biblioteca',
        (tester) async {
      await _open(tester, notFound: true);

      expect(find.text('Música não encontrada'), findsOneWidget);
      await tester.tap(find.text('Voltar à Biblioteca'));
      await tester.pumpAndSettle();
      expect(find.text('route:library'), findsOneWidget);
    });

    testWidgets('read error shows a banner; "Tentar de novo" reads again',
        (tester) async {
      final setup = await _open(tester, failure: StorageFailure(code: 'db'));
      expect(find.text('Não foi possível abrir a música'), findsOneWidget);
      expect(find.text('Tocar'), findsNothing);

      setup.repo.failure = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Ave Verum Corpus'), findsOneWidget);
      expect(find.text('Tocar'), findsOneWidget);
    });

    testWidgets('no tracks: empty state with "Enviar faixa", no player',
        (tester) async {
      await _open(tester, song: _song(tracks: const []));

      expect(find.text('Esta música ainda não tem faixas'), findsOneWidget);
      expect(find.text('Tocar'), findsNothing);
      await tester.tap(find.text('Enviar faixa'));
      await tester.pumpAndSettle();
      expect(find.text('route:track-upload'), findsOneWidget);
    });

    testWidgets('audio load failure: banner, retry loads again',
        (tester) async {
      final setup = await _open(tester, throwOnLoad: true);
      expect(find.text('Não foi possível tocar as faixas desta música.'),
          findsOneWidget);
      expect(find.text('Tocar'), findsNothing);

      setup.engine.throwOnLoad = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(setup.engine.loadCount, 1);
      expect(find.text('Tocar'), findsOneWidget);
    });
  });

  group('ready (SOLO-02 to SOLO-09)', () {
    testWidgets('shows title, author, offline pill, lyrics, mix and 0:00.0',
        (tester) async {
      await _open(tester);

      expect(find.text('Ave Verum Corpus'), findsOneWidget);
      expect(find.text('Mozart'), findsOneWidget);
      expect(find.text('Funciona offline'), findsOneWidget);
      expect(find.byType(LyricView), findsOneWidget);
      for (final id in ['soprano', 'contralto', 'tenor', 'baixo']) {
        expect(await _scrollTo(tester, id), findsOneWidget, reason: id);
      }
      expect(find.text('0:00.0'), findsOneWidget);
      expect(find.text('3:05.0'), findsOneWidget);
    });

    testWidgets('"Tocar" plays and becomes "Pausar"; the clock follows',
        (tester) async {
      final setup = await _open(tester);

      await _tapText(tester, 'Tocar');
      expect(find.text('Pausar'), findsOneWidget);
      expect(setup.engine.calls.last, 'play');

      await _emit(tester, setup.engine, 5300);
      expect(find.text('0:05.3'), findsOneWidget);

      await _tapText(tester, 'Pausar');
      expect(find.text('Tocar'), findsOneWidget);
      expect(setup.engine.calls.last, 'pause');
    });

    testWidgets('the lyric view follows the position', (tester) async {
      final setup = await _open(tester);
      await _tapText(tester, 'Tocar');

      await _emit(tester, setup.engine, 6000);

      expect(find.text('Tenor · piano'), findsOneWidget);
      expect(find.text('vere passum immolatum'), findsOneWidget);
    });

    testWidgets('a song without timed lyrics shows the message instead',
        (tester) async {
      await _open(tester,
          song: _song(lyrics: const [
            LyricLine(text: 'Ave verum corpus', onsetMs: null),
          ]));

      expect(find.byType(LyricView), findsNothing);
      expect(find.text('Esta música ainda não tem letra sincronizada'),
          findsOneWidget);
    });

    testWidgets('mix: M, S and volume reach the engine', (tester) async {
      final setup = await _open(tester);
      final tenor = await _scrollTo(tester, 'tenor');

      await tester.tap(find.descendant(
        of: tenor,
        matching: find.widgetWithText(MuteSoloToggle, 'M'),
      ));
      await tester.pump();
      await tester.tap(find.descendant(
        of: tenor,
        matching: find.widgetWithText(MuteSoloToggle, 'S'),
      ));
      await tester.pump();
      await tester.drag(
        find.descendant(of: tenor, matching: find.byType(Slider)),
        const Offset(-2000, 0),
      );
      await tester.pump();

      expect(setup.engine.calls, contains('mute:tenor:true'));
      expect(setup.engine.calls, contains('solo:tenor:true'));
      expect(setup.engine.volumes['tenor'], 0.0);
      final row = tester.widget<MixTrackRow>(tenor);
      expect(row.muted, isTrue);
      expect(row.solo, isTrue);
    });

    testWidgets('leaving the screen stops the audio', (tester) async {
      final setup = await _open(tester);
      await _tapText(tester, 'Tocar');

      await tester.tap(find.text('‹ Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('route:song-detail:ave'), findsOneWidget);
      expect(setup.engine.calls.last, 'stop');
    });

    testWidgets('position ticks do not rebuild the mix rows', (tester) async {
      final setup = await _open(tester);
      await _tapText(tester, 'Tocar');
      final tenor = await _scrollTo(tester, 'tenor');
      final before = tester.widget<MixTrackRow>(tenor);

      await _emit(tester, setup.engine, 1000);
      await _emit(tester, setup.engine, 1100);

      final after = tester.widget<MixTrackRow>(tenor);
      expect(identical(before, after), isTrue);
    });
  });

  group('loop (SOLO-14 to SOLO-18)', () {
    testWidgets('marking buttons are disabled while paused', (tester) async {
      await _open(tester);

      expect(_tonal(tester, 'Marcar início do loop').onPressed, isNull);
    });

    // Regression (sensor S9): "Marcar fim do loop" while paused was never
    // checked (spec P3-AC7).
    testWidgets('"Marcar fim do loop" is disabled while paused',
        (tester) async {
      final setup = await _open(tester);
      await _tapText(tester, 'Tocar');
      await _emit(tester, setup.engine, 41000);
      await _tapText(tester, 'Marcar início do loop');

      await _tapText(tester, 'Pausar');

      expect(_tonal(tester, 'Marcar fim do loop').onPressed, isNull);
    });

    testWidgets('início → fim → "Repetindo trecho 0:41–1:12" → desligar',
        (tester) async {
      final setup = await _open(tester);
      await _tapText(tester, 'Tocar');
      await _emit(tester, setup.engine, 41000);

      await _tapText(tester, 'Marcar início do loop');
      expect(find.text('Marcar fim do loop'), findsOneWidget);

      await _emit(tester, setup.engine, 72000);
      await _tapText(tester, 'Marcar fim do loop');
      expect(find.text('Repetindo trecho 0:41–1:12'), findsOneWidget);
      expect(find.text('Desligar loop'), findsOneWidget);

      await _emit(tester, setup.engine, 72000);
      expect(setup.engine.calls.last, 'seek:41000');

      await _tapText(tester, 'Desligar loop');
      expect(find.textContaining('Repetindo trecho'), findsNothing);
      expect(find.text('Marcar início do loop'), findsOneWidget);
    });

    testWidgets('an end before the start shows the refusal banner',
        (tester) async {
      final setup = await _open(tester);
      await _tapText(tester, 'Tocar');
      await _emit(tester, setup.engine, 41000);
      await _tapText(tester, 'Marcar início do loop');

      await _tapText(tester, 'Marcar fim do loop'); // same instant

      expect(find.text('O fim do trecho precisa vir depois do início.'),
          findsOneWidget);
      expect(find.text('Marcar fim do loop'), findsOneWidget);
    });
  });

  group('themes, font scale and semantics (AGENTS.md §7)', () {
    testWidgets('one primary action: "Tocar"/"Pausar"', (tester) async {
      await _open(tester);

      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    testWidgets('dark theme renders the ready and looping states',
        (tester) async {
      final setup = await _open(tester, theme: AppTheme.dark);
      await _tapText(tester, 'Tocar');
      await _emit(tester, setup.engine, 41000);
      await _tapText(tester, 'Marcar início do loop');

      expect(tester.takeException(), isNull);
      expect(find.text('Marcar fim do loop'), findsOneWidget);
    });

    testWidgets('360 dp at 130% font: footer fits, targets >= 44 dp',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _open(tester);

      expect(tester.takeException(), isNull);
      for (final label in ['Tocar', 'Marcar início do loop']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (w) => w is PrimaryButton || w is TonalButton,
          ),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44),
            reason: label);
      }
    });
  });
}
