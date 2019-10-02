import 'package:flutter/semantics.dart';
import 'package:json_annotation/json_annotation.dart';

part 'speech_recognition_result.g.dart';

@JsonSerializable()
class SpeechRecognitionResult {
  final String recognizedWords;
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
    return identical( this, other ) ||
      other is SpeechRecognitionResult && 
      recognizedWords == other.recognizedWords &&
      finalResult == other.finalResult;
  }
}
