import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool initResult;
  bool initInvoked;
  bool listenInvoked;
  bool cancelInvoked;
  bool stopInvoked;
  bool localesInvoked;
  String listeningStatusResponse;
  String listenLocale;
  TestSpeechListener listener;
  SpeechToText speech;
  List<String> locales = [];
  String localeId1 = "en_US";
  String localeId2 = "fr_CA";
  String name1 = "English US";
  String name2 = "French Canada";
  String locale1 = "$localeId1:$name1";
  String locale2 = "$localeId2:$name2";
  final String firstRecognizedWords = 'hello';
  final String secondRecognizedWords = 'hello there';
  final double firstConfidence = 0.85;
  final double secondConfidence = 0.62;
  final String firstRecognizedJson =
      '{"alternates":[{"recognizedWords":"$firstRecognizedWords","confidence":$firstConfidence}],"finalResult":false}';
  final String secondRecognizedJson =
      '{"alternates":[{"recognizedWords":"$secondRecognizedWords","confidence":$secondConfidence}],"finalResult":false}';
  final SpeechRecognitionWords firstWords =
      SpeechRecognitionWords(firstRecognizedWords, firstConfidence);
  final SpeechRecognitionWords secondWords =
      SpeechRecognitionWords(secondRecognizedWords, secondConfidence);
  final SpeechRecognitionResult firstRecognizedResult =
      SpeechRecognitionResult([firstWords], false);
  final SpeechRecognitionResult secondRecognizedResult =
      SpeechRecognitionResult([secondWords], false);
  final String transientErrorJson = '{"errorMsg":"network","permanent":false}';
  final String permanentErrorJson = '{"errorMsg":"network","permanent":true}';
  final double level1 = 0.5;
  final double level2 = 10;

  setUp(() {
    initResult = true;
    initInvoked = false;
    listenInvoked = false;
    cancelInvoked = false;
    stopInvoked = false;
    localesInvoked = false;
    listeningStatusResponse = SpeechToText.listeningStatus;
    locales = [];
    listener = TestSpeechListener();
    speech = SpeechToText.withMethodChannel(SpeechToText.speechChannel);
    speech.channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case "initialize":
          initInvoked = true;
          return initResult;
          break;
        case "cancel":
          cancelInvoked = true;
          return true;
          break;
        case "stop":
          stopInvoked = true;
          return true;
          break;
        case SpeechToText.listenMethod:
          listenInvoked = true;
          listenLocale = methodCall.arguments["localeId"];
          await speech.processMethodCall(MethodCall(
              SpeechToText.notifyStatusMethod, listeningStatusResponse));
          return initResult;
          break;
        case "locales":
          localesInvoked = true;
          return locales;
          break;
        default:
      }
      return initResult;
    });
  });

  tearDown(() {
    speech.channel.setMockMethodCallHandler(null);
  });

  group('init', () {
    test('succeeds on platform success', () async {
      expect(await speech.initialize(), true);
      expect(initInvoked, true);
      expect(speech.isAvailable, true);
    });
    test('only invokes once', () async {
      expect(await speech.initialize(), true);
      initInvoked = false;
      expect(await speech.initialize(), true);
      expect(initInvoked, false);
    });
    test('fails on platform failure', () async {
      initResult = false;
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
        initResult = false;
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
      expect(listenLocale, isNull);
      expect(listenInvoked, true);
    });
    test('uses localeId if provided', () async {
      await speech.initialize();
      await speech.listen(localeId: localeId1);
      expect(listenInvoked, true);
      expect(listenLocale, localeId1);
    });
    test('calls speech listener', () async {
      await speech.initialize();
      await speech.listen(onResult: listener.onSpeechResult);
      await speech.processMethodCall(
          MethodCall(SpeechToText.textRecognitionMethod, firstRecognizedJson));
      expect(listener.speechResults, 1);
      expect(listener.results, [firstRecognizedResult]);
      expect(speech.lastRecognizedWords, firstRecognizedWords);
    });
    test('calls speech listener with multiple', () async {
      await speech.initialize();
      await speech.listen(onResult: listener.onSpeechResult);
      await speech.processMethodCall(
          MethodCall(SpeechToText.textRecognitionMethod, firstRecognizedJson));
      await speech.processMethodCall(
          MethodCall(SpeechToText.textRecognitionMethod, secondRecognizedJson));
      expect(listener.speechResults, 2);
      expect(listener.results, [firstRecognizedResult, secondRecognizedResult]);
      expect(speech.lastRecognizedWords, secondRecognizedWords);
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
      await speech.processMethodCall(
          MethodCall(SpeechToText.soundLevelChangeMethod, level1));
      expect(listener.soundLevel, 1);
      expect(listener.soundLevels, contains(level1));
    });
    test('sets lastLevel', () async {
      await speech.initialize();
      await speech.listen(onSoundLevelChange: listener.onSoundLevel);
      await speech.processMethodCall(
          MethodCall(SpeechToText.soundLevelChangeMethod, level1));
      expect(speech.lastSoundLevel, level1);
    });
  });

  group('cancel', () {
    test('does nothing if not initialized', () async {
      speech.cancel();
      expect(cancelInvoked, false);
    });
    test('cancels an active listen', () async {
      await speech.initialize();
      await speech.listen();
      await speech.cancel();
      expect(cancelInvoked, true);
      expect(speech.isListening, isFalse);
    });
  });
  group('stop', () {
    test('does nothing if not initialized', () async {
      speech.stop();
      expect(cancelInvoked, false);
    });
    test('stops an active listen', () async {
      await speech.initialize();
      speech.listen();
      speech.stop();
      expect(stopInvoked, true);
    });
  });
  group('error', () {
    test('notifies handler with transient', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, transientErrorJson));
      expect(listener.speechErrors, 1);
      expect(listener.errors.first.permanent, isFalse);
    });
    test('notifies handler with permanent', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, permanentErrorJson));
      expect(listener.speechErrors, 1);
      expect(listener.errors.first.permanent, isTrue);
    });
    test('continues listening on transient', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, transientErrorJson));
      expect(speech.isListening, isTrue);
    });
    test('continues listening on permanent if cancel not explicitly requested',
        () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, permanentErrorJson));
      expect(speech.isListening, isTrue);
    });
    test('stops listening on permanent if cancel explicitly requested',
        () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen(cancelOnError: true);
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, permanentErrorJson));
      expect(speech.isListening, isFalse);
    });
    test('Error not sent after cancel', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen();
      await speech.cancel();
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, permanentErrorJson));
      expect(speech.isListening, isFalse);
      expect(listener.speechErrors, 0);
    });
    test('Error still sent after implicit cancel', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.listen(cancelOnError: true);
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, permanentErrorJson));
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, permanentErrorJson));
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
      expect(localesInvoked, isTrue);
      expect(localeNames, isEmpty);
    });
    test('returns expected locales', () async {
      await speech.initialize(onError: listener.onSpeechError);
      locales.add(locale1);
      locales.add(locale2);
      List<LocaleName> localeNames = await speech.locales();
      expect(localeNames, hasLength(locales.length));
      expect(localeNames[0].localeId, localeId1);
      expect(localeNames[0].name, name1);
      expect(localeNames[1].localeId, localeId2);
      expect(localeNames[1].name, name2);
    });
    test('skips incorrect locales', () async {
      await speech.initialize(onError: listener.onSpeechError);
      locales.add("InvalidJunk");
      locales.add(locale1);
      List<LocaleName> localeNames = await speech.locales();
      expect(localeNames, hasLength(1));
      expect(localeNames[0].localeId, localeId1);
      expect(localeNames[0].name, name1);
    });
    test('system locale matches first returned locale', () async {
      await speech.initialize(onError: listener.onSpeechError);
      locales.add(locale1);
      locales.add(locale2);
      LocaleName current = await speech.systemLocale();
      expect(current.localeId, localeId1);
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
