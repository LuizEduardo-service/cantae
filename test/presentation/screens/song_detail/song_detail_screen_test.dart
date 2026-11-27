import 'dart:async';

import 'package:cantae/data/library/library_file_releaser.dart';
import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_origin.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/repositories/rehearsal_repository.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/rehearsal_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/providers/track_upload_providers.dart';
import 'package:cantae/presentation/screens/song_detail/song_detail_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:cantae/presentation/theme/cantae_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository({
    required Future<Result<Song, Failure>> Function(String id) getById,
    Future<Result<Unit, Failure>> Function(String id)? delete,
  })  : _getById = getById,
        _delete = delete ?? ((_) async => const Result.success(Unit()));

  final Future<Result<Song, Failure>> Function(String id) _getById;
  final Future<Result<Unit, Failure>> Function(String id) _delete;

  @override
  Future<Result<Song, Failure>> getById(String id) => _getById(id);

  @override
  Future<Result<Unit, Failure>> delete(String id) => _delete(id);

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      const Result.success(<Song>[]);

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

class _FakeRehearsals implements RehearsalRepository {
  _FakeRehearsals(this.count);

  final int count;

  @override
  Future<Result<List<RehearsalLog>, StorageFailure>> getBySong(
    String songId,
  ) async =>
      Result.success([
        for (var i = 0; i < count; i++)
          RehearsalLog(
            id: 'log-$i',
            songId: songId,
            startedAt: DateTime(2026, 11, 25, 19, i),
            endedAt: DateTime(2026, 11, 25, 19, i + 1),
            durationMs: 60000,
            mode: RehearsalMode.solo,
            maxParticipants: 1,
            loopCount: 0,
          ),
      ]);

  @override
  Future<Result<Unit, StorageFailure>> add(RehearsalLog log) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteBySong(String songId) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/songs/s1',
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (context, state) => const Text('route:library'),
      ),
      GoRoute(
        path: '/songs/:id',
        name: 'song-detail',
        builder: (context, state) =>
            SongDetailScreen(songId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/track-align/:id',
        name: 'track-align',
        builder: (context, state) =>
            Text('route:track-align:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/lyrics-editor/:id',
        name: 'lyrics-editor',
        builder: (context, state) =>
            Text('route:lyrics-editor:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/solo-player/:id',
        name: 'solo-player',
        builder: (context, state) =>
            Text('route:solo-player:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/song-history/:id',
        name: 'song-history',
        builder: (context, state) =>
            Text('route:song-history:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/song-editor/:id',
        name: 'track-upload',
        builder: (_, state) => Text(
          'route:track-upload:${state.pathParameters['id']}'
          '${state.uri.query.isEmpty ? '' : '?${state.uri.query}'}',
        ),
      ),
      GoRoute(
        path: '/room/create',
        name: 'room-create',
        builder: (_, state) => Text('route:room-create?${state.uri.query}'),
      ),
      for (final name in [
        'studio',
        'package-import',
      ])
        GoRoute(
          path: '/$name',
          name: name,
          builder: (context, state) => Text('route:$name'),
        ),
    ],
  );
}

/// Records the paths handed over for deletion instead of touching disk.
class _RecordingReleaser extends LibraryFileReleaser {
  _RecordingReleaser(SongRepository repository)
      : super(
          repository: repository,
          resolveRoot: () async => throw UnimplementedError(),
        );

  final released = <String>[];

  @override
  Future<int> release(Iterable<String> paths) async {
    released.addAll(paths);
    return 0;
  }
}

Widget _wrap(
  SongRepository repository, {
  ThemeData? theme,
  int rehearsals = 0,
  _RecordingReleaser? releaser,
}) {
  return ProviderScope(
    overrides: [
      songRepositoryProvider.overrideWithValue(repository),
      libraryFileReleaserProvider
          .overrideWithValue(releaser ?? _RecordingReleaser(repository)),
      rehearsalRepositoryProvider
          .overrideWithValue(_FakeRehearsals(rehearsals)),
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: _buildRouter(),
    ),
  );
}

Song _completeSong({SongOrigin origin = SongOrigin.created}) {
  return Song(
    id: 's1',
    name: 'Ave Maria',
    author: 'Schubert',
    origin: origin,
    tracks: const [
      SongTrack(id: 't1', filePath: 'a.wav', naipe: Naipe.soprano),
      SongTrack(id: 't2', filePath: 'b.wav', naipe: Naipe.contralto),
      SongTrack(id: 't3', filePath: 'c.wav', naipe: Naipe.tenor),
      SongTrack(id: 't4', filePath: 'd.wav', naipe: Naipe.bass),
    ],
  );
}

Song _incompleteSong({SongOrigin origin = SongOrigin.created}) {
  return Song(
    id: 's1',
    name: 'Ave Maria',
    author: 'Schubert',
    origin: origin,
    tracks: const [
      SongTrack(id: 't1', filePath: 'a.wav', naipe: Naipe.soprano),
    ],
  );
}

void main() {
  group('SongDetailScreen', () {
    testWidgets('loading: shows a progress indicator, no naipes or footer', (
      tester,
    ) async {
      final completer = Completer<Result<Song, Failure>>();
      final repo = _FakeSongRepository(getById: (_) => completer.future);
      await tester.pumpWidget(_wrap(repo));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
      completer.complete(Result.success(_completeSong()));
      await tester.pumpAndSettle();
    });

    testWidgets('não encontrada: shows EmptyState and no header/footer', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async =>
            Result.failure(NotFoundFailure(code: 'song_not_found')),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Música não encontrada'), findsOneWidget);
      expect(find.text('Ave Maria'), findsNothing);
    });

    testWidgets(
      'não encontrada: "Voltar à Biblioteca" navigates to the library route',
      (tester) async {
        final repo = _FakeSongRepository(
          getById: (_) async =>
              Result.failure(NotFoundFailure(code: 'song_not_found')),
        );
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Voltar à Biblioteca'));
        await tester.pumpAndSettle();

        expect(find.text('route:library'), findsOneWidget);
      },
    );

    testWidgets('erro: shows an InlineBanner with a retry action', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async =>
            Result.failure(StorageFailure(code: 'song_db_error')),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets(
      'completa: header shows author + "Criada por você", no "Incompleta" suffix, all 4 naipes filled',
      (tester) async {
        final repo = _FakeSongRepository(
          getById: (_) async => Result.success(_completeSong()),
        );
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        expect(find.text('Ave Maria'), findsOneWidget);
        expect(find.textContaining('Schubert'), findsOneWidget);
        expect(find.textContaining('Criada por você'), findsOneWidget);
        expect(find.textContaining('Incompleta'), findsNothing);
        expect(find.text('Enviar faixa'), findsNothing);
      },
    );

    testWidgets(
      'incompleta: header flags "Incompleta" and shows "Enviar faixa" for missing naipes',
      (tester) async {
        final repo = _FakeSongRepository(
          getById: (_) async => Result.success(_incompleteSong()),
        );
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        expect(find.textContaining('Incompleta'), findsOneWidget);
        expect(find.text('Enviar faixa'), findsNWidgets(3));
      },
    );

    testWidgets(
      'nenhum naipe cadastrado (tracks vazio): todos os 4 aparecem como faltantes, sem erro',
      (tester) async {
        const song = Song(id: 's1', name: 'Ave Maria', author: 'Schubert');
        final repo = _FakeSongRepository(
          getById: (_) async => const Result.success(song),
        );
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Incompleta'), findsOneWidget);
        expect(find.text('Enviar faixa'), findsNWidgets(4));
      },
    );

    testWidgets(
        '"Enviar faixa" opens this song\'s tracks on that naipe (UPL-17)',
        (tester) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_incompleteSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar faixa').at(1));
      await tester.pumpAndSettle();

      expect(find.text('route:track-upload:s1?naipe=tenor'), findsOneWidget);
    });

    testWidgets(
        'regression: a missing naipe exposes one "Enviar faixa de <naipe>" '
        'button of at least 44 dp, apart from the naipe name', (tester) async {
      final semantics = tester.ensureSemantics();
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_incompleteSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      final button = find.bySemanticsLabel('Enviar faixa de Tenor');
      expect(button, findsOneWidget);
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Enviar faixa de Tenor',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(CantaeSpacing.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(CantaeSpacing.minTouchTarget));
      final name = tester.getSemantics(find.text('Tenor'));
      expect(name.label, isNot(contains('Enviar faixa')));
      expect(name.getSemanticsData().flagsCollection.isButton, isFalse);
      semantics.dispose();
    });

    testWidgets(
        'a custom naipe track is listed with its name and initial '
        '(UPL-16)', (tester) async {
      final repo = _FakeSongRepository(
        getById: (_) async => const Result.success(Song(
          id: 's1',
          name: 'Ave Maria',
          author: 'Schubert',
          tracks: [
            SongTrack(id: 't1', filePath: 'a.wav', naipe: Naipe.soprano),
            SongTrack(
              id: 't2',
              filePath: 'b.wav',
              naipe: Naipe.custom,
              customNaipe: CustomNaipe(id: 'n1', name: 'Solista'),
            ),
          ],
        )),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Solista'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2));
    });

    testWidgets('Preparar rows navigate to their own placeholder routes', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Cortar áudio no Studio'));
      await tester.pumpAndSettle();
      expect(find.text('route:studio'), findsOneWidget);
    });

    testWidgets('"Alinhar entradas" navigates to the track-align route', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Alinhar entradas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Alinhar entradas'));
      await tester.pumpAndSettle();
      expect(find.text('route:track-align:s1'), findsOneWidget);
    });

    testWidgets('"Sincronizar letra" navigates to the lyrics-editor route', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Sincronizar letra'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('Sincronizar letra'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Sincronizar letra'));
      await tester.pumpAndSettle();
      expect(find.text('route:lyrics-editor:s1'), findsOneWidget);
    });

    // rehearsal-history HIST-08: the row shows the count and opens this
    // song's history (the route now carries the song id).
    testWidgets('"Ensaios anteriores (2)" opens the history of this song', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo, rehearsals: 2));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ensaios anteriores (2)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ensaios anteriores (2)'));
      await tester.pumpAndSettle();
      expect(find.text('route:song-history:s1'), findsOneWidget);
    });

    testWidgets('without rehearsals the row reads "Ensaios anteriores"', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ensaios anteriores'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ensaios anteriores'), findsOneWidget);
    });

    // PRD UX §6.16: history is for every role, so a received (read-only)
    // song still shows it, without the rest of "Preparar".
    testWidgets('a received song shows its history but not "Preparar"', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async =>
            Result.success(_completeSong(origin: SongOrigin.received)),
      );
      await tester.pumpWidget(_wrap(repo, rehearsals: 1));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ensaios anteriores (1)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ensaios anteriores (1)'), findsOneWidget);
      expect(find.text('Alinhar entradas'), findsNothing);
      expect(find.text('Preparar'), findsNothing);
    });

    testWidgets('"Exportar" navigates to the package-import route', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exportar'));
      await tester.pumpAndSettle();
      expect(find.text('route:package-import'), findsOneWidget);
    });

    testWidgets('rodapé: "Ensaiar só" navigates to the solo-player route', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ensaiar só'));
      await tester.pumpAndSettle();
      expect(find.text('route:solo-player:s1'), findsOneWidget);
    });

    testWidgets(
        'rodapé: "Ensaiar em grupo" opens Criar sala with this song (ROOM-07)',
        (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ensaiar em grupo'));
      await tester.pumpAndSettle();
      expect(find.text('route:room-create?songId=s1'), findsOneWidget);
    });

    testWidgets(
      'origin == received: hides Preparar and "Enviar faixa", keeps ensaiar/excluir',
      (tester) async {
        final repo = _FakeSongRepository(
          getById: (_) async =>
              Result.success(_incompleteSong(origin: SongOrigin.received)),
        );
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        expect(find.textContaining('Recebida'), findsOneWidget);
        expect(find.textContaining('Preparar'), findsNothing);
        expect(find.text('Enviar faixa'), findsNothing);
        expect(find.text('Ensaiar só'), findsOneWidget);
        expect(find.text('Ensaiar em grupo'), findsOneWidget);
        expect(find.text('Apagar desta música'), findsOneWidget);
      },
    );

    testWidgets(
      'excluir: confirmar no ConfirmSheet chama delete e navega para a Biblioteca',
      (tester) async {
        String? deletedId;
        final repo = _FakeSongRepository(
          getById: (_) async => Result.success(_completeSong()),
          delete: (id) async {
            deletedId = id;
            return const Result.success(Unit());
          },
        );
        final releaser = _RecordingReleaser(repo);
        await tester.pumpWidget(_wrap(repo, releaser: releaser));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Apagar desta música'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Apagar desta música'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apagar definitivamente'));
        await tester.pumpAndSettle();

        expect(deletedId, equals('s1'));
        expect(find.text('route:library'), findsOneWidget);
        expect(releaser.released, ['a.wav', 'b.wav', 'c.wav', 'd.wav'],
            reason: 'the files of the deleted song go for deletion');
      },
    );

    testWidgets(
      'excluir: cancelar no ConfirmSheet não chama delete e permanece na tela',
      (tester) async {
        var deleteCalled = false;
        final repo = _FakeSongRepository(
          getById: (_) async => Result.success(_completeSong()),
          delete: (id) async {
            deleteCalled = true;
            return const Result.success(Unit());
          },
        );
        await tester.pumpWidget(_wrap(repo));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Apagar desta música'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Apagar desta música'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(deleteCalled, isFalse);
        expect(find.text('route:library'), findsNothing);
        expect(find.text('Apagar desta música'), findsOneWidget);
      },
    );

    testWidgets(
      'excluir: falha no repositório mostra InlineBanner e não navega',
      (tester) async {
        final repo = _FakeSongRepository(
          getById: (_) async => Result.success(_completeSong()),
          delete: (_) async => Result.failure(StorageFailure(code: 'x')),
        );
        final releaser = _RecordingReleaser(repo);
        await tester.pumpWidget(_wrap(repo, releaser: releaser));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Apagar desta música'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Apagar desta música'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apagar definitivamente'));
        await tester.pumpAndSettle();

        expect(find.text('Não foi possível apagar'), findsOneWidget);
        expect(find.text('route:library'), findsNothing);
        expect(releaser.released, isEmpty);
      },
    );

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      final repo = _FakeSongRepository(
        getById: (_) async => Result.success(_completeSong()),
      );
      await tester.pumpWidget(_wrap(repo, theme: AppTheme.dark));
      await tester.pumpAndSettle();

      expect(find.text('Ave Maria'), findsOneWidget);
    });
  });
}
