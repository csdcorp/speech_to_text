import 'package:flutter/material.dart';
import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _hasSpeech = false;
  String lastWords = "";
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
    hasSpeech = await speech.initialize();

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
                  child: Center(
                    child: Text(lastWords),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: speech.isListening ? Text("I'm listening...") : Text( 'Not listening' ),
                  ),
                ),
              ])
            : Text('Speech recognition unavailable'),
      ),
    );
  }

  void startListening() async {
    speech.listen(resultListener: resultListener );
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
}
