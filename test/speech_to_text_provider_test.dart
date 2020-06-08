import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_to_text_provider.dart';

import 'test_speech_channel_handler.dart';
import 'test_speech_listener.dart';

void main() {
  SpeechToTextProvider provider;
  SpeechToText speechToText;
  TestSpeechChannelHandler speechHandler;
  TestSpeechListener speechListener;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    speechToText = SpeechToText.withMethodChannel(SpeechToText.speechChannel);
    speechHandler = TestSpeechChannelHandler(speechToText);
    speechToText.channel
        .setMockMethodCallHandler(speechHandler.methodCallHandler);
    provider = SpeechToTextProvider(speechToText);
    speechListener = TestSpeechListener(provider);
    provider.addListener(speechListener.onNotify);
  });

  tearDown(() {
    print("tearing down channel");
    speechToText.channel.setMockMethodCallHandler(null);
  });

  group('delegates', () {
    test('isListening matches delegate defaults', () {
      expect(provider.isListening, speechToText.isListening);
      expect(provider.isNotListening, speechToText.isNotListening);
    });
    test('isAvailable matches delegate defaults', () {
      expect(provider.isAvailable, speechToText.isAvailable);
      expect(provider.isNotAvailable, !speechToText.isAvailable);
    });
    test('isAvailable matches delegate after init', () async {
      expect(await provider.initialize(), isTrue);
      expect(provider.isAvailable, speechToText.isAvailable);
      expect(provider.isNotAvailable, !speechToText.isAvailable);
    });
  });
  group('listening', () {
    test('notifies on initialize', () async {
      fakeAsync((fa) {
        provider.initialize();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        expect(speechListener.isAvailable, isTrue);
      });
    });
    test('notifies on listening', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener);
        expect(speechListener.notified, isTrue);
        expect(speechListener.isListening, isTrue);
      });
    });
    test('notifies on final words', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener);
        speechListener.reset();
        speechHandler.notifyFinalWords();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        var result = speechListener.recognitionResult;
        expect(result.recognizedWords,
            TestSpeechChannelHandler.secondRecognizedWords);
        expect(result.finalResult, isTrue);
      });
    });
    test('notifies on partial words', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener, partialResults: true);
        speechListener.reset();
        speechHandler.notifyPartialWords();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        var result = speechListener.recognitionResult;
        expect(result.recognizedWords,
            TestSpeechChannelHandler.firstRecognizedWords);
        expect(result.finalResult, isFalse);
      });
    });
  });
  group('stop/cancel', () {
    test('notifies on stop', () async {
      fakeAsync((fa) {
        provider.initialize();
        setupForListen(provider, fa, speechListener);
        speechListener.reset();
        provider.stop();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        expect(speechListener.isListening, isFalse);
      });
    });
    test('notifies on cancel', () async {
      fakeAsync((fa) {
        provider.initialize();
        setupForListen(provider, fa, speechListener);
        speechListener.reset();
        provider.cancel();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        expect(speechListener.isListening, isFalse);
      });
    });
  });
  group('error handling', () {
    test('notifies on error', () async {
      fakeAsync((fa) {
        provider.initialize();
        setupForListen(provider, fa, speechListener);
        speechListener.reset();
        speechHandler.notifyPermanentError();
        expect(speechListener.notified, isTrue);
        expect(speechListener.hasError, isTrue);
      });
    });
  });
}

void setupForListen(SpeechToTextProvider provider, FakeAsync fa,
    TestSpeechListener speechListener,
    {bool partialResults = false}) {
  provider.initialize();
  fa.flushMicrotasks();
  speechListener.reset();
  provider.listen(partialResults: partialResults);
  fa.flushMicrotasks();
}
