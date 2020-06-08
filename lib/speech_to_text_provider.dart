import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_event.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Simplifies interaction with [SpeechToText] by handling all the callbacks and notifying
/// listeners as events happen.
///
/// Here's an example of using the [SpeechToTextProvider]
/// ```
/// var speechProvider = SpeechToTextProvider( SpeechToText());
/// var available = await speechProvider.initialize();
/// StreamSubscription<SpeechRecognitionEvent> _subscription;
/// _subscription = speechProvider.recognitionController.stream.listen((recognitionEvent) {
///   if (recognitionEvent.eventType == SpeechRecognitionEventType.finalRecognitionEvent )  {
///       print("I heard: ${recognitionEvent.recognitionResult.recognizedWords}");
///     }
///   });
/// speechProvider.addListener(() {
///   var words = speechProvider.lastWords;
/// });
class SpeechToTextProvider extends ChangeNotifier {
  final StreamController<SpeechRecognitionEvent> recognitionController =
      StreamController.broadcast();
  final SpeechToText _speechToText;
  SpeechRecognitionResult _lastResult;

  /// Only construct one instance in an application.
  ///
  /// Do not call `initialize` on the [SpeechToText] that is passed as a parameter, instead
  /// call the [initialize] method on this class.
  SpeechToTextProvider(this._speechToText);

  /// Returns the last result received, may be null.
  SpeechRecognitionResult get lastResult => _lastResult;

  /// Returns the last error received, may be null.
  SpeechRecognitionError get lastError => _speechToText.lastError;

  /// Initializes the provider and the contained [SpeechToText] instance.
  ///
  /// Returns true if [SpeechToText] was initialized successful and can now
  /// be used, false otherwse.
  Future<bool> initialize() async {
    bool availableBefore = _speechToText.isAvailable;
    bool isAvailable =
        await _speechToText.initialize(onStatus: _onStatus, onError: _onError);
    if (availableBefore != isAvailable) {
      notifyListeners();
    }
    return isAvailable;
  }

  /// Returns true if the provider has been initialized and can be used to recognize speech.
  bool get isAvailable => _speechToText.isAvailable;

  /// Returns true if the provider cannot be used to recognize speech, either because it has not
  /// yet been initialized or because initialization failed.
  bool get isNotAvailable => !_speechToText.isAvailable;

  /// Returns true if [SpeechToText] is listening for new speech.
  bool get isListening => _speechToText.isListening;

  /// Returns true if [SpeechToText] is not listening for new speech.
  bool get isNotListening => _speechToText.isNotListening;

  /// Returns true if [SpeechToText] has a previous error.
  bool get hasError => _speechToText.hasError;

  /// Start listening for new events, set [partialResults] to true to receive interim
  /// recognition results.
  ///
  /// [listenFor] sets the maximum duration that it will listen for, after
  /// that it automatically stops the listen for you.
  ///
  /// [pauseFor] sets the maximum duration of a pause in speech with no words
  /// detected, after that it automatically stops the listen for you.
  ///
  /// Call this only after a successful [initialize] call
  void listen(
      {bool partialResults = false, Duration listenFor, Duration pauseFor}) {
    _speechToText.listen(
        partialResults: partialResults,
        listenFor: listenFor,
        pauseFor: pauseFor,
        cancelOnError: true,
        onResult: _onListenResult);
  }

  /// Stops a current active listening session.
  ///
  /// Call this after calling [listen] to stop the recognizer from listening further
  /// and return the current result as final.
  void stop() {
    _speechToText.stop();
    notifyListeners();
  }

  /// Cancel a current active listening session.
  ///
  /// Call this after calling [listen] to stop the recognizer from listening further
  /// and ignore any results recognized so far.
  void cancel() {
    _speechToText.cancel();
    notifyListeners();
  }

  void _onError(SpeechRecognitionError errorNotification) {
    recognitionController.add(SpeechRecognitionEvent(
        SpeechRecognitionEventType.errorEvent,
        null,
        errorNotification,
        isListening));
    notifyListeners();
  }

  void _onStatus(String status) {
    recognitionController.add(SpeechRecognitionEvent(
        SpeechRecognitionEventType.statusChangeEvent, null, null, isListening));
    notifyListeners();
  }

  void _onListenResult(SpeechRecognitionResult result) {
    _lastResult = result;
    recognitionController.add(SpeechRecognitionEvent(
        result.finalResult
            ? SpeechRecognitionEventType.finalRecognitionEvent
            : SpeechRecognitionEventType.partialRecognitionEvent,
        result,
        null,
        isListening));
    notifyListeners();
  }
}
