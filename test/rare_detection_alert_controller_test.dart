import 'package:firbird/detection/rare_detection_alert_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rare alert pulses every 15 seconds until verdict', (
    WidgetTester tester,
  ) async {
    final RareDetectionAlertController controller =
        RareDetectionAlertController();
    addTearDown(controller.dispose);

    controller.register('Aquila heliaca');
    expect(controller.detectedSpeciesCount, 1);
    expect(controller.isUnresolved('aquila heliaca'), isTrue);
    expect(controller.isPulseVisible, isTrue);

    await tester.pump(const Duration(milliseconds: 900));
    expect(controller.isPulseVisible, isFalse);
    await tester.pump(const Duration(milliseconds: 14100));
    expect(controller.isPulseVisible, isTrue);

    controller.resolve('Aquila heliaca');
    expect(controller.isUnresolved('Aquila heliaca'), isFalse);
    expect(controller.isPulseVisible, isFalse);
    expect(controller.detectedSpeciesCount, 1);

    controller.register('Aquila heliaca');
    expect(controller.isUnresolved('Aquila heliaca'), isFalse);
  });

  test('repeat detections do not inflate the rare species report', () {
    final RareDetectionAlertController controller =
        RareDetectionAlertController();
    addTearDown(controller.dispose);

    controller
      ..register('Aquila heliaca')
      ..register('aquila heliaca')
      ..register('  Aquila heliaca  ');

    expect(controller.detectedSpeciesCount, 1);
  });
}
