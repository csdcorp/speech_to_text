import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

void main() {
  final firstRecognizedWords = 'hello';
  final secondRecognizedWords = 'hello there';
  final firstConfidence = 0.85;
  final secondConfidence = 0.62;
  final firstRecognizedJson =
      '{"alternates":[{"recognizedWords":"$firstRecognizedWords","confidence":$firstConfidence}],"finalResult":false}';
  final firstWords =
      SpeechRecognitionWords(firstRecognizedWords, firstConfidence);
  final secondWords =
      SpeechRecognitionWords(secondRecognizedWords, secondConfidence);

  setUp(() {});

  group('recognizedWords', () {
    test('empty if no alternates', () {
      var result = SpeechRecognitionResult([], true);
      expect(result.recognizedWords, isEmpty);
    });
    test('matches first alternate', () {
      var result = SpeechRecognitionResult([firstWords, secondWords], true);
      expect(result.recognizedWords, firstRecognizedWords);
    });
  });
  group('alternates', () {
    test('empty if no alternates', () {
      var result = SpeechRecognitionResult([], true);
      expect(result.alternates, isEmpty);
    });
    test('expected contents', () {
      var result = SpeechRecognitionResult([firstWords, secondWords], true);
      expect(result.alternates, contains(firstWords));
      expect(result.alternates, contains(secondWords));
    });
    test('in order', () {
      var result = SpeechRecognitionResult([firstWords, secondWords], true);
      expect(result.alternates.first, firstWords);
    });
  });
  group('confidence', () {
    test('0 if no alternates', () {
      var result = SpeechRecognitionResult([], true);
      expect(result.confidence, 0);
    });
    test('isConfident false if no alternates', () {
      var result = SpeechRecognitionResult([], true);
      expect(result.isConfident(), isFalse);
    });
    test('isConfident matches first alternate', () {
      var result = SpeechRecognitionResult([firstWords, secondWords], true);
      expect(result.isConfident(), firstWords.isConfident());
    });
    test('hasConfidenceRating false if no alternates', () {
      var result = SpeechRecognitionResult([], true);
      expect(result.hasConfidenceRating, isFalse);
    });
    test('hasConfidenceRating matches first alternate', () {
      var result = SpeechRecognitionResult([firstWords, secondWords], true);
      expect(result.hasConfidenceRating, firstWords.hasConfidenceRating);
    });
  });
  group('json', () {
    test('loads correctly', () {
      var json = jsonDecode(firstRecognizedJson);
      var result = SpeechRecognitionResult.fromJson(json);
      expect(result.recognizedWords, firstRecognizedWords);
      expect(result.confidence, firstConfidence);
    });
    test('roundtrips correctly', () {
      var json = jsonDecode(firstRecognizedJson);
      var result = SpeechRecognitionResult.fromJson(json);
      var roundTripJson = result.toJson();
      var roundtripResult = SpeechRecognitionResult.fromJson(roundTripJson);
      expect(result, roundtripResult);
    });
  });
  group('overrides', () {
    test('toString works with no alternates', () {
      var result = SpeechRecognitionResult([], true);
      expect(
          result.toString(), 'SpeechRecognitionResult words: [], final: true');
    });
    test('toString works with alternates', () {
      var result = SpeechRecognitionResult([firstWords], true);
      expect(result.toString(),
          'SpeechRecognitionResult words: [SpeechRecognitionWords words: hello,  confidence: 0.85], final: true');
    });
    test('hash same for same object', () {
      var result = SpeechRecognitionResult([firstWords], true);
      expect(result.hashCode, result.hashCode);
    });
    test('hash differs for different objects', () {
      var result1 = SpeechRecognitionResult([firstWords], true);
      var result2 = SpeechRecognitionResult([secondWords], true);
      expect(result1.hashCode, isNot(result2.hashCode));
    });
    test('equals same for same object', () {
      var result = SpeechRecognitionResult([firstWords], true);
      expect(result, result);
    });
    test('equals same for different object same values', () {
      var result1 = SpeechRecognitionResult([firstWords], true);
      var result1a = SpeechRecognitionResult([firstWords], true);
      expect(result1, result1a);
    });
    test('equals differs for different objects', () {
      var result1 = SpeechRecognitionResult([firstWords], true);
      var result2 = SpeechRecognitionResult([secondWords], true);
      expect(result1, isNot(result2));
    });
  });
}
