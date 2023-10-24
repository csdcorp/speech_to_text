import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

void main() {
  runApp(const MyApp());
}

List<Language> languages = [
  const Language('System', 'default'),
  const Language('Francais', 'fr_FR'),
  const Language('English', 'en_US'),
  const Language("Pyccкий", 'ru_RU'),
  const Language('Italiano', 'it_IT'),
  const Language('Español', 'es_ES'),
];

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var _speech = SpeechToText();

  bool _speechRecognitionAvailable = false;
  bool _isListening = false;

  String transcription = '';

  //String _currentLocale = 'en_US';
  Language selectedLang = languages.first;

  @override
  void initState() {
    super.initState();
    activateSpeechRecognizer();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> activateSpeechRecognizer() async {
    debugPrint('_MyAppState.activateSpeechRecognizer... ');
    _speech = SpeechToText();
    // _speech.setCurrentLocaleHandler(onCurrentLocale);
    // _speech.setRecognitionStartedHandler(onRecognitionStarted);
    // _speech.setRecognitionCompleteHandler(onRecognitionComplete);
    _speechRecognitionAvailable = await _speech.initialize(
        onError: errorHandler, onStatus: onSpeechAvailability);
    var localeNames = await _speech.locales();
    languages.clear();
    for (var localeName in localeNames) {
      languages.add(Language(localeName.name, localeName.localeId));
    }
    var currentLocale = await _speech.systemLocale();
    if (null != currentLocale) {
      selectedLang =
          languages.firstWhere((lang) => lang.code == currentLocale.localeId);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SpeechRecognition'),
          actions: [
            PopupMenuButton<Language>(
              onSelected: _selectLangHandler,
              itemBuilder: (BuildContext context) => _buildLanguagesWidgets,
            )
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: Container(
                          padding: const EdgeInsets.all(8.0),
                          color: Colors.grey.shade200,
                          child: Text(transcription))),
                  _buildButton(
                    onPressed: _speechRecognitionAvailable && !_isListening
                        ? () => start()
                        : null,
                    label: _isListening
                        ? 'Listening...'
                        : 'Listen (${selectedLang.code})',
                  ),
                  _buildButton(
                    onPressed: _isListening ? () => cancel() : null,
                    label: 'Cancel',
                  ),
                  _buildButton(
                    onPressed: _isListening ? () => stop() : null,
                    label: 'Stop',
                  ),
                ],
              ),
            )),
      ),
    );
  }

  List<CheckedPopupMenuItem<Language>> get _buildLanguagesWidgets => languages
      .map((l) => CheckedPopupMenuItem<Language>(
            value: l,
            checked: selectedLang == l,
            child: Text(l.name),
          ))
      .toList();

  void _selectLangHandler(Language lang) {
    setState(() => selectedLang = lang);
  }

  Widget _buildButton({String label = '', VoidCallback? onPressed}) => Padding(
      padding: const EdgeInsets.all(12.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ));

  void start() => _speech.listen(
      onResult: onRecognitionResult, localeId: selectedLang.code);

  void cancel() {
    _speech.cancel();
    setState(() => _isListening = false);
  }

  void stop() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void onSpeechAvailability(String status) {
    setState(() {
      _speechRecognitionAvailable = _speech.isAvailable;
      _isListening = _speech.isListening;
    });
  }

  void onCurrentLocale(String locale) {
    debugPrint('_MyAppState.onCurrentLocale... $locale');
    setState(
        () => selectedLang = languages.firstWhere((l) => l.code == locale));
  }

  // void onRecognitionStarted() => setState(() => _isListening = true);

  void onRecognitionResult(SpeechRecognitionResult result) =>
      setState(() => transcription = result.recognizedWords);

  // void onRecognitionComplete() => setState(() => _isListening = false);

  void errorHandler(SpeechRecognitionError error) => debugPrint(error.errorMsg);
}
