import 'package:cantae/presentation/providers/member_room_notifier.dart';
import 'package:cantae/presentation/screens/room_member/room_member_screen.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Failure modes (ROOM-42..44): the master or the song is missing; "Sair da
// sala" stays on the screen or does not leave; the room ending leaves the
// singer on a dead screen or gives no reason; opening the screen with no
// room shows an empty page; the screen breaks in the dark theme or at
// 360 dp with 130 % font.
class _FakeMember extends MemberRoomNotifier {
  _FakeMember(super.ref, MemberRoomState initial) {
    state = initial;
  }

  final calls = <String>[];

  void set(MemberRoomState s) => state = s;

  @override
  Future<void> leave() async {
    calls.add('leave');
    state = const MemberRoomState(inRoom: false);
  }
}

const _inRoom = MemberRoomState(
  inRoom: true,
  masterName: 'Marina',
  songName: 'Ave Verum Corpus',
);

void main() {
  late _FakeMember member;

  Future<void> pump(
    WidgetTester tester,
    MemberRoomState initial, {
    ThemeData? theme,
    double textScale = 1,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'library',
          builder: (_, __) => const Text('route:library'),
          routes: [
            GoRoute(
              path: 'room/member',
              name: 'room-member',
              builder: (_, __) => const RoomMemberScreen(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        memberRoomProvider
            .overrideWith((ref) => member = _FakeMember(ref, initial)),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
        ),
      ),
    ));
    router.pushNamed('room-member');
    await tester.pumpAndSettle();
  }

  testWidgets('shows the master, the song and what happens next (ROOM-42)',
      (tester) async {
    await pump(tester, _inRoom);

    expect(find.text('Você está na sala de Marina'), findsOneWidget);
    expect(find.text('Ave Verum Corpus'), findsOneWidget);
    expect(
        find.text('O ensaio começa quando o Mestre conduzir.'), findsOneWidget);
  });

  testWidgets('a room without a song says so (ROOM-42)', (tester) async {
    await pump(
      tester,
      const MemberRoomState(inRoom: true, masterName: 'Marina'),
    );

    expect(find.text('Sem música escolhida'), findsOneWidget);
  });

  testWidgets('"Sair da sala" leaves and goes to the Biblioteca (ROOM-43)',
      (tester) async {
    await pump(tester, _inRoom);

    await tester.tap(find.text('Sair da sala'));
    await tester.pumpAndSettle();

    expect(member.calls, ['leave']);
    expect(find.text('route:library'), findsOneWidget);
  });

  testWidgets('system back leaves the room too', (tester) async {
    await pump(tester, _inRoom);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(member.calls, ['leave']);
    expect(find.text('route:library'), findsOneWidget);
  });

  testWidgets(
      'the room ending goes to the Biblioteca with the toast '
      '(ROOM-44)', (tester) async {
    await pump(tester, _inRoom);

    member.set(const MemberRoomState(
      inRoom: false,
      masterName: 'Marina',
      lost: true,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('route:library'), findsOneWidget);
    expect(
        find.text('A sala foi encerrada ou a conexão caiu.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('with no room it goes to the Biblioteca', (tester) async {
    await pump(tester, const MemberRoomState(inRoom: false));

    expect(find.text('route:library'), findsOneWidget);
  });

  testWidgets('fits 360 dp at 130 % in both themes', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await pump(
        tester,
        const MemberRoomState(
          inRoom: true,
          masterName: 'Maria Aparecida da Conceição',
          songName: 'Cantate Domino canticum novum',
        ),
        theme: theme,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
