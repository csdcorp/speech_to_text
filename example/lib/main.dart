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
                Expanded(
                  child: Center(
                    child: Text('Speech recognition available'),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FlatButton(
                        child: Text('Start'),
                        onPressed: startListening,
                      ),
                      FlatButton(
                        child: Text('Stop'),
                        onPressed: stopListening,
                      ),
                      FlatButton(
                        child: Text('Cancel'),
                        onPressed: cancelListening,
                      ),
                      FlatButton(
                        child: Text('Stress Test'),
                        onPressed: stressTest,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Center(
                        child: Text('Recognized Words'),
                      ),
                      Center(
                        child: Text(lastWords),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Center(
                        child: Text('Error'),
                      ),
                      Center(
                        child: Text(lastError),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: _localeNames
                        .map(
                          (localeName) => ListTile(
                            title: Text(
                              localeName.localeId,
                            ),
                            trailing: Text(localeName.name),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: speech.isListening
                        ? Text("I'm listening...")
                        : Text('Not listening'),
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
    speech.listen(onResult: resultListener, listenFor: Duration(seconds: 10));
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
}
