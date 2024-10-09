import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() => runApp(const SpeechSampleApp());

class SpeechSampleApp extends StatefulWidget {
  const SpeechSampleApp({Key? key}) : super(key: key);

  @override
  State<SpeechSampleApp> createState() => _SpeechSampleAppState();
}

/// An example that demonstrates the basic functionality of the
/// SpeechToText plugin for using the speech recognition capability
/// of the underlying platform.
class _SpeechSampleAppState extends State<SpeechSampleApp> {
  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();

  SpeechExampleConfig currentOptions = SpeechExampleConfig(
      SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          onDevice: false,
          cancelOnError: true,
          partialResults: true,
          autoPunctuation: true,
          enableHapticFeedback: true),
      "",
      3,
      30,
      false);

  @override
  void initState() {
    super.initState();
  }

  /// This initializes SpeechToText. That only has to be done
  /// once per application, though calling it again is harmless
  /// it also does nothing. The UX of the sample app ensures that
  /// it can only be called once.
  Future<void> initSpeechState() async {
    _logEvent('Initialize');
    try {
      var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: currentOptions.logEvents,
      );
      if (hasSpeech) {
        speech.unexpectedPhraseAggregator = _punctAggregator;
        // Get the list of languages installed on the supporting platform so they
        // can be displayed in the UI for selection by the user.
        _localeNames = await speech.locales();

        var systemLocale = await speech.systemLocale();
        currentOptions =
            currentOptions.copyWith(localeId: systemLocale?.localeId ?? '');
      }
      if (!mounted) return;

      setState(() {
        _hasSpeech = hasSpeech;
      });
    } catch (e) {
      setState(() {
        lastError = 'Speech recognition failed: ${e.toString()}';
        _hasSpeech = false;
      });
    }
  }

  String _punctAggregator(List<String> phrases) {
    return phrases.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('Speech to Text Example'),
      ),
      body: Builder(
        builder: (ctx) => SingleChildScrollView(
          child: Column(children: [
            Row(
              children: [
                Expanded(child: InitSpeechWidget(_hasSpeech, initSpeechState)),
                TextButton.icon(
                  // key: ,
                  onPressed: () async {
                    currentOptions =
                        await showSetUp(ctx, currentOptions, _localeNames);
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Session Options'),
                ),
              ],
            ),
            SpeechControlWidget(_hasSpeech, speech.isListening, startListening,
                stopListening, cancelListening),
            RecognitionResultsWidget(lastWords: lastWords, level: level),
            SpeechStatusWidget(lastStatus: lastStatus),
            ErrorWidget(lastError: lastError),
          ]),
        ),
      ),
    ));
  }

  // This is called each time the users wants to start a new speech
  // recognition session
  void startListening() {
    _logEvent('start listening');
    lastWords = '';
    lastError = '';
    // Note that `listenFor` is the maximum, not the minimum, on some
    // systems recognition will be stopped before this value is reached.
    // Similarly `pauseFor` is a maximum not a minimum and may be ignored
    // on some devices.
    speech.listen(
      onResult: resultListener,
      listenFor: Duration(seconds: currentOptions.listenFor),
      pauseFor: Duration(seconds: currentOptions.pauseFor),
      localeId: currentOptions.localeId,
      onSoundLevelChange: soundLevelListener,
      listenOptions: currentOptions.options,
    );
    setState(() {});
  }

  void stopListening() {
    _logEvent('stop');
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    _logEvent('cancel');
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  /// This callback is invoked each time new recognition results are
  /// available after `listen` is called.
  void resultListener(SpeechRecognitionResult result) {
    _logEvent(
        'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');
    setState(() {
      lastWords = '${result.recognizedWords} - ${result.finalResult}';
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // _logEvent('sound level $level: $minSoundLevel - $maxSoundLevel ');
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    _logEvent(
        'Received error status: $error, listening: ${speech.isListening}');
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
    });
  }

  void statusListener(String status) {
    _logEvent(
        'Received listener status: $status, listening: ${speech.isListening}');
    setState(() {
      lastStatus = status;
    });
  }

  void _logEvent(String eventDescription) {
    if (currentOptions.logEvents) {
      var eventTime = DateTime.now().toIso8601String();
      debugPrint('$eventTime $eventDescription');
    }
  }
}

/// Displays the most recently recognized words and the sound level.
class RecognitionResultsWidget extends StatelessWidget {
  const RecognitionResultsWidget({
    Key? key,
    required this.lastWords,
    required this.level,
  }) : super(key: key);

  final String lastWords;
  final double level;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Center(
          child: Text(
            'Recognized Words',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Stack(
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(
                minHeight: 200,
              ),
              color: Theme.of(context).secondaryHeaderColor,
              child: Center(
                child: Text(
                  lastWords,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned.fill(
              bottom: 10,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MicrophoneWidget(level: level),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Display the current error status from the speech
/// recognizer
class ErrorWidget extends StatelessWidget {
  const ErrorWidget({
    Key? key,
    required this.lastError,
  }) : super(key: key);

  final String lastError;

  @override
  Widget build(BuildContext context) {
    return lastError.isNotEmpty
        ? Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Center(
                child: SelectableText(lastError),
              ),
            ],
          )
        : const SizedBox();
  }
}

/// Controls to start and stop speech recognition
class SpeechControlWidget extends StatelessWidget {
  const SpeechControlWidget(this.hasSpeech, this.isListening,
      this.startListening, this.stopListening, this.cancelListening,
      {Key? key})
      : super(key: key);

  final bool hasSpeech;
  final bool isListening;
  final void Function() startListening;
  final void Function() stopListening;
  final void Function() cancelListening;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        TextButton(
          onPressed: !hasSpeech || isListening ? null : startListening,
          child: const Text('Start'),
        ),
        TextButton(
          onPressed: isListening ? stopListening : null,
          child: const Text('Stop'),
        ),
        TextButton(
          onPressed: isListening ? cancelListening : null,
          child: const Text('Cancel'),
        )
      ],
    );
  }
}

class SessionOptionsWidget extends StatelessWidget {
  const SessionOptionsWidget(
      {required this.options,
      required this.localeNames,
      Key? key,
      required this.onChange,
      required this.listenForController,
      required this.pauseForController})
      : super(key: key);

  final SpeechExampleConfig options;
  final List<LocaleName> localeNames;
  final void Function(SpeechExampleConfig newOptions) onChange;
  final TextEditingController listenForController;
  final TextEditingController pauseForController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: [
            const Text('Language: '),
            Expanded(
              child: DropdownButton<String>(
                onChanged: (selectedVal) => onChange(options.copyWith(
                    localeId: selectedVal ?? options.localeId)),
                value: options.localeId,
                isExpanded: true,
                items: localeNames
                    .map(
                      (localeName) => DropdownMenuItem(
                        value: localeName.localeId,
                        child: Text(localeName.name),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('pauseFor: '),
            Container(
                padding: const EdgeInsets.only(left: 8),
                width: 80,
                child: TextFormField(
                  controller: pauseForController,
                )),
          ],
        ),
        Row(
          children: [
            const Text('listenFor: '),
            Container(
                padding: const EdgeInsets.only(left: 8),
                width: 80,
                child: TextFormField(
                  controller: listenForController,
                )),
          ],
        ),
        Row(
          children: [
            const Text('On device: '),
            Checkbox(
              value: options.options.onDevice,
              onChanged: (value) {
                onChange(options.copyWith(
                    options: options.options.copyWith(onDevice: value)));
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('Auto Punctuation: '),
            Checkbox(
              value: options.options.autoPunctuation,
              onChanged: (value) {
                onChange(options.copyWith(
                    options: options.options.copyWith(autoPunctuation: value)));
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('Enable Haptics: '),
            Checkbox(
              value: options.options.enableHapticFeedback,
              onChanged: (value) {
                onChange(options.copyWith(
                    options:
                        options.options.copyWith(enableHapticFeedback: value)));
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('Partial results: '),
            Checkbox(
              value: options.options.partialResults,
              onChanged: (value) {
                onChange(options.copyWith(
                    options: options.options.copyWith(partialResults: value)));
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('Cancel on error: '),
            Checkbox(
              value: options.options.cancelOnError,
              onChanged: (value) {
                onChange(options.copyWith(
                    options: options.options.copyWith(cancelOnError: value)));
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('Log events: '),
            Checkbox(
              value: options.logEvents,
              onChanged: (value) =>
                  onChange(options.copyWith(logEvents: value)),
            ),
          ],
        ),
      ],
    );
  }
}

class InitSpeechWidget extends StatelessWidget {
  const InitSpeechWidget(this.hasSpeech, this.initSpeechState, {Key? key})
      : super(key: key);

  final bool hasSpeech;
  final Future<void> Function() initSpeechState;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        OutlinedButton(
          onPressed: hasSpeech ? null : initSpeechState,
          child: const Text('Initialize'),
        ),
      ],
    );
  }
}

/// Display the current status of the listener
class SpeechStatusWidget extends StatelessWidget {
  const SpeechStatusWidget({
    Key? key,
    required this.lastStatus,
  }) : super(key: key);

  final String lastStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Status',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Center(
          child: SelectableText(lastStatus),
        ),
      ],
    );
  }
}

/// A class that holds the configuration for the speech recognition
/// example app. This is used to pass the configuration to the
/// setup dialog and to hold the current configuration.
class SpeechExampleConfig {
  final SpeechListenOptions options;
  final String localeId;
  final bool logEvents;
  final int pauseFor;
  final int listenFor;

  SpeechExampleConfig(this.options, this.localeId, this.pauseFor,
      this.listenFor, this.logEvents);

  SpeechExampleConfig copyWith(
      {SpeechListenOptions? options,
      String? localeId,
      bool? logEvents,
      int? pauseFor,
      int? listenFor}) {
    return SpeechExampleConfig(
        options ?? this.options,
        localeId ?? this.localeId,
        pauseFor ?? this.pauseFor,
        listenFor ?? this.listenFor,
        logEvents ?? this.logEvents);
  }
}

/// Show the setup dialog to allow the user to change the
/// configuration of the speech recognition session.
Future<SpeechExampleConfig> showSetUp(BuildContext context,
    SpeechExampleConfig currentOptions, List<LocaleName> localeNames) async {
  var updatedOptions = currentOptions;
  var listenController = TextEditingController()
    ..text = updatedOptions.listenFor.toString();
  var pauseController = TextEditingController()
    ..text = updatedOptions.pauseFor.toString();
  await showModalBottomSheet(
      elevation: 0,
      context: context,
      isScrollControlled: true,
      builder: (
        context,
      ) {
        return Material(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).copyWith().size.height * 0.75,
              minHeight: MediaQuery.of(context).copyWith().size.height * 0.5,
              maxWidth: double.infinity,
            ),
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Session Options",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                      child: SessionOptionsWidget(
                        onChange: (newOptions) {
                          setState(() {
                            updatedOptions = newOptions;
                          });
                        },
                        listenForController: listenController,
                        pauseForController: pauseController,
                        options: updatedOptions,
                        localeNames: localeNames,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      });
  updatedOptions = updatedOptions.copyWith(
      listenFor:
          int.tryParse(listenController.text) ?? updatedOptions.listenFor,
      pauseFor: int.tryParse(pauseController.text) ?? updatedOptions.pauseFor);
  return updatedOptions;
}

/// A simple widget that displays a microphone icon
/// and a circle that changes size based on the sound level.
class MicrophoneWidget extends StatelessWidget {
  const MicrophoneWidget({
    Key? key,
    required this.level,
  }) : super(key: key);

  final double level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              blurRadius: .26,
              spreadRadius: level * 1.5,
              color: Colors.black.withOpacity(.05))
        ],
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(50)),
      ),
      child: IconButton(
        icon: const Icon(Icons.mic),
        onPressed: () {},
      ),
    );
  }
}
