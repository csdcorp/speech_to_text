import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_to_text_provider.dart';
import 'package:speech_to_text_example/recognition_results_widget.dart';

void main() => runApp(const ProviderDemoApp());

class ProviderDemoApp extends StatefulWidget {
  const ProviderDemoApp({Key? key}) : super(key: key);

  @override
  State<ProviderDemoApp> createState() => _ProviderDemoAppState();
}

class _ProviderDemoAppState extends State<ProviderDemoApp> {
  final SpeechToText speech = SpeechToText();
  late SpeechToTextProvider speechProvider;

  @override
  void initState() {
    super.initState();
    speechProvider = SpeechToTextProvider(speech);
    initSpeechState();
  }

  Future<void> initSpeechState() async {
    await speechProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SpeechToTextProvider>.value(
      value: speechProvider,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Speech to Text Provider Example'),
          ),
          body: const SpeechProviderExampleWidget(),
        ),
      ),
    );
  }
}

class SpeechProviderExampleWidget extends StatefulWidget {
  const SpeechProviderExampleWidget({Key? key}) : super(key: key);

  @override
  SpeechProviderExampleWidgetState createState() =>
      SpeechProviderExampleWidgetState();
}

class SpeechProviderExampleWidgetState
    extends State<SpeechProviderExampleWidget> {
  String _currentLocaleId = '';

  void _setCurrentLocale(SpeechToTextProvider speechProvider) {
    if (speechProvider.isAvailable && _currentLocaleId.isEmpty) {
      _currentLocaleId = speechProvider.systemLocale?.localeId ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    var speechProvider = Provider.of<SpeechToTextProvider>(context);
    if (speechProvider.isNotAvailable) {
      return const Center(
        child: Text(
            'Speech recognition not available, no permission or not available on the device.'),
      );
    }
    _setCurrentLocale(speechProvider);
    return Column(children: [
      const Center(
        child: Text(
          'Speech recognition available',
          style: TextStyle(fontSize: 22.0),
        ),
      ),
      Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              TextButton(
                onPressed:
                    !speechProvider.isAvailable || speechProvider.isListening
                        ? null
                        : () => speechProvider.listen(
                            partialResults: true, localeId: _currentLocaleId),
                child: const Text('Start'),
              ),
              TextButton(
                onPressed: speechProvider.isListening
                    ? () => speechProvider.stop()
                    : null,
                child: const Text('Stop'),
              ),
              TextButton(
                onPressed: speechProvider.isListening
                    ? () => speechProvider.cancel()
                    : null,
                child: const Text('Cancel'),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              DropdownButton(
                onChanged: (selectedVal) => _switchLang(selectedVal),
                value: _currentLocaleId,
                items: speechProvider.locales
                    .map(
                      (localeName) => DropdownMenuItem(
                        value: localeName.localeId,
                        child: Text(localeName.name),
                      ),
                    )
                    .toList(),
              ),
            ],
          )
        ],
      ),
      const Expanded(
        flex: 4,
        child: RecognitionResultsWidget(),
      ),
      Expanded(
        flex: 1,
        child: Column(
          children: <Widget>[
            const Center(
              child: Text(
                'Error Status',
                style: TextStyle(fontSize: 22.0),
              ),
            ),
            Center(
              child: speechProvider.hasError
                  ? Text(speechProvider.lastError!.errorMsg)
                  : Container(),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        color: Theme.of(context).colorScheme.background,
        child: Center(
          child: speechProvider.isListening
              ? const Text(
                  "I'm listening...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
              : const Text(
                  'Not listening',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ),
    ]);
  }

  void _switchLang(selectedVal) {
    setState(() {
      _currentLocaleId = selectedVal;
    });
    debugPrint(selectedVal);
  }
}
