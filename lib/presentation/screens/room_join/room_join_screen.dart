import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/session/room_entry_rules.dart';
import '../../providers/join_room_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/code_input.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/nav_pill.dart';
import '../../widgets/room_tile.dart';
import '../room/display_name_sheet.dart';

/// Entrar em sala (UI_SPEC §6.8, ROOM-01, ROOM-22..38, ROOM-55..58).
class RoomJoinScreen extends ConsumerStatefulWidget {
  const RoomJoinScreen({super.key});

  @override
  ConsumerState<RoomJoinScreen> createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends ConsumerState<RoomJoinScreen> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _named = false;

  JoinRoomNotifier get _notifier => ref.read(joinRoomProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askName());
  }

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _askName() async {
    final name = await DisplayNameSheet.ensure(context, ref);
    if (!mounted) return;
    if (name == null) {
      context.goNamed('library');
      return;
    }
    setState(() => _named = true);
    await _notifier.start(displayName: name);
  }

  void _selectRoom(RoomTileView room) {
    _notifier.selectRoom(room.id);
    _codeFocus.requestFocus();
  }

  void _typeAgain() {
    _notifier.dismissOutcome();
    _code.clear();
    _codeFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(joinRoomProvider, (previous, next) {
      if (next.outcome == JoinOutcome.joined &&
          previous?.outcome != JoinOutcome.joined) {
        context.goNamed('room-member');
      }
      if (_code.text != next.code) _code.text = next.code;
    });
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final state = ref.watch(joinRoomProvider);
    final awaiting = state.phase == JoinPhase.awaiting;
    final selected = state.selectedRoom;

    return CantaeScaffold(
      topLeft: NavPill(
        variant: NavPillVariant.back,
        label: 'Biblioteca',
        onTap: () => context.goNamed('library'),
      ),
      body: !_named
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(top: CantaeSpacing.space4),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Entrar em sala',
                    style:
                        CantaeTypography.titlePage.copyWith(color: colors.text),
                  ),
                ),
                const SizedBox(height: CantaeSpacing.space4),
                _CodeCard(
                  controller: _code,
                  focusNode: _codeFocus,
                  state: state,
                  hint: selected == null
                      ? 'Digite o código que aparece na tela do Mestre.'
                      : 'Digite o código que aparece na tela de '
                          '${selected.masterName}.',
                  onChanged: _notifier.setCode,
                  onSubmit: _notifier.submitCode,
                ),
                const SizedBox(height: CantaeSpacing.space4),
                _PhaseBanner(
                  state: state,
                  isIos: defaultTargetPlatform == TargetPlatform.iOS,
                  onSearchAgain: _notifier.searchAgain,
                  onCancel: _notifier.cancelRequest,
                  onDismiss: _notifier.dismissOutcome,
                  onRetry: _notifier.retry,
                  onTypeAgain: _typeAgain,
                  onOpenSettings: _notifier.openSettings,
                ),
                const SizedBox(height: CantaeSpacing.space4),
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    'Salas neste Wi‑Fi',
                    style:
                        CantaeTypography.caption.copyWith(color: colors.text2),
                  ),
                ),
                const SizedBox(height: CantaeSpacing.space2),
                for (final room in state.rooms)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: CantaeSpacing.space2),
                    child: RoomTile(
                      masterName: room.masterName,
                      songName: room.songName,
                      selected: awaiting
                          ? state.target?.id == room.id
                          : state.selected == room.id,
                      onTap: awaiting ? null : () => _selectRoom(room),
                    ),
                  ),
              ],
            ),
      footer: Text(
        'Você entra como Cantor.',
        textAlign: TextAlign.center,
        style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.hint,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final JoinRoomState state;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final awaiting = state.phase == JoinPhase.awaiting;
    return Container(
      padding: const EdgeInsets.all(CantaeSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CantaeRadii.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint,
            style: CantaeTypography.bodySmall.copyWith(color: colors.text2),
          ),
          const SizedBox(height: CantaeSpacing.space3),
          CodeInput(
            controller: controller,
            focusNode: focusNode,
            enabled: !awaiting,
            hasError: state.phase == JoinPhase.codeNotFound,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: CantaeSpacing.space3),
          PrimaryButton(
            label: 'Entrar',
            onPressed: state.canSubmit ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}

/// One banner per phase, each with its action (ROOM-24..37, ROOM-57).
class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({
    required this.state,
    required this.isIos,
    required this.onSearchAgain,
    required this.onCancel,
    required this.onDismiss,
    required this.onRetry,
    required this.onTypeAgain,
    required this.onOpenSettings,
  });

  final JoinRoomState state;
  final bool isIos;
  final VoidCallback onSearchAgain;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;
  final VoidCallback onTypeAgain;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final master = state.target?.masterName ?? 'o Mestre';
    Widget banner(
      InlineBannerVariant variant,
      String title,
      String message,
      String action,
      VoidCallback onAction,
    ) =>
        Semantics(
          container: true,
          liveRegion: true,
          child: InlineBanner(
            variant: variant,
            title: title,
            message: message,
            actionLabel: action,
            onAction: onAction,
          ),
        );

    switch (state.phase) {
      case JoinPhase.searching:
        if (state.rooms.isNotEmpty) return const SizedBox.shrink();
        return Semantics(
          container: true,
          liveRegion: true,
          child: Text(
            'Procurando salas…',
            style: CantaeTypography.body.copyWith(color: colors.text2),
          ),
        );
      case JoinPhase.noneFound:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            banner(
              InlineBannerVariant.warning,
              'Nenhuma sala neste Wi‑Fi',
              isIos
                  ? 'Confira se você está no mesmo Wi‑Fi do Mestre. Se você '
                      'negou o acesso à rede local, libere nos ajustes.'
                  : 'Confira se você está no mesmo Wi‑Fi do Mestre.',
              'Procurar de novo',
              onSearchAgain,
            ),
            if (isIos) ...[
              const SizedBox(height: CantaeSpacing.space2),
              TonalButton(label: 'Abrir ajustes', onPressed: onOpenSettings),
            ],
          ],
        );
      case JoinPhase.awaiting:
        return banner(
          InlineBannerVariant.info,
          'Aguardando $master aprovar',
          'O pedido aparece na tela do Mestre.',
          'Cancelar pedido',
          onCancel,
        );
      case JoinPhase.codeNotFound:
        return banner(
          InlineBannerVariant.error,
          'Código não encontrado',
          'Confira o código na tela do Mestre.',
          'Digitar de novo',
          onTypeAgain,
        );
      case JoinPhase.permissionDenied:
        return banner(
          InlineBannerVariant.error,
          'Sem acesso à rede local',
          'Libere o acesso à rede local para o Cantaê nos ajustes do '
              'aparelho.',
          'Abrir ajustes',
          onOpenSettings,
        );
      case JoinPhase.outcome:
        return switch (state.outcome) {
          JoinOutcome.rejected => banner(
              InlineBannerVariant.error,
              'Entrada recusada',
              '$master não aprovou a entrada.',
              'Escolher outra sala',
              onDismiss,
            ),
          JoinOutcome.roomFull => banner(
              InlineBannerVariant.warning,
              'Sala cheia (8 de 8)',
              'A sala já tem o máximo de pessoas.',
              'Escolher outra sala',
              onDismiss,
            ),
          JoinOutcome.protocolMismatch => banner(
              InlineBannerVariant.error,
              'Versão do app incompatível',
              'Atualize o Cantaê nos dois aparelhos.',
              'Escolher outra sala',
              onDismiss,
            ),
          JoinOutcome.expired => banner(
              InlineBannerVariant.warning,
              'O Mestre não respondeu',
              'O pedido passou do tempo sem resposta.',
              'Tentar de novo',
              onRetry,
            ),
          JoinOutcome.connectionLost => banner(
              InlineBannerVariant.error,
              'Não foi possível falar com a sala',
              'Confira o Wi‑Fi e tente de novo.',
              'Tentar de novo',
              onRetry,
            ),
          _ => const SizedBox.shrink(),
        };
    }
  }
}
