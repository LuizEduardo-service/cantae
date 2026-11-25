import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/theme/cantae_colors.dart';
import 'package:cantae/presentation/widgets/playback_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: child),
        ),
      ),
    );

PlaybackLoopTrackShape _trackShape(WidgetTester tester) => tester
    .widget<SliderTheme>(find.descendant(
      of: find.byType(PlaybackProgress),
      matching: find.byType(SliderTheme),
    ))
    .data
    .trackShape! as PlaybackLoopTrackShape;

void main() {
  group('PlaybackProgress', () {
    testWidgets('shows the current and total time in m:ss.s', (tester) async {
      await tester.pumpWidget(_wrap(PlaybackProgress(
        positionMs: 5300,
        durationMs: 185000,
        onSeek: (_) {},
      )));

      expect(find.text('0:05.3'), findsOneWidget);
      expect(find.text('3:05.0'), findsOneWidget);
    });

    testWidgets('dragging seeks once, on release, to the dropped time',
        (tester) async {
      final seeks = <int>[];
      await tester.pumpWidget(_wrap(PlaybackProgress(
        positionMs: 0,
        durationMs: 60000,
        onSeek: seeks.add,
      )));

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Slider)));
      await gesture.moveBy(const Offset(2000, 0)); // past the right end
      await tester.pump();

      expect(seeks, isEmpty, reason: 'no seek while the finger is down');
      expect(find.text('1:00.0'), findsNWidgets(2),
          reason: 'the current time follows the drag before release');

      await gesture.up();
      await tester.pump();

      expect(seeks, [60000]);
    });

    testWidgets('loop region is set only when both bounds are given',
        (tester) async {
      await tester.pumpWidget(_wrap(PlaybackProgress(
        positionMs: 0,
        durationMs: 100000,
        loopStartMs: 41000,
        onSeek: (_) {},
      )));
      expect(_trackShape(tester).loopStart, isNull);
      expect(_trackShape(tester).loopEnd, isNull);

      await tester.pumpWidget(_wrap(PlaybackProgress(
        positionMs: 0,
        durationMs: 100000,
        loopStartMs: 41000,
        loopEndMs: 72000,
        onSeek: (_) {},
      )));
      final colors = AppTheme.light.extension<CantaeColors>()!;
      expect(_trackShape(tester).loopStart, closeTo(0.41, 1e-9));
      expect(_trackShape(tester).loopEnd, closeTo(0.72, 1e-9));
      expect(_trackShape(tester).loopColor, colors.accentTrack);
    });

    testWidgets('shows the caption when given', (tester) async {
      await tester.pumpWidget(_wrap(PlaybackProgress(
        positionMs: 0,
        durationMs: 100000,
        caption: 'Repetindo trecho 0:41–1:12',
        onSeek: (_) {},
      )));

      expect(find.text('Repetindo trecho 0:41–1:12'), findsOneWidget);
    });

    testWidgets('slider is labelled "Posição da música" with the time value',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(PlaybackProgress(
        positionMs: 5300,
        durationMs: 60000,
        onSeek: (_) {},
      )));

      final node = tester
          .getSemantics(find.bySemanticsLabel(RegExp('Posição da música')));
      expect(node.value, '0:05.3');
      handle.dispose();
    });

    testWidgets('renders under the dark theme', (tester) async {
      await tester.pumpWidget(_wrap(
        PlaybackProgress(positionMs: 0, durationMs: 60000, onSeek: (_) {}),
        theme: AppTheme.dark,
      ));

      expect(tester.takeException(), isNull);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(
          slider.activeColor, AppTheme.dark.extension<CantaeColors>()!.accent);
    });

    testWidgets('360 dp at 130% font: lays out without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PlaybackProgress(
                positionMs: 5300,
                durationMs: 185000,
                loopStartMs: 41000,
                loopEndMs: 72000,
                caption: 'Repetindo trecho 0:41–1:12',
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
