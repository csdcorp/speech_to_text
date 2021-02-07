import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech To Text Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Speech To Text Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _ready = false;
  bool _listening = false;
  String _lastWords = '';
  String _lastStatus = '';
  String _lastError = '';

  @override
  void initState() {
    super.initState();
  }

  void _init() async {
    _ready =
        await _speechToText.initialize(onError: _onError, onStatus: _onStatus);
    setState(() {});
  }

  void _start() async {
    await _speechToText.listen(onResult: _speechResult);
    _listening = true;
    setState(() {});
  }

  void _stop() async {
    _speechToText.stop();
    _listening = false;
    setState(() {});
  }

  void _cancel() async {
    _speechToText.cancel();
    _listening = false;
    setState(() {});
  }

  void _speechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: _ready ? null : _init,
                    child: Text('Initialize')),
                TextButton(
                    onPressed: _ready && !_listening ? _start : null,
                    child: Text('Listen')),
                TextButton(
                    onPressed: _listening ? _stop : null, child: Text('Stop')),
                TextButton(
                    onPressed: _listening ? _cancel : null,
                    child: Text('Cancel')),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  Divider(),
                  Text(
                    'Speech to text initialized: $_ready',
                  ),
                  Text(
                    'Status: $_lastStatus',
                  ),
                  Text(
                    'Error: $_lastError',
                  ),
                  Divider(),
                  Text(
                    'Words: $_lastWords',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onStatus(String status) {
    _lastStatus = status;
  }

  void _onError(SpeechRecognitionError errorNotification) {
    _lastError = errorNotification.errorMsg;
  }
}
