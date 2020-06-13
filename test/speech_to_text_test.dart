import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'test_speech_channel_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestSpeechListener listener;
  TestSpeechChannelHandler speechHandler;
  SpeechToText speech;

  setUp(() {
    listener = TestSpeechListener();
    speech = SpeechToText.withMethodChannel(SpeechToText.speechChannel);
    speechHandler = TestSpeechChannelHandler(speech);
    speech.channel.setMockMethodCallHandler(speechHandler.methodCallHandler);
  });

  tearDown(() {
    speech.channel.setMockMethodCallHandler(null);
  });

  group('hasPermission', () {
    test('true if platform reports true', () async {
      expect(await speech.hasPermission, true);
    });
    test('false if platform reports false', () async {
      speechHandler.hasPermissionResult = false;
      expect(await speech.hasPermission, false);
    });
  });
  group('init', () {
    test('succeeds on platform success', () async {
      expect(await speech.initialize(), true);
      expect(speechHandler.initInvoked, true);
      expect(speech.isAvailable, true);
    });
    test('only invokes once', () async {
      expect(await speech.initialize(), true);
      speechHandler.initInvoked = false;
      expect(await speech.initialize(), true);
      expect(speechHandler.initInvoked, false);
    });
    test('fails on platform failure', () async {
      speechHandler.initResult = false;
      expect(await speech.initialize(), false);
      expect(speech.isAvailable, false);
    });
  });

  group('listen', () {
    test('fails with exception if not initialized', () async {
      try {
        await speech.listen();
        fail("Expected an exception.");
      } on SpeechToTextNotInitializedException {
        // This is a good result
      }
    });
    test('fails with exception if init fails', () async {
      try {
        speechHandler.initResult = false;
        await speech.initialize();
        await speech.listen();
        fail("Expected an exception.");
      } on SpeechToTextNotInitializedException {
        // This is a good result
      }
    });
    test('invokes listen after successful init', () async {
      await speech.initialize();
      await speech.listen();
      expect(speechHandler.listenLocale, isNull);
      expect(speechHandler.listenInvoked, true);
    });
    test('stops listen after listenFor duration', () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(listenFor: Duration(seconds: 2));
        fa.flushMicrotasks();
        expect(speech.isListening, isTrue);
        fa.elapse(Duration(seconds: 2));
        expect(speech.isListening, isFalse);
      });
    });
    test('stops listen after listenFor duration even with speech event',
        () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(listenFor: Duration(seconds: 1));
        speech.processMethodCall(MethodCall(SpeechToText.textRecognitionMethod,
            TestSpeechChannelHandler.firstRecognizedJson));
        fa.flushMicrotasks();
        expect(speech.isListening, isTrue);
        fa.elapse(Duration(seconds: 1));
        expect(speech.isListening, isFalse);
      });
    });
    test('stops listen after pauseFor duration with no speech', () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(pauseFor: Duration(seconds: 2));
        fa.flushMicrotasks();
        expect(speech.isListening, isTrue);
        fa.elapse(Duration(seconds: 2));
        expect(speech.isListening, isFalse);
      });
    });
    test('stops listen after pauseFor with longer listenFor duration',
        () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(
            pauseFor: Duration(seconds: 1), listenFor: Duration(seconds: 5));
        fa.flushMicrotasks();
        expect(speech.isListening, isTrue);
        fa.elapse(Duration(seconds: 1));
        expect(speech.isListening, isFalse);
      });
    });
    test('stops listen after listenFor with longer pauseFor duration',
        () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(
            listenFor: Duration(seconds: 1), pauseFor: Duration(seconds: 5));
        fa.flushMicrotasks();
        expect(speech.isListening, isTrue);
        fa.elapse(Duration(seconds: 1));
        expect(speech.isListening, isFalse);
      });
    });
    test('keeps listening after pauseFor with speech event', () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(pauseFor: Duration(seconds: 2));
        fa.flushMicrotasks();
        fa.elapse(Duration(seconds: 1));
        speech.processMethodCall(MethodCall(SpeechToText.textRecognitionMethod,
            TestSpeechChannelHandler.firstRecognizedJson));
        fa.flushMicrotasks();
        fa.elapse(Duration(seconds: 1));
        expect(speech.isListening, isTrue);
      });
    });
    test('uses localeId if provided', () async {
      await speech.initialize();
      await speech.listen(localeId: TestSpeechChannelHandler.localeId1);
      expect(speechHandler.listenInvoked, true);
      expect(speechHandler.listenLocale, TestSpeechChannelHandler.localeId1);
    });
    test('calls speech listener', () async {
      await speech.initialize();
      await speech.listen(onResult: listener.onSpeechResult);
      await speech.processMethodCall(MethodCall(
          SpeechToText.textRecognitionMethod,
          TestSpeechChannelHandler.firstRecognizedJson));
      expect(listener.speechResults, 1);
      expect(
          listener.results, [TestSpeechChannelHandler.firstRecognizedResult]);
      expect(speech.lastRecognizedWords,
          TestSpeechChannelHandler.firstRecognizedWords);
    });
    test('calls speech listener with multiple', () async {
      await speech.initialize();
      await speech.listen(onResult: listener.onSpeechResult);
      await speech.processMethodCall(MethodCall(
          SpeechToText.textRecognitionMethod,
          TestSpeechChannelHandler.firstRecognizedJson));
      await speech.processMethodCall(MethodCall(
          SpeechToText.textRecognitionMethod,
          TestSpeechChannelHandler.secondRecognizedJson));
      expect(listener.speechResults, 2);
      expect(listener.results, [
        TestSpeechChannelHandler.firstRecognizedResult,
        TestSpeechChannelHandler.secondRecognizedResult
      ]);
      expect(speech.lastRecognizedWords,
          TestSpeechChannelHandler.secondRecognizedWords);
    });
  });

  group('status callback', () {
    test('invoked on listen', () async {
      await speech.initialize(
          onError: listener.onSpeechError, onStatus: listener.onSpeechStatus);
      await speech.processMethodCall(MethodCall(
          SpeechToText.notifyStatusMethod, SpeechToText.listeningStatus));
      expect(listener.speechStatus, 1);
      expect(listener.statuses.contains(SpeechToText.listeningStatus), true);
    });
  });

  group('soundLevel callback', () {
    test('invoked on listen', () async {
      await speech.initialize();
      await speech.listen(onSoundLevelChange: listener.onSoundLevel);
      await speech.processMethodCall(MethodCall(
          SpeechToText.soundLevelChangeMethod,
          TestSpeechChannelHandler.level1));
      expect(listener.soundLevel, 1);
      expect(listener.soundLevels, contains(TestSpeechChannelHandler.level1));
    });
    test('sets lastLevel', () async {
      await speech.initialize();
      await speech.listen(onSoundLevelChange: listener.onSoundLevel);
      await speech.processMethodCall(MethodCall(
          SpeechToText.soundLevelChangeMethod,
          TestSpeechChannelHandler.level1));
      expect(speech.lastSoundLevel, TestSpeechChannelHandler.level1);
    });
  });

  group('cancel', () {
    test('does nothing if not initialized', () async {
      speech.cancel();
      expect(speechHandler.cancelInvoked, false);
    });
    test('cancels an active listen', () async {
      await speech.initialize();
      await speech.listen();
      await speech.cancel();
      expect(speechHandler.cancelInvoked, true);
      expect(speech.isListening, isFalse);
    });
  });
  group('stop', () {
    test('does nothing if not initialized', () async {
      speech.stop();
      expect(speechHandler.cancelInvoked, false);
    });
    test('stops an active listen', () async {
      await speech.initialize();
      speech.listen();
      speech.stop();
      expect(speechHandler.stopInvoked, true);
    });
  });
  group('error', () {
    test('notifies handler with transient', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.transientErrorJson));
      expect(listener.speechErrors, 1);
      expect(listener.errors.first.permanent, isFalse);
    });
    test('notifies handler with permanent', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.permanentErrorJson));
      expect(listener.speechErrors, 1);
      expect(listener.errors.first.permanent, isTrue);
    });
    test('continues listening on transient', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.transientErrorJson));
      expect(speech.isListening, isTrue);
    });
    test('continues listening on permanent if cancel not explicitly requested',
        () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.permanentErrorJson));
      expect(speech.isListening, isTrue);
    });
    test('stops listening on permanent if cancel explicitly requested',
        () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen(cancelOnError: true);
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.permanentErrorJson));
      expect(speech.isListening, isFalse);
    });
    test('Error not sent after cancel', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.cancel();
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.permanentErrorJson));
      expect(speech.isListening, isFalse);
      expect(listener.speechErrors, 0);
    });
    test('Error still sent after implicit cancel', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen(cancelOnError: true);
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.permanentErrorJson));
      await speech.processMethodCall(MethodCall(SpeechToText.notifyErrorMethod,
          TestSpeechChannelHandler.permanentErrorJson));
      expect(speech.isListening, isFalse);
      expect(listener.speechErrors, 2);
    });
  });
  group('locales', () {
    test('fails with exception if not initialized', () async {
      try {
        await speech.locales();
        fail("Expected an exception.");
      } on SpeechToTextNotInitializedException {
        // This is a good result
      }
    });
    test('system locale null if not initialized', () async {
      LocaleName current;
      try {
        current = await speech.systemLocale();
        fail("Expected an exception.");
      } on SpeechToTextNotInitializedException {
        expect(current, isNull);
      }
    });
    test('handles an empty list', () async {
      await speech.initialize(onError: listener.onSpeechError);
      List<LocaleName> localeNames = await speech.locales();
      expect(speechHandler.localesInvoked, isTrue);
      expect(localeNames, isEmpty);
    });
    test('returns expected locales', () async {
      await speech.initialize(onError: listener.onSpeechError);
      speechHandler.locales.add(TestSpeechChannelHandler.locale1);
      speechHandler.locales.add(TestSpeechChannelHandler.locale2);
      List<LocaleName> localeNames = await speech.locales();
      expect(localeNames, hasLength(speechHandler.locales.length));
      expect(localeNames[0].localeId, TestSpeechChannelHandler.localeId1);
      expect(localeNames[0].name, TestSpeechChannelHandler.name1);
      expect(localeNames[1].localeId, TestSpeechChannelHandler.localeId2);
      expect(localeNames[1].name, TestSpeechChannelHandler.name2);
    });
    test('skips incorrect locales', () async {
      await speech.initialize(onError: listener.onSpeechError);
      speechHandler.locales.add("InvalidJunk");
      speechHandler.locales.add(TestSpeechChannelHandler.locale1);
      List<LocaleName> localeNames = await speech.locales();
      expect(localeNames, hasLength(1));
      expect(localeNames[0].localeId, TestSpeechChannelHandler.localeId1);
      expect(localeNames[0].name, TestSpeechChannelHandler.name1);
    });
    test('system locale matches first returned locale', () async {
      await speech.initialize(onError: listener.onSpeechError);
      speechHandler.locales.add(TestSpeechChannelHandler.locale1);
      speechHandler.locales.add(TestSpeechChannelHandler.locale2);
      LocaleName current = await speech.systemLocale();
      expect(current.localeId, TestSpeechChannelHandler.localeId1);
    });
  });
  group('status', () {
    test('recognized false at start', () async {
      expect(speech.hasRecognized, isFalse);
    });
    test('listening false at start', () async {
      expect(speech.isListening, isFalse);
    });
  });
  test('available false at start', () async {
    expect(speech.isAvailable, isFalse);
  });
  test('hasError false at start', () async {
    expect(speech.hasError, isFalse);
  });
  test('lastError null at start', () async {
    expect(speech.lastError, isNull);
  });
  test('status empty at start', () async {
    expect(speech.lastStatus, isEmpty);
  });
}

class TestSpeechListener {
  int speechResults = 0;
  List<SpeechRecognitionResult> results = [];
  int speechErrors = 0;
  List<SpeechRecognitionError> errors = [];
  int speechStatus = 0;
  List<String> statuses = [];
  int soundLevel = 0;
  List<double> soundLevels = [];

  void onSpeechResult(SpeechRecognitionResult result) {
    ++speechResults;
    results.add(result);
  }

  void onSpeechError(SpeechRecognitionError errorResult) {
    ++speechErrors;
    errors.add(errorResult);
  }

  void onSpeechStatus(String status) {
    ++speechStatus;
    statuses.add(status);
  }

  void onSoundLevel(double level) {
    ++soundLevel;
    soundLevels.add(level);
  }
}
