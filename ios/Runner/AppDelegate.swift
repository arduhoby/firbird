import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioPlayer: AVAudioPlayer?
  private var playbackGain: Float = 1.0
  private var currentAudioPath: String?
  private var currentLooping: Bool = false

  private func amplifyPcm16Wav(data: Data, gain: Float) -> Data {
    guard gain > 1.0, data.count > 44 else { return data }
    guard data[0] == 0x52, data[1] == 0x49, data[2] == 0x46, data[3] == 0x46,
          data[8] == 0x57, data[9] == 0x41, data[10] == 0x56, data[11] == 0x45 else {
      return data
    }
    var mutableData = data
    mutableData.withUnsafeMutableBytes { (rawBuffer: UnsafeMutableRawBufferPointer) in
      guard let base = rawBuffer.baseAddress?.advanced(by: 44) else { return }
      let sampleCount = (data.count - 44) / 2
      let samples = base.assumingMemoryBound(to: Int16.self)
      for i in 0..<sampleCount {
        let sample = Float(samples[i]) * gain
        if sample > 30000 {
          let excess = sample - 30000
          samples[i] = Int16(clamping: Int(30000.0 + 2767.0 * (excess / (excess + 2767.0))))
        } else if sample < -30000 {
          let excess = -sample - 30000
          samples[i] = Int16(clamping: Int(-30000.0 - 2767.0 * (excess / (excess + 2767.0))))
        } else {
          samples[i] = Int16(clamping: Int(sample))
        }
      }
    }
    return mutableData
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      setupMediaChannel(messenger: controller.binaryMessenger)
      setupMicrophoneChannel(messenger: controller.binaryMessenger)
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FirBirdMediaPlayerPlugin") {
      setupMediaChannel(messenger: registrar.messenger())
      setupMicrophoneChannel(messenger: registrar.messenger())
    }
  }

  private func setupMediaChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "org.firbird3.app/media_player", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMediaCall(call, result: result)
    }
  }

  private func bottomMicrophone() throws -> (AVAudioSessionPortDescription, AVAudioSessionDataSourceDescription?)? {
    let session = AVAudioSession.sharedInstance()
    if session.category != .playAndRecord && session.category != .record {
      try session.setCategory(.playAndRecord, options: [.allowBluetooth, .defaultToSpeaker])
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
    guard let port = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
      return nil
    }
    let source = port.dataSources?.first(where: { $0.location == .lower })
      ?? port.dataSources?.first(where: { $0.dataSourceName.localizedCaseInsensitiveContains("bottom") })
      ?? port.dataSources?.first
    return (port, source)
  }

  private func setupMicrophoneChannel(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "org.firbird3.app/microphone_input", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { result(nil); return }
        do {
          let session = AVAudioSession.sharedInstance()
          switch call.method {
          case "bottomInputId":
            let bottom = try self.bottomMicrophone()
            result(bottom?.0.uid ?? session.availableInputs?.first(where: { $0.portType == .builtInMic })?.uid)
          case "preferBottom":
            guard let (port, maybeSource) = try self.bottomMicrophone() else {
              result(nil)
              return
            }
            if let source = maybeSource {
              try? port.setPreferredDataSource(source)
            }
            try? session.setPreferredInput(port)
            result(nil)
          case "activeInput":
            guard let port = session.currentRoute.inputs.first else { result(nil); return }
            let kind: String
            switch port.portType {
            case .builtInMic:
              kind = "main"
            case .headsetMic, .usbAudio:
              kind = "wired"
            case .bluetoothHFP, .bluetoothLE:
              kind = "bluetooth"
            default:
              kind = "unknown"
            }
            result(["id": port.uid, "kind": kind, "label": port.portName])
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "MICROPHONE_FAILED", message: error.localizedDescription, details: nil))
        }
      }
  }

  private func handleMediaCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing audio path", details: nil))
        return
      }
      playAudio(path: path, looping: false, result: result)

    case "playLooping":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing audio path", details: nil))
        return
      }
      playAudio(path: path, looping: true, result: result)

    case "pause":
      audioPlayer?.pause()
      result(nil)

    case "resume":
      audioPlayer?.play()
      result(nil)

    case "stop":
      stopAudio()
      result(nil)

    case "seekTo":
      if let args = call.arguments as? [String: Any],
         let positionMs = args["positionMs"] as? Int {
        audioPlayer?.currentTime = TimeInterval(positionMs) / 1000.0
      }
      result(nil)

    case "setVolume":
      if let args = call.arguments as? [String: Any],
         let volume = args["volume"] as? Double {
        playbackGain = Float(max(0.0, min(volume, 4.0)))
        if playbackGain <= 1.0 {
          audioPlayer?.volume = playbackGain
        } else if let path = currentAudioPath,
                  let player = audioPlayer,
                  let rawData = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  rawData.count > 44 {
          let wasPlaying = player.isPlaying
          let currentPos = player.currentTime
          let boostedData = amplifyPcm16Wav(data: rawData, gain: playbackGain)
          if let newPlayer = try? AVAudioPlayer(data: boostedData) {
            newPlayer.numberOfLoops = player.numberOfLoops
            newPlayer.volume = 1.0
            newPlayer.currentTime = currentPos
            newPlayer.prepareToPlay()
            if wasPlaying {
              newPlayer.play()
            }
            audioPlayer = newPlayer
          }
        }
      }
      result(nil)

    case "position":
      let currentPos = Int((audioPlayer?.currentTime ?? 0) * 1000)
      let duration = Int((audioPlayer?.duration ?? 0) * 1000)
      let isPlaying = audioPlayer?.isPlaying ?? false
      result([
        "positionMs": currentPos,
        "durationMs": duration,
        "isPlaying": isPlaying
      ])

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func playAudio(path: String, looping: Bool, result: @escaping FlutterResult) {
    stopAudio()
    currentAudioPath = path
    currentLooping = looping
    let url = URL(fileURLWithPath: path)
    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
      try AVAudioSession.sharedInstance().setActive(true)
      if playbackGain > 1.0,
         let rawData = try? Data(contentsOf: url),
         rawData.count > 44 {
        let boostedData = amplifyPcm16Wav(data: rawData, gain: playbackGain)
        audioPlayer = try AVAudioPlayer(data: boostedData)
        audioPlayer?.volume = 1.0
      } else {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.volume = min(1.0, playbackGain)
      }
      audioPlayer?.numberOfLoops = looping ? -1 : 0
      audioPlayer?.prepareToPlay()
      audioPlayer?.play()
      result(nil)
    } catch {
      result(FlutterError(code: "MEDIA_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  private func stopAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
    currentAudioPath = nil
  }
}
