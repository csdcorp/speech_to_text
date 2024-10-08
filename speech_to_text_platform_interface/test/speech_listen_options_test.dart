import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

void main() {
  group('copyWith', () {
    test('modifies expected properties', () async {
      final options = SpeechListenOptions(
        onDevice: true,
        partialResults: true,
        listenMode: ListenMode.search,
        sampleRate: 16000,
        cancelOnError: true,
        autoPunctuation: true,
        enableHapticFeedback: true,
      );
      final modifiedOptions = options.copyWith(
        onDevice: false,
        partialResults: false,
        listenMode: ListenMode.confirmation,
        sampleRate: 8000,
        cancelOnError: false,
        autoPunctuation: false,
        enableHapticFeedback: false,
      );
      expect(modifiedOptions.onDevice, false);
      expect(modifiedOptions.partialResults, false);
      expect(modifiedOptions.listenMode, ListenMode.confirmation);
      expect(modifiedOptions.sampleRate, 8000);
      expect(modifiedOptions.cancelOnError, false);
      expect(modifiedOptions.autoPunctuation, false);
      expect(modifiedOptions.enableHapticFeedback, false);
    });
  });
}
