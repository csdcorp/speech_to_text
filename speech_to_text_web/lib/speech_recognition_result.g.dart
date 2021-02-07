// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_recognition_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebSpeechRecognitionResult _$SpeechRecognitionResultFromJson(
    Map<String, dynamic> json) {
  return WebSpeechRecognitionResult(
    (json['alternates'] as List)
        ?.map((e) => e == null
            ? null
            : WebSpeechRecognitionWords.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    json['finalResult'] as bool,
  );
}

Map<String, dynamic> _$SpeechRecognitionResultToJson(
        WebSpeechRecognitionResult instance) =>
    <String, dynamic>{
      'alternates': instance.alternates?.map((e) => e?.toJson())?.toList(),
      'finalResult': instance.finalResult,
    };

WebSpeechRecognitionWords _$SpeechRecognitionWordsFromJson(
    Map<String, dynamic> json) {
  return WebSpeechRecognitionWords(
    json['recognizedWords'] as String,
    (json['confidence'] as num)?.toDouble(),
  );
}

Map<String, dynamic> _$SpeechRecognitionWordsToJson(
        WebSpeechRecognitionWords instance) =>
    <String, dynamic>{
      'recognizedWords': instance.recognizedWords,
      'confidence': instance.confidence,
    };
