import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_to_text_provider.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'test_speech_channel_handler.dart';
import 'test_speech_listener.dart';
import 'test_speech_to_text_platform.dart';

void main() {
  late SpeechToTextProvider provider;
  late SpeechToText speechToText;
  late TestSpeechToTextPlatform testPlatform;
  late TestSpeechListener speechListener;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    testPlatform = TestSpeechToTextPlatform();
    SpeechToTextPlatform.instance = testPlatform;
    speechToText = SpeechToText.withMethodChannel();
    provider = SpeechToTextProvider(speechToText);
    speechListener = TestSpeechListener(provider);
    provider.addListener(speechListener.onNotify);
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
    test('hasError matches delegate after error', () async {
      expect(await provider.initialize(), isTrue);
      expect(provider.hasError, speechToText.hasError);
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
        testPlatform.notifyListening();
        expect(speechListener.notified, isTrue);
        expect(speechListener.isListening, isTrue);
        expect(provider.hasResults, isFalse);
      });
    });
    test('notifies on final words', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener);
        speechListener.reset();
        testPlatform.notifyFinalWords();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        expect(provider.hasResults, isTrue);
        var result = speechListener.recognitionResult;
        expect(result?.recognizedWords,
            TestSpeechChannelHandler.secondRecognizedWords);
        expect(result?.finalResult, isTrue);
      });
    });
    test('hasResult false after listening before new results', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener);
        testPlatform.notifyFinalWords();
        provider.stop();
        setupForListen(provider, fa, speechListener);
        fa.flushMicrotasks();
        expect(provider.hasResults, isFalse);
      });
    });
    test('notifies on partial words', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener, partialResults: true);
        speechListener.reset();
        testPlatform.notifyPartialWords();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        expect(provider.hasResults, isTrue);
        var result = speechListener.recognitionResult;
        expect(result?.recognizedWords,
            TestSpeechChannelHandler.firstRecognizedWords);
        expect(result?.finalResult, isFalse);
      });
    });
  });
  group('soundLevel', () {
    test('notifies when requested', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener,
            partialResults: true, soundLevel: true);
        testPlatform.notifyListening();
        speechListener.reset();
        testPlatform.notifySoundLevel();
        fa.flushMicrotasks();
        expect(speechListener.notified, isTrue);
        expect(speechListener.soundLevel, TestSpeechChannelHandler.level2);
      });
    });
    test('no notification by default', () async {
      fakeAsync((fa) {
        setupForListen(provider, fa, speechListener,
            partialResults: true, soundLevel: false);
        speechListener.reset();
        testPlatform.notifySoundLevel();
        fa.flushMicrotasks();
        expect(speechListener.notified, isFalse);
        expect(speechListener.soundLevel, 0);
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
    test('hasError matches delegate default', () async {
      expect(await provider.initialize(), isTrue);
      expect(provider.hasError, speechToText.hasError);
    });
    test('notifies on error', () async {
      fakeAsync((fa) {
        provider.initialize();
        setupForListen(provider, fa, speechListener);
        speechListener.reset();
        testPlatform.notifyPermanentError();
        expect(speechListener.notified, isTrue);
        expect(speechListener.hasError, isTrue);
      });
    });
  });
  group('locale', () {
    test('locales empty before init', () async {
      expect(provider.systemLocale, isNull);
      expect(provider.locales, isEmpty);
    });
    test('set from SpeechToText after init', () async {
      fakeAsync((fa) {
        testPlatform.setupLocales();
        provider.initialize();
        fa.flushMicrotasks();
        expect(provider.systemLocale?.localeId,
            TestSpeechChannelHandler.localeId1);
        expect(provider.locales, hasLength(testPlatform.localesResult.length));
      });
    });
  });
}

void setupForListen(SpeechToTextProvider provider, FakeAsync fa,
    TestSpeechListener speechListener,
    {bool partialResults = false, bool soundLevel = false}) {
  provider.initialize();
  fa.flushMicrotasks();
  speechListener.reset();
  provider.listen(partialResults: partialResults, soundLevel: soundLevel);
  fa.flushMicrotasks();
}
