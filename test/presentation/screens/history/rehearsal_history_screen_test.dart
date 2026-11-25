import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/core/unit.dart';
import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/repositories/rehearsal_repository.dart';
import 'package:cantae/domain/repositories/song_repository.dart';
import 'package:cantae/presentation/providers/rehearsal_providers.dart';
import 'package:cantae/presentation/providers/song_repository_provider.dart';
import 'package:cantae/presentation/screens/history/rehearsal_history_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

RehearsalLog _log(String id, String songId, DateTime at, int ms, int loops) =>
    RehearsalLog(
      id: id,
      songId: songId,
      startedAt: at,
      endedAt: at.add(Duration(milliseconds: ms)),
      durationMs: ms,
      mode: RehearsalMode.solo,
      maxParticipants: 1,
      loopCount: loops,
    );

class _Rehearsals implements RehearsalRepository {
  _Rehearsals(this.logs);

  final List<RehearsalLog> logs;
  bool failRead = false;
  bool failDelete = false;

  @override
  Future<Result<Unit, StorageFailure>> add(RehearsalLog log) =>
      throw UnimplementedError();

  @override
  Future<Result<List<RehearsalLog>, StorageFailure>> getBySong(
    String songId,
  ) async {
    if (failRead) {
      return Result.failure(StorageFailure(code: 'rehearsal_read_failed'));
    }
    return Result.success(logs.where((l) => l.songId == songId).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt)));
  }

  @override
  Future<Result<Unit, StorageFailure>> deleteBySong(String songId) async {
    if (failDelete) {
      return Result.failure(StorageFailure(code: 'rehearsal_delete_failed'));
    }
    logs.removeWhere((l) => l.songId == songId);
    return const Result.success(Unit());
  }

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() async {
    if (failDelete) {
      return Result.failure(StorageFailure(code: 'rehearsal_delete_failed'));
    }
    logs.clear();
    return const Result.success(Unit());
  }
}

class _Songs implements SongRepository {
  bool missing = false;

  @override
  Future<Result<Song, Failure>> getById(String id) async => missing
      ? Result.failure(NotFoundFailure(code: 'song_not_found'))
      : Result.success(
          Song(id: id, name: 'Ave Verum Corpus', author: 'Mozart'));

  @override
  Future<Result<Unit, StorageFailure>> save(Song song) =>
      throw UnimplementedError();

  @override
  Future<Result<List<Song>, StorageFailure>> getAll() async =>
      const Result.success(<Song>[]);

  @override
  Future<Result<Unit, Failure>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<Unit, StorageFailure>> deleteAll() =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, Failure>> markRehearsed(String id, DateTime at) =>
      throw UnimplementedError();
}

List<RehearsalLog> _twoLogs() => [
      _log('old', 'ave', DateTime(2026, 11, 20, 8, 5), 185000, 0),
      _log('new', 'ave', DateTime(2026, 11, 25, 19, 40), 750000, 8),
      _log('other', 'aleluia', DateTime(2026, 11, 24, 10), 300000, 2),
    ];

Future<({_Rehearsals rehearsals, _Songs songs})> _open(
  WidgetTester tester, {
  List<RehearsalLog>? logs,
  bool missing = false,
  bool failRead = false,
  ThemeData? theme,
}) async {
  final rehearsals = _Rehearsals(logs ?? _twoLogs())..failRead = failRead;
  final songs = _Songs()..missing = missing;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      rehearsalRepositoryProvider.overrideWithValue(rehearsals),
      songRepositoryProvider.overrideWithValue(songs),
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      routerConfig: GoRouter(
        initialLocation: '/song-history/ave',
        routes: [
          GoRoute(
            path: '/',
            name: 'library',
            builder: (_, __) => const Text('route:library'),
          ),
          GoRoute(
            path: '/songs/:id',
            name: 'song-detail',
            builder: (_, s) =>
                Text('route:song-detail:${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/solo-player/:id',
            name: 'solo-player',
            builder: (_, s) =>
                Text('route:solo-player:${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/song-history/:id',
            name: 'song-history',
            builder: (_, s) =>
                RehearsalHistoryScreen(songId: s.pathParameters['id']!),
          ),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (rehearsals: rehearsals, songs: songs);
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  group('RehearsalHistoryScreen (UI_SPEC §6.16)', () {
    testWidgets('ready: header, totals and rows newest first', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);

      expect(find.text('‹ Ave Verum Corpus'), findsOneWidget);
      expect(find.text('Ensaios'), findsOneWidget);
      expect(find.text('Registrados só neste aparelho.'), findsOneWidget);
      expect(find.bySemanticsLabel('ensaios: 2'), findsOneWidget);
      expect(find.bySemanticsLabel('tempo: 15:35'), findsOneWidget);
      expect(find.bySemanticsLabel('loops: 8'), findsOneWidget);

      final newRow = find.text('25 nov 2026 · 19:40');
      final oldRow = find.text('20 nov 2026 · 08:05');
      expect(newRow, findsOneWidget);
      expect(oldRow, findsOneWidget);
      expect(
        tester.getTopLeft(newRow).dy,
        lessThan(tester.getTopLeft(oldRow).dy),
      );
      expect(find.textContaining('12:30'), findsOneWidget);
      expect(find.textContaining('8 loops'), findsOneWidget);
      expect(find.textContaining('3:05'), findsOneWidget);
      expect(find.textContaining('sem loops'), findsOneWidget);
      expect(find.textContaining('Modo solo'), findsNWidgets(2));
      semantics.dispose();
    });

    testWidgets('empty: message and "Ensaiar agora" opens Modo solo',
        (tester) async {
      await _open(tester, logs: []);

      expect(find.text('Nenhum ensaio registrado ainda'), findsOneWidget);
      expect(find.text('Apagar tudo'), findsNothing);
      await _tap(tester, 'Ensaiar agora');

      expect(find.text('route:solo-player:ave'), findsOneWidget);
    });

    testWidgets('loading shows a progress indicator', (tester) async {
      final rehearsals = _Rehearsals(_twoLogs());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          rehearsalRepositoryProvider.overrideWithValue(rehearsals),
          songRepositoryProvider.overrideWithValue(_Songs()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RehearsalHistoryScreen(songId: 'ave'),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a read error offers "Tentar de novo"', (tester) async {
      final s = await _open(tester, failRead: true);

      expect(find.text('Não foi possível carregar os ensaios'), findsOneWidget);
      s.rehearsals.failRead = false;
      await _tap(tester, 'Tentar de novo');

      expect(find.text('25 nov 2026 · 19:40'), findsOneWidget);
    });

    testWidgets('a missing song offers "Voltar à Biblioteca"', (tester) async {
      await _open(tester, missing: true);

      expect(find.text('Música não encontrada'), findsOneWidget);
      await _tap(tester, 'Voltar à Biblioteca');

      expect(find.text('route:library'), findsOneWidget);
    });

    testWidgets('back goes to the song detail', (tester) async {
      await _open(tester);

      await _tap(tester, '‹ Ave Verum Corpus');

      expect(find.text('route:song-detail:ave'), findsOneWidget);
    });

    testWidgets('"Apagar desta música" confirmed: empty and toast',
        (tester) async {
      final s = await _open(tester);

      await _tap(tester, 'Apagar desta música');
      expect(find.text('Apagar os ensaios desta música?'), findsOneWidget);
      await _tap(tester, 'Apagar ensaios');

      expect(find.text('Nenhum ensaio registrado ainda'), findsOneWidget);
      expect(find.text('Ensaios apagados'), findsOneWidget);
      expect(s.rehearsals.logs.map((l) => l.id), ['other']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      final s = await _open(tester);

      await _tap(tester, 'Apagar desta música');
      await _tap(tester, 'Cancelar');

      expect(find.text('25 nov 2026 · 19:40'), findsOneWidget);
      expect(s.rehearsals.logs, hasLength(3));
    });

    testWidgets('"Apagar tudo" confirmed deletes every song', (tester) async {
      final s = await _open(tester);

      await _tap(tester, 'Apagar tudo');
      expect(
        find.textContaining('todas as músicas deste aparelho'),
        findsOneWidget,
      );
      await _tap(tester, 'Apagar todos');

      expect(find.text('Nenhum ensaio registrado ainda'), findsOneWidget);
      expect(s.rehearsals.logs, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a failed delete keeps the list and shows a banner',
        (tester) async {
      final s = await _open(tester);
      s.rehearsals.failDelete = true;

      await _tap(tester, 'Apagar desta música');
      await _tap(tester, 'Apagar ensaios');

      expect(find.text('Não foi possível apagar os ensaios.'), findsOneWidget);
      expect(find.text('25 nov 2026 · 19:40'), findsOneWidget);
      expect(find.text('Ensaios apagados'), findsNothing);
    });

    testWidgets('renders under the dark theme', (tester) async {
      await _open(tester, theme: AppTheme.dark);

      expect(tester.takeException(), isNull);
      expect(find.text('Ensaios'), findsOneWidget);
    });

    testWidgets('360 dp at 130 %: no overflow, buttons at least 44 dp',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _open(tester);

      expect(tester.takeException(), isNull);
      for (final button in [
        find.widgetWithText(DestructiveButton, 'Apagar desta música'),
        find.widgetWithText(SecondaryButton, 'Apagar tudo'),
      ]) {
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      }
    });
  });
}
