import Flutter
import UIKit
import Speech

public enum SwiftSpeechToTextMethods: String {
    case initialize
    case listen
    case cancel
    case unknown // just for testing
}

public enum SwiftSpeechToTextCallbackMethods: String {
    case textRecognition
}

struct SpeechRecognitionResult : Codable {
    let recognizedWords: String
    let finalResult: Bool
}

@available(iOS 10.0, *)
public class SwiftSpeechToTextPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var recognizer: SFSpeechRecognizer?
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var currentTask: SFSpeechRecognitionTask?
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()
    private let encoder = JSONEncoder()
    private let busForNodeTap = 0
    private let speechBufferSize: AVAudioFrameCount = 1024

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "plugin.csdcorp.com/speech_to_text", binaryMessenger: registrar.messenger())
        let instance = SwiftSpeechToTextPlugin( channel )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init( _ channel: FlutterMethodChannel) {
        self.channel = channel
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case SwiftSpeechToTextMethods.initialize.rawValue:
            initialize( result )
        case SwiftSpeechToTextMethods.listen.rawValue:
            do {
                try listenForSpeech( result )
            }
            catch {
                result( false )
            }
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
    
    private func setupSpeechRecognition( _ result: @escaping FlutterResult) {
        recognizer = SFSpeechRecognizer()
        guard recognizer != nil else {
            result( false )
            return
        }
        result( true )
    }
    
    private func cancelSpeech( _ result: @escaping FlutterResult) {
        stopCurrentListen()
        result( true )
    }
    
    private func stopCurrentListen() {
        currentRequest?.endAudio()
        currentTask?.cancel()
        audioEngine.stop()
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: busForNodeTap);
        currentRequest = nil
        currentTask = nil
    }
    
    private func listenForSpeech( _ result: @escaping FlutterResult) throws {
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        currentRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let currentRequest = currentRequest else {
            result( false )
            return
        }
        currentRequest.shouldReportPartialResults = true
        recognizer?.recognitionTask(with: currentRequest, resultHandler: {( speechResult, error ) -> Void in
            var isFinal = false;
            if let speechResult = speechResult {
                isFinal = speechResult.isFinal
                let speechInfo = SpeechRecognitionResult(recognizedWords: speechResult.bestTranscription.formattedString, finalResult: isFinal )
                do {
                    let speechMsg = try self.encoder.encode(speechInfo)
                    self.handleResult( String( data:speechMsg, encoding: .utf8)! )
                } catch {
                    print("Could not encode JSON")
                }
            }
            if ( nil != error || isFinal ) {
                self.stopCurrentListen()
            }
        })
        let recordingFormat = inputNode.outputFormat(forBus: busForNodeTap)
        inputNode.installTap(onBus: busForNodeTap, bufferSize: speechBufferSize, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.currentRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

    }
    
    private func handleResult( _ recognizedWords: String ) {
        channel?.invokeMethod(SwiftSpeechToTextCallbackMethods.textRecognition.rawValue, arguments: recognizedWords )
    }
}
