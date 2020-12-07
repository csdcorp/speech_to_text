import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

void main() {
  final firstRecognizedWords = 'hello';
  final secondRecognizedWords = 'hello there';
  final firstConfidence = 0.85;
  final secondConfidence = 0.62;
  final firstRecognizedJson =
      '{"recognizedWords":"$firstRecognizedWords","confidence":$firstConfidence}';
  final firstWords =
      SpeechRecognitionWords(firstRecognizedWords, firstConfidence);
  final secondWords =
      SpeechRecognitionWords(secondRecognizedWords, secondConfidence);

  setUp(() {});

  group('properties', () {
    test('words', () {
      expect(firstWords.recognizedWords, firstRecognizedWords);
      expect(secondWords.recognizedWords, secondRecognizedWords);
    });
    test('confidence', () {
      expect(firstWords.confidence, firstConfidence);
      expect(secondWords.confidence, secondConfidence);
      expect(firstWords.hasConfidenceRating, isTrue);
    });
    test('equals true for same object', () {
      expect(firstWords, firstWords);
    });
    test('equals true for different object with same values', () {
      var firstWordsA =
          SpeechRecognitionWords(firstRecognizedWords, firstConfidence);
      expect(firstWords, firstWordsA);
    });
    test('equals false for different results', () {
      expect(firstWords, isNot(secondWords));
    });
    test('hash same for same object', () {
      expect(firstWords.hashCode, firstWords.hashCode);
    });
    test('hash same for different object with same values', () {
      var firstWordsA =
          SpeechRecognitionWords(firstRecognizedWords, firstConfidence);
      expect(firstWords.hashCode, firstWordsA.hashCode);
    });
    test('hash different for different results', () {
      expect(firstWords.hashCode, isNot(secondWords.hashCode));
    });
  });
  group('isConfident', () {
    test('true when >= 0.8', () {
      expect(firstWords.isConfident(), isTrue);
    });
    test('false when < 0.8', () {
      expect(secondWords.isConfident(), isFalse);
    });
    test('respects threshold', () {
      expect(secondWords.isConfident(threshold: 0.5), isTrue);
    });
    test('true when missing', () {
      var words = SpeechRecognitionWords(
          firstRecognizedWords, SpeechRecognitionWords.missingConfidence);
      expect(words.isConfident(), isTrue);
      expect(words.hasConfidenceRating, isFalse);
    });
  });
  group('json', () {
    test('loads correctly', () {
      var json = jsonDecode(firstRecognizedJson);
      var words = SpeechRecognitionWords.fromJson(json);
      expect(words.recognizedWords, firstRecognizedWords);
      expect(words.confidence, firstConfidence);
    });
    test('roundtrips correctly', () {
      var json = jsonDecode(firstRecognizedJson);
      var words = SpeechRecognitionWords.fromJson(json);
      var roundTripJson = words.toJson();
      var roundtripWords = SpeechRecognitionWords.fromJson(roundTripJson);
      expect(words, roundtripWords);
    });
  });
}
