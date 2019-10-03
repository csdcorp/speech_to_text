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
  final SpeechToText speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    bool hasSpeech;
    // Platform messages may fail, so we use a try/catch PlatformException.
    hasSpeech = await speech.initialize(onError: errorListener );

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
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

  void startListening() async {
    speech.listen(onResult: resultListener );
    setState(() {
      
    });
  }

  void stopListening() async {
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
}
