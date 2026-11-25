import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/audio/lyric_cursor.dart';
import '../../../domain/audio/loop_controller.dart';
import '../../../domain/entities/lyric_line.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/song_track.dart';
import '../../providers/solo_player_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/lyric_view.dart';
import '../../widgets/mix_track_row.dart';
import '../../widgets/naipe_labels.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/playback_progress.dart';
import '../../widgets/status_pill.dart';

/// Everything the screen renders except the playback position. Watching
/// this (instead of the whole state) keeps position ticks from rebuilding
/// the mix rows; only [PlaybackProgress] and [LyricView] listen to the
/// position, each in its own `Consumer`.
typedef _View = ({
  SoloPlayerStatus status,
  Song? song,
  int durationMs,
  bool playing,
  Map<String, TrackMix> mix,
  String? soloTrackId,
  int? loopStartMs,
  LoopController? loop,
  String? loopError,
});

_View _viewOf(SoloPlayerState s) => (
      status: s.status,
      song: s.song,
      durationMs: s.durationMs,
      playing: s.playing,
      mix: s.mix,
      soloTrackId: s.soloTrackId,
      loopStartMs: s.loopStartMs,
      loop: s.loop,
      loopError: s.loopError,
    );

/// `m:ss`, for the loop caption ("Repetindo trecho 0:41–1:12").
String _minutesSeconds(int ms) {
  final totalSeconds = ms ~/ 1000;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '${totalSeconds ~/ 60}:$seconds';
}

/// `solo-player` — `UI_SPEC.md` §6.12. All states live in this one file
/// (same precedent as `LyricsEditorScreen`). Leaving the screen disposes
/// [soloPlayerProvider], which stops the audio.
class SoloPlayerScreen extends ConsumerWidget {
  const SoloPlayerScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(soloPlayerProvider(songId).select(_viewOf));
    final notifier = ref.read(soloPlayerProvider(songId).notifier);
    void back() =>
        context.goNamed('song-detail', pathParameters: {'id': songId});

    switch (view.status) {
      case SoloPlayerStatus.loading:
        return _StateScaffold(onBack: back, body: const _LoadingBody());
      case SoloPlayerStatus.notFound:
        return _StateScaffold(
          backLabel: 'Biblioteca',
          onBack: () => context.goNamed('library'),
          body: const _NotFoundBody(),
        );
      case SoloPlayerStatus.error:
        return _StateScaffold(
          onBack: back,
          body: _ErrorBody(
            title: 'Não foi possível abrir a música',
            message: 'A música não pôde ser lida neste aparelho. '
                'Tente de novo.',
            onRetry: notifier.retry,
          ),
        );
      case SoloPlayerStatus.noTracks:
        return _StateScaffold(onBack: back, body: const _NoTracksBody());
      case SoloPlayerStatus.audioError:
        return _StateScaffold(
          onBack: back,
          body: _ErrorBody(
            title: 'Não foi possível tocar',
            message: 'Não foi possível tocar as faixas desta música.',
            onRetry: notifier.retry,
          ),
        );
      case SoloPlayerStatus.ready:
        return _ReadyScaffold(
          songId: songId,
          view: view,
          notifier: notifier,
          onBack: back,
        );
    }
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.onBack,
    required this.body,
    this.backLabel = 'Voltar',
  });

  final String backLabel;
  final VoidCallback onBack;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: backLabel,
        onTap: onBack,
      ),
      topRight: const StatusPill(label: 'Funciona offline'),
      body: body,
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(color: colors.accent),
      ),
    );
  }
}

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'Música não encontrada',
      message:
          'Essa música não existe mais ou nunca existiu na sua biblioteca.',
      primaryLabel: 'Voltar à Biblioteca',
      onPrimary: () => context.goNamed('library'),
    );
  }
}

class _NoTracksBody extends StatelessWidget {
  const _NoTracksBody();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.music_off,
      title: 'Esta música ainda não tem faixas',
      message: 'Envie ao menos uma faixa para ensaiar esta música.',
      primaryLabel: 'Enviar faixa',
      onPrimary: () => context.goNamed('track-upload'),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InlineBanner(
        variant: InlineBannerVariant.error,
        title: title,
        message: message,
        actionLabel: 'Tentar de novo',
        onAction: onRetry,
      ),
    );
  }
}

class _ReadyScaffold extends StatelessWidget {
  const _ReadyScaffold({
    required this.songId,
    required this.view,
    required this.notifier,
    required this.onBack,
  });

  final String songId;
  final _View view;
  final SoloPlayerNotifier notifier;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final song = view.song!;
    final tracks = [
      ...song.tracks,
      if (song.playbackTrack != null) song.playbackTrack!,
    ];
    final timedLines =
        song.lyrics.where((line) => line.onsetMs != null).toList();

    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: 'Voltar',
        onTap: onBack,
      ),
      topRight: const StatusPill(label: 'Funciona offline'),
      body: ListView(
        children: [
          const SizedBox(height: CantaeSpacing.space4),
          Text(
            song.name,
            style: CantaeTypography.titlePage.copyWith(color: colors.text),
          ),
          const SizedBox(height: CantaeSpacing.space1),
          Text(
            song.author,
            style: CantaeTypography.body.copyWith(color: colors.text2),
          ),
          const SizedBox(height: CantaeSpacing.space5),
          if (timedLines.isEmpty)
            Text(
              'Esta música ainda não tem letra sincronizada',
              style: CantaeTypography.body.copyWith(color: colors.text2),
            )
          else
            _Lyrics(songId: songId, lines: timedLines),
          const SizedBox(height: CantaeSpacing.space5),
          Text(
            'Mix por naipe',
            style: CantaeTypography.caption.copyWith(color: colors.text2),
          ),
          const SizedBox(height: CantaeSpacing.space2),
          for (final track in tracks) ...[
            _mixRow(track),
            const SizedBox(height: CantaeSpacing.space3),
          ],
        ],
      ),
      footer: _Footer(songId: songId, view: view, notifier: notifier),
    );
  }

  Widget _mixRow(SongTrack track) {
    final mix = view.mix[track.id] ?? const TrackMix();
    final String label;
    if (track.isPlayback) {
      label = 'Playback';
    } else {
      final name = naipeDisplayName(track.naipe);
      label = name.isEmpty ? 'Outro naipe' : name;
    }
    return MixTrackRow(
      key: ValueKey('mix-${track.id}'),
      naipe: track.isPlayback ? null : track.naipe,
      label: label,
      volume: mix.volume,
      muted: mix.muted,
      solo: view.soloTrackId == track.id,
      onVolumeChanged: (volume) => notifier.setVolume(track.id, volume),
      onMuteToggled: () => notifier.toggleMute(track.id),
      onSoloToggled: () => notifier.toggleSolo(track.id),
    );
  }
}

/// Rebuilds only when the cursor moves to another line, not on every tick.
class _Lyrics extends ConsumerWidget {
  const _Lyrics({required this.songId, required this.lines});

  final String songId;
  final List<LyricLine> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursor = ref.watch(soloPlayerProvider(songId)
        .select((s) => LyricCursor.at(lines, s.positionMs)));
    return LyricView(lines: lines, cursor: cursor);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.songId,
    required this.view,
    required this.notifier,
  });

  final String songId;
  final _View view;
  final SoloPlayerNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final loop = view.loop;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final positionMs = ref.watch(
              soloPlayerProvider(songId).select((s) => s.positionMs),
            );
            return PlaybackProgress(
              positionMs: positionMs,
              durationMs: view.durationMs,
              loopStartMs: loop?.startMs,
              loopEndMs: loop?.endMs,
              caption: loop == null
                  ? null
                  : 'Repetindo trecho ${_minutesSeconds(loop.startMs)}–'
                      '${_minutesSeconds(loop.endMs)}',
              onSeek: notifier.seekTo,
            );
          },
        ),
        if (view.loopError != null) ...[
          const SizedBox(height: CantaeSpacing.space2),
          Semantics(
            liveRegion: true,
            child: InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Trecho recusado',
              message: view.loopError!,
            ),
          ),
        ],
        const SizedBox(height: CantaeSpacing.space3),
        Row(
          children: [
            Expanded(child: _loopButton()),
            const SizedBox(width: CantaeSpacing.space3),
            Expanded(
              child: PrimaryButton(
                label: view.playing ? 'Pausar' : 'Tocar',
                onPressed: notifier.togglePlay,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _loopButton() {
    if (view.loop != null) {
      return TonalButton(
        label: 'Desligar loop',
        positive: true,
        onPressed: notifier.clearLoop,
      );
    }
    if (view.loopStartMs != null) {
      return TonalButton(
        label: 'Marcar fim do loop',
        onPressed: view.playing ? notifier.markLoopEnd : null,
      );
    }
    return TonalButton(
      label: 'Marcar início do loop',
      onPressed: view.playing ? notifier.markLoopStart : null,
    );
  }
}
