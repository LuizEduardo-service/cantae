import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'package:cantae/domain/audio/audio_mix_calculator.dart';
import 'package:cantae/domain/audio/audio_playback_engine.dart';
import 'package:cantae/domain/audio/timeline_converter.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';

/// Infrastructure implementation of [AudioPlaybackEngine] using one
/// `just_audio` `AudioPlayer` per track (design.md's `MultiTrackAudioEngine`).
/// Applies [AudioMixCalculator] gains and [TimelineConverter] seek targets —
/// both unchanged pure domain math; this class is the only place
/// `package:just_audio` is imported (AD-001).
///
/// API verified against the installed `just_audio` package source
/// (pub cache `just_audio-0.9.46`, satisfying `pubspec.yaml`'s `^0.9.39`):
/// `AudioPlayer.setFilePath(String)`, `play()`, `pause()`, `stop()`,
/// `setVolume(double)`, `seek(Duration?, {int? index})`, `dispose()` all
/// match design.md's sketch exactly — no deviation needed for the
/// transport-control surface.
///
/// SPEC_DEVIATION: design.md's `MultiTrackAudioEngine` purpose line says
/// gains come from `AudioMixCalculator.ownGain`/`choirGain`, but neither
/// `AudioPlaybackEngine.loadSong(Song)` nor `Song`/`SongTrack` carries a
/// per-device "own naipe" selection or mix ratio today — that selection is
/// presentation-layer state not yet wired through the domain. Until that
/// input exists, this engine applies `AudioMixCalculator.ownGain(1.0)` (full
/// volume, mix = 1.0) to every non-playback naipe track and full volume to
/// the playback track, leaving `choirGain` unused. This keeps the engine
/// compiling and functionally correct for the common single-naipe-selected
/// case without inventing a mix-selection API the task didn't ask for.
class MultiTrackAudioEngine implements AudioPlaybackEngine {
  final AudioPlayer Function() _playerFactory;
  final Map<String, AudioPlayer> _playersByTrackId = {};
  final Map<String, int> _startDelayMsByTrackId = {};
  final Map<String, double> _baseGainByTrackId = {};
  final Map<String, bool> _mutedByTrackId = {};
  final Map<String, double> _volumeByTrackId = {};
  final Map<String, int?> _fileDurationMsByTrackId = {};
  final StreamController<int> _positionMsController =
      StreamController<int>.broadcast();
  String? _soloTrackId;
  StreamSubscription<PlaybackEvent>? _referencePlaybackEventSubscription;

  MultiTrackAudioEngine({AudioPlayer Function()? playerFactory})
      : _playerFactory = playerFactory ?? AudioPlayer.new;

  @override
  Future<void> loadSong(Song song) async {
    await _disposeAllPlayers();

    final tracks = <SongTrack>[
      ...song.tracks,
      if (song.playbackTrack != null) song.playbackTrack!,
    ];

    for (final track in tracks) {
      final player = _playerFactory();
      final baseGain = track.isPlayback ? 1.0 : AudioMixCalculator.ownGain(1.0);
      final fileDuration = await player.setFilePath(track.filePath);
      await player.setVolume(baseGain);
      _playersByTrackId[track.id] = player;
      _startDelayMsByTrackId[track.id] = track.startDelayMs;
      _baseGainByTrackId[track.id] = baseGain;
      _mutedByTrackId[track.id] = false;
      _volumeByTrackId[track.id] = 1.0;
      _fileDurationMsByTrackId[track.id] = fileDuration?.inMilliseconds;
    }

    if (tracks.isNotEmpty) {
      final referenceTrack = tracks.first;
      final referencePlayer = _playersByTrackId[referenceTrack.id]!;
      final referenceStartDelayMs = referenceTrack.startDelayMs;
      _referencePlaybackEventSubscription =
          referencePlayer.playbackEventStream.listen((event) {
        _positionMsController.add(TimelineConverter.toTimeline(
          trackLocalMs: event.updatePosition.inMilliseconds,
          startDelayMs: referenceStartDelayMs,
        ));
      });
    }
  }

  @override
  Future<void> setTrackMuted(String trackId, bool muted) async {
    _mutedByTrackId[trackId] = muted;
    await _applyVolume(trackId);
  }

  @override
  Future<void> setTrackSolo(String trackId, bool solo) async {
    if (solo) {
      _soloTrackId = trackId;
    } else if (_soloTrackId == trackId) {
      _soloTrackId = null;
    }
    for (final id in _playersByTrackId.keys) {
      await _applyVolume(id);
    }
  }

  @override
  Future<void> setTrackVolume(String trackId, double volume) async {
    _volumeByTrackId[trackId] = volume.clamp(0.0, 1.0);
    await _applyVolume(trackId);
  }

  @override
  Future<void> setTrackStartDelayMs(String trackId, int startDelayMs) async {
    _startDelayMsByTrackId[trackId] = startDelayMs;
  }

  @override
  int? get durationMs {
    int? maxMs;
    for (final entry in _startDelayMsByTrackId.entries) {
      final fileDurationMs = _fileDurationMsByTrackId[entry.key];
      if (fileDurationMs == null) continue;
      final totalMs = entry.value + fileDurationMs;
      if (maxMs == null || totalMs > maxMs) {
        maxMs = totalMs;
      }
    }
    return maxMs;
  }

  @override
  Stream<int> get positionMs => _positionMsController.stream;

  Future<void> _applyVolume(String trackId) async {
    final player = _playersByTrackId[trackId];
    if (player == null) return;
    await player.setVolume(_effectiveVolume(trackId));
  }

  double _effectiveVolume(String trackId) {
    final gain = (_baseGainByTrackId[trackId] ?? 1.0) *
        (_volumeByTrackId[trackId] ?? 1.0);
    if (_soloTrackId != null) {
      return trackId == _soloTrackId ? gain : 0.0;
    }
    final muted = _mutedByTrackId[trackId] ?? false;
    return muted ? 0.0 : gain;
  }

  @override
  Future<void> playAt(DateTime scheduledStart) async {
    final delay = scheduledStart.difference(DateTime.now());
    if (!delay.isNegative) {
      await Future<void>.delayed(delay);
    }
    for (final player in _playersByTrackId.values) {
      await player.play();
    }
  }

  @override
  Future<void> pause() async {
    for (final player in _playersByTrackId.values) {
      await player.pause();
    }
  }

  @override
  Future<void> stop() async {
    for (final player in _playersByTrackId.values) {
      await player.stop();
    }
  }

  @override
  Future<void> seekAllTo(int timelineMs) async {
    for (final entry in _playersByTrackId.entries) {
      final startDelayMs = _startDelayMsByTrackId[entry.key] ?? 0;
      final localMs = TimelineConverter.toTrackLocal(
        timelineMs: timelineMs,
        startDelayMs: startDelayMs,
      );
      await entry.value.seek(Duration(milliseconds: localMs));
    }
  }

  Future<void> _disposeAllPlayers() async {
    await _referencePlaybackEventSubscription?.cancel();
    _referencePlaybackEventSubscription = null;
    for (final player in _playersByTrackId.values) {
      await player.dispose();
    }
    _playersByTrackId.clear();
    _startDelayMsByTrackId.clear();
    _baseGainByTrackId.clear();
    _mutedByTrackId.clear();
    _volumeByTrackId.clear();
    _fileDurationMsByTrackId.clear();
    _soloTrackId = null;
  }

  /// Releases every track's `AudioPlayer`. Not part of [AudioPlaybackEngine]
  /// — called by infrastructure owners (e.g. [BackgroundAudioHandler]) when
  /// the engine itself is being torn down, not on every song change.
  Future<void> dispose() async {
    await _disposeAllPlayers();
    await _positionMsController.close();
  }
}
