// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_recognition_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpeechRecognitionResult _$SpeechRecognitionResultFromJson(
    Map<String, dynamic> json) {
  return SpeechRecognitionResult(
    json['recognizedWords'] as String,
    json['finalResult'] as bool,
  );
}

Map<String, dynamic> _$SpeechRecognitionResultToJson(
        SpeechRecognitionResult instance) =>
    <String, dynamic>{
      'recognizedWords': instance.recognizedWords,
      'finalResult': instance.finalResult,
    };
