import 'package:fake_async/fake_async.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'test_speech_channel_handler.dart';
import 'test_speech_to_text_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestSpeechToTextPlatform testPlatform;
  late TestSpeechListener listener;
  late SpeechToText speech;

  setUp(() {
    listener = TestSpeechListener();
    testPlatform = TestSpeechToTextPlatform();
    SpeechToTextPlatform.instance = testPlatform;
    speech = SpeechToText.withMethodChannel();
  });

  group('hasPermission', () {
    test('true if platform reports true', () async {
      expect(await speech.hasPermission, true);
    });
    test('false if platform reports false', () async {
      testPlatform.hasPermissionResult = false;
      expect(await speech.hasPermission, false);
    });
  });
  group('init', () {
    test('succeeds on platform success', () async {
      expect(await speech.initialize(), true);
      expect(speech.isAvailable, true);
    });
    test('only invokes once', () async {
      expect(await speech.initialize(), true);
      expect(await speech.initialize(), true);
    });
    test('fails on platform failure', () async {
      testPlatform.initResult = false;
      expect(await speech.initialize(), false);
      expect(speech.isAvailable, false);
    });
  });

  group('listen', () {
    test('fails with exception if not initialized', () async {
      try {
        await speech.listen();
        fail('Expected an exception.');
      } on SpeechToTextNotInitializedException {
        // This is a good result
      }
    });
    test('fails with exception if init fails', () async {
      try {
        testPlatform.initResult = false;
        await speech.initialize();
        await speech.listen();
        fail('Expected an exception.');
      } on SpeechToTextNotInitializedException {
        // This is a good result
      }
    });
    test('invokes listen after successful init', () async {
      await speech.initialize();
      await speech.listen();
      expect(testPlatform.listenLocale, isNull);
      expect(testPlatform.listenInvoked, true);
    });
    test('converts platformException to listenFailed', () async {
      await speech.initialize();
      testPlatform.listenException = true;
      try {
        await speech.listen();
        fail('Should have thrown');
      } on ListenFailedException catch (e) {
        expect(e.details, TestSpeechToTextPlatform.listenExceptionDetails);
      } catch (wrongE) {
        fail('Should have been ListenFailedException');
      }
    });
    test('stops listen after listenFor duration', () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(listenFor: Duration(seconds: 2));
        testPlatform.onStatus!(SpeechToText.listeningStatus);
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
        testPlatform.onStatus!(SpeechToText.listeningStatus);
        testPlatform
            .onTextRecognition!(TestSpeechChannelHandler.firstRecognizedJson);
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
        testPlatform.onStatus!(SpeechToText.listeningStatus);
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
        testPlatform.onStatus!(SpeechToText.listeningStatus);
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
        testPlatform.onStatus!(SpeechToText.listeningStatus);
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
        testPlatform.onStatus!(SpeechToText.listeningStatus);
        fa.flushMicrotasks();
        fa.elapse(Duration(seconds: 1));
        testPlatform
            .onTextRecognition!(TestSpeechChannelHandler.firstRecognizedJson);
        fa.flushMicrotasks();
        fa.elapse(Duration(seconds: 1));
        expect(speech.isListening, isTrue);
      });
    });
    test('creates finalResult true if none provided', () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(
            pauseFor: Duration(seconds: 2), onResult: listener.onSpeechResult);
        fa.flushMicrotasks();
        testPlatform
            .onTextRecognition!(TestSpeechChannelHandler.firstRecognizedJson);
        fa.flushMicrotasks();
        // 2200 because it is the 2 second duration of the pauseFor then
        // 200 milliseconds to create the synthetic result
        fa.elapse(Duration(milliseconds: 2200));
        expect(listener.results.last.finalResult, isTrue);
      });
    });
    test('returns only one finalResult true if provided', () async {
      fakeAsync((fa) {
        speech.initialize();
        fa.flushMicrotasks();
        speech.listen(
            pauseFor: Duration(seconds: 2), onResult: listener.onSpeechResult);
        fa.flushMicrotasks();
        testPlatform
            .onTextRecognition!(TestSpeechChannelHandler.finalRecognizedJson);
        fa.flushMicrotasks();
        // 2200 because it is the 2 second duration of the pauseFor then
        // 200 milliseconds to create the synthetic result
        fa.elapse(Duration(milliseconds: 2200));
        expect(listener.results.last.finalResult, isTrue);
        expect(listener.results, hasLength(1));
      });
    });
    test('uses localeId if provided', () async {
      await speech.initialize();
      await speech.listen(localeId: TestSpeechChannelHandler.localeId1);
      expect(testPlatform.listenInvoked, true);
      expect(testPlatform.listenLocale, TestSpeechChannelHandler.localeId1);
    });
    test('calls speech listener', () async {
      await speech.initialize();
      await speech.listen(onResult: listener.onSpeechResult);
      testPlatform
          .onTextRecognition!(TestSpeechChannelHandler.firstRecognizedJson);
      expect(listener.speechResults, 1);
      expect(
          listener.results, [TestSpeechChannelHandler.firstRecognizedResult]);
      expect(speech.lastRecognizedWords,
          TestSpeechChannelHandler.firstRecognizedWords);
    });
    test('calls speech listener with multiple', () async {
      await speech.initialize();
      await speech.listen(onResult: listener.onSpeechResult);
      testPlatform
          .onTextRecognition!(TestSpeechChannelHandler.firstRecognizedJson);
      testPlatform
          .onTextRecognition!(TestSpeechChannelHandler.secondRecognizedJson);
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
      testPlatform.onStatus!(SpeechToText.listeningStatus);
      expect(listener.speechStatus, 1);
      expect(listener.statuses.contains(SpeechToText.listeningStatus), true);
    });
  });

  group('soundLevel callback', () {
    test('invoked on listen', () async {
      await speech.initialize();
      await speech.listen(onSoundLevelChange: listener.onSoundLevel);
      testPlatform.onStatus!(SpeechToText.listeningStatus);
      testPlatform.onSoundLevel!(TestSpeechToTextPlatform.level1);
      expect(listener.soundLevel, 1);
      expect(listener.soundLevels, contains(TestSpeechChannelHandler.level1));
    });
    test('sets lastLevel', () async {
      await speech.initialize();
      await speech.listen(onSoundLevelChange: listener.onSoundLevel);
      testPlatform.onStatus!(SpeechToText.listeningStatus);
      testPlatform.onSoundLevel!(TestSpeechToTextPlatform.level1);
      expect(speech.lastSoundLevel, TestSpeechChannelHandler.level1);
    });
  });

  group('cancel', () {
    test('does nothing if not initialized', () async {
      await speech.cancel();
      expect(testPlatform.cancelInvoked, false);
    });
    test('cancels an active listen', () async {
      await speech.initialize();
      await speech.listen();
      await speech.cancel();
      expect(testPlatform.cancelInvoked, true);
      expect(speech.isListening, isFalse);
    });
  });
  group('stop', () {
    test('does nothing if not initialized', () async {
      await speech.stop();
      expect(testPlatform.stopInvoked, false);
    });
    test('stops an active listen', () async {
      await speech.initialize();
      await speech.listen();
      await speech.stop();
      expect(testPlatform.stopInvoked, true);
    });
  });

  group('error', () {
    test('notifies handler with transient', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      testPlatform.onError!(TestSpeechChannelHandler.transientErrorJson);
      expect(listener.speechErrors, 1);
      expect(listener.errors.first.permanent, isFalse);
    });
    test('notifies handler with permanent', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      testPlatform.onError!(TestSpeechChannelHandler.permanentErrorJson);
      expect(listener.speechErrors, 1);
      expect(listener.errors.first.permanent, isTrue);
    });
    test('continues listening on transient', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      testPlatform.onStatus!(SpeechToText.listeningStatus);
      testPlatform.onError!(TestSpeechChannelHandler.transientErrorJson);
      expect(speech.isListening, isTrue);
    });
    test('continues listening on permanent if cancel not explicitly requested',
        () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      testPlatform.onStatus!(SpeechToText.listeningStatus);
      testPlatform.onError!(TestSpeechChannelHandler.permanentErrorJson);
      expect(speech.isListening, isTrue);
    });
    test('stops listening on permanent if cancel explicitly requested',
        () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen(cancelOnError: true);
      testPlatform.onStatus!(SpeechToText.listeningStatus);
      testPlatform.onError!(TestSpeechChannelHandler.permanentErrorJson);
      expect(speech.isListening, isFalse);
    });
    test('Error not sent after cancel', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.cancel();
      testPlatform.onError!(TestSpeechChannelHandler.permanentErrorJson);
      expect(speech.isListening, isFalse);
      expect(listener.speechErrors, 0);
    });
    test('Error still sent after implicit cancel', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen(cancelOnError: true);
      testPlatform.onError!(TestSpeechChannelHandler.permanentErrorJson);
      testPlatform.onError!(TestSpeechChannelHandler.permanentErrorJson);
      expect(speech.isListening, isFalse);
      expect(listener.speechErrors, 2);
    });
  });

  group('locales', () {
    test('fails with exception if not initialized', () async {
      try {
        await speech.locales();
        fail('Expected an exception.');
      } on SpeechToTextNotInitializedException {
        // This is a good result
      }
    });
    test('system locale null if not initialized', () async {
      LocaleName? current;
      try {
        current = await speech.systemLocale();
        fail('Expected an exception.');
      } on SpeechToTextNotInitializedException {
        expect(current, isNull);
      }
    });
    test('handles an empty list', () async {
      await speech.initialize();
      var localeNames = await speech.locales();
      expect(testPlatform.localesInvoked, true);
      expect(localeNames, isEmpty);
    });
    test('returns expected locales', () async {
      await speech.initialize();
      testPlatform.localesResult.addAll(
          [TestSpeechChannelHandler.locale1, TestSpeechChannelHandler.locale2]);
      var localeNames = await speech.locales();
      expect(localeNames, hasLength(2));
      expect(localeNames[0].localeId, TestSpeechChannelHandler.localeId1);
      expect(localeNames[0].name, TestSpeechChannelHandler.name1);
      expect(localeNames[1].localeId, TestSpeechChannelHandler.localeId2);
      expect(localeNames[1].name, TestSpeechChannelHandler.name2);
    });
    test('skips incorrect locales', () async {
      await speech.initialize();
      testPlatform.localesResult.addAll([
        'InvalidJunk',
        TestSpeechChannelHandler.locale1,
      ]);
      var localeNames = await speech.locales();
      expect(localeNames, hasLength(1));
      expect(localeNames[0].localeId, TestSpeechChannelHandler.localeId1);
      expect(localeNames[0].name, TestSpeechChannelHandler.name1);
    });
    test('system locale matches first returned locale', () async {
      await speech.initialize();
      testPlatform.localesResult.addAll(
          [TestSpeechChannelHandler.locale1, TestSpeechChannelHandler.locale2]);
      var current = await speech.systemLocale();
      expect(current?.localeId, TestSpeechChannelHandler.localeId1);
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

class MockSpeechToText extends Mock
    with MockPlatformInterfaceMixin
    implements SpeechToTextPlatform {}
