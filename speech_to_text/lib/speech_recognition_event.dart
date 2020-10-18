import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum SpeechRecognitionEventType {
  finalRecognitionEvent,
  partialRecognitionEvent,
  errorEvent,
  statusChangeEvent,
  soundLevelChangeEvent,
}

/// A single event in a stream of speech recognition events.
///
/// Use [eventType] to determine what type of event it is and depending on that
/// use the other properties to get information about it.
class SpeechRecognitionEvent {
  final SpeechRecognitionEventType eventType;
  final SpeechRecognitionError _error;
  final SpeechRecognitionResult _result;
  final bool _listening;
  final double _level;

  SpeechRecognitionEvent(
      this.eventType, this._result, this._error, this._listening, this._level);

  bool get isListening => _listening;
  double get level => _level;
  SpeechRecognitionResult get recognitionResult => _result;
  SpeechRecognitionError get error => _error;
}
