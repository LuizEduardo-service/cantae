import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/audio/lyric_cursor.dart';
import '../../../domain/audio/loop_controller.dart';
import '../../../domain/entities/lyric_line.dart';
import '../../../domain/entities/metronome_config.dart';
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
import '../../widgets/tempo_sheet.dart';
import '../../widgets/toast.dart';

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
  bool metronomeOn,
  double metronomeVolume,
  bool metronomeMuted,
  bool metronomeBusy,
  String? metronomeError,
  bool canEditTempo,
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
      metronomeOn: s.metronomeOn,
      metronomeVolume: s.metronomeVolume,
      metronomeMuted: s.metronomeMuted,
      metronomeBusy: s.metronomeBusy,
      metronomeError: s.metronomeError,
      canEditTempo: s.canEditTempo,
    );

/// Opens the "Andamento" sheet; a successful save shows "Andamento salvo".
Future<void> _openTempoSheet(
  BuildContext context,
  SoloPlayerNotifier notifier,
  MetronomeConfig? current,
) {
  return TempoSheet.show(
    context,
    initial: current ?? const MetronomeConfig(bpm: 72, beatsPerMeasure: 4),
    onSave: (config) async {
      final saved = await notifier.saveTempo(config);
      if (!saved) return tempoSaveFailedMessage;
      if (context.mounted) Toast.show(context, 'Andamento salvo');
      return null;
    },
  );
}

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
        return _StateScaffold(
            onBack: back, body: _NoTracksBody(songId: songId));
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
        return _ExternalPauseToast(
          songId: songId,
          child: _ReadyScaffold(
            songId: songId,
            view: view,
            notifier: notifier,
            onBack: back,
          ),
        );
    }
  }
}

/// Says why the music paused without the person asking (BGA-14). While the
/// app is in the background the toast would disappear unseen, so it waits
/// for the return.
class _ExternalPauseToast extends ConsumerStatefulWidget {
  const _ExternalPauseToast({required this.songId, required this.child});

  final String songId;
  final Widget child;

  @override
  ConsumerState<_ExternalPauseToast> createState() =>
      _ExternalPauseToastState();
}

class _ExternalPauseToastState extends ConsumerState<_ExternalPauseToast> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _showPending);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _showPending() {
    final provider = soloPlayerProvider(widget.songId);
    final reason = ref.read(provider).externalPause;
    if (reason == null || !mounted) return;
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    Toast.show(
      context,
      switch (reason) {
        ExternalPause.interruption => 'Música pausada: outro áudio começou',
        ExternalPause.headphones => 'Música pausada: fone desconectado',
      },
    );
    ref.read(provider.notifier).acknowledgeExternalPause();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      soloPlayerProvider(widget.songId).select((s) => s.externalPause),
      (_, next) {
        if (next != null) _showPending();
      },
    );
    return widget.child;
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
  const _NoTracksBody({required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.music_off,
      title: 'Esta música ainda não tem faixas',
      message: 'Envie ao menos uma faixa para ensaiar esta música.',
      primaryLabel: 'Enviar faixa',
      onPrimary: () => context.goNamed(
        'track-upload',
        pathParameters: {'id': songId},
      ),
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
          if (view.metronomeOn) ...[
            MixTrackRow(
              key: const ValueKey('mix-metronome'),
              naipe: null,
              label: 'Metrônomo',
              volume: view.metronomeVolume,
              muted: view.metronomeMuted,
              solo: false,
              showSolo: false,
              onVolumeChanged: notifier.setMetronomeVolume,
              onMuteToggled: notifier.toggleMetronomeMute,
              onSoloToggled: () {},
            ),
            const SizedBox(height: CantaeSpacing.space3),
          ],
          if (view.canEditTempo && song.metronomeConfig != null) ...[
            Text(
              '${song.metronomeConfig!.bpm} BPM · '
              '${song.metronomeConfig!.beatsPerMeasure} tempos',
              style: CantaeTypography.caption.copyWith(color: colors.text2),
            ),
            const SizedBox(height: CantaeSpacing.space2),
            TonalButton(
              label: 'Ajustar andamento',
              onPressed: () =>
                  _openTempoSheet(context, notifier, song.metronomeConfig),
            ),
            const SizedBox(height: CantaeSpacing.space4),
          ],
        ],
      ),
      footer: _Footer(songId: songId, view: view, notifier: notifier),
    );
  }

  Widget _mixRow(SongTrack track) {
    final mix = view.mix[track.id] ?? const TrackMix();
    return MixTrackRow(
      key: ValueKey('mix-${track.id}'),
      naipe: track.isPlayback ? null : track.naipe,
      customNaipe: track.customNaipe,
      label: trackDisplayName(track),
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
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final loop = view.loop;
    final config = view.song?.metronomeConfig;
    final receivedWithoutTempo = config == null && !view.canEditTempo;

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
        if (view.metronomeError != null) ...[
          const SizedBox(height: CantaeSpacing.space2),
          Semantics(
            liveRegion: true,
            child: InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Metrônomo desligado',
              message: view.metronomeError!,
            ),
          ),
        ],
        const SizedBox(height: CantaeSpacing.space3),
        // Two rows so the three actions fit 360 dp at 130 % font.
        Row(
          children: [
            Expanded(child: _loopButton()),
            const SizedBox(width: CantaeSpacing.space3),
            Expanded(child: _metronomeButton(context, config)),
          ],
        ),
        if (receivedWithoutTempo) ...[
          const SizedBox(height: CantaeSpacing.space2),
          Text(
            'Música recebida: só quem criou pode definir o andamento.',
            style: CantaeTypography.caption.copyWith(color: colors.text2),
          ),
        ],
        const SizedBox(height: CantaeSpacing.space3),
        PrimaryButton(
          label: view.playing ? 'Pausar' : 'Tocar',
          onPressed: notifier.togglePlay,
        ),
      ],
    );
  }

  Widget _metronomeButton(BuildContext context, MetronomeConfig? config) {
    if (config != null) {
      return TonalButton(
        label: 'Metrônomo ♩ ${config.bpm}',
        positive: view.metronomeOn,
        onPressed: view.metronomeBusy ? null : notifier.toggleMetronome,
      );
    }
    return TonalButton(
      label: 'Metrônomo',
      onPressed: view.canEditTempo
          ? () => _openTempoSheet(context, notifier, null)
          : null,
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
