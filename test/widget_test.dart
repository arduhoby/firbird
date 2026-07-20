import 'package:firbird/app/firbird_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigates from onboarding to photo selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FirBirdApp());

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Select photo'), findsOneWidget);
    await tester.tap(find.text('Select photo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose a photo from your gallery. It stays on your device.'),
      findsOneWidget,
    );
  });
}
