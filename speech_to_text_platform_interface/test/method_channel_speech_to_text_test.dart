import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_platform_interface/method_channel_speech_to_text.dart';

import 'test_speech_channel_handler.dart';

void main() {
  MethodChannelSpeechToText? speechToText;
  TestSpeechChannelHandler channelHandler = TestSpeechChannelHandler();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    speechToText = MethodChannelSpeechToText();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            speechToText!.channel, channelHandler.methodCallHandler);
    channelHandler.reset();
  });

  group('hasPermission', () {
    test('true if platform reports true', () async {
      expect(await speechToText?.hasPermission(), isTrue);
    });
    test('false if platform reports false', () async {
      channelHandler.hasPermissionResult = false;
      expect(await speechToText?.hasPermission(), isFalse);
    });
    test('false if platform reports null', () async {
      channelHandler.hasPermissionResult = null;
      expect(await speechToText?.hasPermission(), isFalse);
    });
  });

  group('initialize', () {
    test('true if platform reports true', () async {
      expect(await speechToText?.initialize(), isTrue);
      expect(channelHandler.debugLogging, isFalse);
    });
    test('false if platform reports false', () async {
      channelHandler.initResult = false;
      expect(await speechToText?.initialize(), isFalse);
    });
    test('false if platform reports null', () async {
      channelHandler.initResult = null;
      expect(await speechToText?.initialize(), isFalse);
    });
    test('handles options if provided', () async {
      await speechToText?.initialize(
          options: [TestSpeechChannelHandler.androidAlwaysUseStop]);
      expect(channelHandler.initOption,
          TestSpeechChannelHandler.androidAlwaysUseStop.value);
    });
    test('passes debug flag', () async {
      await speechToText?.initialize(debugLogging: true);
      expect(channelHandler.debugLogging, isTrue);
    });
  });
  group('locales', () {
    test('returns empty array from platform', () async {
      expect(await speechToText?.locales(), isEmpty);
    });
    test('returns array provided by platform', () async {
      channelHandler.setupLocales();
      expect(await speechToText?.locales(), channelHandler.locales);
    });
    test('empty if platform reports null', () async {
      channelHandler.locales = null;
      expect(await speechToText?.locales(), isEmpty);
    });
  });
  group('listen', () {
    test('true if platform reports true', () async {
      expect(await speechToText?.listen(), isTrue);
    });
    test('false if platform reports false', () async {
      channelHandler.listenResult = false;
      expect(await speechToText?.listen(), isFalse);
    });
    test('false if platform reports null', () async {
      channelHandler.listenResult = null;
      expect(await speechToText?.listen(), isFalse);
    });
    test('passes localeId parameter', () async {
      expect(
          await speechToText?.listen(
              localeId: TestSpeechChannelHandler.localeId1),
          isTrue);
      expect(channelHandler.listenLocale, TestSpeechChannelHandler.localeId1);
    });
    test('passes onDevice parameter', () async {
      expect(await speechToText?.listen(onDevice: true), isTrue);
      expect(channelHandler.onDevice, isTrue);
    });
    test('passes partialResults parameter', () async {
      expect(await speechToText?.listen(partialResults: false), isTrue);
      expect(channelHandler.partialResults, isFalse);
    });
    test('passes listenMode parameter', () async {
      expect(await speechToText?.listen(listenMode: 3), isTrue);
      expect(channelHandler.listenMode, 3);
    });
    test('passes sampleRate parameter', () async {
      expect(await speechToText?.listen(sampleRate: 10000), isTrue);
      expect(channelHandler.sampleRate, 10000);
    });
  });
  group('control methods invoked as expected', () {
    test('stop invoked', () async {
      await speechToText?.stop();
      expect(channelHandler.stopInvoked, isTrue);
    });
    test('cancel invoked', () async {
      await speechToText?.cancel();
      expect(channelHandler.cancelInvoked, isTrue);
    });
  });
}
