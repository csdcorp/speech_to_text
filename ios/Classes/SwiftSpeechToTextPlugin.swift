import Flutter
import UIKit
import Speech

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
}

public enum SpeechToTextStatus: String {
    case listening
    case notListening
    case unavailable
    case available
}

public enum SpeechToTextErrors: String {
    case missingOrInvalidArg
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
    private var returnPartialResults: Bool = true
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()
    private let jsonEncoder = JSONEncoder()
    private let busForNodeTap = 0
    private let speechBufferSize: AVAudioFrameCount = 1024
    
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
                let partialResults = argsArr["partialResults"] as? Bool
                else {
                    result(FlutterError( code: SpeechToTextErrors.missingOrInvalidArg.rawValue,
                                         message:"Missing arg partialResults",
                                         details: nil ))
                    return
            }
            var localeStr: String? = nil
            if let localeParam = argsArr["localeId"] as? String {
                localeStr = localeParam
            }
            listenForSpeech( result, localeStr: localeStr, partialResults: partialResults )
        case SwiftSpeechToTextMethods.stop.rawValue:
            stopSpeech( result )
        case SwiftSpeechToTextMethods.cancel.rawValue:
            cancelSpeech( result )
        case SwiftSpeechToTextMethods.locales.rawValue:
            locales( result )
        default:
            print("Unrecognized method: \(call.method)")
            result( FlutterMethodNotImplemented)
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
        if ( SFSpeechRecognizer.authorizationStatus() == SFSpeechRecognizerAuthorizationStatus.notDetermined ) {
            SFSpeechRecognizer.requestAuthorization({(status)->Void in
                success = status == SFSpeechRecognizerAuthorizationStatus.authorized
                if ( success ) {
                    AVAudioSession.sharedInstance().requestRecordPermission({(granted: Bool)-> Void in
                       if granted {
                           self.setupSpeechRecognition(result)
                       } else{
                           self.initResult( false, result );
                       }
                    })
                }
                else {
                    self.initResult( false, result );
                }
            });
        }
        else {
            setupSpeechRecognition(result)
        }
    }
    
    fileprivate func initResult( _ value: Bool, _ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            result( value )
        }
    }
    
    fileprivate func setupListeningSound() {
        listeningSound = loadSound("assets/sounds/speech_to_text_listening.m4r")
        successSound = loadSound("assets/sounds/speech_to_text_stop.m4r")
        cancelSound = loadSound("assets/sounds/speech_to_text_cancel.m4r")
    }
    
    fileprivate func loadSound( _ soundPath: String ) -> AVAudioPlayer? {
        var player: AVAudioPlayer? = nil
        let soundKey = registrar.lookupKey(forAsset: soundPath )
        guard !soundKey.isEmpty else {
            return player
        }
        if let soundPath = Bundle.main.path(forResource: soundKey, ofType:nil) {
            let soundUrl = URL(fileURLWithPath: soundPath )
            do {
                player = try AVAudioPlayer(contentsOf: soundUrl )
            } catch {
                // no audio
            }
        }
        return player
    }
    
    private func setupSpeechRecognition( _ result: @escaping FlutterResult) {
        setupRecognizerForLocale( locale: Locale.current )
        guard recognizer != nil else {
            initResult( false, result );
            return
        }
        recognizer?.delegate = self
        setupListeningSound()

        initResult( true, result );
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
        currentTask?.finish()
        stopCurrentListen( )
        successSound?.play()
        result( true )
    }
    
    private func cancelSpeech( _ result: @escaping FlutterResult) {
        currentTask?.cancel()
        stopCurrentListen( )
        cancelSound?.play()
        result( true )
    }
    
    private func stopCurrentListen( ) {
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
        }
        currentRequest = nil
        currentTask = nil
    }
    
    private func listenForSpeech( _ result: @escaping FlutterResult, localeStr: String?, partialResults: Bool ) {
        if ( nil != currentTask ) {
            return
        }
        do {
            returnPartialResults = partialResults
            setupRecognizerForLocale(locale: getLocale(localeStr))
            listeningSound?.play()
            rememberedAudioCategory = self.audioSession.category
            try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord)
            try self.audioSession.setMode(AVAudioSession.Mode.measurement)
            try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = self.audioEngine.inputNode
            self.currentRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let currentRequest = self.currentRequest else {
                result( false )
                return
            }
            currentRequest.shouldReportPartialResults = true
            self.currentTask = self.recognizer?.recognitionTask(with: currentRequest, delegate: self )
            let recordingFormat = inputNode.outputFormat(forBus: self.busForNodeTap)
            inputNode.installTap(onBus: self.busForNodeTap, bufferSize: self.speechBufferSize, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                currentRequest.append(buffer)
            }
            
            self.audioEngine.prepare()
            try self.audioEngine.start()
            self.invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.listening.rawValue )
        }
        catch {
            result( false )
        }
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
        result(localeNames)
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
            print("Could not encode JSON")
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
        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: availability )
    }
}

@available(iOS 10.0, *)
extension SwiftSpeechToTextPlugin : SFSpeechRecognitionTaskDelegate {
    public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        // Do nothing for now
    }
    
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.notListening.rawValue )
    }
    
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.notListening.rawValue )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        stopCurrentListen( )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        handleResult( [transcription], isFinal: false )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        let isFinal = recognitionResult.isFinal
        handleResult( recognitionResult.transcriptions, isFinal: isFinal )
    }
    
}

@available(iOS 10.0, *)
extension SwiftSpeechToTextPlugin : AVAudioPlayerDelegate {
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                     successfully flag: Bool) {
        
    }
}
