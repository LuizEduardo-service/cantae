import 'package:cantae/main.dart';
import 'package:cantae/presentation/screens/library/library_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'CantaeApp boots to the Biblioteca screen with no exception thrown',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: CantaeApp()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(LibraryScreen), findsOneWidget);
    },
  );
}
