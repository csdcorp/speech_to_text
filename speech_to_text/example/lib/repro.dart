import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
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
  int _counter = 0;
  String _recognized = '';
  html.SpeechRecognition? _webSpeech;

  @override
  void initState() {
    super.initState();
    if (html.SpeechRecognition.supported) {
      _webSpeech = html.SpeechRecognition();
    }
  }

  void _incrementCounter() {
    _webSpeech?.stop();
    _webSpeech?.onResult.listen((speechEvent) => _onResult(speechEvent));
    _webSpeech?.interimResults = true;
    _webSpeech?.continuous = true;
    _webSpeech?.start();
    setState(() {
      _counter++;
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
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              'You said: $_recognized',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _onResult(html.SpeechRecognitionEvent event) {
    var results = event.results;
    if (null == results) return;
    for (var recognitionResult in results) {
      if (null == recognitionResult.length || recognitionResult.length == 0) {
        continue;
      }
      for (var altIndex = 0; altIndex < recognitionResult.length!; ++altIndex) {
        html.SpeechRecognitionAlternative alt =
            js_util.callMethod(recognitionResult, 'item', [altIndex]);

        if (null != alt.transcript && null != alt.confidence) {
          setState(() {
            _recognized = alt.transcript!;
          });
        }
      }
    }
  }
}
