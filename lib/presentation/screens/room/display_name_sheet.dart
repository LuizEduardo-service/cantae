import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/session/room_entry_rules.dart';
import '../../providers/room_providers.dart';
import '../../theme/cantae_colors.dart';
import '../../theme/cantae_spacing.dart';
import '../../theme/cantae_typography.dart';
import '../../widgets/buttons.dart';

/// "Como você quer aparecer na sala?" (ROOM-01..04).
abstract final class DisplayNameSheet {
  /// Returns the saved name, or null when the sheet was closed.
  static Future<String?> show(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (_) => const _DisplayNameBody(),
    );
  }

  /// The saved name, asking for it first when there is none (ROOM-01).
  /// Null means the person closed the sheet, or the profile cannot be read.
  static Future<String?> ensure(BuildContext context, WidgetRef ref) async {
    final profile = await ref.read(localProfileRepositoryProvider).load();
    final saved = profile.when(
      success: (p) => p.displayName,
      failure: (_) => null,
    );
    if (saved != null && saved.isNotEmpty) return saved;
    if (!context.mounted) return null;
    return show(context);
  }
}

class _DisplayNameBody extends ConsumerStatefulWidget {
  const _DisplayNameBody();

  @override
  ConsumerState<_DisplayNameBody> createState() => _DisplayNameBodyState();
}

class _DisplayNameBodyState extends ConsumerState<_DisplayNameBody> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _saveError = null));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _lengthError => _name.text.trim().length > displayNameMaxLength
      ? 'Use até $displayNameMaxLength caracteres.'
      : null;

  bool get _valid => validateDisplayName(_name.text).isSuccess;

  Future<void> _save() async {
    final name = validateDisplayName(_name.text)
        .when<String?>(success: (n) => n, failure: (_) => null);
    if (name == null) return;
    setState(() => _saving = true);
    final saved =
        await ref.read(localProfileRepositoryProvider).saveDisplayName(name);
    if (!mounted) return;
    saved.when(
      success: (_) {
        ref.invalidate(localProfileProvider);
        Navigator.of(context).pop(name);
      },
      failure: (_) => setState(() {
        _saving = false;
        _saveError = 'Não foi possível salvar o nome.';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CantaeColors>()!;
    final radius = BorderRadius.circular(CantaeRadii.radiusMd);
    final error = _lengthError ?? _saveError;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: 2),
        );

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
                  'Como você quer aparecer na sala?',
                  style:
                      CantaeTypography.titleSheet.copyWith(color: colors.text),
                ),
                const SizedBox(height: CantaeSpacing.space2),
                Text(
                  'O Mestre vê esse nome quando você pede para entrar.',
                  style:
                      CantaeTypography.bodySmall.copyWith(color: colors.text2),
                ),
                const SizedBox(height: CantaeSpacing.space4),
                TextField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _save(),
                  style: CantaeTypography.body.copyWith(color: colors.text),
                  decoration: InputDecoration(
                    labelText: 'Seu nome',
                    labelStyle:
                        CantaeTypography.body.copyWith(color: colors.text2),
                    errorText: error,
                    errorStyle: CantaeTypography.caption
                        .copyWith(color: colors.dangerSolid),
                    filled: true,
                    fillColor: colors.fillField,
                    border: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: border(colors.accent),
                    errorBorder: border(colors.dangerSolid),
                    focusedErrorBorder: border(colors.dangerSolid),
                  ),
                ),
                const SizedBox(height: CantaeSpacing.space4),
                PrimaryButton(
                  label: 'Salvar nome',
                  loading: _saving,
                  onPressed: _valid && !_saving ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
