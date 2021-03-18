# speech_to_text_example

Demonstrates how to use the speech_to_text plugin. This example requires 
that the plugin has been installed. It initializes speech recognition, 
listens for words and prints them.  


## Source

```dart
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
  String lastWords = "";
  String lastError = "";
  String lastStatus = "";
  final SpeechToText speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    initSpeechState();
  }

  Future<void> initSpeechState() async {
    bool hasSpeech = await speech.initialize(onError: errorListener, onStatus: statusListener );

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
                      TextButton(
                        child: Text('Start'),
                        onPressed: startListening,
                      ),
                      TextButton(
                        child: Text('Stop'),
                        onPressed: stopListening,
                      ),
                      TextButton(
                        child: Text('Cancel'),
                        onPressed:cancelListening,
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
                  child: Center(
                    child: speech.isListening ? Text("I'm listening...") : Text( 'Not listening' ),
                  ),
                ),
              ])
            : Center( child: Text('Speech recognition unavailable', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold))),
      ),
    );
  }

  void startListening() {
    lastWords = "";
    lastError = "";
    speech.listen(onResult: resultListener );
    setState(() {
      
    });
  }

  void stopListening() {
    speech.stop( );
    setState(() {
      
    });
  }

  void cancelListening() {
    speech.cancel( );
    setState(() {
      
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    setState(() {
      lastWords = "${result.recognizedWords} - ${result.finalResult}";
    });
  }

  void errorListener(SpeechRecognitionError error ) {
    setState(() {
      lastError = "${error.errorMsg} - ${error.permanent}";
    });
  }
  void statusListener(String status ) {
    setState(() {
      lastStatus = "$status";
    });
  }
}
```