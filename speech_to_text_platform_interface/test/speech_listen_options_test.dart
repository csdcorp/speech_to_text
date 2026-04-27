import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

void main() {
  group('constructor', () {
    test('contextualPhrases defaults to null', () {
      final options = SpeechListenOptions();
      expect(options.contextualPhrases, isNull);
    });
    test('contextualPhrases is stored when supplied', () {
      final options = SpeechListenOptions(
          contextualPhrases: const ['Nosema', 'Langstroth']);
      expect(options.contextualPhrases, ['Nosema', 'Langstroth']);
    });
  });
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
        contextualPhrases: const ['Nosema'],
      );
      final modifiedOptions = options.copyWith(
        onDevice: false,
        partialResults: false,
        listenMode: ListenMode.confirmation,
        sampleRate: 8000,
        cancelOnError: false,
        autoPunctuation: false,
        enableHapticFeedback: false,
        contextualPhrases: const ['varroa', 'brood box'],
      );
      expect(modifiedOptions.onDevice, false);
      expect(modifiedOptions.partialResults, false);
      expect(modifiedOptions.listenMode, ListenMode.confirmation);
      expect(modifiedOptions.sampleRate, 8000);
      expect(modifiedOptions.cancelOnError, false);
      expect(modifiedOptions.autoPunctuation, false);
      expect(modifiedOptions.enableHapticFeedback, false);
      expect(modifiedOptions.contextualPhrases, ['varroa', 'brood box']);
    });
    test('preserves contextualPhrases when not modified', () {
      final options = SpeechListenOptions(
          contextualPhrases: const ['Nosema', 'varroa']);
      final modified = options.copyWith(onDevice: true);
      expect(modified.contextualPhrases, ['Nosema', 'varroa']);
    });
  });
}
