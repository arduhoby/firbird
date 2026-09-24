import 'package:firbird/app/firbird_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('opens the firbird4 identification home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FirBirdApp()));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('firbird4'), findsOneWidget);
  });
}
