# speech_to_text

A library that exposes device specific text to speech recognition capability.

This plugin contains a set of classes that make it easy to use the speech recognition 
capabilities of the mobile device in Flutter. It supports both Android and iOS. 

*Note*: This plugin is under development and will be extended over the coming weeks. 

## Using

To recognize text from the microphone import the package and call the plugin, like so: 

```dart
import 'package:speech_to_text/speech_to_text.dart' as stt;

    stt.SpeechToText speech = stt.SpeechToText();
    bool available = await speech.initialize( onStatus: statusListener, onError: errorListener );
    if ( available ) {
        speech.listen( onResult: resultListener );
    }
    else {
        print("The user has denied the use of speech recognition.");
    }
    // some time later...
    speec.stop()
```

## Permissions

Applications using this plugin require user permissions. 
### iOS

Add the following keys to your _Info.plist_ file, located in `<project root>/ios/Runner/Info.plist`:

* `NSSpeechRecognitionUsageDescription` - describe why your app uses speech recognition. This is called _Privacy - Speech Recognition Usage Description_ in the visual editor.
* `NSMicrophoneUsageDescription` - describe why your app needs access to the microphone. This is called _Privacy - Microphone Usage Description_ in the visual editor.

### Android

Add the record audio permission to your _AndroidManifest.xml_ file, located in `<project root>/android/app/src/main/AndroidManifest.xml`.

* `android.permission.RECORD_AUDIO` - this permission is required for microphone access.
* `android.permission.INTERNET` - this permission is required because speech recognition may use remote services.

