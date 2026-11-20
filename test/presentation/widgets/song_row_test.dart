import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/song_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required ThemeData theme}) {
  return MaterialApp(theme: theme, home: Scaffold(body: child));
}

/// `SongRow`'s subtitle is a `RichText` (title + status span), so
/// `find.text`/`find.textContaining` (which only match plain `Text` widgets)
/// can't see it. Reads every `RichText`'s flattened plain text instead.
bool _anyRichTextContains(WidgetTester tester, String substring) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  return richTexts.any(
    (rt) => rt.text.toPlainText().contains(substring),
  );
}

SongTrack _track(Naipe naipe) =>
    SongTrack(id: 't-${naipe.name}', filePath: '/tmp/${naipe.name}.wav', naipe: naipe);

final _completeSong = Song(
  id: 's1',
  name: 'Ave Maria',
  author: 'Marina Silva',
  tracks: [
    _track(Naipe.soprano),
    _track(Naipe.contralto),
    _track(Naipe.tenor),
    _track(Naipe.bass),
  ],
);

final _missingOneSong = Song(
  id: 's2',
  name: 'O Sacrum Convivium',
  author: 'José Pereira',
  tracks: [_track(Naipe.soprano), _track(Naipe.contralto), _track(Naipe.bass)],
);

final _missingTwoSong = Song(
  id: 's3',
  name: 'Panis Angelicus',
  author: 'Carla Souza',
  tracks: [_track(Naipe.soprano)],
);

void main() {
  group('SongRow', () {
    testWidgets('a complete song shows no status text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _completeSong, onTap: () {}),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('Ave Maria'), findsOneWidget);
      expect(_anyRichTextContains(tester, 'Falta'), isFalse);
    });

    testWidgets('a song missing exactly one naipe shows "Falta {Naipe}"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _missingOneSong, onTap: () {}),
          theme: AppTheme.light,
        ),
      );

      expect(_anyRichTextContains(tester, 'Falta Tenor'), isTrue);
    });

    testWidgets('a song missing 2+ naipes shows "Faltam {N} naipes"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _missingTwoSong, onTap: () {}),
          theme: AppTheme.light,
        ),
      );

      expect(_anyRichTextContains(tester, 'Faltam 3 naipes'), isTrue);
    });

    testWidgets('highlighted renders the surface background treatment', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _completeSong, highlighted: true, onTap: () {}),
          theme: AppTheme.light,
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('Ave Maria'), matching: find.byType(Container))
            .first,
      );
      expect(container.color, const Color(0xFFFFFFFF));
    });

    testWidgets('not highlighted has no surface background', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _completeSong, onTap: () {}),
          theme: AppTheme.light,
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('Ave Maria'), matching: find.byType(Container))
            .first,
      );
      expect(container.color, isNull);
    });

    testWidgets('tapping the row fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _completeSong, onTap: () => tapped = true),
          theme: AppTheme.light,
        ),
      );

      await tester.tap(find.byType(SongRow));
      expect(tapped, isTrue);
    });

    testWidgets('renders 4 VoicePartBadges per row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _missingOneSong, onTap: () {}),
          theme: AppTheme.light,
        ),
      );

      expect(find.text('S'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SongRow(song: _missingOneSong, onTap: () {}),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('O Sacrum Convivium'), findsOneWidget);
    });
  });
}
