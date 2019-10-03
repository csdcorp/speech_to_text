# speech_to_text_example

Demonstrates how to use the speech_to_text plugin. This example requires 
that the plugin has been installed. It initializes speech recognition, 
listens for words and prints them.  


## Source

```dart

import 'package:speech_to_text/local_album.dart';
import 'package:speech_to_text/local_image.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() async {
  print('In main.');
  SpeechToText speech = SpeechToText();
  bool available = await speech.initialize();
  if ( available ) {
      
  }
}
```