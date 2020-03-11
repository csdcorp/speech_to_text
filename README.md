# speech_to_text

[![pub package](https://img.shields.io/badge/pub-v1.0.1-blue)](https://pub.dartlang.org/packages/speech_to_text) [![build status](https://github.com/csdcorp/speech_to_text/workflows/build/badge.svg)](https://github.com/csdcorp/speech_to_text/actions?query=workflow%3Abuild)

A library that exposes device specific speech to text recognition capability.

This plugin contains a set of classes that make it easy to use the speech recognition 
capabilities of the mobile device in Flutter. It supports both Android and iOS. The 
target use cases for this library are commands and short phrases, not continuous spoken
conversion or always on listening. 

## Recent Updates

The 1.0.0 version adds the ability to automatically cancel listening on a permanent error. 
This is a new parameter on the `listen` method, defaulted to false for backward 
compatibility. It also adds the ability to control whether partial and complete or only 
complete results are sent during listening.  

The 0.8.0 version exposes a list of possible speech transcriptions instead of just the 
transcription with the highest confidence. The functionality should be backwards compatible,
to find out more have a look at the details of `SpeechRecognitionResult` and 
`SpeechRecognitionWords`. 

*Note*: Feedback from any test devices is welcome. 

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
    speech.stop()
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

## Adding Sounds for iOS (optional)

Android automatically plays system sounds when speech listening starts or stops but iOS does not. This plugin supports playing sounds to indicate listening status on iOS if sound files are available as assets in the application. To enable sounds in an application using this plugin add the sound files to the project and reference them in the assets section of the application `pubspec.yaml`. The location and filenames of the sound files must exactly match what 
is shown below or they will not be found. The example application for the plugin shows the usage. 
```yaml
  assets:
  - assets/sounds/speech_to_text_listening.m4r
  - assets/sounds/speech_to_text_cancel.m4r
  - assets/sounds/speech_to_text_stop.m4r
```
* `speech_to_text_listening.m4r` - played when the listen method is called.
* `speech_to_text_cancel.m4r` - played when the cancel method is called.
* `speech_to_text_stop.m4r` - played when the stop method is called.

