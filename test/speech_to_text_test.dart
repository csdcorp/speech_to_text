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
  bool localesInvoked;
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
  final String listeningStatus = "listening";
  final String firstRecognizedWords = 'hello';
  final String secondRecognizedWords = 'hello there';
  final String firstRecognizedJson =
      '{"recognizedWords":"$firstRecognizedWords","finalResult":false}';
  final String secondRecognizedJson =
      '{"recognizedWords":"$secondRecognizedWords","finalResult":false}';
  final SpeechRecognitionResult firstRecognizedResult =
      SpeechRecognitionResult(firstRecognizedWords, false);
  final SpeechRecognitionResult secondRecognizedResult =
      SpeechRecognitionResult(secondRecognizedWords, false);
  final String transientErrorJson = '{"errorMsg":"network","permanent":false}';

  setUp(() {
    initResult = true;
    initInvoked = false;
    listenInvoked = false;
    cancelInvoked = false;
    localesInvoked = false;
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
        case "listen":
          listenInvoked = true;
          listenLocale = methodCall.arguments;
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
    });
    test('fails on platform failure', () async {
      initResult = false;
      expect(await speech.initialize(), false);
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
      speech.listen();
      expect(listenLocale, isNull);
      expect(listenInvoked, true);
    });
    test('uses localeId if provided', () async {
      await speech.initialize();
      speech.listen(localeId: localeId1);
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
    });
  });

  group('status callback', () {
    test('invoked on listen', () async {
      await speech.initialize(
          onError: listener.onSpeechError, onStatus: listener.onSpeechStatus);
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyStatusMethod, listeningStatus));
      expect(listener.speechStatus, 1);
      expect(listener.statuses.contains(listeningStatus), true);
    });
  });

  group('cancel', () {
    test('does nothing if not initialized', () async {
      speech.cancel();
      expect(cancelInvoked, false);
    });
    test('cancels an active listen', () async {
      await speech.initialize();
      speech.listen();
      speech.cancel();
      expect(cancelInvoked, true);
    });
  });
  group('error', () {
    test('notifies handler with transient', () async {
      await speech.initialize(onError: listener.onSpeechError);
      await speech.processMethodCall(
          MethodCall(SpeechToText.notifyErrorMethod, transientErrorJson));
      expect(listener.speechErrors, 1);
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
    test('handles an empty list', () async {
      await speech.initialize(onError: listener.onSpeechError);
      List<LocaleName> localeNames = await speech.locales();
      expect( localesInvoked, isTrue );
      expect(localeNames, isEmpty);
    });
    test('returns expected locales', () async {
      await speech.initialize(onError: listener.onSpeechError);
      locales.add( locale1);
      locales.add( locale2);
      List<LocaleName> localeNames = await speech.locales();
      expect(localeNames, hasLength(locales.length));
      expect( localeNames[0].localeId, localeId1 );
      expect( localeNames[0].name, name1 );
      expect( localeNames[1].localeId, localeId2 );
      expect( localeNames[1].name, name2 );
    });
    test('skips incorrect locales', () async {
      await speech.initialize(onError: listener.onSpeechError);
      locales.add( "InvalidJunk");
      locales.add( locale1);
      List<LocaleName> localeNames = await speech.locales();
      expect(localeNames, hasLength(1));
      expect( localeNames[0].localeId, localeId1 );
      expect( localeNames[0].name, name1 );
    });
  });
}

class TestSpeechListener {
  int speechResults = 0;
  List<SpeechRecognitionResult> results = [];
  int speechErrors = 0;
  List<SpeechRecognitionError> errors = [];
  int speechStatus = 0;
  List<String> statuses = [];

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
}
