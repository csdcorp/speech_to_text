import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

void main() {
  const msg1 = 'msg1';

  setUp(() {});

  group('properties', () {
    test('equals true for same object', () {
      var error = SpeechRecognitionError(msg1, false);
      expect(error, error);
    });
    test('equals true for different object same values', () {
      var error1 = SpeechRecognitionError(msg1, false);
      var error2 = SpeechRecognitionError(msg1, false);
      expect(error1, error2);
    });
    test('equals false for different object', () {
      var error1 = SpeechRecognitionError(msg1, false);
      var error2 = SpeechRecognitionError('msg2', false);
      expect(error1, isNot(error2));
    });
    test('hash same for same object', () {
      var error = SpeechRecognitionError(msg1, false);
      expect(error.hashCode, error.hashCode);
    });
    test('hash same for different object same values', () {
      var error1 = SpeechRecognitionError(msg1, false);
      var error2 = SpeechRecognitionError(msg1, false);
      expect(error1.hashCode, error2.hashCode);
    });
    test('hash different for different object', () {
      var error1 = SpeechRecognitionError(msg1, false);
      var error2 = SpeechRecognitionError('msg2', false);
      expect(error1.hashCode, isNot(error2.hashCode));
    });
    test('toString as expected', () {
      var error1 = SpeechRecognitionError(msg1, false);
      expect(error1.toString(),
          'SpeechRecognitionError msg: $msg1, permanent: false');
    });
  });
  group('json', () {
    test('loads properly', () {
      var json = jsonDecode('{"errorMsg":"$msg1","permanent":true}');
      var error = SpeechRecognitionError.fromJson(json);
      expect(error.errorMsg, msg1);
      expect(error.permanent, isTrue);
      json = jsonDecode('{"errorMsg":"$msg1","permanent":false}');
      error = SpeechRecognitionError.fromJson(json);
      expect(error.permanent, isFalse);
    });
    test('roundtrips properly', () {
      var json = jsonDecode('{"errorMsg":"$msg1","permanent":true}');
      var error = SpeechRecognitionError.fromJson(json);
      var roundtripJson = error.toJson();
      var roundtripError = SpeechRecognitionError.fromJson(roundtripJson);
      expect(error, roundtripError);
    });
  });
}
