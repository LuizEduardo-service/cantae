import 'dart:io';

import 'package:cantae/domain/audio/metronome_pulse_generator.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/infrastructure/audio/click_track_wav.dart';
import 'package:cantae/infrastructure/audio/multi_track_audio_engine.dart';
import 'package:cantae/presentation/providers/audio_playback_engine_provider.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/screens/solo_player/solo_player_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Device-only check for background-audio BGA-16 (and the solo-metronome
/// fixes MET-01/MET-02, never run on a device before):
/// Modo solo with two real tracks, real `just_audio` players, "Tocar",
/// then 2 s of playback.
///
/// Artifact: `background_audio.log` in the app documents directory, also
/// printed with the `BACKGROUND_AUDIO_LOG` prefix so `flutter test` output
/// keeps it. Run with:
///   flutter test -d <device-id> integration_test/background_audio_test.dart
///
/// Locked-screen and notification behavior cannot be driven from a test;
/// `docs/device-test-background-audio.md` covers it by hand.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Modo solo plays both tracks and the clock advances',
      (tester) async {
    final dir = await getApplicationDocumentsDirectory();
    final soprano = await _writeTrack(dir, 'bg_soprano.wav', bpm: 60);
    final tenor = await _writeTrack(dir, 'bg_tenor.wav', bpm: 90);
    final song = Song(
      id: 'ave',
      name: 'Ave Verum Corpus',
      author: 'Mozart',
      tracks: [
        SongTrack(id: 'soprano', filePath: soprano, naipe: Naipe.soprano),
        SongTrack(id: 'tenor', filePath: tenor, naipe: Naipe.tenor),
      ],
    );

    final players = <AudioPlayer>[];
    final engine = MultiTrackAudioEngine(playerFactory: () {
      final player = MultiTrackAudioEngine.defaultPlayer();
      players.add(player);
      return player;
    });
    final positions = <int>[];
    final subscription = engine.positionMs.listen(positions.add);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioPlaybackEngineProvider.overrideWithValue(engine),
        songRepositoryProvider.overrideWithValue(_OneSong(song)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          initialLocation: '/solo-player/ave',
          routes: [
            GoRoute(
              path: '/songs/:id',
              name: 'song-detail',
              builder: (_, __) => const SizedBox(),
            ),
            GoRoute(
              path: '/solo-player/:id',
              name: 'solo-player',
              builder: (_, state) =>
                  SoloPlayerScreen(songId: state.pathParameters['id']!),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tocar'));
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < const Duration(seconds: 2)) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final playing = [for (final player in players) player.playing];
    final advancedMs = positions.isEmpty ? 0 : positions.last;
    final log = [
      'BACKGROUND_AUDIO_LOG players=${players.length}',
      for (var i = 0; i < players.length; i++)
        'BACKGROUND_AUDIO_LOG player[$i].playing=${playing[i]} '
            'position=${players[i].position.inMilliseconds}ms',
      'BACKGROUND_AUDIO_LOG timeline_advanced=${advancedMs}ms '
          'ticks=${positions.length}',
    ];
    File('${dir.path}/background_audio.log').writeAsStringSync(
      '${log.join('\n')}\n',
    );
    log.forEach(debugPrint);

    await subscription.cancel();
    expect(players, hasLength(2));
    expect(playing, everyElement(isTrue));
    expect(advancedMs, greaterThanOrEqualTo(1500));
  });
}

Future<String> _writeTrack(Directory dir, String name, {required int bpm}) {
  const durationMs = 10000;
  final pulses = [
    for (var ms = 0; ms < durationMs; ms += 60000 ~/ bpm)
      MetronomePulse(positionMs: ms, isDownbeat: ms == 0),
  ];
  final file = File('${dir.path}/$name');
  return file
      .writeAsBytes(
          ClickTrackWav.encode(pulses: pulses, durationMs: durationMs))
      .then((f) => f.path);
}

class _OneSong implements SongRepository {
  _OneSong(this.song);

  final Song song;

  @override
  Future<Result<Song, Failure>> getById(String id) async =>
      Result.success(song);

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) async =>
      const Result.success(Unit());

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      Result.success([song]);

  @override
  Future<Result<Unit, Failure>> delete(String id) async =>
      const Result.success(Unit());

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() async =>
      const Result.success(Unit());

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) async =>
      const Result.success(Unit());
}
