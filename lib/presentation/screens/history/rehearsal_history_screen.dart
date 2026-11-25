import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/rehearsal_log.dart';
import '../../formatting/rehearsal_format.dart';
import '../../providers/rehearsal_history_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/toast.dart';

/// "Ensaios" — `UI_SPEC.md` §6.16: one song's rehearsals on this device.
class RehearsalHistoryScreen extends ConsumerWidget {
  const RehearsalHistoryScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rehearsalHistoryProvider(songId));
    final notifier = ref.read(rehearsalHistoryProvider(songId).notifier);
    void back() =>
        context.goNamed('song-detail', pathParameters: {'id': songId});

    switch (state.status) {
      case RehearsalHistoryStatus.loading:
        return _Shell(label: 'Voltar', onBack: back, body: const _Loading());
      case RehearsalHistoryStatus.notFound:
        return _Shell(
          label: 'Biblioteca',
          onBack: () => context.goNamed('library'),
          body: EmptyState(
            icon: Icons.search_off,
            title: 'Música não encontrada',
            message:
                'Essa música não existe mais ou nunca existiu na sua biblioteca.',
            primaryLabel: 'Voltar à Biblioteca',
            onPrimary: () => context.goNamed('library'),
          ),
        );
      case RehearsalHistoryStatus.error:
        return _Shell(
          label: 'Voltar',
          onBack: back,
          body: Center(
            child: InlineBanner(
              variant: InlineBannerVariant.error,
              title: 'Não foi possível carregar os ensaios',
              message: 'Os ensaios não puderam ser lidos neste aparelho.',
              actionLabel: 'Tentar de novo',
              onAction: notifier.retry,
            ),
          ),
        );
      case RehearsalHistoryStatus.ready:
        return _Ready(
          songId: songId,
          state: state,
          notifier: notifier,
          onBack: back,
        );
    }
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.label, required this.onBack, required this.body});

  final String label;
  final VoidCallback onBack;
  final Widget body;

  @override
  Widget build(BuildContext context) => CantaeScaffold(
        topLeft: NavPill(
          variant: NavPillVariant.back,
          label: label,
          onTap: onBack,
        ),
        body: body,
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Center(child: CircularProgressIndicator(color: colors.accent));
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.songId,
    required this.state,
    required this.notifier,
    required this.onBack,
  });

  final String songId;
  final RehearsalHistoryState state;
  final RehearsalHistoryNotifier notifier;
  final VoidCallback onBack;

  Future<void> _confirmDelete(BuildContext context, {required bool all}) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title:
          all ? 'Apagar todos os ensaios?' : 'Apagar os ensaios desta música?',
      message: all
          ? 'Os ensaios de todas as músicas deste aparelho vão sumir. '
              'Isso não pode ser desfeito.'
          : 'Os ensaios de "${state.songName}" vão sumir. '
              'Isso não pode ser desfeito.',
      safeLabel: 'Cancelar',
      destructiveLabel: all ? 'Apagar todos' : 'Apagar ensaios',
    );
    if (!confirmed) return;
    final deleted =
        all ? await notifier.deleteAll() : await notifier.deleteForSong();
    if (deleted && context.mounted) Toast.show(context, 'Ensaios apagados');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final hasLogs = state.logs.isNotEmpty;
    final deleteError = state.deleteError;

    final header = <Widget>[
      const SizedBox(height: CantaeSpacing.space4),
      Text(
        'Ensaios',
        style: CantaeTypography.titlePage.copyWith(color: colors.text),
      ),
      const SizedBox(height: CantaeSpacing.space1),
      Text(
        'Registrados só neste aparelho.',
        style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
      ),
      const SizedBox(height: CantaeSpacing.space5),
      if (deleteError != null) ...[
        InlineBanner(
          variant: InlineBannerVariant.error,
          title: 'Ensaios não apagados',
          message: deleteError,
        ),
        const SizedBox(height: CantaeSpacing.space4),
      ],
    ];

    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: state.songName,
        onTap: onBack,
      ),
      body: hasLogs
          ? ListView.builder(
              itemCount: header.length + 2 + state.logs.length,
              itemBuilder: (context, index) {
                if (index < header.length) return header[index];
                final i = index - header.length;
                if (i == 0) return _Summary(state: state);
                if (i == 1) {
                  return const SizedBox(height: CantaeSpacing.space4);
                }
                return _RehearsalRow(log: state.logs[i - 2]);
              },
            )
          : ListView(
              children: [
                ...header,
                EmptyState(
                  icon: Icons.history,
                  title: 'Nenhum ensaio registrado ainda',
                  message: 'Ensaios no Modo solo com pelo menos 1 minuto '
                      'de música tocando aparecem aqui.',
                  primaryLabel: 'Ensaiar agora',
                  onPrimary: () => context.goNamed(
                    'solo-player',
                    pathParameters: {'id': songId},
                  ),
                ),
              ],
            ),
      footer: hasLogs
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DestructiveButton(
                  label: 'Apagar desta música',
                  onPressed: state.deleting
                      ? null
                      : () => _confirmDelete(context, all: false),
                ),
                const SizedBox(height: CantaeSpacing.space2),
                SecondaryButton(
                  label: 'Apagar tudo',
                  onPressed: state.deleting
                      ? null
                      : () => _confirmDelete(context, all: true),
                ),
              ],
            )
          : null,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final RehearsalHistoryState state;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatTile(value: '${state.count}', caption: 'ensaios'),
          ),
          const SizedBox(width: CantaeSpacing.space2),
          Expanded(
            child: StatTile(
              value: formatDuration(state.totalDurationMs),
              caption: 'tempo',
            ),
          ),
          const SizedBox(width: CantaeSpacing.space2),
          Expanded(
            child: StatTile(value: '${state.totalLoops}', caption: 'loops'),
          ),
        ],
      );
}

String _loopsLabel(int loops) => switch (loops) {
      0 => 'sem loops',
      1 => '1 loop',
      _ => '$loops loops',
    };

class _RehearsalRow extends StatelessWidget {
  const _RehearsalRow({required this.log});

  final RehearsalLog log;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final meta = CantaeTypography.bodySmall.copyWith(color: colors.text2);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CantaeSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatRehearsalDate(log.startedAt),
              style: CantaeTypography.listTitle.copyWith(color: colors.text),
            ),
            const SizedBox(height: CantaeSpacing.space1),
            Text.rich(
              TextSpan(
                style: meta,
                children: [
                  const TextSpan(text: 'Modo solo · '),
                  TextSpan(
                    text: formatDuration(log.durationMs),
                    style: CantaeTypography.mono.copyWith(color: colors.text2),
                  ),
                  TextSpan(text: ' · ${_loopsLabel(log.loopCount)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
