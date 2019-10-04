import 'package:json_annotation/json_annotation.dart';

part 'speech_recognition_result.g.dart';

/// A sequence of recognized words from the speech recognition
/// service.
///
/// Depending on the platform behaviour the words may come in all
/// at once at the end or as partial results as each word is
/// recognized. Use the [finalResult] flag to determine if the
/// result is considered final by the platform.
@JsonSerializable()
class SpeechRecognitionResult {
  /// The sequence of words recognized.
  final String recognizedWords;

  /// False means the words are an interim result, true means
  /// they are the final recognition.
  final bool finalResult;

  SpeechRecognitionResult(this.recognizedWords, this.finalResult);

  factory SpeechRecognitionResult.fromJson(Map<String, dynamic> json) =>
      _$SpeechRecognitionResultFromJson(json);
  Map<String, dynamic> toJson() => _$SpeechRecognitionResultToJson(this);

  @override
  String toString() {
    return "SpeechRecognitionResult words: $recognizedWords, final: $finalResult";
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SpeechRecognitionResult &&
            recognizedWords == other.recognizedWords &&
            finalResult == other.finalResult;
  }

  @override
  int get hashCode => recognizedWords.hashCode;
}
