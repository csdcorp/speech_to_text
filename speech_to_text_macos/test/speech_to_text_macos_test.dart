import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_macos/speech_to_text_macos.dart';

void main() {
  late SpeechToTextMacOS speechToText;

  setUp(() {
    speechToText = SpeechToTextMacOS();
  });

  test('hasPermission is false before initialize', () async {
    expect(await speechToText.hasPermission(), isFalse);
  });
  test('initialize is false', () async {
    expect(await speechToText.initialize(), isFalse);
  });
  test('hasPermission is false after initialize', () async {
    expect(await speechToText.initialize(), isFalse);
    expect(await speechToText.hasPermission(), isFalse);
  });
  test('locales is empty', () async {
    expect(await speechToText.locales(), isEmpty);
  });
  test('listen is false', () async {
    expect(await speechToText.initialize(), isFalse);
    expect(await speechToText.listen(), isFalse);
  });
}
