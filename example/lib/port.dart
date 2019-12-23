import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

void main() {
  runApp(new MyApp());
}

List<Language> languages = [
  const Language('System', 'default'),
  const Language('Francais', 'fr_FR'),
  const Language('English', 'en_US'),
  const Language('Pусский', 'ru_RU'),
  const Language('Italiano', 'it_IT'),
  const Language('Español', 'es_ES'),
];

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  SpeechToText _speech;

  bool _speechRecognitionAvailable = false;
  bool _isListening = false;

  String transcription = '';

  //String _currentLocale = 'en_US';
  Language selectedLang = languages.first;

  @override
  initState() {
    super.initState();
    activateSpeechRecognizer();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> activateSpeechRecognizer() async {
    print('_MyAppState.activateSpeechRecognizer... ');
    _speech = SpeechToText();
    // _speech.setCurrentLocaleHandler(onCurrentLocale);
    // _speech.setRecognitionStartedHandler(onRecognitionStarted);
    // _speech.setRecognitionCompleteHandler(onRecognitionComplete);
    _speechRecognitionAvailable = await _speech.initialize(
        onError: errorHandler, onStatus: onSpeechAvailability);
    List<LocaleName> localeNames = await _speech.locales();
    languages.clear();
    localeNames.forEach((localeName) =>
        languages.add(Language(localeName.name, localeName.localeId)));
    var currentLocale = await _speech.systemLocale();
    if (null != currentLocale) {
      selectedLang =
          languages.firstWhere((lang) => lang.code == currentLocale.localeId);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('SpeechRecognition'),
          actions: [
            new PopupMenuButton<Language>(
              onSelected: _selectLangHandler,
              itemBuilder: (BuildContext context) => _buildLanguagesWidgets,
            )
          ],
        ),
        body: new Padding(
            padding: new EdgeInsets.all(8.0),
            child: new Center(
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  new Expanded(
                      child: new Container(
                          padding: const EdgeInsets.all(8.0),
                          color: Colors.grey.shade200,
                          child: new Text(transcription))),
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
      .map((l) => new CheckedPopupMenuItem<Language>(
            value: l,
            checked: selectedLang == l,
            child: new Text(l.name),
          ))
      .toList();

  void _selectLangHandler(Language lang) {
    setState(() => selectedLang = lang);
  }

  Widget _buildButton({String label, VoidCallback onPressed}) => new Padding(
      padding: new EdgeInsets.all(12.0),
      child: new RaisedButton(
        color: Colors.cyan.shade600,
        onPressed: onPressed,
        child: new Text(
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
    print('_MyAppState.onCurrentLocale... $locale');
    setState(
        () => selectedLang = languages.firstWhere((l) => l.code == locale));
  }

  // void onRecognitionStarted() => setState(() => _isListening = true);

  void onRecognitionResult(SpeechRecognitionResult result) =>
      setState(() => transcription = result.recognizedWords);

  // void onRecognitionComplete() => setState(() => _isListening = false);

  void errorHandler(SpeechRecognitionError error) => print(error);
}
