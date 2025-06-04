import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text_windows/speech_to_text_windows.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (defaultTargetPlatform == TargetPlatform.windows) {
    SpeechToTextWindows.registerWith();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech to Text Windows Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SpeechToTextDemo(),
    );
  }
}

class SpeechToTextDemo extends StatefulWidget {
  const SpeechToTextDemo({super.key});

  @override
  State<SpeechToTextDemo> createState() => _SpeechToTextDemoState();
}

class _SpeechToTextDemoState extends State<SpeechToTextDemo> {
  final SpeechToTextWindows _speechToText = SpeechToTextWindows();
  bool _speechEnabled = false;
  String _lastWords = '';
  String _status = 'Not initialized';
  List<String> _locales = [];
  String? _selectedLocale;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      // Set up callbacks
      _speechToText.onTextRecognition = (text) {
        setState(() {
          _lastWords = text;
        });
      };
      
      _speechToText.onStatus = (status) {
        setState(() {
          _status = status;
          _isListening = status == 'listening';
        });
      };
      
      _speechToText.onError = (error) {
        setState(() {
          _status = 'Error: $error';
          _isListening = false;
        });
      };

      // Initialize speech recognition
      _speechEnabled = await _speechToText.initialize(
        debugLogging: true,
      );
      
      if (_speechEnabled) {
        final localeResults = await _speechToText.locales();
        _locales = localeResults.cast<String>();
        if (_locales.isNotEmpty) {
          _selectedLocale = _locales.first.split(':').first;
        }
      }
    } catch (e) {
      setState(() {
        _status = 'Initialization error: $e';
      });
    }
    
    setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) return;

    try {
      await _speechToText.listen(
        localeId: _selectedLocale,
        partialResults: true,
      );
    } catch (e) {
      setState(() {
        _status = 'Listen error: $e';
      });
    }
  }

  void _stopListening() async {
    try {
      await _speechToText.stop();
    } catch (e) {
      setState(() {
        _status = 'Stop error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Windows Speech to Text Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Speech Enabled: $_speechEnabled'),
                    Text('Current Status: $_status'),
                    Text('Available Locales: ${_locales.length}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Locale Selection
            if (_locales.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language Selection',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _selectedLocale,
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedLocale = newValue;
                          });
                        },
                        items: _locales.map<DropdownMenuItem<String>>((String locale) {
                          final parts = locale.split(':');
                          final localeId = parts.isNotEmpty ? parts[0] : locale;
                          final displayName = parts.length > 1 ? parts[1] : localeId;
                          return DropdownMenuItem<String>(
                            value: localeId,
                            child: Text('$displayName ($localeId)'),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Recognition Results
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recognition Results',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _lastWords.isEmpty ? 'Say something...' : _lastWords,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _speechEnabled && !_isListening ? _startListening : null,
                  icon: const Icon(Icons.mic),
                  label: const Text('Start Listening'),
                ),
                ElevatedButton.icon(
                  onPressed: _speechEnabled && _isListening ? _stopListening : null,
                  icon: const Icon(Icons.mic_off),
                  label: const Text('Stop Listening'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _speechEnabled ? () {
                    setState(() {
                      _lastWords = '';
                    });
                  } : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: _speechEnabled
          ? FloatingActionButton(
              onPressed: _isListening ? _stopListening : _startListening,
              tooltip: _isListening ? 'Stop Listening' : 'Start Listening',
              backgroundColor: _isListening ? Colors.red : Colors.blue,
              child: Icon(_isListening ? Icons.mic_off : Icons.mic),
            )
          : null,
    );
  }
}