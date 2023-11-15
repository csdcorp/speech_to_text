# speech_to_text

[![pub package](https://img.shields.io/badge/pub-v6.4.1-blue)](https://pub.dartlang.org/packages/speech_to_text) [![build status](https://github.com/csdcorp/speech_to_text/workflows/build/badge.svg)](https://github.com/csdcorp/speech_to_text/actions?query=workflow%3Abuild) [![codecov](https://codecov.io/gh/csdcorp/speech_to_text/branch/main/graph/badge.svg?token=4LV3HESMS4)](undefined)

A library that exposes device specific speech recognition capability.

This plugin contains a set of classes that make it easy to use the speech recognition 
capabilities of the underlying platform in Flutter. It supports Android, iOS and web. The 
target use cases for this library are commands and short phrases, not continuous spoken
conversion or always on listening. 

## Recent Updates

6.4.0 Better support for newer Android devices, locales a

6.2.0 Upgrades for Flutter 3.x thanks to [jinosh05](https://github.com/jinosh05) for that!

*Note*: Feedback from any test devices is welcome. 

## Using

To recognize text from the microphone import the package and call the plugin, like so: 

### Minimal 
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

### Complete Flutter example
```dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(16),
              child: Text(
                'Recognized words:',
                style: TextStyle(fontSize: 20.0),
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  // If listening is active show the recognized words
                  _speechToText.isListening
                      ? '$_lastWords'
                      // If listening isn't active but could be tell the user
                      // how to start it, otherwise indicate that speech
                      // recognition is not yet ready or not supported on
                      // the target device
                      : _speechEnabled
                          ? 'Tap the microphone to start listening...'
                          : 'Speech not available',
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            // If not yet listening for speech start, otherwise stop
            _speechToText.isNotListening ? _startListening : _stopListening,
        tooltip: 'Listen',
        child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}
```

### Initialize once
The `initialize` method only needs to be called once per application session. After that `listen`, 
`start`, `stop`, and `cancel` can be used to interact with the plugin. Subsequent calls to `initialize` 
are ignored which is safe but does mean that the `onStatus` and `onError` callbacks cannot be reset after
the first call to `initialize`. For that reason there should be only one instance of the plugin per 
application. The `SpeechToTextProvider` is one way to create a single instance and easily reuse it in 
multiple widgets. 

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
* `android.permission.BLUETOOTH` - this permission is required because speech recognition can use bluetooth headsets when connected.
* `android.permission.BLUETOOTH_ADMIN` - this permission is required because speech recognition can use bluetooth headsets when connected.
* `android.permission.BLUETOOTH_CONNECT` - this permission is required because speech recognition can use bluetooth headsets when connected.

```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

#### Android SDK 30 or later

If you are targeting Android SDK, i.e. you set your `targetSDKVersion` to 30 or later, then you will need to add the following to your `AndroidManifest.xml` right after the permissions section. See the example app for the complete usage. 

```xml
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

## Adding Sounds for iOS (optional)

Android automatically plays system sounds when speech listening starts or stops but iOS does not. This plugin supports playing sounds to indicate listening status on iOS if sound files are available as assets in the application. To enable sounds in an application using this plugin add the sound files to the project and reference them in the assets section of the application `pubspec.yaml`. The location and filenames of the sound files must exactly match what 
is shown below or they will not be found. The example application for the plugin shows the usage. *Note* These files should be very short as they delay 
the start / end of the speech recognizer until the sound playback is complete. 
```yaml
  assets:
  - assets/sounds/speech_to_text_listening.m4r
  - assets/sounds/speech_to_text_cancel.m4r
  - assets/sounds/speech_to_text_stop.m4r
```
* `speech_to_text_listening.m4r` - played when the listen method is called.
* `speech_to_text_cancel.m4r` - played when the cancel method is called.
* `speech_to_text_stop.m4r` - played when the stop method is called.


## Tips

### Switching Recognition Language
The speech_to_text plugin uses the default locale for the device for speech recognition by default. However it also 
supports using any language installed on the device. To find the available languages and select a particular language 
use these properties.

There's a `locales` property on the `SpeechToText` instance that provides the list of locales installed on the device 
as `LocaleName` instances. Then the `listen` method takes an optional `localeId` named param which would be the `localeId`
 property of any of the values returned in `locales`. A call looks like this:
 ```dart
    var locales = await speech.locales();

    // Some UI or other code to select a locale from the list
    // resulting in an index, selectedLocale

    var selectedLocale = locales[selectedLocale];
    speech.listen(
        onResult: resultListener,
        localeId: selectedLocale.localeId,
        );
 ```

## Troubleshooting

### Speech recognition not working on iOS Simulator

If speech recognition is not working on your simulator try going to the Settings app in the simulator:
Accessibility -> Spoken content -> Voices

From there select any language and any speaker and it should download to the device. After that speech 
recognition should work on the simulator. 

### Speech recognition stops after a brief pause on Android

Android speech recognition has a very short timeout when the speaker pauses. The duration seems to vary by device 
and version of the Android OS. In the devices I've used none have had a pause longer than 5 seconds. Unfortunately
there appears to be no way to change that behaviour. 

### Android beeps on start/stop of speech recognition

This is a feature of the Android OS and there is no supported way to disable it. 

Android build
Version 5.2.0 of the plugin and later require at least `compileSdkVersion 31` for the Android build.  This property can be set in the `build.gradle` file.

### Continuous speech recognition

There have been a number of questions about how to achieve continuous speech recognition using this plugin. Currently 
the plugin is designed for short intermittent use, like when expecting a response to a question, or issuing a single
voice command. Issue #63 is the current home for that discussion. There is not yet a way to achieve this goal using the 
Android or iOS speech recognition capabilities. 

There are at least two separate use cases for continuous speech recognition:
1. voice assistant style, where recognition of a particular phrase triggers an interaction;
2. dictation of text for input. 

Voice assistant style interaction is possibly better handled by integrating with the existing assistant capability on 
the device rather than building out a separate capability. Text dictation is available through the keyboard for standard
text input controls though there are other uses of dictation that are not currently well supported. 

### Browser support for speech recognition 
Web browsers vary in their level of support for speech recognition. This 
[issue](https://github.com/csdcorp/speech_to_text/issues/239) has some details. 
The best lists I've seen are https://caniuse.com/speech-recognition and 
https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition. In particular 
in issue #239 it was reported that Brave Browser and Firefox for Linux do not 
support speech recognition. 

### Speech recognition from recorded audio 
There have been a number of questions about whether speech can be recognized from recorded audio. The short answer is 
that this may be possible on iOS but doesn't appear to be on Android. There is an open issue on this here #205. 

### iOS interactions with other sound plugins, crash when listening or initializing, pauses
On iOS the speech recognition plugin can interact with other sound plugins, things like WebRTC, or sound playback 
or recording plugins. While this plugin tries hard to be a good citizen and properly share the various iOS sound 
resources there is always room for interactions. One thing that might help is to add a brief delay between the end of 
another sound plugin and starting to listen using SpeechToText. See this [issue](https://github.com/csdcorp/speech_to_text/issues/372) 
for example.

### SDK version error trying to compile for Android
```
Manifest merger failed : uses-sdk:minSdkVersion 16 cannot be smaller than version 21 declared in library [:speech_to_text] 
```
The speech_to_text plugin requires at least Android SDK 21 because some of the speech functions in Android 
were only introduced in that version. To fix this error you need to change the `build.gradle` entry to reflect
this version. Here's what the relevant part of that file looked like as of this writing:
```
   defaultConfig {
        applicationId "com.example.app"
        minSdkVersion 21
        targetSdkVersion 28
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }
```

### Recording audio on Android

It is not currently possible to record audio on Android while doing speech recognition. The only solution right now is to 
stop recording while the speech recognizer is active and then start again after. 

### Incorrect Swift version trying to compile for iOS
```
/Users/markvandergon/flutter/.pub-cache/hosted/pub.dartlang.org/speech_to_text-1.1.0/ios/Classes/SwiftSpeechToTextPlugin.swift:224:44: error: value of type 'SwiftSpeechToTextPlugin' has no member 'AVAudioSession'
                rememberedAudioCategory = self.AVAudioSession.Category
                                          ~~~~ ^~~~~~~~~~~~~~
    /Users/markvandergon/flutter/.pub-cache/hosted/pub.dartlang.org/speech_to_text-1.1.0/ios/Classes/SwiftSpeechToTextPlugin.swift:227:63: error: type 'Int' has no member 'notifyOthersOnDeactivation'
                try self.audioSession.setActive(true, withFlags: .notifyOthersOnDeactivation)
```
This happens when the Swift language version is not set correctly. See this thread for help https://github.com/csdcorp/speech_to_text/issues/45.

### Swift not supported trying to compile for iOS
```
`speech_to_text` does not specify a Swift version and none of the targets (`Runner`) integrating it have the `SWIFT_VERSION` attribute set.
```
This usually happens for older projects that only support Objective-C. See this thread for help https://github.com/csdcorp/speech_to_text/issues/88. 

### Last word lost on Android
There's a discussion here https://github.com/csdcorp/speech_to_text/issues/434 about this known issue 
with some Android speech recognition. This issue is up to Google and other Android implementers to 
address, the plugin can't improve on their recognition quality. 

### Not working on a particular Android device
The symptom for this issue is that the `initialize` method will always fail. If you turn on debug logging 
using the `debugLogging: true` flag on the `initialize` method you'll see `'Speech recognition unavailable'`
in the Android log. There's a lengthy issue discussion here https://github.com/csdcorp/speech_to_text/issues/36 
about this. The issue seems to be that the recognizer is not always automatically enabled on the device. Two 
key things helped resolve the issue in this case at least. 

### Not working on an Android emulator
The above tip about getting it working on an Android device is also useful for emulators. Some users have reported seeing another error on Android simulators - sdk gphone x86 (Pixel 3a API 30). 
AUDIO_RECORD perms were in Manifest, also manually set Mic perms in Android Settings. When running sample app, Initialize works, but Start failed the log looks as follows.
```
D/SpeechToTextPlugin(12555): put partial
D/SpeechToTextPlugin(12555): put languageTag
D/SpeechToTextPlugin(12555): Error 9 after start at 35 1000.0 / -100.0
D/SpeechToTextPlugin(12555): Cancel listening
```

#### Resolved by
Resolved it by Opening Google, clicking Mic icon and granting it perms, then everything on the App works...

#### First 
1. Go to Google Play
2. Search for 'Google'
3. You should find this app: https://play.google.com/store/apps/details?id=com.google.android.googlequicksearchbox
If 'Disabled' enable it

This is the SO post that helped: https://stackoverflow.com/questions/28769320/how-to-check-wether-speech-recognition-is-available-or-not

#### Second
Ensure the app has the required permissions. The symptom for this that you get a permanent error notification 
 'error_audio_error` when starting a listen session. Here's a Stack Overflow post that addresses that 
 https://stackoverflow.com/questions/46376193/android-speechrecognizer-audio-recording-error
 Here's the important excerpt: 
 >You should go to system setting, Apps, Google app, then enable its permission of microphone. 

#### User reported steps
From issue [#298](https://github.com/csdcorp/speech_to_text/issues/298) this is the detailed set of steps that
resolved their issue:

1. install google app
2. Settings > Voice > Languages - select the language
3. Settings > Voice > Languages > Offline speech recognition - install language
4. Settings > Language and region - select the Search language and Search region
5. Delete the build folder from the root path of the project and run again

### iOS recognition guidelines
Apple has quite a good guide on the user experience for using speech, the original is here 
https://developer.apple.com/documentation/speech/sfspeechrecognizer This is the section  that I think is particularly relevant:

>#### Create a Great User Experience for Speech Recognition
>Here are some tips to consider when adding speech recognition support to your app.

>**Be prepared to handle failures caused by speech recognition limits.** Because speech recognition is a network-based service, limits are enforced so that the service can remain freely available to all apps. Individual devices may be limited in the number of recognitions that can be performed per day, and each app may be throttled globally based on the number of requests it makes per day. If a recognition request fails quickly (within a second or two of starting), check to see if the recognition service became unavailable. If it is, you may want to ask users to try again later.

>**Plan for a one-minute limit on audio duration.** Speech recognition places a relatively high burden on battery life and network usage. To minimize this burden, the framework stops speech recognition tasks that last longer than one minute. This limit is similar to the one for keyboard-related dictation.
Remind the user when your app is recording. For example, display a visual indicator and play sounds at the beginning and end of speech recognition to help users understand that they're being actively recorded. You can also display speech as it is being recognized so that users understand what your app is doing and see any mistakes made during the recognition process.

>**Do not perform speech recognition on private or sensitive information.** Some speech is not appropriate for recognition. Don't send passwords, health or financial data, and other sensitive speech for recognition.
