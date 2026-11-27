import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/presentation/providers/library_providers.dart';
import 'package:cantae/presentation/screens/room_create/song_choice_sheet.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (ROOM-08, ROOM-09): picking a song returns another one;
// "Sem música" cannot be picked, or looks like closing; closing looks like
// a choice; an empty library or a read error leaves a blank sheet; the
// screen reader cannot tell the current song.
const _ave = Song(id: 'ave', name: 'Ave Verum Corpus', author: 'Mozart');
const _cantate = Song(id: 'cantate', name: 'Cantate Domino', author: '');

void main() {
  late ValueNotifier<SongChoice?> result;
  late bool closed;

  setUp(() {
    result = ValueNotifier<SongChoice?>(null);
    closed = false;
  });

  Future<void> open(
    WidgetTester tester,
    Future<List<Song>> Function() songs, {
    String? currentId,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [songsProvider.overrideWith((ref) => songs())],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final choice =
                      await SongChoiceSheet.show(context, currentId: currentId);
                  closed = choice == null;
                  result.value = choice;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('picking a song returns it (ROOM-09)', (tester) async {
    await open(tester, () async => [_ave, _cantate]);

    await tester.tap(find.text('Cantate Domino'));
    await tester.pumpAndSettle();

    expect(result.value!.song!.id, 'cantate');
  });

  testWidgets('"Sem música" returns no song, which is not closing (ROOM-08)',
      (tester) async {
    await open(tester, () async => [_ave], currentId: 'ave');

    await tester.tap(find.text('Sem música'));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(result.value!.song, isNull);
  });

  testWidgets('closing returns nothing', (tester) async {
    await open(tester, () async => [_ave]);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('the current song is marked for the screen reader',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, () async => [_ave, _cantate], currentId: 'ave');

    final ave = tester
        .getSemantics(find.bySemanticsLabel('Ave Verum Corpus, Mozart'))
        .getSemanticsData();
    final cantate = tester
        .getSemantics(find.bySemanticsLabel('Cantate Domino'))
        .getSemanticsData();
    expect(ave.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(cantate.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    semantics.dispose();
  });

  testWidgets('an empty library says so and still offers "Sem música"',
      (tester) async {
    await open(tester, () async => const []);

    expect(find.textContaining('ainda não tem músicas'), findsOneWidget);
    expect(find.text('Sem música'), findsOneWidget);
  });

  testWidgets('a read error says so', (tester) async {
    await open(tester, () async => throw StateError('song_read_failed'));

    expect(find.text('Não foi possível ler a biblioteca.'), findsOneWidget);
  });

  testWidgets('renders in the dark theme', (tester) async {
    await open(tester, () async => [_ave], theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('Música da sala'), findsOneWidget);
  });
}
