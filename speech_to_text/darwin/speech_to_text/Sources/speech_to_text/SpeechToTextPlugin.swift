import Speech
import CwlCatchException
import os.log

#if os(OSX)
  import FlutterMacOS
  import Cocoa
  import AVFoundation
#else
  import Flutter
  import UIKit
#endif

public enum SwiftSpeechToTextMethods: String {
  case has_permission
  case initialize
  case listen
  case stop
  case cancel
  case locales
  case unknown  // just for testing
}

public enum SwiftSpeechToTextCallbackMethods: String {
  case textRecognition
  case notifyStatus
  case notifyError
  case soundLevelChange
}

public enum SpeechToTextStatus: String {
  case listening
  case notListening
  case unavailable
  case available
  case done
  case doneNoResult
}

public enum SpeechToTextErrors: String {
  case onDeviceError
  case noRecognizerError
  case listenFailedError
  case missingOrInvalidArg
}

public enum ListenMode: Int {
  case deviceDefault = 0
  case dictation = 1
  case search = 2
  case confirmation = 3
}

struct SpeechRecognitionWords: Codable {
  let recognizedWords: String
  let recognizedPhrases: [String]?
  let confidence: Decimal
}

struct SpeechRecognitionResult: Codable {
  let alternates: [SpeechRecognitionWords]
  let finalResult: Bool
}

struct SpeechRecognitionError: Codable {
  let errorMsg: String
  let permanent: Bool
}

enum SpeechToTextError: Error {
  case runtimeError(String)
}

@available(iOS 10.0, macOS 10.15, *)
public class SpeechToTextPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel
  private var registrar: FlutterPluginRegistrar
  private var recognizer: SFSpeechRecognizer?
  private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
  private var currentTask: SFSpeechRecognitionTask?
  private var listeningSound: AVAudioPlayer?
  private var successSound: AVAudioPlayer?
  private var cancelSound: AVAudioPlayer?

  #if os(iOS)
    private var rememberedAudioCategory: AVAudioSession.Category?
    private var rememberedAudioCategoryOptions: AVAudioSession.CategoryOptions?
    private let audioSession = AVAudioSession.sharedInstance()
  #endif

  private var previousLocale: Locale?
  private var onPlayEnd: (() -> Void)?
  private var returnPartialResults: Bool = true
  private var failedListen: Bool = false
  private var onDeviceStatus: Bool = false
  private var listening = false
  private var stopping = false
  private var audioEngine: AVAudioEngine?
  private var inputNode: AVAudioInputNode?
  private var aggregateResults: SpeechResultAggregator = SpeechResultAggregator()
  private let jsonEncoder = JSONEncoder()
  private let busForNodeTap = 0
  private let speechBufferSize: AVAudioFrameCount = 1024
  private static var subsystem = Bundle.main.bundleIdentifier!
  private let pluginLog = OSLog(subsystem: "com.csdcorp.speechToText", category: "plugin")

  public static func register(with registrar: FlutterPluginRegistrar) {

    var channel: FlutterMethodChannel
    #if os(OSX)
      channel = FlutterMethodChannel(
        name: "plugin.csdcorp.com/speech_to_text", binaryMessenger: registrar.messenger)
    #else
      channel = FlutterMethodChannel(
        name: "plugin.csdcorp.com/speech_to_text", binaryMessenger: registrar.messenger())

    #endif

    let instance = SpeechToTextPlugin(channel, registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(_ channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case SwiftSpeechToTextMethods.has_permission.rawValue:
      hasPermission(result)
    case SwiftSpeechToTextMethods.initialize.rawValue:
      initialize(result)
    case SwiftSpeechToTextMethods.listen.rawValue:
      guard let argsArr = call.arguments as? [String: AnyObject],
        let partialResults = argsArr["partialResults"] as? Bool,
        let onDevice = argsArr["onDevice"] as? Bool,
        let listenModeIndex = argsArr["listenMode"] as? Int,
        let sampleRate = argsArr["sampleRate"] as? Int,
        let autoPunctuation = argsArr["autoPunctuation"] as? Bool,
        let enableHaptics = argsArr["enableHaptics"] as? Bool
      else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: SpeechToTextErrors.missingOrInvalidArg.rawValue,
              message:
                "Missing arg partialResults, onDevice, listenMode, autoPunctuatio, enableHaptics and sampleRate are required",
              details: nil))
        }
        return
      }
      var localeStr: String? = nil
      if let localeParam = argsArr["localeId"] as? String {
        localeStr = localeParam
      }
      guard let listenMode = ListenMode(rawValue: listenModeIndex) else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: SpeechToTextErrors.missingOrInvalidArg.rawValue,
              message: "invalid value for listenMode, must be 0-2, was \(listenModeIndex)",
              details: nil))
        }
        return
      }

      listenForSpeech(
        result, localeStr: localeStr, partialResults: partialResults, onDevice: onDevice,
        listenMode: listenMode, sampleRate: sampleRate, autoPunctuation: autoPunctuation,
        enableHaptics: enableHaptics)
    case SwiftSpeechToTextMethods.stop.rawValue:
      stopSpeech(result)
    case SwiftSpeechToTextMethods.cancel.rawValue:
      cancelSpeech(result)
    case SwiftSpeechToTextMethods.locales.rawValue:
      locales(result)
    default:
      os_log("Unrecognized method: %{PUBLIC}@", log: pluginLog, type: .error, call.method)
      DispatchQueue.main.async {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func hasPermission(_ result: @escaping FlutterResult) {
    var has =
      SFSpeechRecognizer.authorizationStatus() == SFSpeechRecognizerAuthorizationStatus.authorized
    #if os(iOS)
      has = has && self.audioSession.recordPermission == AVAudioSession.RecordPermission.granted
    #else
      has = has && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    #endif

    DispatchQueue.main.async {
      result(has)
    }
  }

  private func initialize(_ result: @escaping FlutterResult) {
    var success = false
    let status = SFSpeechRecognizer.authorizationStatus()
    switch status {
    case SFSpeechRecognizerAuthorizationStatus.notDetermined:
      SFSpeechRecognizer.requestAuthorization({ (status) -> Void in
        success = status == SFSpeechRecognizerAuthorizationStatus.authorized
        if success {

          #if os(iOS)

            self.audioSession.requestRecordPermission({ (granted: Bool) -> Void in
              if granted {
                self.setupSpeechRecognition(result)
              } else {
                self.sendBoolResult(false, result)
                os_log("User denied permission", log: self.pluginLog, type: .info)
              }
            })

          #else
            self.requestMacOSMicrophonePermission { success in
              if success {
                self.setupSpeechRecognition(result)
              } else {
                self.sendBoolResult(false, result)
                os_log("User denied permission", log: self.pluginLog, type: .info)
              }
            }
          #endif
        } else {
          self.sendBoolResult(false, result)
        }
      })
    case SFSpeechRecognizerAuthorizationStatus.denied:
      os_log("Permission permanently denied", log: self.pluginLog, type: .info)
      sendBoolResult(false, result)
    case SFSpeechRecognizerAuthorizationStatus.restricted:
      os_log("Device restriction prevented initialize", log: self.pluginLog, type: .info)
      sendBoolResult(false, result)
    default:
      os_log("Has permissions continuing with setup", log: self.pluginLog, type: .debug)
      setupSpeechRecognition(result)
    }
  }

  fileprivate func sendBoolResult(_ value: Bool, _ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      result(value)
    }
  }

  fileprivate func setupListeningSound() {
    listeningSound = loadSound("assets/sounds/speech_to_text_listening.m4r")
    successSound = loadSound("assets/sounds/speech_to_text_stop.m4r")
    cancelSound = loadSound("assets/sounds/speech_to_text_cancel.m4r")
  }

  fileprivate func loadSound(_ assetPath: String) -> AVAudioPlayer? {
    var player: AVAudioPlayer? = nil
    let soundKey = registrar.lookupKey(forAsset: assetPath)
    guard !soundKey.isEmpty else {
      return player
    }
    
    if let soundPath = Bundle.main.path(forResource: soundKey, ofType: nil) {
      let soundUrl = URL(fileURLWithPath: soundPath)
      do {
        player = try AVAudioPlayer(contentsOf: soundUrl)
        player?.delegate = self
      } catch {
        // no audio
      }
    }
    return player
  }

  private func requestMacOSMicrophonePermission(completion: @escaping (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      completion(true)

    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        if granted {
          completion(granted)
        } else {
          completion(granted)
        }
      }

    case .denied, .restricted:
      completion(false)

    @unknown default:
      completion(false)
    }
  }

  private func setupSpeechRecognition(_ result: @escaping FlutterResult) {
    setupRecognizerForLocale(locale: Locale.current)
    guard recognizer != nil else {
      sendBoolResult(false, result)
      return
    }
    if #available(iOS 13.0, *), let localRecognizer = recognizer {
      onDeviceStatus = localRecognizer.supportsOnDeviceRecognition
    }
    recognizer?.delegate = self
    setupListeningSound()

    sendBoolResult(true, result)
  }

  private func initAudioEngine(_ result: @escaping FlutterResult) -> Bool {
    audioEngine = AVAudioEngine()
    inputNode = audioEngine?.inputNode
    if inputNode == nil {
      os_log("Error no input node", log: pluginLog, type: .error)
      sendBoolResult(false, result)
    }
    return inputNode != nil
  }

  private func setupRecognizerForLocale(locale: Locale) {
    if previousLocale == locale {
      return
    }
    previousLocale = locale
    recognizer = SFSpeechRecognizer(locale: locale)
  }

  private func getLocale(_ localeStr: String?) -> Locale {
    guard let aLocaleStr = localeStr else {
      return Locale.current
    }
    let locale = Locale(identifier: aLocaleStr)
    return locale
  }

  private func stopSpeech(_ result: @escaping FlutterResult) {
    if !listening {
      sendBoolResult(false, result)
      return
    }
    stopping = true
    stopAllPlayers()
    self.currentTask?.finish()
    if let sound = successSound {
      onPlayEnd = { () -> Void in
        self.stopCurrentListen()
        self.sendBoolResult(true, result)
        return
      }
      sound.play()
    } else {
      stopCurrentListen()
      sendBoolResult(true, result)
    }
  }

  private func cancelSpeech(_ result: @escaping FlutterResult) {
    if !listening {
      sendBoolResult(false, result)
      return
    }
    stopping = true
    stopAllPlayers()
    self.currentTask?.cancel()
    if let sound = cancelSound {
      onPlayEnd = { () -> Void in
        self.stopCurrentListen()
        self.sendBoolResult(true, result)
        return
      }
      sound.play()
    } else {
      stopCurrentListen()
      sendBoolResult(true, result)
    }
  }

  private func stopAllPlayers() {
    cancelSound?.stop()
    successSound?.stop()
    listeningSound?.stop()
  }

  private func stopCurrentListen() {
    self.currentRequest?.endAudio()
    stopAllPlayers()
    do {
      try catchExceptionAsError {
        self.audioEngine?.stop()
      }
    } catch {
      os_log(
        "Error stopping engine: %{PUBLIC}@", log: pluginLog, type: .error,
        error.localizedDescription)
    }
    do {
      try catchExceptionAsError {
        self.inputNode?.removeTap(onBus: self.busForNodeTap)
      }
    } catch {
      os_log(
        "Error removing trap: %{PUBLIC}@", log: pluginLog, type: .error, error.localizedDescription)
    }
    #if os(iOS)
      do {
        if let rememberedAudioCategory = rememberedAudioCategory,
          let rememberedAudioCategoryOptions = rememberedAudioCategoryOptions
        {
          try self.audioSession.setCategory(
            rememberedAudioCategory, options: rememberedAudioCategoryOptions)
        }
      } catch {
        os_log(
          "Error stopping listen: %{PUBLIC}@", log: pluginLog, type: .error,
          error.localizedDescription)
      }
      do {
        try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      } catch {
        os_log(
          "Error deactivation: %{PUBLIC}@", log: pluginLog, type: .info, error.localizedDescription)
      }

    #endif
    self.invokeFlutter(
      SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.done.rawValue)

    currentRequest = nil
    currentTask = nil
    onPlayEnd = nil
    listening = false
    stopping = false
  }

  private func listenForSpeech(
    _ result: @escaping FlutterResult, localeStr: String?, partialResults: Bool,
    onDevice: Bool, listenMode: ListenMode, sampleRate: Int, autoPunctuation: Bool,
    enableHaptics: Bool
  ) {
    if nil != currentTask || listening {
      sendBoolResult(false, result)
      return
    }
    do {
      //    let inErrorTest = true
      failedListen = false
      stopping = false
      returnPartialResults = partialResults
      aggregateResults = SpeechResultAggregator()
      setupRecognizerForLocale(locale: getLocale(localeStr))
      guard let localRecognizer = recognizer else {
        result(
          FlutterError(
            code: SpeechToTextErrors.noRecognizerError.rawValue,
            message: "Failed to create speech recognizer",
            details: nil))
        return
      }
      if onDevice {
        if #available(iOS 13.0, *), !localRecognizer.supportsOnDeviceRecognition {
          result(
            FlutterError(
              code: SpeechToTextErrors.onDeviceError.rawValue,
              message: "on device recognition is not supported on this device",
              details: nil))
        }
      }

      #if os(iOS)
        rememberedAudioCategory = self.audioSession.category
        rememberedAudioCategoryOptions = self.audioSession.categoryOptions
        try self.audioSession.setCategory(
          AVAudioSession.Category.playAndRecord,
          options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
        //            try self.audioSession.setMode(AVAudioSession.Mode.measurement)
        if sampleRate > 0 {
          try self.audioSession.setPreferredSampleRate(Double(sampleRate))
        }
        try self.audioSession.setMode(AVAudioSession.Mode.default)
        try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        if #available(iOS 13.0, *) {
          try self.audioSession.setAllowHapticsAndSystemSoundsDuringRecording(enableHaptics)
        }
      #endif
      if let sound = listeningSound {
        self.onPlayEnd = { () -> Void in
          if !self.failedListen {
            self.listening = true
            self.invokeFlutter(
              SwiftSpeechToTextCallbackMethods.notifyStatus,
              arguments: SpeechToTextStatus.listening.rawValue)

          }
        }
        sound.play()
      }
      if !initAudioEngine(result) {
        return
      }
      if inputNode?.inputFormat(forBus: 0).channelCount == 0 {
        throw SpeechToTextError.runtimeError("Not enough available inputs.")
      }
      self.currentRequest = SFSpeechAudioBufferRecognitionRequest()
      guard let currentRequest = self.currentRequest else {
        sendBoolResult(false, result)
        return
      }
      currentRequest.shouldReportPartialResults = true
      if #available(iOS 13.0, *), onDevice {
        currentRequest.requiresOnDeviceRecognition = true
      }
      switch listenMode {
      case ListenMode.dictation:
        currentRequest.taskHint = SFSpeechRecognitionTaskHint.dictation
        break
      case ListenMode.search:
        currentRequest.taskHint = SFSpeechRecognitionTaskHint.search
        break
      case ListenMode.confirmation:
        currentRequest.taskHint = SFSpeechRecognitionTaskHint.confirmation
        break
      default:
        break
      }
      if #available(iOS 16.0, macOS 13, *) {
        currentRequest.addsPunctuation = autoPunctuation
      }
      self.currentTask = self.recognizer?.recognitionTask(with: currentRequest, delegate: self)
      let recordingFormat = inputNode?.outputFormat(forBus: self.busForNodeTap)
      var fmt: AVAudioFormat!
      #if os(iOS)

        let theSampleRate = audioSession.sampleRate

        fmt = AVAudioFormat(
          commonFormat: recordingFormat!.commonFormat, sampleRate: theSampleRate,
          channels: recordingFormat!.channelCount, interleaved: recordingFormat!.isInterleaved)

      #else
        let bus = 0
        fmt = self.inputNode?.inputFormat(forBus: bus)

      #endif
      try catchExceptionAsError {
        self.inputNode?.installTap(
          onBus: self.busForNodeTap, bufferSize: self.speechBufferSize, format: fmt
        ) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
          currentRequest.append(buffer)
          self.updateSoundLevel(buffer: buffer)
        }
      }
      //    if ( inErrorTest ){
      //        throw SpeechToTextError.runtimeError("for testing only")
      //    }
      self.audioEngine?.prepare()
      try self.audioEngine?.start()
      if nil == listeningSound {
        listening = true
        self.invokeFlutter(
          SwiftSpeechToTextCallbackMethods.notifyStatus,
          arguments: SpeechToTextStatus.listening.rawValue)
      }
      sendBoolResult(true, result)
    } catch {
      failedListen = true
      os_log(
        "Error starting listen: %{PUBLIC}@", log: pluginLog, type: .error,
        error.localizedDescription)
      self.invokeFlutter(
        SwiftSpeechToTextCallbackMethods.notifyStatus,
        arguments: SpeechToTextStatus.notListening.rawValue)
      stopCurrentListen()
      sendBoolResult(false, result)
      // ensure the not listening signal is sent in the error case
      let speechError = SpeechRecognitionError(errorMsg: "error_listen_failed", permanent: true)
      do {
        let errorResult = try jsonEncoder.encode(speechError)
        invokeFlutter(
          SwiftSpeechToTextCallbackMethods.notifyError,
          arguments: String(data: errorResult, encoding: .utf8))
        invokeFlutter(
          SwiftSpeechToTextCallbackMethods.notifyStatus,
          arguments: SpeechToTextStatus.doneNoResult.rawValue)
      } catch {
        os_log("Could not encode JSON", log: pluginLog, type: .error)
      }
    }
  }

  private func updateSoundLevel(buffer: AVAudioPCMBuffer) {
    guard
      let channelData = buffer.floatChannelData
    else {
      return
    }

    let channelDataValue = channelData.pointee
    let channelDataValueArray = stride(
      from: 0,
      to: Int(buffer.frameLength),
      by: buffer.stride
    ).map { channelDataValue[$0] }
    let frameLength = Float(buffer.frameLength)
    let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / frameLength)
    let avgPower = 20 * log10(rms)
    self.invokeFlutter(SwiftSpeechToTextCallbackMethods.soundLevelChange, arguments: avgPower)
  }

  /// Build a list of localId:name with the current locale first
  private func locales(_ result: @escaping FlutterResult) {
    var localeNames = [String]()
    let locales = SFSpeechRecognizer.supportedLocales()
    var currentLocaleId = Locale.current.identifier
    if Locale.preferredLanguages.count > 0 {
      currentLocaleId = Locale.preferredLanguages[0]
    }
    if let idName = buildIdNameForLocale(forIdentifier: currentLocaleId) {
      localeNames.append(idName)
    }
    for locale in locales {
      if locale.identifier == currentLocaleId {
        continue
      }
      if let idName = buildIdNameForLocale(forIdentifier: locale.identifier) {
        localeNames.append(idName)
      }
    }
    DispatchQueue.main.async {
      result(localeNames)
    }
  }

  private func buildIdNameForLocale(forIdentifier: String) -> String? {
    var idName: String?
    if let name = Locale.current.localizedString(forIdentifier: forIdentifier) {
      let sanitizedName = name.replacingOccurrences(of: ":", with: " ")
      idName = "\(forIdentifier):\(sanitizedName)"
    }
    return idName
  }

    private func handleResult(_ transcriptions: [SFTranscription], isFinal: Bool, maybeFinal: Bool) {
    if !isFinal && !returnPartialResults {
      return
    }
    aggregateResults = aggregateResults.addResult(transcriptions, isFinal: isFinal, maybeFinal: maybeFinal)
    let speechInfo = aggregateResults.results
    do {
      let speechMsg = try jsonEncoder.encode(speechInfo)
      if let speechStr = String(data: speechMsg, encoding: .utf8) {
        os_log("Encoded JSON result: %{PUBLIC}@", log: pluginLog, type: .debug, speechStr)
        invokeFlutter(SwiftSpeechToTextCallbackMethods.textRecognition, arguments: speechStr)
      }
    } catch {
      os_log("Could not encode JSON", log: pluginLog, type: .error)
    }
  }

  private func confidenceIn(_ transcription: SFTranscription) -> Decimal {
    guard transcription.segments.count > 0 else {
      return 0
    }
    var totalConfidence: Float = 0.0
    for segment in transcription.segments {
      totalConfidence += segment.confidence
    }
    let avgConfidence: Float = totalConfidence / Float(transcription.segments.count)
    let confidence: Float = (avgConfidence * 1000).rounded() / 1000
    return Decimal(string: String(describing: confidence))!
  }

  private func invokeFlutter(_ method: SwiftSpeechToTextCallbackMethods, arguments: Any?) {
    if method != SwiftSpeechToTextCallbackMethods.soundLevelChange {
      os_log("invokeFlutter %{PUBLIC}@", log: pluginLog, type: .debug, method.rawValue)
    }
    DispatchQueue.main.async {
      self.channel.invokeMethod(method.rawValue, arguments: arguments)
    }
  }

}

@available(iOS 10.0, macOS 10.15, *)
extension SpeechToTextPlugin: SFSpeechRecognizerDelegate {
  public func speechRecognizer(
    _ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool
  ) {
    let availability =
      available ? SpeechToTextStatus.available.rawValue : SpeechToTextStatus.unavailable.rawValue
    os_log("Availability changed: %{PUBLIC}@", log: pluginLog, type: .debug, availability)
    invokeFlutter(SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: availability)
  }
}

@available(iOS 10.0, macOS 10.15, *)
extension SpeechToTextPlugin: SFSpeechRecognitionTaskDelegate {
  public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
    // Do nothing for now
  }

  public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
    reportError(source: "FinishedReadingAudio", error: task.error)
    os_log("Finished reading audio", log: pluginLog, type: .debug)
    invokeFlutter(
      SwiftSpeechToTextCallbackMethods.notifyStatus,
      arguments: SpeechToTextStatus.notListening.rawValue)
  }

  public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
    reportError(source: "TaskWasCancelled", error: task.error)
    os_log("Canceled reading audio", log: pluginLog, type: .debug)
    invokeFlutter(
      SwiftSpeechToTextCallbackMethods.notifyStatus,
      arguments: SpeechToTextStatus.notListening.rawValue)
  }

  public func speechRecognitionTask(
    _ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool
  ) {
    reportError(source: "FinishSuccessfully", error: task.error)
    os_log("FinishSuccessfully", log: pluginLog, type: .debug)
    if !successfully {
      invokeFlutter(
        SwiftSpeechToTextCallbackMethods.notifyStatus,
        arguments: SpeechToTextStatus.doneNoResult.rawValue)
      if let err = task.error as NSError? {
        var errorMsg: String
        switch err.code {
        case 102:
          errorMsg = "error_assets_not_installed"
        case 201:
          errorMsg = "error_speech_recognizer_disabled"
        case 203:
          errorMsg = "error_retry"
        case 301:
          errorMsg = "error_request_cancelled"
        case 1100:
          errorMsg = "error_speech_recognizer_already_active"
        case 1101:
          errorMsg = "error_speech_recognizer_connection_invalidated"
        case 1107:
          errorMsg = "error_speech_recognizer_connection_interrupted"
        case 1110:
          errorMsg = "error_no_match"
        case 1700:
          errorMsg = "error_speech_recognizer_request_not_authorized"
        default:
          errorMsg = "error_unknown (\(err.code))"
        }
        let speechError = SpeechRecognitionError(errorMsg: errorMsg, permanent: true)
        do {
          let errorResult = try jsonEncoder.encode(speechError)
          invokeFlutter(
            SwiftSpeechToTextCallbackMethods.notifyError,
            arguments: String(data: errorResult, encoding: .utf8))
        } catch {
          os_log("Could not encode JSON", log: pluginLog, type: .error)
        }
      }
    }
    if !stopping {
      if let sound = successfully ? successSound : cancelSound {
        onPlayEnd = { () -> Void in
          self.stopCurrentListen()
        }
        sound.play()
      } else {
        stopCurrentListen()
      }
    }
  }

  public func speechRecognitionTask(
    _ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription
  ) {
    os_log("HypothesizeTranscription", log: pluginLog, type: .debug)
    reportError(source: "HypothesizeTranscription", error: task.error)
      handleResult([transcription], isFinal: false, maybeFinal: false)
  }

  public func speechRecognitionTask(
    _ task: SFSpeechRecognitionTask,
    didFinishRecognition recognitionResult: SFSpeechRecognitionResult
  ) {
    reportError(source: "FinishRecognition", error: task.error)
    os_log(
      "FinishRecognition %{PUBLIC}@", log: pluginLog, type: .debug,
      recognitionResult.isFinal.description)
    var pseudoFinal = false
      if #available(iOS 14.0, macOS 13.0, *) {
          pseudoFinal = recognitionResult.speechRecognitionMetadata != nil
      }
    let isFinal = recognitionResult.isFinal
      handleResult(recognitionResult.transcriptions, isFinal: isFinal, maybeFinal: pseudoFinal )
  }

  private func reportError(source: String, error: Error?) {
    if nil != error {
      os_log(
        "%{PUBLIC}@ with error: %{PUBLIC}@", log: pluginLog, type: .debug, source,
        error.debugDescription)
    }
  }
}

@available(iOS 10.0, macOS 10.15, *)
extension SpeechToTextPlugin: AVAudioPlayerDelegate {

  public func audioPlayerDidFinishPlaying(
    _ player: AVAudioPlayer,
    successfully flag: Bool
  ) {
    if let playEnd = self.onPlayEnd {
      playEnd()
    }
  }
}

private class SpeechResultAggregator {
    private var speechTranscriptions: [SFTranscription]
    private var previousTranscriptions: [[SFTranscription]]
    private let isFinal: Bool
    private let interimFinal: Bool
    
    init() {
        speechTranscriptions = []
        previousTranscriptions = []
        isFinal = false
        interimFinal = false
    }
    
    init( withTranscriptions: [SFTranscription], final: Bool, maybeFinal: Bool) {
        speechTranscriptions = []
        speechTranscriptions.append( contentsOf: withTranscriptions)
        previousTranscriptions = []
        isFinal = final
        interimFinal = maybeFinal
    }
    
    init( withTranscriptions: [SFTranscription], existingTranscriptions: [[SFTranscription]], final: Bool, maybeFinal: Bool) {
        speechTranscriptions = []
        speechTranscriptions.append( contentsOf: withTranscriptions)
        previousTranscriptions = []
        previousTranscriptions.append(contentsOf: existingTranscriptions)
        isFinal = final
        interimFinal = maybeFinal
    }
    
    /// returns a new SpeechResultAggregator.
    /// If the existing aggregator has no content then return a new aggregator with just the
    /// new content. If the existing is not empty and keepPrevious is true then append the
    /// current transcription to the previous transcriptions and then return a new aggregator
    /// with that set of transcriptions and the new content.
    public func addResult( _ newResult: [SFTranscription], isFinal: Bool, maybeFinal: Bool ) -> SpeechResultAggregator {
        if isEmpty {
            return SpeechResultAggregator(withTranscriptions: newResult, final: isFinal, maybeFinal:  interimFinal)
        }
        if !maybeFinal && interimFinal {
            previousTranscriptions.append(speechTranscriptions)
        }
        return SpeechResultAggregator(withTranscriptions: newResult, existingTranscriptions: previousTranscriptions, final: isFinal, maybeFinal: maybeFinal)
    }
    
    public var isEmpty: Bool {
        get {
            speechTranscriptions.isEmpty
        }
    }
    
    public var hasPreviousTranscriptions: Bool {
        get {
            return !previousTranscriptions.isEmpty
        }
    }
    
    /// If there are previous transcriptions then generate a new transcription and insert it as
    /// the first entry in the returned results.
    /// This behaviour was created to handle an apparent bug in the iOS speech
    /// recognition API. When the speaker pauses for a few seconds the recognition
    /// engine discards the previous transcriptions and returns a transcription
    /// with just the words after the pause. This is a change in behaviour that
    /// happened some time in iOS 17 or 18. This class tries to simulate the previous
    /// behaviour of returning the complete transcription including the words before
    /// and after the pause.
    public var results: SpeechRecognitionResult {
        var speechWords: [SpeechRecognitionWords] = []
        if hasPreviousTranscriptions {
            var lowestConfidence: Decimal = 1.0
            var aggregatePhrase = ""
            var recognizedPhrases: [String] = []
            for previousTranscription in previousTranscriptions {
                if let transcription = previousTranscription.first {
                    recognizedPhrases.append(transcription.formattedString)
                    lowestConfidence = min( lowestConfidence, confidenceIn(transcription))
                    if aggregatePhrase.count > 0 && aggregatePhrase.last != " " {
                        aggregatePhrase += " "
                    }
                    aggregatePhrase += transcription.formattedString
                }
            }
            if let transcription = speechTranscriptions.first {
                recognizedPhrases.append(transcription.formattedString)
                lowestConfidence = min( lowestConfidence, confidenceIn(transcription))
                if aggregatePhrase.count > 0 && aggregatePhrase.last != " " {
                    aggregatePhrase += " "
                }
                aggregatePhrase += transcription.formattedString
            }
            speechWords.append(SpeechRecognitionWords(recognizedWords: aggregatePhrase, recognizedPhrases: recognizedPhrases, confidence: lowestConfidence))
        }
        for transcription in speechTranscriptions {
            let words: SpeechRecognitionWords = SpeechRecognitionWords(
                recognizedWords: transcription.formattedString, recognizedPhrases: nil, confidence: confidenceIn(transcription))
            speechWords.append(words)
        }
        return SpeechRecognitionResult(alternates: speechWords, finalResult: isFinal )

    }
    
    private func confidenceIn(_ transcription: SFTranscription) -> Decimal {
      guard transcription.segments.count > 0 else {
        return 0
      }
      var totalConfidence: Float = 0.0
      for segment in transcription.segments {
        totalConfidence += segment.confidence
      }
      let avgConfidence: Float = totalConfidence / Float(transcription.segments.count)
      let confidence: Float = (avgConfidence * 1000).rounded() / 1000
      return Decimal(string: String(describing: confidence))!
    }
}
