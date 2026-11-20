import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/routing/app_router.dart';
import 'package:cantae/presentation/screens/coming_soon/coming_soon_screen.dart';
import 'package:cantae/presentation/screens/library/library_screen.dart';
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
  Future<Result<Song, Failure>> getById(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> delete(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      songRepositoryProvider.overrideWithValue(_EmptySongRepository()),
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

    testWidgets('song-detail renders ComingSoonScreen', (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed('song-detail', pathParameters: {'id': 'abc'});
      await tester.pumpAndSettle();

      expect(find.byType(ComingSoonScreen), findsOneWidget);
      expect(find.text('Detalhe da música'), findsOneWidget);
    });

    testWidgets('room-create renders ComingSoonScreen', (tester) async {
      final router = await _pumpRouter(tester);

      router.goNamed('room-create');
      await tester.pumpAndSettle();

      expect(find.byType(ComingSoonScreen), findsOneWidget);
      expect(find.text('Criar sala'), findsOneWidget);
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
  });
}
