import Flutter
import UIKit
import Speech

public enum SwiftSpeechToTextMethods: String {
    case initialize
    case listen
    case stop
    case cancel
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

struct SpeechRecognitionResult : Codable {
    let recognizedWords: String
    let finalResult: Bool
}

@available(iOS 10.0, *)
public class SwiftSpeechToTextPlugin: NSObject, FlutterPlugin, SFSpeechRecognizerDelegate, SFSpeechRecognitionTaskDelegate {
    private var channel: FlutterMethodChannel
    private var registrar: FlutterPluginRegistrar
    private var recognizer: SFSpeechRecognizer?
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var currentTask: SFSpeechRecognitionTask?
    private var listeningSound: AVAudioPlayer?
    private var successSound: AVAudioPlayer?
    private var cancelSound: AVAudioPlayer?
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
        case SwiftSpeechToTextMethods.initialize.rawValue:
            initialize( result )
        case SwiftSpeechToTextMethods.listen.rawValue:
            listenForSpeech( result )
        case SwiftSpeechToTextMethods.stop.rawValue:
            stopSpeech( result )
        case SwiftSpeechToTextMethods.cancel.rawValue:
            cancelSpeech( result )
        default:
            print("Unrecognized method: \(call.method)")
            result( FlutterMethodNotImplemented)
        }
    }
    
    private func initialize( _ result: @escaping FlutterResult) {
        var success = false
        if ( SFSpeechRecognizer.authorizationStatus() == SFSpeechRecognizerAuthorizationStatus.notDetermined ) {
            SFSpeechRecognizer.requestAuthorization({(status)->Void in
                success = status == SFSpeechRecognizerAuthorizationStatus.authorized
                if ( success ) {
                    self.setupSpeechRecognition(result)
                }
                else {
                    result( false )
                }
            });
        }
        else {
            setupSpeechRecognition(result)
        }
    }
    
    fileprivate func setupListeningSound() {
        listeningSound = loadSound("assets/sounds/speech_to_text_listening.m4r")
        successSound = loadSound("assets/sounds/speech_to_text_success.m4r")
        cancelSound = loadSound("assets/sounds/speech_to_text_stopped.m4r")
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
        recognizer = SFSpeechRecognizer()
        guard recognizer != nil else {
            result( false )
            return
        }
        recognizer?.delegate = self
        setupListeningSound()

        result( true )
    }
    
    private func stopSpeech( _ result: @escaping FlutterResult) {
        successSound?.play()
        currentTask?.finish()
        stopCurrentListen( )
        result( true )
    }
    
    private func cancelSpeech( _ result: @escaping FlutterResult) {
        cancelSound?.play()
        currentTask?.cancel()
        stopCurrentListen( )
        result( true )
    }
    
    private func stopCurrentListen( ) {
        currentRequest?.endAudio()
        audioEngine.stop()
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: busForNodeTap);
        currentRequest = nil
        currentTask = nil
    }
    
    private func listenForSpeech( _ result: @escaping FlutterResult) {
        if ( nil != currentTask ) {
            return
        }
        do {
            try self.audioSession.setCategory(AVAudioSessionCategoryRecord)
            try self.audioSession.setMode(AVAudioSessionModeMeasurement)
            try self.audioSession.setActive(true, with: .notifyOthersOnDeactivation)
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
            listeningSound?.play()
        }
        catch {
            result( false )
        }
    }
    
    private func handleResult( _ recognizedWords: String, isFinal: Bool ) {
        let speechInfo = SpeechRecognitionResult(recognizedWords: recognizedWords, finalResult: isFinal )
        do {
            let speechMsg = try jsonEncoder.encode(speechInfo)
            invokeFlutter( SwiftSpeechToTextCallbackMethods.textRecognition, arguments: String( data:speechMsg, encoding: .utf8) )
        } catch {
            print("Could not encode JSON")
        }
    }
    
    private func invokeFlutter( _ method: SwiftSpeechToTextCallbackMethods, arguments: Any? ) {
        channel.invokeMethod( method.rawValue, arguments: arguments )
    }
    
    private func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        let availability = available ? SpeechToTextStatus.available : SpeechToTextStatus.unavailable
        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: availability )
    }
    
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
        handleResult( transcription.formattedString, isFinal: false )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        let isFinal = recognitionResult.isFinal
        handleResult( recognitionResult.bestTranscription.formattedString, isFinal: isFinal )
    }
}
