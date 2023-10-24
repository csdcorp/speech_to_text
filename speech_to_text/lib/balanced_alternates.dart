import 'dart:math';

import 'package:speech_to_text/speech_recognition_result.dart';

class BalancedAlternates {
  final Map<int, List<SpeechRecognitionWords>> _alternates = {};

  /// Add a new phrase to a particular alternate. The way this works is
  /// that the first alternate is the most likely, the second alternate is
  /// the second most likely, etc. The first alternate is the one that
  /// is returned by the speech recognition engine as 'the answer'. Engines
  /// may return more than one alternate, but the first one will always
  /// contain the most phrases. If a phrase is added to an alternate that
  ///
  void add(int phrase, String words, double confidence) {
    _alternates[phrase] ??= [];
    _alternates[phrase]?.add(SpeechRecognitionWords(words, confidence));
  }

  /// Return the full speech recognition results which is the concatenation
  /// of all the alternates and all their phrases into separate results. The
  /// approach is to concatenate the all phrases from the first, or most likely,
  /// alternate. The first is assumed to have the most phrases, since there
  /// must be a recognition result for a phrase or it wouldn't have alternates.
  /// Then all the phrases for each subsequent alternate are concatenated, any
  /// phrase that is missing an alternate has that alternate filled in with the
  /// previous alternate. This is done so that the result is a complete
  /// transcript of all the alternates.
  List<SpeechRecognitionWords> getAlternates() {
    final phraseCount = _alternates.length;
    var result = <SpeechRecognitionWords>[];
    final maxAlternates = _alternates.values
        .fold(0, (max, list) => max = list.length > max ? list.length : max);
    for (var phraseIndex = 0; phraseIndex < phraseCount; ++phraseIndex) {
      final phraseAlternates = _alternates[phraseIndex] ?? [];
      for (var altIndex = max(1, phraseAlternates.length);
          altIndex < maxAlternates;
          ++altIndex) {
        phraseAlternates.add(phraseAlternates[altIndex - 1]);
      }
    }

    for (var altCount = 0; altCount < maxAlternates; ++altCount) {
      var alternatePhrase = '';
      var alternateConfidence = 1.0;
      for (var phraseIndex = 0; phraseIndex < phraseCount; ++phraseIndex) {
        alternatePhrase += _alternates[phraseIndex]![altCount].recognizedWords;
        alternateConfidence = min(alternateConfidence,
            _alternates[phraseIndex]![altCount].confidence);
      }
      result.add(SpeechRecognitionWords(alternatePhrase, alternateConfidence));
    }
    return result;
  }
}
