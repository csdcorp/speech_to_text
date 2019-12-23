import 'package:flutter/material.dart';
import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _hasSpeech = false;
  bool _stressTest = false;
  int _stressLoops = 0;
  String lastWords = "";
  String lastError = "";
  String lastStatus = "";
  String _currentLocaleId = "";
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    initSpeechState();
  }

  Future<void> initSpeechState() async {
    bool hasSpeech = await speech.initialize(
        onError: errorListener, onStatus: statusListener);
    _localeNames = await speech.locales();
    var systemLocale = await speech.systemLocale();
    _currentLocaleId = systemLocale.localeId;
    if (!mounted) return;
    setState(() {
      _hasSpeech = hasSpeech;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Speech to Text Example'),
        ),
        body: _hasSpeech
            ? Column(children: [
                Center(
                  child: Text(
                    'Speech recognition available',
                    style: TextStyle(fontSize: 22.0),
                  ),
                ),
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      FlatButton(
                        child: Text('Start'),
                        onPressed: speech.isListening ? null : startListening,
                      ),
                      FlatButton(
                        child: Text('Stop'),
                        onPressed: speech.isListening ? stopListening : null,
                      ),
                      FlatButton(
                        child: Text('Cancel'),
                        onPressed: speech.isListening ? cancelListening : null,
                      ),
                      DropdownButton(
                        onChanged: (selectedVal) => _switchLang(selectedVal),
                        value: _currentLocaleId,
                        items: _localeNames
                            .map(
                              (localeName) => DropdownMenuItem(
                                value: localeName.localeId,
                                child: Text(localeName.name),
                              ),
                            )
                            .toList(),
                      )
                      // FlatButton(
                      //   child: Text('Stress Test'),
                      //   onPressed: stressTest,
                      // ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      Center(
                        child: Text(
                          'Recognized Words',
                          style: TextStyle(fontSize: 22.0),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Theme.of(context).selectedRowColor,
                          child: Center(
                            child: Text(lastWords),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: <Widget>[
                      Center(
                        child: Text(
                          'Error Status',
                          style: TextStyle(fontSize: 22.0),
                        ),
                      ),
                      Center(
                        child: Text(lastError),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  color: Theme.of(context).backgroundColor,
                  child: Center(
                    child: speech.isListening
                        ? Text(
                            "I'm listening...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )
                        : Text(
                            'Not listening',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ])
            : Center(
                child: Text('Speech recognition unavailable',
                    style: TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold))),
      ),
    );
  }

  void stressTest() {
    if (_stressTest) {
      return;
    }
    _stressLoops = 0;
    _stressTest = true;
    print("Starting stress test...");
    startListening();
  }

  void changeStatusForStress(String status) {
    if (!_stressTest) {
      return;
    }
    if (speech.isListening) {
      stopListening();
    } else {
      if (_stressLoops >= 100) {
        _stressTest = false;
        print("Stress test complete.");
        return;
      }
      print("Stress loop: $_stressLoops");
      ++_stressLoops;
      startListening();
    }
  }

  void startListening() {
    lastWords = "";
    lastError = "";
    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 10),
        localeId: _currentLocaleId);
    setState(() {});
  }

  void stopListening() {
    speech.stop();
    setState(() {});
  }

  void cancelListening() {
    speech.cancel();
    setState(() {});
  }

  void resultListener(SpeechRecognitionResult result) {
    setState(() {
      lastWords = "${result.recognizedWords} - ${result.finalResult}";
    });
  }

  void errorListener(SpeechRecognitionError error) {
    setState(() {
      lastError = "${error.errorMsg} - ${error.permanent}";
    });
  }

  void statusListener(String status) {
    changeStatusForStress(status);
    setState(() {
      lastStatus = "$status";
    });
  }

  _switchLang(selectedVal) {
    setState(() {
      _currentLocaleId = selectedVal;
    });
    print(selectedVal);
  }
}
