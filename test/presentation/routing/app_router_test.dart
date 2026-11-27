import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/custom_naipe_repository.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/providers/track_upload_providers.dart';
import 'package:cantae/presentation/routing/app_router.dart';
import 'package:cantae/presentation/screens/room_create/room_create_screen.dart';
import 'package:cantae/presentation/screens/coming_soon/coming_soon_screen.dart';
import 'package:cantae/presentation/screens/history/rehearsal_history_screen.dart';
import 'package:cantae/presentation/screens/library/library_screen.dart';
import 'package:cantae/presentation/screens/lyrics_editor/lyrics_editor_screen.dart';
import 'package:cantae/presentation/screens/solo_player/solo_player_screen.dart';
import 'package:cantae/presentation/screens/song_detail/song_detail_screen.dart';
import 'package:cantae/presentation/screens/song_editor/song_editor_screen.dart';
import 'package:cantae/presentation/screens/track_align/track_align_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _EmptySongRepository implements SongRepository {
  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      const Result.success(<Song>[]);

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Song, Failure>> getById(String id) async =>
      Result.failure(NotFoundFailure(code: 'song_not_found'));

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

class _NoCustomNaipes implements CustomNaipeRepository {
  @override
  Future<Result<List<CustomNaipe>, StorageFailure>> getAll() async =>
      const Result.success(<CustomNaipe>[]);
}

Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      songRepositoryProvider.overrideWithValue(_EmptySongRepository()),
      customNaipeRepositoryProvider.overrideWithValue(_NoCustomNaipes()),
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('AppRouter', () {
    testWidgets('"/" (library) renders LibraryScreen', (tester) async {
      await _pumpRouter(tester);

      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(ComingSoonScreen), findsNothing);
    });

    testWidgets('song-detail renders SongDetailScreen with the route id', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);

      router.goNamed('song-detail', pathParameters: {'id': 'abc'});
      await tester.pumpAndSettle();

      expect(find.byType(SongDetailScreen), findsOneWidget);
      expect(
        tester.widget<SongDetailScreen>(find.byType(SongDetailScreen)).songId,
        equals('abc'),
      );
    });

    testWidgets('room-create renders RoomCreateScreen with the song id',
        (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed('room-create', queryParameters: {'songId': 'ave'});
      await tester.pump();

      expect(
        tester.widget<RoomCreateScreen>(find.byType(RoomCreateScreen)).songId,
        'ave',
      );
    });

    testWidgets('room-join renders ComingSoonScreen', (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed('room-join');
      await tester.pumpAndSettle();

      expect(find.byType(ComingSoonScreen), findsOneWidget);
      expect(find.text('Entrar em sala'), findsOneWidget);
    });

    testWidgets('profile renders ComingSoonScreen', (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed('profile');
      await tester.pumpAndSettle();

      expect(find.byType(ComingSoonScreen), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('package-import renders ComingSoonScreen', (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed('package-import');
      await tester.pumpAndSettle();

      expect(find.byType(ComingSoonScreen), findsOneWidget);
      expect(find.text('Importar pacote'), findsOneWidget);
    });

    testWidgets('track-align renders TrackAlignScreen with the route id', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);

      router.goNamed('track-align', pathParameters: {'id': 'abc'});
      await tester.pumpAndSettle();

      expect(find.byType(TrackAlignScreen), findsOneWidget);
      expect(
        tester.widget<TrackAlignScreen>(find.byType(TrackAlignScreen)).songId,
        equals('abc'),
      );
    });

    testWidgets('lyrics-editor renders LyricsEditorScreen with the route id', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);

      router.goNamed('lyrics-editor', pathParameters: {'id': 'abc'});
      await tester.pumpAndSettle();

      expect(find.byType(LyricsEditorScreen), findsOneWidget);
      expect(
        tester
            .widget<LyricsEditorScreen>(find.byType(LyricsEditorScreen))
            .songId,
        equals('abc'),
      );
    });

    testWidgets('solo-player renders SoloPlayerScreen with the route id', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);

      router.goNamed('solo-player', pathParameters: {'id': 'abc'});
      await tester.pumpAndSettle();

      expect(find.byType(SoloPlayerScreen), findsOneWidget);
      expect(
        tester.widget<SoloPlayerScreen>(find.byType(SoloPlayerScreen)).songId,
        equals('abc'),
      );
    });

    testWidgets('song-history renders RehearsalHistoryScreen with the route id',
        (
      tester,
    ) async {
      final router = await _pumpRouter(tester);

      router.goNamed('song-history', pathParameters: {'id': 'abc'});
      await tester.pumpAndSettle();

      expect(find.byType(RehearsalHistoryScreen), findsOneWidget);
      expect(
        tester
            .widget<RehearsalHistoryScreen>(
              find.byType(RehearsalHistoryScreen),
            )
            .songId,
        equals('abc'),
      );
    });

    testWidgets('song-create renders SongEditorScreen for a new song',
        (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed('song-create');
      await tester.pumpAndSettle();

      final screen =
          tester.widget<SongEditorScreen>(find.byType(SongEditorScreen));
      expect(screen.songId, isNull);
      expect(screen.initialNaipe, isNull);
    });

    testWidgets('track-upload renders SongEditorScreen with id and naipe',
        (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed(
        'track-upload',
        pathParameters: {'id': 'abc'},
        queryParameters: {'naipe': 'tenor'},
      );
      await tester.pumpAndSettle();

      final screen =
          tester.widget<SongEditorScreen>(find.byType(SongEditorScreen));
      expect(screen.songId, 'abc');
      expect(screen.initialNaipe, Naipe.tenor);
    });

    testWidgets('track-upload ignores an unknown naipe', (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed(
        'track-upload',
        pathParameters: {'id': 'abc'},
        queryParameters: {'naipe': 'mezzo'},
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SongEditorScreen>(find.byType(SongEditorScreen))
            .initialNaipe,
        isNull,
      );
    });

    for (final entry in {
      'studio': 'Studio — corte de áudio',
    }.entries) {
      testWidgets('${entry.key} renders ComingSoonScreen', (tester) async {
        final router = await _pumpRouter(tester);

        router.goNamed(entry.key);
        await tester.pumpAndSettle();

        expect(find.byType(ComingSoonScreen), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
      });
    }
  });
}
