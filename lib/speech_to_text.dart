import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Notified as words are recognized with the current set of recognized words.
typedef SpeechResultListener = void Function(SpeechRecognitionResult result);

/// An interface to device specific speech recognition services.
class SpeechToText {
  static const String textRecognitionMethod = 'textRecognition';
  static const MethodChannel _kChannel =
      const MethodChannel('plugin.csdcorp.com/speech_to_text');
  static final SpeechToText _instance =
      SpeechToText.withMethodChannel(_kChannel);
  bool _initWorked = false;
  bool _recognized = false;
  bool _listening = false;
  String _lastRecognized = "";
  SpeechResultListener _resultListener;

  final MethodChannel channel;
  factory SpeechToText() => _instance;
  @visibleForTesting
  SpeechToText.withMethodChannel(this.channel);

  bool get hasRecognized => _recognized;
  String get lastRecognizedWords => _lastRecognized;
  bool get isAvailable => _initWorked;
  bool get isListening => _listening;

  /// Initialize speech recognition services, returns true if
  /// successful, false if failed.
  ///
  /// This method must be called before any other speech functions.
  /// If this method returns false no further [SpeechToText] methods
  /// should be used.
  Future<bool> initialize() async {
    channel.setMethodCallHandler(_handleCallbacks);
    _initWorked = await channel.invokeMethod('initialize');
    return _initWorked;
  }

  /// Cancels the current listen for speech if active, does nothing if not.
  void cancel() {
    channel.invokeMethod('cancel');
    _listening = false;
  }

  /// Listen for speech and convert to text invoking the provided [interimListener]
  /// as words are recognized.
  Future listen({SpeechResultListener resultListener}) async {
    if (!_initWorked) {
      throw SpeechToTextNotInitializedException();
    }
    _recognized = false;
    _listening = true;
    _resultListener = resultListener;
    channel.invokeMethod('listen');
  }

  @visibleForTesting
  Future processMethodCall(MethodCall call) async {
    return _handleCallbacks(call);
  }

  Future _handleCallbacks(MethodCall call) async {
    print("SpeechToText call: ${call.method} ${call.arguments}");
    switch (call.method) {
      case textRecognitionMethod:
        if (call.arguments is String) {
          _onTextRecognition(call.arguments);
        }
        break;
      default:
    }
  }

  void _onTextRecognition(String resultJson) {
    _recognized = true;
    Map<String, dynamic> resultMap = jsonDecode(resultJson);
    SpeechRecognitionResult speechResult = SpeechRecognitionResult.fromJson(resultMap);

    _lastRecognized = speechResult.recognizedWords;
    if (null != _resultListener) {
      _resultListener(speechResult);
    }
  }
}

class SpeechToTextNotInitializedException implements Exception {}
