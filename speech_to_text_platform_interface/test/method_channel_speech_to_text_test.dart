import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_platform_interface/method_channel_speech_to_text.dart';

import 'test_speech_channel_handler.dart';

void main() {
  MethodChannelSpeechToText? speechToText;
  TestSpeechChannelHandler channelHandler = TestSpeechChannelHandler();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    speechToText = MethodChannelSpeechToText();
    speechToText?.setMockHandler(channelHandler.methodCallHandler);
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
}
