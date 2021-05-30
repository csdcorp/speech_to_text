import 'package:flutter/services.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

/// Holds a set of responses and acts as a mock for the platform specific
/// implementations allowing test cases to determine what the result of
/// a call should be.
class TestSpeechChannelHandler {
  bool listenException = false;

  static const String listenExceptionCode = 'listenFailedError';
  static const String listenExceptionMessage = 'Failed';
  static const String listenExceptionDetails = 'Device Listen Failure';

  TestSpeechChannelHandler();

  bool? initResult = true;
  bool? listenResult = true;
  bool initInvoked = false;
  bool listenInvoked = false;
  bool cancelInvoked = false;
  bool stopInvoked = false;
  bool localesInvoked = false;
  bool? hasPermissionResult = true;
  String listeningStatusResponse = 'listening';
  String? listenLocale = 'en_US';
  List<String>? locales = [];

  bool? onDevice = false;
  bool? partialResults = false;
  bool? debugLogging;
  int? listenMode = 0;
  int? sampleRate = 0;
  dynamic initOption;
  static const String localeId1 = 'en_US';
  static const String localeId2 = 'fr_CA';
  static const String name1 = 'English US';
  static const String name2 = 'French Canada';
  static const String locale1 = '$localeId1:$name1';
  static const String locale2 = '$localeId2:$name2';
  static final SpeechConfigOption androidAlwaysUseStop =
      SpeechConfigOption('android', 'alwaysUseStop', true);
  static const String firstRecognizedWords = 'hello';
  static const String secondRecognizedWords = 'hello there';
  static const double firstConfidence = 0.85;
  static const double secondConfidence = 0.62;
  static const String firstRecognizedJson =
      '{"alternates":[{"recognizedWords":"$firstRecognizedWords","confidence":$firstConfidence}],"finalResult":false}';
  static const String secondRecognizedJson =
      '{"alternates":[{"recognizedWords":"$secondRecognizedWords","confidence":$secondConfidence}],"finalResult":false}';
  static const String finalRecognizedJson =
      '{"alternates":[{"recognizedWords":"$secondRecognizedWords","confidence":$secondConfidence}],"finalResult":true}';
  // static const SpeechRecognitionWords firstWords =
  //     SpeechRecognitionWords(firstRecognizedWords, firstConfidence);
  // static const SpeechRecognitionWords secondWords =
  //     SpeechRecognitionWords(secondRecognizedWords, secondConfidence);
  // static final SpeechRecognitionResult firstRecognizedResult =
  //     SpeechRecognitionResult([firstWords], false);
  // static final SpeechRecognitionResult secondRecognizedResult =
  //     SpeechRecognitionResult([secondWords], false);
  // static final SpeechRecognitionResult finalRecognizedResult =
  //     SpeechRecognitionResult([secondWords], true);
  static const String transientErrorJson =
      '{"errorMsg":"network","permanent":false}';
  static const String permanentErrorJson =
      '{"errorMsg":"network","permanent":true}';
  // static final SpeechRecognitionError firstError =
  //     SpeechRecognitionError('network', true);
  static const double level1 = 0.5;
  static const double level2 = 10;

  Future<dynamic> methodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'has_permission':
        return hasPermissionResult;
      case 'initialize':
        initInvoked = true;
        initOption = methodCall.arguments[androidAlwaysUseStop.name];
        debugLogging = methodCall.arguments['debugLogging'];
        return initResult;
      case 'cancel':
        cancelInvoked = true;
        return true;
      case 'stop':
        stopInvoked = true;
        return true;
      case 'listen':
        listenInvoked = true;
        if (listenException) {
          throw PlatformException(
              code: listenExceptionCode,
              message: listenExceptionMessage,
              details: listenExceptionDetails);
        }
        listenLocale = methodCall.arguments['localeId'];
        onDevice = methodCall.arguments['onDevice'];
        partialResults = methodCall.arguments['partialResults'];
        listenMode = methodCall.arguments['listenMode'];
        sampleRate = methodCall.arguments['sampleRate'];
        // await _speech.processMethodCall(MethodCall(
        //     SpeechToText.notifyStatusMethod, listeningStatusResponse));
        return listenResult;
      case 'locales':
        localesInvoked = true;
        return locales;
      default:
    }
    return initResult;
  }

  void notifyFinalWords() {
    // _speech.processMethodCall(
    //     MethodCall(SpeechToText.textRecognitionMethod, finalRecognizedJson));
  }

  void notifyPartialWords() {
    // _speech.processMethodCall(
    //     MethodCall(SpeechToText.textRecognitionMethod, firstRecognizedJson));
  }

  void notifyPermanentError() {
    // if (null != _speech) {}
    // _speech.processMethodCall(
    //     MethodCall(SpeechToText.notifyErrorMethod, permanentErrorJson));
  }

  void notifyTransientError() {
    // _speech.processMethodCall(
    //     MethodCall(SpeechToText.notifyErrorMethod, transientErrorJson));
  }

  void notifySoundLevel() {
    // _speech.processMethodCall(
    //     MethodCall(SpeechToText.soundLevelChangeMethod, level2));
  }

  void reset() {
    initResult = true;
    listenResult = true;
    initInvoked = false;
    listenInvoked = false;
    cancelInvoked = false;
    stopInvoked = false;
    localesInvoked = false;
    hasPermissionResult = true;
    listeningStatusResponse = 'listening';
    listenLocale = 'en_US';
    locales = [];

    onDevice = false;
    partialResults = false;
    listenMode = 0;
    sampleRate = 0;
    initOption = null;
    debugLogging = null;
  }

  void setupLocales() {
    locales?.clear();
    locales?.add(locale1);
    locales?.add(locale2);
  }
}
