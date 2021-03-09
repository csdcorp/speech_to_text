import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

class TestSpeechToTextPlatform extends SpeechToTextPlatform {
  static const String listenExceptionCode = 'listenFailedError';
  static const String listenExceptionMessage = 'Failed';
  static const String listenExceptionDetails = 'Device Listen Failure';

  bool initResult = true;
  bool initInvoked = false;
  bool listenInvoked = false;
  bool cancelInvoked = false;
  bool stopInvoked = false;
  bool localesInvoked = false;
  bool hasPermissionResult = true;
  bool listenException = false;
  String listeningStatusResponse = SpeechToText.listeningStatus;
  String? listenLocale;
  List<String> localesResult = [];
  static const String localeId1 = 'en_US';
  static const String localeId2 = 'fr_CA';
  static const String name1 = 'English US';
  static const String name2 = 'French Canada';
  static const String locale1 = '$localeId1:$name1';
  static const String locale2 = '$localeId2:$name2';
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
  static const SpeechRecognitionWords firstWords =
      SpeechRecognitionWords(firstRecognizedWords, firstConfidence);
  static const SpeechRecognitionWords secondWords =
      SpeechRecognitionWords(secondRecognizedWords, secondConfidence);
  static final SpeechRecognitionResult firstRecognizedResult =
      SpeechRecognitionResult([firstWords], false);
  static final SpeechRecognitionResult secondRecognizedResult =
      SpeechRecognitionResult([secondWords], false);
  static final SpeechRecognitionResult finalRecognizedResult =
      SpeechRecognitionResult([secondWords], true);
  static const String transientErrorJson =
      '{"errorMsg":"network","permanent":false}';
  static const String permanentErrorJson =
      '{"errorMsg":"network","permanent":true}';
  static final SpeechRecognitionError firstError =
      SpeechRecognitionError('network', true);
  static const double level1 = 0.5;
  static const double level2 = 10;

  @override
  Future<bool> hasPermission() async {
    return hasPermissionResult;
  }

  @override
  Future<bool> initialize(
      {debugLogging = false, List<SpeechConfigOption>? options}) async {
    initInvoked = true;
    return initResult;
  }

  @override
  Future<void> stop() async {
    stopInvoked = true;
  }

  @override
  Future<void> cancel() async {
    cancelInvoked = true;
  }

  @override
  Future<bool> listen(
      {String? localeId,
      partialResults = true,
      onDevice = false,
      int listenMode = 0,
      sampleRate = 0}) async {
    listenInvoked = true;
    listenLocale = localeId;
    if (listenException) {
      throw PlatformException(
          code: listenExceptionCode,
          message: listenExceptionMessage,
          details: listenExceptionDetails);
    }
    return true;
  }

  @override
  Future<List<dynamic>> locales() async {
    localesInvoked = true;
    return localesResult;
  }

  void notifyListening() {
    onStatus!(SpeechToText.listeningStatus);
  }

  void notifyFinalWords() {
    onTextRecognition!(finalRecognizedJson);
  }

  void notifyPartialWords() {
    onTextRecognition!(firstRecognizedJson);
  }

  void notifyPermanentError() {
    onError!(permanentErrorJson);
  }

  void notifyTransientError() {
    onError!(transientErrorJson);
  }

  void notifySoundLevel() {
    onSoundLevel!(level2);
  }

  void setupLocales() {
    localesResult.clear();
    localesResult.add(locale1);
    localesResult.add(locale2);
  }
}
