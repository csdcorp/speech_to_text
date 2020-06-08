import Flutter
import UIKit
import Speech
import os.log

public enum SwiftSpeechToTextMethods: String {
    case has_permission
    case initialize
    case listen
    case stop
    case cancel
    case locales
    case unknown // just for testing
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
}

public enum SpeechToTextErrors: String {
    case onDeviceError
    case noRecognizerError
    case missingOrInvalidArg
}

public enum ListenMode: Int {
    case deviceDefault = 0
    case dictation = 1
    case search = 2
    case confirmation = 3
}

struct SpeechRecognitionWords : Codable {
    let recognizedWords: String
    let confidence: Decimal
}

struct SpeechRecognitionResult : Codable {
    let alternates: [SpeechRecognitionWords]
    let finalResult: Bool
}

@available(iOS 10.0, *)
public class SwiftSpeechToTextPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel
    private var registrar: FlutterPluginRegistrar
    private var recognizer: SFSpeechRecognizer?
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var currentTask: SFSpeechRecognitionTask?
    private var listeningSound: AVAudioPlayer?
    private var successSound: AVAudioPlayer?
    private var cancelSound: AVAudioPlayer?
    private var rememberedAudioCategory: AVAudioSession.Category?
    private var previousLocale: Locale?
    private var onPlayEnd: (() -> Void)?
    private var returnPartialResults: Bool = true
    private var listening = false
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()
    private let jsonEncoder = JSONEncoder()
    private let busForNodeTap = 0
    private let speechBufferSize: AVAudioFrameCount = 1024
    private static var subsystem = Bundle.main.bundleIdentifier!
    private let pluginLog = OSLog(subsystem: "com.csdcorp.speechToText", category: "plugin")

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "plugin.csdcorp.com/speech_to_text", binaryMessenger: registrar.messenger())
        let instance = SwiftSpeechToTextPlugin( channel, registrar: registrar )
        registrar.addMethodCallDelegate(instance, channel: channel )
    }
    
    init( _ channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar ) {
        self.channel = channel
        self.registrar = registrar
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case SwiftSpeechToTextMethods.has_permission.rawValue:
            hasPermission( result )
        case SwiftSpeechToTextMethods.initialize.rawValue:
            initialize( result )
        case SwiftSpeechToTextMethods.listen.rawValue:
            guard let argsArr = call.arguments as? Dictionary<String,AnyObject>,
                let partialResults = argsArr["partialResults"] as? Bool, let onDevice = argsArr["onDevice"] as? Bool, let listenModeIndex = argsArr["listenMode"] as? Int
                else {
                    DispatchQueue.main.async {
                    result(FlutterError( code: SpeechToTextErrors.missingOrInvalidArg.rawValue,
                                         message:"Missing arg partialResults, onDevice, and listenMode are required",
                                         details: nil ))
                    }
                    return
            }
            var localeStr: String? = nil
            if let localeParam = argsArr["localeId"] as? String {
                localeStr = localeParam
            }
            guard let listenMode = ListenMode(rawValue: listenModeIndex) else {
                DispatchQueue.main.async {
                result(FlutterError( code: SpeechToTextErrors.missingOrInvalidArg.rawValue,
                                     message:"invalid value for listenMode, must be 0-2, was \(listenModeIndex)",
                                     details: nil ))
                }
                return
            }
            listenForSpeech( result, localeStr: localeStr, partialResults: partialResults, onDevice: onDevice, listenMode: listenMode )
        case SwiftSpeechToTextMethods.stop.rawValue:
            stopSpeech( result )
        case SwiftSpeechToTextMethods.cancel.rawValue:
            cancelSpeech( result )
        case SwiftSpeechToTextMethods.locales.rawValue:
            locales( result )
        default:
            os_log("Unrecognized method: %{PUBLIC}@", log: pluginLog, type: .error, call.method)
            DispatchQueue.main.async {
            result( FlutterMethodNotImplemented)
            }
        }
    }
    
    private func hasPermission( _ result: @escaping FlutterResult) {
        let has = SFSpeechRecognizer.authorizationStatus() == SFSpeechRecognizerAuthorizationStatus.authorized &&
            AVAudioSession.sharedInstance().recordPermission == AVAudioSession.RecordPermission.granted
        DispatchQueue.main.async {
            result( has )
        }
    }
    
    private func initialize( _ result: @escaping FlutterResult) {
        var success = false
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case SFSpeechRecognizerAuthorizationStatus.notDetermined:
            SFSpeechRecognizer.requestAuthorization({(status)->Void in
                success = status == SFSpeechRecognizerAuthorizationStatus.authorized
                if ( success ) {
                    AVAudioSession.sharedInstance().requestRecordPermission({(granted: Bool)-> Void in
                       if granted {
                           self.setupSpeechRecognition(result)
                       } else{
                           self.sendBoolResult( false, result );
                        os_log("User denied permission", log: self.pluginLog, type: .info)
                       }
                    })
                }
                else {
                    self.sendBoolResult( false, result );
                }
            });
        case SFSpeechRecognizerAuthorizationStatus.denied:
            os_log("Permission permanently denied", log: self.pluginLog, type: .info)
            sendBoolResult( false, result );
        case SFSpeechRecognizerAuthorizationStatus.restricted:
            os_log("Device restriction prevented initialize", log: self.pluginLog, type: .info)
            sendBoolResult( false, result );
        default:
            os_log("Has permissions continuing with setup", log: self.pluginLog, type: .debug)
            setupSpeechRecognition(result)
        }
    }
    
    fileprivate func sendBoolResult( _ value: Bool, _ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            result( value )
        }
    }
    
    fileprivate func setupListeningSound() {
        listeningSound = loadSound("assets/sounds/speech_to_text_listening.m4r")
        successSound = loadSound("assets/sounds/speech_to_text_stop.m4r")
        cancelSound = loadSound("assets/sounds/speech_to_text_cancel.m4r")
    }
    
    fileprivate func loadSound( _ assetPath: String ) -> AVAudioPlayer? {
        var player: AVAudioPlayer? = nil
        let soundKey = registrar.lookupKey(forAsset: assetPath )
        guard !soundKey.isEmpty else {
            return player
        }
        if let soundPath = Bundle.main.path(forResource: soundKey, ofType:nil) {
            let soundUrl = URL(fileURLWithPath: soundPath )
            do {
                player = try AVAudioPlayer(contentsOf: soundUrl )
                player?.delegate = self
            } catch {
                // no audio
            }
        }
        return player
    }
    
    private func setupSpeechRecognition( _ result: @escaping FlutterResult) {
        setupRecognizerForLocale( locale: Locale.current )
        guard recognizer != nil else {
            sendBoolResult( false, result );
            return
        }
        recognizer?.delegate = self
        setupListeningSound()

        sendBoolResult( true, result );
    }

    private func setupRecognizerForLocale( locale: Locale ) {
        if ( previousLocale == locale ) {
            return
        }
        previousLocale = locale
        recognizer = SFSpeechRecognizer( locale: locale )
    }
    
    private func getLocale( _ localeStr: String? ) -> Locale {
        guard let aLocaleStr = localeStr else {
            return Locale.current
        }
        let locale = Locale(identifier: aLocaleStr)
        return locale
    }
    
    private func stopSpeech( _ result: @escaping FlutterResult) {
        if ( !listening ) {
            sendBoolResult( false, result );
            return
        }
        stopAllPlayers()
        if let sound = successSound {
            onPlayEnd = {() -> Void in
                self.currentTask?.finish()
                self.stopCurrentListen( )
                self.sendBoolResult( true, result )
                return
            }
            sound.play()
        }
        else {
            stopCurrentListen( )
            sendBoolResult( true, result );
        }
    }
    
    private func cancelSpeech( _ result: @escaping FlutterResult) {
        if ( !listening ) {
            sendBoolResult( false, result );
            return
        }
        stopAllPlayers()
        if let sound = cancelSound {
            onPlayEnd = {() -> Void in
                self.currentTask?.cancel()
                self.stopCurrentListen( )
                self.sendBoolResult( true, result )
                return
            }
            sound.play()
        }
        else {
            self.currentTask?.cancel()
            stopCurrentListen( )
            sendBoolResult( true, result );
        }
    }
    
    private func stopAllPlayers() {
        cancelSound?.stop()
        successSound?.stop()
        listeningSound?.stop()
    }
    
    private func stopCurrentListen( ) {
        stopAllPlayers()
        currentRequest?.endAudio()
        
        audioEngine.stop()
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: busForNodeTap);
        do {
            if let rememberedAudioCategory = rememberedAudioCategory {
                try self.audioSession.setCategory(rememberedAudioCategory)
            }
        }
        catch {
            os_log("Error stopping listen: %{PUBLIC}@", log: pluginLog, type: .error, error.localizedDescription)
        }
        do {
            try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
        catch {
            os_log("Error deactivation: %{PUBLIC}@", log: pluginLog, type: .info, error.localizedDescription)
        }
        currentRequest = nil
        currentTask = nil
        onPlayEnd = nil
        listening = false
    }
    
    private func listenForSpeech( _ result: @escaping FlutterResult, localeStr: String?, partialResults: Bool, onDevice: Bool, listenMode: ListenMode ) {
        if ( nil != currentTask || listening ) {
            sendBoolResult( false, result );
            return
        }
        do {
            returnPartialResults = partialResults
            setupRecognizerForLocale(locale: getLocale(localeStr))
            guard let localRecognizer = recognizer else {
                result(FlutterError( code: SpeechToTextErrors.noRecognizerError.rawValue,
                                     message:"Failed to create speech recognizer",
                                     details: nil ))
                return
            }
            if ( onDevice ) {
                if #available(iOS 13.0, *), !localRecognizer.supportsOnDeviceRecognition {
                    result(FlutterError( code: SpeechToTextErrors.onDeviceError.rawValue,
                                         message:"on device recognition is not supported on this device",
                                         details: nil ))
                }
            }
            rememberedAudioCategory = self.audioSession.category
            try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord, options: .defaultToSpeaker)
//            try self.audioSession.setMode(AVAudioSession.Mode.measurement)
            try self.audioSession.setMode(AVAudioSession.Mode.default)
            try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            if let sound = listeningSound {
                self.onPlayEnd = {()->Void in
                    self.listening = true
                    self.invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.listening.rawValue )
                }
                sound.play()
            }
            let inputNode = self.audioEngine.inputNode
            self.currentRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let currentRequest = self.currentRequest else {
                sendBoolResult( false, result );
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
            self.currentTask = self.recognizer?.recognitionTask(with: currentRequest, delegate: self )
            let recordingFormat = inputNode.outputFormat(forBus: self.busForNodeTap)
            inputNode.installTap(onBus: self.busForNodeTap, bufferSize: self.speechBufferSize, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                currentRequest.append(buffer)
                self.updateSoundLevel( buffer: buffer )
            }

            self.audioEngine.prepare()
            try self.audioEngine.start()
            if nil == listeningSound {
                listening = true
                self.invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.listening.rawValue )
            }
        }
        catch {
            os_log("Error starting listen: %{PUBLIC}@", log: pluginLog, type: .error, error.localizedDescription)
            sendBoolResult( false, result );
        }
    }
    
    private func updateSoundLevel( buffer: AVAudioPCMBuffer) {
        guard
          let channelData = buffer.floatChannelData
          else {
            return
        }

        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride).map{ channelDataValue[$0] }
        let frameLength = Float(buffer.frameLength)
        let rms = sqrt(channelDataValueArray.map{ $0 * $0 }.reduce(0, +) / frameLength )
        let avgPower = 20 * log10(rms)
        self.invokeFlutter( SwiftSpeechToTextCallbackMethods.soundLevelChange, arguments: avgPower )
    }
    
    /// Build a list of localId:name with the current locale first
    private func locales( _ result: @escaping FlutterResult ) {
        var localeNames = [String]();
        let locales = SFSpeechRecognizer.supportedLocales();
        let currentLocale = Locale.current
        if let idName = buildIdNameForLocale(forIdentifier: currentLocale.identifier ) {
            localeNames.append(idName)
        }
        for locale in locales {
            if ( locale.identifier == currentLocale.identifier) {
                continue
            }
            if let idName = buildIdNameForLocale(forIdentifier: locale.identifier ) {
                localeNames.append(idName)
            }
        }
        DispatchQueue.main.async {
        result(localeNames)
        }
    }
    
    private func buildIdNameForLocale( forIdentifier: String ) -> String? {
        var idName: String?
        if let name = Locale.current.localizedString(forIdentifier: forIdentifier ) {
            let sanitizedName = name.replacingOccurrences(of: ":", with: " ")
            idName = "\(forIdentifier):\(sanitizedName)"
        }
        return idName
    }
    
    private func handleResult( _ transcriptions: [SFTranscription], isFinal: Bool ) {
        if ( !isFinal && !returnPartialResults ) {
            return
        }
        var speechWords: [SpeechRecognitionWords] = []
        for transcription in transcriptions {
            let words: SpeechRecognitionWords = SpeechRecognitionWords(recognizedWords: transcription.formattedString, confidence: confidenceIn( transcription))
            speechWords.append( words )
        }
        let speechInfo = SpeechRecognitionResult(alternates: speechWords, finalResult: isFinal )
        do {
            let speechMsg = try jsonEncoder.encode(speechInfo)
            invokeFlutter( SwiftSpeechToTextCallbackMethods.textRecognition, arguments: String( data:speechMsg, encoding: .utf8) )
        } catch {
            os_log("Could not encode JSON", log: pluginLog, type: .error)
        }
    }
    
    private func confidenceIn( _ transcription: SFTranscription ) -> Decimal {
        guard ( transcription.segments.count > 0 ) else {
            return 0;
        }
        var totalConfidence: Float = 0.0;
        for segment in transcription.segments {
            totalConfidence += segment.confidence
        }
        let avgConfidence: Float = totalConfidence / Float(transcription.segments.count )
        let confidence: Float = (avgConfidence * 1000).rounded() / 1000
        return Decimal( string: String( describing: confidence ) )!
    }
    
    private func invokeFlutter( _ method: SwiftSpeechToTextCallbackMethods, arguments: Any? ) {
        DispatchQueue.main.async {
            self.channel.invokeMethod( method.rawValue, arguments: arguments )
        }
    }
        
}

@available(iOS 10.0, *)
extension SwiftSpeechToTextPlugin : SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        let availability = available ? SpeechToTextStatus.available.rawValue : SpeechToTextStatus.unavailable.rawValue
        os_log("Availability changed: %{PUBLIC}@", log: pluginLog, type: .debug, availability)
        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: availability )
    }
}

@available(iOS 10.0, *)
extension SwiftSpeechToTextPlugin : SFSpeechRecognitionTaskDelegate {
    public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        // Do nothing for now
    }
    
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        reportError(source: "FinishedReadingAudio", error: task.error)
        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.notListening.rawValue )
    }
    
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        reportError(source: "TaskWasCancelled", error: task.error)
        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.notListening.rawValue )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        reportError(source: "FinishSuccessfully", error: task.error)
        stopCurrentListen( )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        reportError(source: "HypothesizeTranscription", error: task.error)
        handleResult( [transcription], isFinal: false )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        reportError(source: "FinishRecognition", error: task.error)
        let isFinal = recognitionResult.isFinal
        handleResult( recognitionResult.transcriptions, isFinal: isFinal )
    }
    
    private func reportError( source: String, error: Error?) {
        if ( nil != error) {
            os_log("%{PUBLIC}@ with error: %{PUBLIC}@", log: pluginLog, type: .debug, source, error.debugDescription)
        }
    }
}

@available(iOS 10.0, *)
extension SwiftSpeechToTextPlugin : AVAudioPlayerDelegate {
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                     successfully flag: Bool) {
        if let playEnd = self.onPlayEnd {
            playEnd()
        }
    }
}
