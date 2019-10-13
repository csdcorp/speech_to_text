import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  bool initResult;
  bool initInvoked;
  bool listenInvoked;
  bool cancelInvoked;
  TestSpeechListener listener;
  SpeechToText speech;
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
          return initResult;
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
      expect(listenInvoked, true);
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
