import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/session/ids.dart';
import '../../providers/host_room_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/join_request_row.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/room_code_display.dart';
import '../../widgets/room_person_row.dart';
import '../../widgets/status_pill.dart';
import '../room/display_name_sheet.dart';
import 'song_choice_sheet.dart';

/// Criar sala (UI_SPEC §6.7, ROOM-01, ROOM-05..21).
class RoomCreateScreen extends ConsumerStatefulWidget {
  const RoomCreateScreen({super.key, this.songId});

  /// Song preselected when coming from the Detalhe (ROOM-07).
  final String? songId;

  @override
  ConsumerState<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends ConsumerState<RoomCreateScreen> {
  bool _named = false;

  HostRoomNotifier get _notifier => ref.read(hostRoomProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askName());
  }

  Future<void> _askName() async {
    final name = await DisplayNameSheet.ensure(context, ref);
    if (!mounted) return;
    if (name == null) {
      context.goNamed('library');
      return;
    }
    setState(() => _named = true);
    await _notifier.start(masterName: name, songId: widget.songId);
  }

  /// Cancelar / system back (ROOM-18, ROOM-19).
  Future<void> _leave() async {
    final state = ref.read(hostRoomProvider);
    if (state.status == HostRoomStatus.ready && state.people.hasPeople) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Encerrar sala?',
        message: 'Quem está na sala ou pedindo para entrar vai sair dela.',
        safeLabel: 'Continuar na sala',
        destructiveLabel: 'Encerrar sala',
      );
      if (!confirmed) return;
    }
    await _notifier.end();
    if (mounted) context.goNamed('library');
  }

  Future<void> _chooseSong(String? currentId) async {
    final choice = await SongChoiceSheet.show(context, currentId: currentId);
    if (choice != null) await _notifier.chooseSong(choice.song);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostRoomProvider);
    final ready = _named && state.status == HostRoomStatus.ready;

    final Widget body = switch (state.status) {
      _ when !_named => const SizedBox.shrink(),
      HostRoomStatus.generating => const _Generating(),
      HostRoomStatus.permissionDenied => Center(
          child: InlineBanner(
            variant: InlineBannerVariant.error,
            title: 'Sem acesso à rede local',
            message: 'Libere o acesso à rede local para o Cantaê nos ajustes '
                'do aparelho.',
            actionLabel: 'Abrir ajustes',
            onAction: _notifier.openSettings,
          ),
        ),
      HostRoomStatus.failed => Center(
          child: InlineBanner(
            variant: InlineBannerVariant.error,
            title: 'Não foi possível criar a sala.',
            message: 'Confira se o Wi‑Fi está ligado e tente de novo.',
            actionLabel: 'Tentar de novo',
            onAction: _notifier.retry,
          ),
        ),
      HostRoomStatus.ready => _Room(
          state: state,
          onChooseSong: () => _chooseSong(state.songId),
          onApprove: _notifier.approve,
          onReject: _notifier.reject,
        ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: CantaeScaffold(
        topLeft: NavPill(
          variant: NavPillVariant.cancel,
          label: 'Cancelar',
          onTap: _leave,
        ),
        topRight: ready
            ? const StatusPill(
                label: 'Visível neste Wi‑Fi',
                variant: StatusPillVariant.synced,
              )
            : null,
        body: body,
        footer: PrimaryButton(
          label: 'Começar a conduzir',
          onPressed: ready ? () => context.goNamed('room-host') : null,
        ),
      ),
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: CantaeSpacing.space4),
            Text(
              'Gerando código',
              style: CantaeTypography.body.copyWith(color: colors.text2),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ready room: code, song, requests and people (ROOM-05..16).
class _Room extends StatelessWidget {
  const _Room({
    required this.state,
    required this.onChooseSong,
    required this.onApprove,
    required this.onReject,
  });

  final HostRoomState state;
  final VoidCallback onChooseSong;
  final void Function(ParticipantId id) onApprove;
  final void Function(ParticipantId id) onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final people = state.people;
    final song = state.songName;
    return ListView(
      padding: const EdgeInsets.only(top: CantaeSpacing.space4),
      children: [
        RoomCodeDisplay(code: state.code ?? ''),
        const SizedBox(height: CantaeSpacing.space6),
        const HostSectionLabel('Música'),
        Text(
          song ?? 'Nenhuma música escolhida',
          style: CantaeTypography.body
              .copyWith(color: song == null ? colors.text2 : colors.text),
        ),
        const SizedBox(height: CantaeSpacing.space2),
        TonalButton(
          label: song == null ? 'Escolher música' : 'Trocar',
          semanticLabel: song == null ? 'Escolher música' : 'Trocar música',
          onPressed: onChooseSong,
        ),
        const SizedBox(height: CantaeSpacing.space6),
        HostPeopleSections(
          people: people,
          onApprove: onApprove,
          onReject: onReject,
        ),
      ],
    );
  }
}

/// "Pedindo para entrar · N" and "Na sala · N de 8", shared by Criar sala
/// and the master's temporary room (ROOM-10..16, ROOM-39, ROOM-40).
class HostPeopleSections extends StatelessWidget {
  const HostPeopleSections({
    super.key,
    required this.people,
    required this.onApprove,
    required this.onReject,
  });

  final HostPeople people;
  final void Function(ParticipantId id) onApprove;
  final void Function(ParticipantId id) onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (people.pending.isNotEmpty) ...[
          HostSectionLabel('Pedindo para entrar · ${people.pending.length}'),
          for (final person in people.pending)
            JoinRequestRow(
              name: person.name,
              roomFull: people.isFull,
              onApprove: () => onApprove(person.id),
              onReject: () => onReject(person.id),
            ),
          const SizedBox(height: CantaeSpacing.space6),
        ] else if (people.members.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: CantaeSpacing.space6),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                'Ninguém pediu para entrar ainda',
                style: CantaeTypography.body.copyWith(color: colors.text2),
              ),
            ),
          ),
        HostSectionLabel('Na sala · ${people.members.length} de 8'),
        const RoomPersonRow(name: 'Você', role: 'Mestre'),
        for (final person in people.members)
          RoomPersonRow(name: person.name, role: 'Cantor'),
      ],
    );
  }
}

class HostSectionLabel extends StatelessWidget {
  const HostSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: CantaeSpacing.space2),
      child: Semantics(
        container: true,
        header: true,
        child: Text(
          text,
          style: CantaeTypography.caption.copyWith(color: colors.text2),
        ),
      ),
    );
  }
}
