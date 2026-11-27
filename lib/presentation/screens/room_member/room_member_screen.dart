import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/member_room_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cantae_scaffold.dart';
import '../../widgets/toast.dart';

/// The singer's temporary room (ROOM-42..44), until the full Tela do
/// Cantor (§6.10) arrives.
class RoomMemberScreen extends ConsumerStatefulWidget {
  const RoomMemberScreen({super.key});

  @override
  ConsumerState<RoomMemberScreen> createState() => _RoomMemberScreenState();
}

class _RoomMemberScreenState extends ConsumerState<RoomMemberScreen> {
  MemberRoomNotifier get _notifier => ref.read(memberRoomProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(memberRoomProvider);
      if (!state.inRoom && !state.lost && mounted) context.goNamed('library');
    });
  }

  /// "Sair da sala" and system back (ROOM-43).
  Future<void> _leave() async {
    await _notifier.leave();
    if (mounted) context.goNamed('library');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(memberRoomProvider, (previous, next) {
      if (next.lost && !(previous?.lost ?? false)) {
        Toast.show(context, 'A sala foi encerrada ou a conexão caiu.');
        context.goNamed('library');
      }
    });
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final state = ref.watch(memberRoomProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: CantaeScaffold(
        body: !state.inRoom
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.only(top: CantaeSpacing.space6),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Você está na sala de ${state.masterName}',
                      style: CantaeTypography.titleRoom
                          .copyWith(color: colors.text),
                    ),
                  ),
                  const SizedBox(height: CantaeSpacing.space2),
                  Text(
                    state.songName ?? 'Sem música escolhida',
                    style: CantaeTypography.body.copyWith(color: colors.text2),
                  ),
                  const SizedBox(height: CantaeSpacing.space6),
                  Text(
                    'O ensaio começa quando o Mestre conduzir.',
                    style:
                        CantaeTypography.body.copyWith(color: colors.textBody),
                  ),
                ],
              ),
        footer: SecondaryButton(
          label: 'Sair da sala',
          onPressed: state.inRoom ? _leave : null,
        ),
      ),
    );
  }
}
