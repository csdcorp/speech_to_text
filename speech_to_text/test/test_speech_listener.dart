import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text_provider.dart';

/// Holds the results of notification by the [SpeechToTextProvider]
class TestSpeechListener {
  final SpeechToTextProvider _speechProvider;

  bool isListening = false;
  bool isFinal = false;
  bool isAvailable = false;
  bool notified = false;
  bool hasError = false;
  SpeechRecognitionResult? recognitionResult;
  SpeechRecognitionError? lastError;
  double soundLevel = 0.0;

  TestSpeechListener(this._speechProvider);

  void reset() {
    isListening = false;
    isFinal = false;
    isAvailable = false;
    notified = false;
  }

  void onNotify() {
    notified = true;
    isAvailable = _speechProvider.isAvailable;
    isListening = _speechProvider.isListening;
    recognitionResult = _speechProvider.lastResult;
    hasError = _speechProvider.hasError;
    lastError = _speechProvider.lastError;
    soundLevel = _speechProvider.lastLevel;
  }
}
