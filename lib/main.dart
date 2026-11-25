import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infrastructure/audio/background_audio_bootstrap.dart';
import 'presentation/providers/background_audio_providers.dart';
import 'presentation/routing/app_router.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before any screen plays (BGA-01/02); never throws (BGA-18).
  final audio = await bootstrapBackgroundAudio();
  runApp(ProviderScope(
    overrides: [
      playbackRemoteProvider.overrideWithValue(audio.remote),
      audioInterruptionsProvider.overrideWithValue(audio.interruptions),
    ],
    child: const CantaeApp(),
  ));
}

class CantaeApp extends ConsumerWidget {
  const CantaeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // AppTheme.defaultThemeMode is ThemeMode.system, MaterialApp's own
    // default — not passed explicitly to avoid an avoid_redundant_argument_
    // values lint; AppTheme stays the single source of truth for both.
    return MaterialApp.router(
      title: 'Cantaê',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
