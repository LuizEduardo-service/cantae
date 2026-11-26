import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/naipe.dart';
import '../../providers/song_editor_notifier.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/naipe_labels.dart';

/// "Adicionar naipe" sheet (UI_SPEC §6.4, UPL-13/14): the device's custom
/// naipes this song does not use yet, and a field to create a new one.
abstract final class AddNaipeSheet {
  static Future<void> show(BuildContext context, {required String? songId}) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (_) => _AddNaipeBody(songId: songId),
    );
  }
}

class _AddNaipeBody extends ConsumerStatefulWidget {
  const _AddNaipeBody({required this.songId});

  final String? songId;

  @override
  ConsumerState<_AddNaipeBody> createState() => _AddNaipeBodyState();
}

class _AddNaipeBodyState extends ConsumerState<_AddNaipeBody> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  SongEditorNotifier get _notifier =>
      ref.read(songEditorProvider(widget.songId).notifier);

  void _create() {
    final error = _notifier.createCustomNaipe(_name.text);
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final addable =
        ref.watch(songEditorProvider(widget.songId)).addableCustomNaipes;
    final radius = BorderRadius.circular(CantaeRadii.radiusSm);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(CantaeRadii.radiusSheet),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CantaeSpacing.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Adicionar naipe',
                  style:
                      CantaeTypography.titleSheet.copyWith(color: colors.text),
                ),
                if (addable.isNotEmpty) ...[
                  const SizedBox(height: CantaeSpacing.space4),
                  Text(
                    'Naipes já criados',
                    style:
                        CantaeTypography.caption.copyWith(color: colors.text2),
                  ),
                  for (final naipe in addable)
                    Semantics(
                      button: true,
                      label: 'Adicionar ${naipe.name}',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () {
                          _notifier.addCustomNaipe(naipe);
                          Navigator.of(context).pop();
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: CantaeSpacing.minTouchTarget,
                          ),
                          child: Row(
                            children: [
                              NaipeBadge(
                                naipe: Naipe.custom,
                                customNaipe: naipe,
                              ),
                              const SizedBox(width: CantaeSpacing.space3),
                              Expanded(
                                child: Text(
                                  naipe.name,
                                  style: CantaeTypography.body
                                      .copyWith(color: colors.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: CantaeSpacing.space4),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _create(),
                  style: CantaeTypography.body.copyWith(color: colors.text),
                  decoration: InputDecoration(
                    labelText: 'Novo naipe',
                    labelStyle:
                        CantaeTypography.body.copyWith(color: colors.text2),
                    errorText: _error,
                    errorStyle: CantaeTypography.caption
                        .copyWith(color: colors.dangerSolid),
                    filled: true,
                    fillColor: colors.fillField,
                    border: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(color: colors.accent, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide:
                          BorderSide(color: colors.dangerSolid, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide:
                          BorderSide(color: colors.dangerSolid, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: CantaeSpacing.space4),
                PrimaryButton(label: 'Criar naipe', onPressed: _create),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
