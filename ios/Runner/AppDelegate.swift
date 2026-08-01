import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioPlayer: AVAudioPlayer?
  private var playbackGain: Float = 1.0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      setupMediaChannel(messenger: controller.binaryMessenger)
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FirBirdMediaPlayerPlugin") {
      setupMediaChannel(messenger: registrar.messenger())
    }
  }

  private func setupMediaChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "org.firbird3.app/media_player", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMediaCall(call, result: result)
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
        audioPlayer?.volume = min(1.0, playbackGain)
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
    let url = URL(fileURLWithPath: path)
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.numberOfLoops = looping ? -1 : 0
      audioPlayer?.volume = min(1.0, playbackGain)
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
  }
}
