import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/coming_soon/coming_soon_screen.dart';
import '../screens/library/library_screen.dart';

/// The app's single `GoRouter` instance (AD-012). Routes are always named
/// (`context.goNamed(...)`), never raw path strings. `library` is the real
/// screen; the other 5 render the shared [ComingSoonScreen] placeholder.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/songs/:id',
        name: 'song-detail',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Detalhe da música'),
      ),
      GoRoute(
        path: '/room/create',
        name: 'room-create',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Criar sala'),
      ),
      GoRoute(
        path: '/room/join',
        name: 'room-join',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Entrar em sala'),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ComingSoonScreen(title: 'Perfil'),
      ),
      GoRoute(
        path: '/import',
        name: 'package-import',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Importar pacote'),
      ),
    ],
  );
});
