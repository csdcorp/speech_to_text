import 'package:flutter/material.dart';
import 'dart:async';

import 'package:speech_to_text_macos/speech_to_text_macos.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _hasPermission = false;
  final _speechToTextMacosPlugin = SpeechToTextMacos();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    bool hasPermission = await _speechToTextMacosPlugin.initialize();

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _hasPermission = hasPermission;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MacOS Plugin example app'),
        ),
        body: Center(
          child: Text(_hasPermission ? 'Has permission' : 'No permission'),
        ),
      ),
    );
  }
}
