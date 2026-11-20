import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/routing/app_router.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: CantaeApp()));
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
