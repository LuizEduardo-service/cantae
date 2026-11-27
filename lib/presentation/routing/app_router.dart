import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/coming_soon/coming_soon_screen.dart';
import '../screens/room_create/room_create_screen.dart';
import '../screens/room_host/room_host_screen.dart';
import '../screens/room_join/room_join_screen.dart';
import '../screens/history/rehearsal_history_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/lyrics_editor/lyrics_editor_screen.dart';
import '../screens/solo_player/solo_player_screen.dart';
import '../../domain/entities/naipe.dart';
import '../screens/song_detail/song_detail_screen.dart';
import '../screens/song_editor/song_editor_screen.dart';
import '../screens/track_align/track_align_screen.dart';

/// The app's single `GoRouter` instance (AD-012). Routes are always named
/// (`context.goNamed(...)`), never raw path strings. `studio` and the room,
/// profile and package screens still render the shared [ComingSoonScreen]
/// placeholder.
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
            RoomCreateScreen(songId: state.uri.queryParameters['songId']),
      ),
      GoRoute(
        path: '/room/host',
        name: 'room-host',
        builder: (context, state) => const RoomHostScreen(),
      ),
      GoRoute(
        path: '/room/join',
        name: 'room-join',
        builder: (context, state) => const RoomJoinScreen(),
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
        path: '/solo-player/:id',
        name: 'solo-player',
        builder: (context, state) =>
            SoloPlayerScreen(songId: state.pathParameters['id']!),
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
        path: '/lyrics-editor/:id',
        name: 'lyrics-editor',
        builder: (context, state) =>
            LyricsEditorScreen(songId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/song-history/:id',
        name: 'song-history',
        builder: (context, state) =>
            RehearsalHistoryScreen(songId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/song-editor',
        name: 'song-create',
        builder: (context, state) => const SongEditorScreen(),
      ),
      // "Enviar faixa": an existing song's tracks; `?naipe=tenor` opens the
      // picker for that naipe.
      GoRoute(
        path: '/song-editor/:id',
        name: 'track-upload',
        builder: (context, state) => SongEditorScreen(
          songId: state.pathParameters['id'],
          initialNaipe:
              Naipe.values.asNameMap()[state.uri.queryParameters['naipe']],
        ),
      ),
    ],
  );
});
