import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/voice_part_colors.dart';
import 'package:cantae/presentation/widgets/naipe_labels.dart';
import 'package:cantae/presentation/widgets/voice_part_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (UPL-16):
// - a custom naipe track shows a blank name or "Outro naipe";
// - the Playback track shows a naipe name;
// - a custom badge shows no letter (color alone) or a standard naipe's
//   color;
// - the custom badge's letter is unreadable in the dark theme.
const solista = CustomNaipe(id: 'n1', name: 'solista');

SongTrack track(Naipe naipe, {CustomNaipe? custom, bool playback = false}) =>
    SongTrack(
      id: 't',
      filePath: '/f.mp3',
      naipe: naipe,
      customNaipe: custom,
      isPlayback: playback,
    );

Widget _wrap(Widget child, ThemeData theme) =>
    MaterialApp(theme: theme, home: Scaffold(body: Center(child: child)));

void main() {
  test('standard tracks show the pt-BR naipe name', () {
    expect(trackDisplayName(track(Naipe.soprano)), 'Soprano');
    expect(trackDisplayName(track(Naipe.contralto)), 'Contralto');
    expect(trackDisplayName(track(Naipe.tenor)), 'Tenor');
    expect(trackDisplayName(track(Naipe.bass)), 'Baixo');
  });

  test('a custom naipe track shows its own name', () {
    expect(trackDisplayName(track(Naipe.custom, custom: solista)), 'solista');
  });

  test('a nameless custom track is "Outro naipe"', () {
    expect(trackDisplayName(track(Naipe.custom)), 'Outro naipe');
  });

  test('the Playback track is "Playback"', () {
    expect(trackDisplayName(track(Naipe.custom, playback: true)), 'Playback');
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final dark = theme.brightness == Brightness.dark;

    testWidgets(
        'a custom naipe badge shows its uppercase initial in neutral colors '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await tester.pumpWidget(
        _wrap(
            const NaipeBadge(naipe: Naipe.custom, customNaipe: solista), theme),
      );

      final letter = tester.widget<Text>(find.text('S'));
      final neutral = VoicePartColors.of(VoicePart.todos, theme.brightness);
      expect(letter.style!.color, neutral.textColor);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(VoicePartBadge),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).color, neutral.background);
    });
  }

  testWidgets('a standard naipe badge keeps its own letter', (tester) async {
    await tester.pumpWidget(
      _wrap(const NaipeBadge(naipe: Naipe.tenor), AppTheme.light),
    );

    expect(find.text('T'), findsOneWidget);
  });
}
