import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum SpeechRecognitionEventType {
  /// The final transcription of speech for a recognition session. This is
  /// the only recognition event when not receiving partial results and
  /// the last when receiving partial results.
  finalRecognitionEvent,

  /// Sent every time the recognizer recognizes some speech on the input if
  /// partial events were requested.
  partialRecognitionEvent,

  /// Sent when there is an error from the platform speech recognizer.
  errorEvent,

  /// Sent when listening starts after a call to listen and when it ends
  /// after a timeout, cancel or stop call. Use the isListening property
  /// of the event to determine whether this is the start or end of a
  /// listening session.
  statusChangeEvent,

  /// Sent when listening is complete and all speech recognition results have
  /// been sent.
  doneEvent,

  /// Sent whenever the sound level on the input changes during a listen
  /// session.
  soundLevelChangeEvent,
}

/// A single event in a stream of speech recognition events.
///
/// Use [eventType] to determine what type of event it is and depending on that
/// use the other properties to get information about it.
class SpeechRecognitionEvent {
  final SpeechRecognitionEventType eventType;
  final SpeechRecognitionError? _error;
  final SpeechRecognitionResult? _result;
  final bool? _listening;
  final double? _level;

  SpeechRecognitionEvent(
      this.eventType, this._result, this._error, this._listening, this._level);

  /// true when there is still an active listening session, false when the
  /// listening session has ended.
  bool? get isListening => _listening;

  /// the sound level seen on the input.
  double? get level => _level;

  /// The words recognized by the speech recognizer during a listen session.
  SpeechRecognitionResult? get recognitionResult => _result;

  /// The error received from the speech recognizer.
  SpeechRecognitionError? get error => _error;
}
