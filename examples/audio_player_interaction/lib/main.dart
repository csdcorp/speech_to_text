import 'package:audio_player_interaction/sound_player.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEST',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'TEST'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final SoundPlayer _player = AudioSoundPlayer();

  // ignore: unused_field
  String _info = '';
  String _currentActivity = 'stopped';
  int _loopCount = 0;
  bool _inTest = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _loopTest() async {
    if (!_inTest) {
      setState(() {
        _currentActivity = 'stopped';
      });
      return;
    }
    _info = "***** Starting loop test ***** \n";

    _info += "Open Audio Session\n";
    String testAudioAsset = 'sounds/notification.m4r';
    await _player.play(testAudioAsset, loop: false);

    _info += "Start Player\n";

    setState(() {
      _currentActivity = 'playing';
    });
  }

  void _init() async {
    _info += "Init speech\n";
    await _speechToText.initialize(onError: _onError, onStatus: _onStatus);
    _player.onStop = _onPlayerStop;
    setState(() {});
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
                    onPressed: _inTest
                        ? null
                        : () {
                            _inTest = true;
                            _loopTest();
                          },
                    child: Text('Loop test')),
              ],
            ),
            TextButton(
              onPressed: _inTest
                  ? () {
                      _inTest = false;
                    }
                  : null,
              child: Text('End Test'),
            ),
            Expanded(
              child: Column(
                children: [
                  Divider(),
                  Text(
                    'Currently: $_currentActivity',
                  ),
                  Text('Loops: $_loopCount'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onStatus(String status) {
    _info += "Speech Status: ${status}\n";
    if (_inTest && status == SpeechToText.doneStatus) {
      print('listener stopped');
      _loopTest();
    }
    setState(() {});
  }

  void _onError(SpeechRecognitionError errorNotification) {
    _info += "Error: ${errorNotification.errorMsg}\n";
    setState(() {});
  }

  void _onPlayerStop() {
    print('Player stopped');
    _currentActivity = 'listening';
    ++_loopCount;
    _speechToText.listen(listenFor: Duration(seconds: 1));
    setState(() {});
  }
}
