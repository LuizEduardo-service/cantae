import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:cantae/presentation/widgets/mix_track_row.dart';
import 'package:cantae/presentation/widgets/mute_solo_toggle.dart';
import 'package:cantae/presentation/widgets/voice_part_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Calls {
  final volumes = <double>[];
  var mutes = 0;
  var solos = 0;
}

Widget _row(
  _Calls calls, {
  Naipe? naipe = Naipe.tenor,
  String label = 'Tenor',
  double volume = 1.0,
  bool muted = false,
  bool solo = false,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: MixTrackRow(
            naipe: naipe,
            label: label,
            volume: volume,
            muted: muted,
            solo: solo,
            onVolumeChanged: calls.volumes.add,
            onMuteToggled: () => calls.mutes++,
            onSoloToggled: () => calls.solos++,
          ),
        ),
      ),
    );

void main() {
  group('MixTrackRow', () {
    testWidgets('a naipe row shows its selo and name', (tester) async {
      await tester.pumpWidget(_row(_Calls()));

      expect(find.byType(VoicePartBadge), findsOneWidget);
      expect(find.text('Tenor'), findsOneWidget);
    });

    testWidgets('the Playback row shows "Playback" and no naipe selo',
        (tester) async {
      await tester.pumpWidget(_row(_Calls(), naipe: null, label: 'Playback'));

      expect(find.text('Playback'), findsOneWidget);
      expect(find.byType(VoicePartBadge), findsNothing);
    });

    testWidgets('dragging the volume reports the new value', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_row(calls));

      await tester.drag(find.byType(Slider), const Offset(-2000, 0));
      await tester.pump();

      expect(calls.volumes, isNotEmpty);
      expect(calls.volumes.last, 0.0);
    });

    testWidgets('volume slider reads "Volume do Tenor" with a percent value',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_row(_Calls(), volume: 0.3));

      final node =
          tester.getSemantics(find.bySemanticsLabel('Volume do Tenor'));
      expect(node.value, '30 %');
      handle.dispose();
    });

    testWidgets('M and S report their taps', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_row(calls));

      await tester.tap(find.widgetWithText(MuteSoloToggle, 'M'));
      await tester.tap(find.widgetWithText(MuteSoloToggle, 'S'));

      expect(calls.mutes, 1);
      expect(calls.solos, 1);
    });

    testWidgets('muted and solo states are announced, not only colored',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_row(_Calls(), muted: true));

      final mute = tester.getSemantics(find.bySemanticsLabel(RegExp('Mudo')));
      final solo = tester.getSemantics(find.bySemanticsLabel(RegExp('Solo')));
      expect(mute.flagsCollection.isToggled.toBoolOrNull(), isTrue);
      expect(solo.flagsCollection.isToggled.toBoolOrNull(), isFalse);
      handle.dispose();
    });

    testWidgets('M and S are at least 44 dp', (tester) async {
      await tester.pumpWidget(_row(_Calls()));

      for (final toggle in tester.widgetList(find.byType(MuteSoloToggle))) {
        final size = tester.getSize(find.byWidget(toggle));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('showSolo: false renders M only (metronome row)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MixTrackRow(
            naipe: null,
            label: 'Metrônomo',
            volume: 1.0,
            muted: false,
            solo: false,
            showSolo: false,
            onVolumeChanged: (_) {},
            onMuteToggled: () {},
            onSoloToggled: () {},
          ),
        ),
      ));

      expect(find.widgetWithText(MuteSoloToggle, 'M'), findsOneWidget);
      expect(find.widgetWithText(MuteSoloToggle, 'S'), findsNothing);
      expect(find.text('Metrônomo'), findsOneWidget);
    });

    testWidgets('by default both M and S are shown', (tester) async {
      await tester.pumpWidget(_row(_Calls()));

      expect(find.byType(MuteSoloToggle), findsNWidgets(2));
    });

    testWidgets('renders under the dark theme', (tester) async {
      await tester
          .pumpWidget(_row(_Calls(), muted: true, theme: AppTheme.dark));

      expect(tester.takeException(), isNull);
      expect(find.text('Tenor'), findsOneWidget);
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
              child: MixTrackRow(
                naipe: Naipe.contralto,
                label: 'Contralto',
                volume: 0.5,
                muted: true,
                solo: true,
                onVolumeChanged: (_) {},
                onMuteToggled: () {},
                onSoloToggled: () {},
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
