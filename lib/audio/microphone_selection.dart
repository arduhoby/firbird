import 'dart:io';

import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MicrophoneChoice { main, bluetooth, wired }

class SelectedMicrophone {
  const SelectedMicrophone(this.choice, this.device);

  final MicrophoneChoice choice;
  final InputDevice device;

  String get label => switch (choice) {
    MicrophoneChoice.main => 'Alt/ana mikrofon',
    MicrophoneChoice.bluetooth => 'Bluetooth: ${device.label}',
    MicrophoneChoice.wired => 'Kablolu: ${device.label}',
  };
}

/// One selection rule for settings and the single live PCM recorder.
SelectedMicrophone chooseMicrophone(
  MicrophoneChoice requested,
  List<InputDevice> devices, {
  required String? mainId,
}) {
  InputDevice? firstOf(bool Function(InputDevice) matches) {
    for (final InputDevice device in devices) {
      if (matches(device)) return device;
    }
    return null;
  }

  final InputDevice? bluetooth = firstOf(
    (device) =>
        device.type == InputDeviceType.bluetoothSco ||
        device.type == InputDeviceType.bluetoothLe,
  );
  final InputDevice? wired = firstOf(
    (device) =>
        device.type == InputDeviceType.wiredHeadset ||
        device.type == InputDeviceType.usb,
  );
  final InputDevice? main = firstOf((device) => device.id == mainId);

  if (requested == MicrophoneChoice.bluetooth) {
    if (bluetooth == null) throw StateError('Bluetooth mikrofon bağlı değil.');
    return SelectedMicrophone(MicrophoneChoice.bluetooth, bluetooth);
  }
  if (wired != null) return SelectedMicrophone(MicrophoneChoice.wired, wired);
  if (requested == MicrophoneChoice.wired) {
    throw StateError('Kablolu mikrofon bağlı değil.');
  }
  if (main == null) {
    throw StateError('Alt mikrofon ayrı bir giriş olarak doğrulanamadı.');
  }
  return SelectedMicrophone(MicrophoneChoice.main, main);
}

class MicrophoneSelection {
  MicrophoneSelection(this.recorder);

  static const String _preferenceKey = 'microphone_choice';
  static const MethodChannel _channel = MethodChannel(
    'org.firbird3.app/microphone_input',
  );

  final AudioRecorder recorder;

  Future<MicrophoneChoice> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String value = prefs.getString(_preferenceKey) ?? 'main';
    for (final choice in MicrophoneChoice.values) {
      if (choice.name == value) return choice;
    }
    return MicrophoneChoice.main;
  }

  Future<void> save(MicrophoneChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, choice.name);
  }

  Future<List<InputDevice>> devices() => recorder.listInputDevices();

  RecordConfig recordingConfig(
    SelectedMicrophone selected, {
    required int sampleRate,
  }) => RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: 1,
    device: selected.device,
    // Android's PCM backend otherwise explicitly disables hardware level control.
    // Keep this capture gain separate from the model-only noise filter.
    autoGain: Platform.isAndroid,
    echoCancel: false,
    noiseSuppress: false,
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.mic,
      manageBluetooth: selected.choice == MicrophoneChoice.bluetooth,
    ),
  );

  Future<String?> bottomInputId() =>
      _channel.invokeMethod<String>('bottomInputId');

  Future<SelectedMicrophone> resolve(MicrophoneChoice choice) async =>
      chooseMicrophone(choice, await devices(), mainId: await bottomInputId());

  Future<void> applyAfterStart(SelectedMicrophone selected) async {
    if (Platform.isIOS && selected.choice == MicrophoneChoice.main) {
      await _channel.invokeMethod<void>('preferBottom');
    }
  }

  Future<String> verifyRoute(SelectedMicrophone selected) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final Map<Object?, Object?>? route = await _channel
          .invokeMethod<Map<Object?, Object?>>('activeInput');
      final String? id = route?['id'] as String?;
      final String? kind = route?['kind'] as String?;
      final bool matches = Platform.isAndroid
          ? id == selected.device.id
          : kind == selected.choice.name;
      if (route != null && matches) {
        return route['label'] as String? ?? selected.label;
      }
      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    throw StateError('Seçilen mikrofondan kayıt doğrulanamadı.');
  }
}
