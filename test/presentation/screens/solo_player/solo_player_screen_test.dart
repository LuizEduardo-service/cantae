import 'dart:async';

import 'package:cantae/domain/audio/audio_interruptions.dart';
import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/audio/click_track_builder.dart';
import 'package:cantae/domain/audio/playback_remote.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/metronome_config.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:cantae/presentation/providers/background_audio_providers.dart';
import 'package:cantae/presentation/providers/click_track_builder_provider.dart';
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
  Future<void> addTrack(SongTrack track, {bool exemptFromSolo = false}) async =>
      calls.add('add:${track.id}');

  @override
  Future<void> setDucked(bool ducked) async => calls.add('ducked:$ducked');

  @override
  Future<void> removeTrack(String trackId) async =>
      calls.add('remove:$trackId');

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

  Song? savedSong;

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async {
    savedSong = song;
    this.song = song;
    return const Result.success(Unit());
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

class _FakeClickTrackBuilder implements ClickTrackBuilder {
  bool fail = false;

  @override
  Future<Result<String, Failure>> build({
    required String songId,
    required MetronomeConfig config,
    required int durationMs,
  }) async {
    if (fail) {
      return Result.failure(PlaybackFailure(code: 'click_track_build_failed'));
    }
    return Result.success('/tmp/metronome_$songId.wav');
  }
}

class _FakeInterruptions implements AudioInterruptions {
  final controller = StreamController<AudioInterruption>.broadcast();

  @override
  Stream<AudioInterruption> get events => controller.stream;
}

class _FakeRemote implements PlaybackRemote {
  final controller = StreamController<RemoteCommand>.broadcast();

  @override
  void publish(NowPlaying info) {}

  @override
  void clear() {}

  @override
  Stream<RemoteCommand> get commands => controller.stream;
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
  MetronomeConfig? metronomeConfig,
  SongOrigin origin = SongOrigin.created,
}) =>
    Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      tracks: tracks,
      lyrics: lyrics,
      metronomeConfig: metronomeConfig,
      origin: origin,
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
          path: '/song-editor/:id',
          name: 'track-upload',
          builder: (_, state) => Text(
            'route:track-upload:${state.pathParameters['id']}'
            '${state.uri.query.isEmpty ? '' : '?${state.uri.query}'}',
          ),
        ),
        GoRoute(
          path: '/solo-player/:id',
          name: 'solo-player',
          builder: (_, state) =>
              SoloPlayerScreen(songId: state.pathParameters['id']!),
        ),
      ],
    );

Future<
    ({
      _FakeAudioPlaybackEngine engine,
      _FakeSongRepository repo,
      _FakeClickTrackBuilder builder,
      _FakeInterruptions interruptions,
      _FakeRemote remote,
    })> _open(
  WidgetTester tester, {
  Song? song,
  bool notFound = false,
  Failure? failure,
  bool throwOnLoad = false,
  bool clickFails = false,
  ThemeData? theme,
}) async {
  final engine = _FakeAudioPlaybackEngine()..throwOnLoad = throwOnLoad;
  final builder = _FakeClickTrackBuilder()..fail = clickFails;
  final interruptions = _FakeInterruptions();
  final remote = _FakeRemote();
  final repo = _FakeSongRepository(
    song: notFound ? null : (song ?? _song()),
    failure: failure,
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      audioPlaybackEngineProvider.overrideWithValue(engine),
      songRepositoryProvider.overrideWithValue(repo),
      clickTrackBuilderProvider.overrideWithValue(builder),
      audioInterruptionsProvider.overrideWithValue(interruptions),
      playbackRemoteProvider.overrideWithValue(remote),
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: _router(),
    ),
  ));
  await tester.pumpAndSettle();
  return (
    engine: engine,
    repo: repo,
    builder: builder,
    interruptions: interruptions,
    remote: remote,
  );
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
      expect(find.text('route:track-upload:ave'), findsOneWidget);
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

    testWidgets('a custom naipe mixes under its own name and initial (UPL-16)',
        (tester) async {
      await _open(tester,
          song: _song(tracks: const [
            ..._tracks,
            SongTrack(
              id: 'solista',
              filePath: '/tmp/sol.mp3',
              naipe: Naipe.custom,
              customNaipe: CustomNaipe(id: 'n1', name: 'Solista'),
            ),
          ]));
      final row = await _scrollTo(tester, 'solista');

      expect(find.descendant(of: row, matching: find.text('Solista')),
          findsOneWidget);
      expect(
          find.descendant(of: row, matching: find.text('S')), findsNWidgets(2),
          reason: 'badge initial + the solo toggle');
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

  group('metronome (MET-04 to MET-17)', () {
    const tempo72 = MetronomeConfig(bpm: 72, beatsPerMeasure: 4);

    Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );

    testWidgets('"Metrônomo ♩ 72" turns the click on and off', (tester) async {
      final setup = await _open(tester, song: _song(metronomeConfig: tempo72));
      expect(_tonal(tester, 'Metrônomo ♩ 72').positive, isFalse);
      expect(find.byKey(const ValueKey('mix-metronome')), findsNothing);

      await _tapText(tester, 'Metrônomo ♩ 72');
      await tester.pumpAndSettle();
      expect(_tonal(tester, 'Metrônomo ♩ 72').positive, isTrue);
      expect(setup.engine.calls, contains('add:metronome'));

      await _tapText(tester, 'Metrônomo ♩ 72');
      await tester.pumpAndSettle();
      expect(_tonal(tester, 'Metrônomo ♩ 72').positive, isFalse);
      expect(setup.engine.calls.last, 'remove:metronome');
    });

    testWidgets('the "Metrônomo" mix row: M without S, volume reaches it',
        (tester) async {
      final setup = await _open(tester, song: _song(metronomeConfig: tempo72));
      await _tapText(tester, 'Metrônomo ♩ 72');
      await tester.pumpAndSettle();

      final row = await _scrollTo(tester, 'metronome');
      expect(
          find.descendant(
              of: row, matching: find.widgetWithText(MuteSoloToggle, 'M')),
          findsOneWidget);
      expect(
          find.descendant(
              of: row, matching: find.widgetWithText(MuteSoloToggle, 'S')),
          findsNothing);

      await tester.drag(
        find.descendant(of: row, matching: find.byType(Slider)),
        const Offset(-2000, 0),
      );
      await tester.pump();
      expect(setup.engine.volumes['metronome'], 0.0);
    });

    testWidgets('no tempo: "Metrônomo" opens the sheet; saving turns it on',
        (tester) async {
      final setup = await _open(tester);

      await _tapText(tester, 'Metrônomo');
      await tester.pumpAndSettle();
      expect(find.text('Andamento'), findsOneWidget);
      expect(tester.widget<TextField>(field('BPM')).controller!.text, '72');

      await tester.enterText(field('BPM'), '96');
      await tester.tap(find.text('Salvar andamento'));
      await tester.pumpAndSettle();

      expect(find.text('Andamento salvo'), findsOneWidget);
      expect(_tonal(tester, 'Metrônomo ♩ 96').positive, isTrue);
      expect(setup.repo.savedSong!.metronomeConfig!.bpm, 96);
      await tester.pump(const Duration(seconds: 3)); // toast goes away
    });

    testWidgets('"Ajustar andamento" opens the sheet with the saved tempo',
        (tester) async {
      await _open(tester,
          song: _song(
              metronomeConfig:
                  const MetronomeConfig(bpm: 88, beatsPerMeasure: 3)));

      await tester.scrollUntilVisible(
        find.text('Ajustar andamento'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('88 BPM · 3 tempos'), findsOneWidget);
      await tester.tap(find.text('Ajustar andamento'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field('BPM')).controller!.text, '88');
      expect(
        tester.widget<TextField>(field('Tempos por compasso')).controller!.text,
        '3',
      );
    });

    testWidgets('received song without tempo: disabled, with the reason',
        (tester) async {
      await _open(tester, song: _song(origin: SongOrigin.received));

      expect(_tonal(tester, 'Metrônomo').onPressed, isNull);
      expect(
        find.text('Música recebida: só quem criou pode definir o andamento.'),
        findsOneWidget,
      );
    });

    testWidgets('received song with tempo: toggles, no "Ajustar andamento"',
        (tester) async {
      final setup = await _open(tester,
          song: _song(origin: SongOrigin.received, metronomeConfig: tempo72));

      await _tapText(tester, 'Metrônomo ♩ 72');
      await tester.pumpAndSettle();

      expect(setup.engine.calls, contains('add:metronome'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('Ajustar andamento'), findsNothing);
    });

    testWidgets('a click that cannot be prepared shows the reason',
        (tester) async {
      await _open(tester,
          song: _song(metronomeConfig: tempo72), clickFails: true);

      await _tapText(tester, 'Metrônomo ♩ 72');
      await tester.pumpAndSettle();

      expect(
          find.text('Não foi possível preparar o metrônomo.'), findsOneWidget);
      expect(_tonal(tester, 'Metrônomo ♩ 72').positive, isFalse);
    });

    testWidgets('"ligar ao abrir" opens with the metronome on', (tester) async {
      await _open(tester,
          song: _song(
              metronomeConfig: const MetronomeConfig(
            bpm: 72,
            beatsPerMeasure: 4,
            enabledByDefault: true,
          )));

      expect(_tonal(tester, 'Metrônomo ♩ 72').positive, isTrue);
    });

    testWidgets('dark theme with the metronome on', (tester) async {
      await _open(tester,
          song: _song(metronomeConfig: tempo72), theme: AppTheme.dark);
      await _tapText(tester, 'Metrônomo ♩ 72');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    testWidgets('360 dp at 130%: the two-row footer fits, targets >= 44 dp',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _open(tester, song: _song(origin: SongOrigin.received));

      expect(tester.takeException(), isNull);
      for (final label in ['Tocar', 'Marcar início do loop', 'Metrônomo']) {
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

  group('external pause (BGA-14)', () {
    Future<void> interrupt(
      WidgetTester tester,
      _FakeInterruptions interruptions,
      AudioInterruption event,
    ) async {
      interruptions.controller.add(event);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a call while the app is open: "Tocar" and the toast now',
        (tester) async {
      final s = await _open(tester);
      await _tapText(tester, 'Tocar');

      await interrupt(tester, s.interruptions, AudioInterruption.pauseBegan);

      expect(find.text('Tocar'), findsOneWidget);
      expect(find.text('Música pausada: outro áudio começou'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('headphones disconnected: its own toast', (tester) async {
      final s = await _open(tester);
      await _tapText(tester, 'Tocar');

      await interrupt(
          tester, s.interruptions, AudioInterruption.headphonesDisconnected);

      expect(find.text('Música pausada: fone desconectado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
        'paused in the background: the toast waits for the return, '
        'and shows once', (tester) async {
      final s = await _open(tester);
      await _tapText(tester, 'Tocar');
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await interrupt(tester, s.interruptions, AudioInterruption.pauseBegan);
      expect(find.text('Música pausada: outro áudio começou'), findsNothing);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Música pausada: outro áudio começou'), findsOneWidget);
      expect(find.text('Tocar'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Música pausada: outro áudio começou'), findsNothing);
    });

    testWidgets('Pausar from the lock screen: "Tocar" without a toast',
        (tester) async {
      final s = await _open(tester);
      await _tapText(tester, 'Tocar');

      s.remote.controller.add(const RemotePause());
      await tester.pump();
      await tester.pump();

      expect(find.text('Tocar'), findsOneWidget);
      expect(find.textContaining('Música pausada'), findsNothing);
    });

    testWidgets('the toast renders under the dark theme', (tester) async {
      final s = await _open(tester, theme: AppTheme.dark);
      await _tapText(tester, 'Tocar');

      await interrupt(tester, s.interruptions, AudioInterruption.pauseBegan);

      expect(tester.takeException(), isNull);
      expect(find.text('Música pausada: outro áudio começou'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
