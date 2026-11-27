import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/host_room_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/confirm_sheet.dart';
import '../room_create/room_create_screen.dart';

/// The master's temporary room (ROOM-39..41, ROOM-45), until the full Sala
/// do Mestre (§6.9) arrives.
class RoomHostScreen extends ConsumerStatefulWidget {
  const RoomHostScreen({super.key});

  @override
  ConsumerState<RoomHostScreen> createState() => _RoomHostScreenState();
}

class _RoomHostScreenState extends ConsumerState<RoomHostScreen> {
  HostRoomNotifier get _notifier => ref.read(hostRoomProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_notifier.resume() && mounted) context.goNamed('library');
    });
  }

  Future<bool> _confirmEnd() => ConfirmSheet.show(
        context,
        title: 'Encerrar sala?',
        message: 'Quem está na sala ou pedindo para entrar vai sair dela.',
        safeLabel: 'Continuar na sala',
        destructiveLabel: 'Encerrar sala',
      );

  /// "Encerrar sala" always asks (ROOM-41).
  Future<void> _end() async {
    if (!await _confirmEnd()) return;
    await _endAndLeave();
  }

  /// System back: asks only with people in the room (ROOM-45).
  Future<void> _back() async {
    if (ref.read(hostRoomProvider).people.hasPeople && !await _confirmEnd()) {
      return;
    }
    await _endAndLeave();
  }

  Future<void> _endAndLeave() async {
    await _notifier.end();
    if (mounted) context.goNamed('library');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final state = ref.watch(hostRoomProvider);
    final ready = state.status == HostRoomStatus.ready;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CantaeScaffold(
        body: !ready
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.only(top: CantaeSpacing.space4),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Sala ${state.code ?? ''}',
                      style: CantaeTypography.titleRoom
                          .copyWith(color: colors.text),
                    ),
                  ),
                  const SizedBox(height: CantaeSpacing.space1),
                  Text(
                    state.songName ?? 'Sem música escolhida',
                    style: CantaeTypography.body.copyWith(color: colors.text2),
                  ),
                  const SizedBox(height: CantaeSpacing.space6),
                  HostPeopleSections(
                    people: state.people,
                    onApprove: _notifier.approve,
                    onReject: _notifier.reject,
                  ),
                ],
              ),
        footer: DestructiveButton(
          label: 'Encerrar sala',
          onPressed: ready ? _end : null,
        ),
      ),
    );
  }
}
