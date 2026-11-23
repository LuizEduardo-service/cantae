import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/widgets/track_align_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
      theme: theme ?? AppTheme.light, home: Scaffold(body: child));
}

void main() {
  group('TrackAlignRow', () {
    testWidgets('renders selo, nome, atraso formatado e botões M/S', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.soprano,
            startDelayMs: 1500,
            muted: false,
            solo: false,
            onOffsetChanged: (_) {},
            onMuteChanged: (_) {},
            onSoloChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Soprano'), findsOneWidget);
      expect(find.text('0:01.5'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'M'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'S'), findsOneWidget);
    });

    testWidgets('editing with a valid value calls onOffsetChanged in ms', (
      tester,
    ) async {
      int? changedMs;
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.soprano,
            startDelayMs: 0,
            muted: false,
            solo: false,
            onOffsetChanged: (ms) => changedMs = ms,
            onMuteChanged: (_) {},
            onSoloChanged: (_) {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '0:01.5');
      await tester.pump();

      expect(changedMs, 1500);
    });

    testWidgets('editing with an invalid value does not call onOffsetChanged', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.soprano,
            startDelayMs: 0,
            muted: false,
            solo: false,
            onOffsetChanged: (_) => called = true,
            onMuteChanged: (_) {},
            onSoloChanged: (_) {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('tapping M calls onMuteChanged with the toggled value', (
      tester,
    ) async {
      bool? mutedValue;
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.soprano,
            startDelayMs: 0,
            muted: false,
            solo: false,
            onOffsetChanged: (_) {},
            onMuteChanged: (v) => mutedValue = v,
            onSoloChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.widgetWithText(InkWell, 'M'));

      expect(mutedValue, isTrue);
    });

    testWidgets('tapping S calls onSoloChanged with the toggled value', (
      tester,
    ) async {
      bool? soloValue;
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.soprano,
            startDelayMs: 0,
            muted: false,
            solo: false,
            onOffsetChanged: (_) {},
            onMuteChanged: (_) {},
            onSoloChanged: (v) => soloValue = v,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(InkWell, 'S'));

      expect(soloValue, isTrue);
    });

    testWidgets('muted renders the waveform at 25% opacity', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.soprano,
            startDelayMs: 0,
            muted: true,
            solo: false,
            onOffsetChanged: (_) {},
            onMuteChanged: (_) {},
            onSoloChanged: (_) {},
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.25);
    });

    testWidgets('solo renders the card with an accent border', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.soprano,
            startDelayMs: 0,
            muted: false,
            solo: true,
            onOffsetChanged: (_) {},
            onMuteChanged: (_) {},
            onSoloChanged: (_) {},
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.border!.top.color,
        AppTheme.light.extension<CantaeColors>()!.accent,
      );
    });

    testWidgets('renders under the dark theme without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TrackAlignRow(
            naipe: Naipe.contralto,
            startDelayMs: 0,
            muted: false,
            solo: false,
            onOffsetChanged: (_) {},
            onMuteChanged: (_) {},
            onSoloChanged: (_) {},
          ),
          theme: AppTheme.dark,
        ),
      );

      expect(find.text('Contralto'), findsOneWidget);
    });
  });

  group('TrackAlignDuration', () {
    test('format renders mm:ss.s with no leading zero on minutes', () {
      expect(TrackAlignDuration.format(1500), '0:01.5');
      expect(TrackAlignDuration.format(65400), '1:05.4');
    });

    test('parse rejects malformed or out-of-range input', () {
      expect(TrackAlignDuration.parse('abc'), isNull);
      expect(TrackAlignDuration.parse('0:60.0'), isNull);
      expect(TrackAlignDuration.parse('0:01.5'), 1500);
    });
  });
}
