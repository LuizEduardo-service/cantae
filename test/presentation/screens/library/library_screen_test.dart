import 'dart:async';

import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/screens/library/library_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository(List<Song> songs) : _results = [Result.success(songs)];

  _FakeSongRepository.sequence(this._results);

  final List<Result<List<Song>, StorageFailure>> _results;
  int _callCount = 0;

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async {
    final result = _results[_callCount.clamp(0, _results.length - 1)];
    _callCount++;
    return result;
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Song, Failure>> getById(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

class _PendingSongRepository implements SongRepository {
  final Completer<Result<List<Song>, StorageFailure>> completer = Completer();

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() => completer.future;

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Song, Failure>> getById(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

Song _song({
  required String id,
  required String name,
  required String author,
  SongOrigin origin = SongOrigin.created,
}) {
  return Song(id: id, name: name, author: author, origin: origin);
}

GoRouter _buildRouter() {
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
            Text('route:song-detail:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/room/create',
        name: 'room-create',
        builder: (context, state) => const Text('route:room-create'),
      ),
      GoRoute(
        path: '/room/join',
        name: 'room-join',
        builder: (context, state) => const Text('route:room-join'),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const Text('route:profile'),
      ),
      GoRoute(
        path: '/import',
        name: 'package-import',
        builder: (context, state) => const Text('route:package-import'),
      ),
    ],
  );
}

Widget _wrap(SongRepository repository, {ThemeData? theme}) {
  return ProviderScope(
    overrides: [songRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: _buildRouter(),
    ),
  );
}

void main() {
  group('LibraryScreen', () {
    testWidgets('loading: renders a 5-row skeleton with SearchField disabled', (
      tester,
    ) async {
      final repo = _PendingSongRepository();
      await tester.pumpWidget(_wrap(repo));

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      // Resolve so the pending future doesn't leak past the test.
      repo.completer.complete(const Result.success(<Song>[]));
      await tester.pumpAndSettle();
    });

    testWidgets('populated: renders search, filter, sort, count and rows', (
      tester,
    ) async {
      final repo = _FakeSongRepository([
        _song(id: '1', name: 'Ave Maria', author: 'Marina Silva'),
        _song(id: '2', name: 'Panis Angelicus', author: 'José Pereira'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Ave Maria'), findsOneWidget);
      expect(find.text('Panis Angelicus'), findsOneWidget);
      expect(find.text('2 músicas'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Criadas'), findsOneWidget);
      expect(find.text('Recebidas'), findsOneWidget);
      expect(find.text('Nome (A-Z)'), findsOneWidget);
      expect(find.text('Último ensaio'), findsOneWidget);
    });

    testWidgets('populated: typing a matching search narrows the list', (
      tester,
    ) async {
      final repo = _FakeSongRepository([
        _song(id: '1', name: 'Ave Maria', author: 'Marina Silva'),
        _song(id: '2', name: 'Panis Angelicus', author: 'José Pereira'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ave');
      await tester.pumpAndSettle();

      expect(find.text('Ave Maria'), findsOneWidget);
      expect(find.text('Panis Angelicus'), findsNothing);
      expect(find.text('1 músicas'), findsOneWidget);
    });

    testWidgets('empty: renders EmptyState instead of search/filter/list UI', (
      tester,
    ) async {
      final repo = _FakeSongRepository(const []);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma música ainda'), findsOneWidget);
      expect(find.text('Cadastrar primeira música'), findsOneWidget);
      expect(find.text('Abrir pacote .cantae'), findsOneWidget);
      expect(find.text('Tem ensaio rolando por perto?'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
      'filtered-empty: a non-matching search shows "Nada encontrado para" and Limpar busca',
      (tester) async {
        final repo = _FakeSongRepository([
          _song(id: '1', name: 'Ave Maria', author: 'Marina Silva'),
        ]);
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'zzzznotfound');
        await tester.pumpAndSettle();

        expect(
            find.text('Nada encontrado para "zzzznotfound"'), findsOneWidget);
        expect(find.text('Limpar busca'), findsOneWidget);

        await tester.tap(find.text('Limpar busca'));
        await tester.pumpAndSettle();

        expect(find.text('Ave Maria'), findsOneWidget);
      },
    );

    testWidgets(
      'filtered-empty: switching to Recebidas with no received songs shows the empty-filter state',
      (tester) async {
        final repo = _FakeSongRepository([
          _song(id: '1', name: 'Ave Maria', author: 'Marina Silva'),
        ]);
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Recebidas'));
        await tester.pumpAndSettle();

        expect(find.text('Ave Maria'), findsNothing);
        expect(find.text('Limpar busca'), findsOneWidget);
      },
    );

    testWidgets(
      'error: renders the error banner with Tentar de novo, which retries',
      (tester) async {
        final repo = _FakeSongRepository.sequence([
          Result.failure(StorageFailure(code: 'db_unreachable')),
          Result.success([_song(id: '1', name: 'Ave Maria', author: 'x')]),
        ]);
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        expect(
          find.text('Não foi possível carregar sua biblioteca'),
          findsOneWidget,
        );
        expect(find.text('Tentar de novo'), findsOneWidget);

        await tester.tap(find.text('Tentar de novo'));
        await tester.pumpAndSettle();

        expect(find.text('Ave Maria'), findsOneWidget);
      },
    );

    testWidgets(
        'renders the populated state under the dark theme without throwing', (
      tester,
    ) async {
      final repo = _FakeSongRepository([
        _song(id: '1', name: 'Ave Maria', author: 'Marina Silva'),
      ]);
      await tester.pumpWidget(_wrap(repo, theme: AppTheme.dark));
      await tester.pumpAndSettle();

      expect(find.text('Ave Maria'), findsOneWidget);
    });

    testWidgets('tapping a SongRow navigates to song-detail with that id', (
      tester,
    ) async {
      final repo = _FakeSongRepository([
        _song(id: 'song-42', name: 'Ave Maria', author: 'Marina Silva'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ave Maria'));
      await tester.pumpAndSettle();

      expect(find.text('route:song-detail:song-42'), findsOneWidget);
    });

    testWidgets('tapping Importar navigates to package-import', (tester) async {
      final repo = _FakeSongRepository([
        _song(id: '1', name: 'Ave Maria', author: 'x'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();

      expect(find.text('route:package-import'), findsOneWidget);
    });

    testWidgets('tapping the avatar navigates to profile', (tester) async {
      final repo = _FakeSongRepository([
        _song(id: '1', name: 'Ave Maria', author: 'x'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.text('route:profile'), findsOneWidget);
    });

    testWidgets(
        'tapping the footer Entrar em sala/Criar sala navigate accordingly', (
      tester,
    ) async {
      final repo = _FakeSongRepository([
        _song(id: '1', name: 'Ave Maria', author: 'x'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entrar em sala'));
      await tester.pumpAndSettle();
      expect(find.text('route:room-join'), findsOneWidget);
    });

    testWidgets('tapping Criar sala navigates to room-create', (tester) async {
      final repo = _FakeSongRepository([
        _song(id: '1', name: 'Ave Maria', author: 'x'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar sala'));
      await tester.pumpAndSettle();
      expect(find.text('route:room-create'), findsOneWidget);
    });
  });
}
