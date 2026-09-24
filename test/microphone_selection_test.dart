import 'package:firbird/audio/microphone_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  const InputDevice main = InputDevice(
    id: '1',
    label: 'Alt mikrofon',
    type: InputDeviceType.builtIn,
  );
  const InputDevice wired = InputDevice(
    id: '2',
    label: 'Kablolu',
    type: InputDeviceType.wiredHeadset,
  );
  const InputDevice bluetooth = InputDevice(
    id: '3',
    label: 'Bluetooth',
    type: InputDeviceType.bluetoothSco,
  );

  test('wired input takes over the main setting when connected', () {
    expect(
      chooseMicrophone(MicrophoneChoice.main, const <InputDevice>[
        main,
        wired,
        bluetooth,
      ], mainId: '1').choice,
      MicrophoneChoice.wired,
    );
  });

  test('explicit Bluetooth wins over an attached wired input', () {
    expect(
      chooseMicrophone(MicrophoneChoice.bluetooth, const <InputDevice>[
        main,
        wired,
        bluetooth,
      ], mainId: '1').choice,
      MicrophoneChoice.bluetooth,
    );
  });

  test('Bluetooth connection alone leaves the bottom microphone selected', () {
    expect(
      chooseMicrophone(MicrophoneChoice.main, const <InputDevice>[
        main,
        bluetooth,
      ], mainId: '1').choice,
      MicrophoneChoice.main,
    );
  });

  test('missing Bluetooth does not silently switch to another microphone', () {
    expect(
      () => chooseMicrophone(MicrophoneChoice.bluetooth, const <InputDevice>[
        main,
      ], mainId: '1'),
      throwsStateError,
    );
  });

  test('main selection refuses an unverified built-in microphone', () {
    expect(
      () => chooseMicrophone(MicrophoneChoice.main, const <InputDevice>[
        main,
      ], mainId: null),
      throwsStateError,
    );
  });
}
