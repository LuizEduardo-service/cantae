import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/coming_soon/coming_soon_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/song_detail/song_detail_screen.dart';
import '../screens/track_align/track_align_screen.dart';

/// The app's single `GoRouter` instance (AD-012). Routes are always named
/// (`context.goNamed(...)`), never raw path strings. `library` and
/// `song-detail` are real screens; the rest render the shared
/// [ComingSoonScreen] placeholder.
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
            SongDetailScreen(songId: state.pathParameters['id']!),
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
      GoRoute(
        path: '/solo-player',
        name: 'solo-player',
        builder: (context, state) => const ComingSoonScreen(title: 'Modo solo'),
      ),
      GoRoute(
        path: '/studio',
        name: 'studio',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Studio — corte de áudio'),
      ),
      GoRoute(
        path: '/track-align/:id',
        name: 'track-align',
        builder: (context, state) =>
            TrackAlignScreen(songId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lyrics-editor',
        name: 'lyrics-editor',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Sincronizar letra'),
      ),
      GoRoute(
        path: '/song-history',
        name: 'song-history',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Ensaios anteriores'),
      ),
      GoRoute(
        path: '/track-upload',
        name: 'track-upload',
        builder: (context, state) =>
            const ComingSoonScreen(title: 'Enviar faixa'),
      ),
    ],
  );
});
