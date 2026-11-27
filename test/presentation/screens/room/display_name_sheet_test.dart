import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/presentation/providers/room_providers.dart';
import 'package:cantae/presentation/screens/room/display_name_sheet.dart';
import 'package:cantae/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/room_fakes.dart';

// Failure modes (ROOM-01..04): a blank or 41-character name can be saved;
// nothing says why the button is off for a long name; the name is saved
// with spaces around it; a failed save closes the sheet and loses the
// name; closing the sheet looks like a saved name; a saved name asks
// again; the dark theme breaks the sheet.
class _Host extends ConsumerWidget {
  const _Host(this.result);

  final ValueNotifier<String?> result;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async =>
                result.value = await DisplayNameSheet.ensure(context, ref),
            child: const Text('abrir'),
          ),
        ),
      );
}

void main() {
  late InMemoryLocalProfiles profiles;
  late ValueNotifier<String?> result;

  setUp(() {
    profiles = InMemoryLocalProfiles('ana');
    result = ValueNotifier<String?>('unset');
  });

  Future<void> open(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [localProfileRepositoryProvider.overrideWithValue(profiles)],
      child: MaterialApp(theme: theme ?? AppTheme.light, home: _Host(result)),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Finder save() => find.widgetWithText(InkWell, 'Salvar nome');

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<InkWell>(save()).onTap != null;

  testWidgets('without a saved name the sheet asks first (ROOM-01)',
      (tester) async {
    await open(tester);

    expect(find.text('Como você quer aparecer na sala?'), findsOneWidget);
  });

  testWidgets('a blank name keeps "Salvar nome" off (ROOM-02)', (tester) async {
    await open(tester);

    expect(saveEnabled(tester), isFalse);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('41 characters keep it off and say why (ROOM-02)',
      (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'a' * 41);
    await tester.pump();

    expect(saveEnabled(tester), isFalse);
    expect(find.text('Use até 40 caracteres.'), findsOneWidget);
  });

  testWidgets('saving stores the trimmed name and returns it (ROOM-03)',
      (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '  Marina  ');
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();

    expect(profiles.displayName, 'Marina');
    expect(result.value, 'Marina');
    expect(find.text('Como você quer aparecer na sala?'), findsNothing);
  });

  testWidgets('a saved name is returned without asking again (ROOM-03)',
      (tester) async {
    profiles.displayName = 'Marina';

    await open(tester);

    expect(find.text('Como você quer aparecer na sala?'), findsNothing);
    expect(result.value, 'Marina');
  });

  testWidgets('a failed save keeps the sheet and the name', (tester) async {
    profiles.failure = StorageFailure(code: 'local_profile_save_failed');
    await open(tester);

    await tester.enterText(find.byType(TextField), 'Marina');
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível salvar o nome.'), findsOneWidget);
    expect(find.text('Marina'), findsOneWidget);
    expect(result.value, 'unset');
  });

  testWidgets('closing the sheet returns no name (ROOM-04)', (tester) async {
    await open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result.value, isNull);
    expect(profiles.displayName, isNull);
  });

  testWidgets('renders in the dark theme', (tester) async {
    await open(tester, theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('Salvar nome'), findsOneWidget);
  });
}
