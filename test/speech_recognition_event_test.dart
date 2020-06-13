import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_event.dart';

import 'test_speech_channel_handler.dart';

void main() {
  group('properties', () {
    test('status listening matches', () {
      var event = SpeechRecognitionEvent(
          SpeechRecognitionEventType.statusChangeEvent, null, null, true, null);
      expect(event.eventType, SpeechRecognitionEventType.statusChangeEvent);
      expect(event.isListening, isTrue);
    });
    test('result matches', () {
      var event = SpeechRecognitionEvent(
          SpeechRecognitionEventType.finalRecognitionEvent,
          TestSpeechChannelHandler.firstRecognizedResult,
          null,
          null,
          null);
      expect(event.eventType, SpeechRecognitionEventType.finalRecognitionEvent);
      expect(event.recognitionResult,
          TestSpeechChannelHandler.firstRecognizedResult);
    });
    test('error matches', () {
      var event = SpeechRecognitionEvent(SpeechRecognitionEventType.errorEvent,
          null, TestSpeechChannelHandler.firstError, null, null);
      expect(event.eventType, SpeechRecognitionEventType.errorEvent);
      expect(event.error, TestSpeechChannelHandler.firstError);
    });
    test('sound level matches', () {
      var event = SpeechRecognitionEvent(
          SpeechRecognitionEventType.soundLevelChangeEvent,
          null,
          null,
          null,
          TestSpeechChannelHandler.level1);
      expect(event.eventType, SpeechRecognitionEventType.soundLevelChangeEvent);
      expect(event.level, TestSpeechChannelHandler.level1);
    });
  });
}
