# Changelog

## 2.3.0

### New
  * new parameter `onDevice` on the `listen` method enforces on device recognition for sensitive content
  * onSoundLevelChange now supported on iOS
  * added compile troubleshooting help to README.md
  * `SpeechToTextProvider` is an alternate and simpler way to interact with the `SpeechToText` plugin.
  * new `provider_example.dart` example for usage of `SpeechToTextProvider`. 

## 2.2.0

### New
  * improved error handling and logging in the iOS implementation
  * added general guides for iOS to the README
  * moved stress testing out of the main example 
  * iOS now defaults to using the speaker rather than the receiver for start /stop sounds when no headphones
### Fix
  * iOS now properly deactivates the audio session when no longer listening
  * start and stop sounds on iOS should be more reliable when available

## 2.1.0
### Breaking
  * `listenFor` now calls `stop` rather than `cancel` as this seems like more useful behaviour

### Fix
  * Android no longer stops or cancels the speech recognizer if it has already been shutdown by a 
  timeout or other platform behaviour. 
  * Android no longer tries to restart the listener when it is already active
  * Now properly notifies errors that happen after listening stops due to platform callback rather than 
  client request. See https://github.com/csdcorp/speech_to_text/issues/51

## 2.0.1
### Fix
  * Resolves an issue with the Android implementation not handling permission requests properly on apps 
  that didn't use the 1.12.x plugin APIs for registration. The permission dialog would not appear and 
  permission was denied.  


## 2.0.0

### Breaking

  * Upgraded to New Swift 1.12 plugin structure, may work with older Flutter version but not guaranteed
  
### New

  * the plugin now requests both speech and microphone permission on initialize on iOS
  * added `debugLogging` parameter to the `initialize` method to control native logging

### Fix

  * The Android implementation now blocks duplicate results notifications. It appears that at least on some 
  Android versions the final results notification onResults is notified twice when Android automatically
  terminates the session due to a pause time. The de-duplication looks for successive notifications 
  with < 100 ms between them and blocks the second. If you miss any onResult notifications please post 
  an issue. 

## 1.1.0

### New

  * error_timeout has been separated into error_network_timeout and error_speech_timeout

## 1.0.0

### New
  * hasPermission to check for the current permission without bringing up the system dialog
  * `listen` has a new optional `cancelOnError` parameter to support automatically canceling 
  a listening session on a permanent error. 
  * `listen` has a new optional `partialResults` parameter that controls whether the callback
  receives partial or only final results. 

## 0.8.0

### New

  * speech recognizer now exposes multiple possible transcriptions for each recognized speech
  * alternates list on SpeechRecognitionResult exposes alternate transcriptions of voice 
  * confidence on SpeechRecognitionResult gives an estimate of confidence in the transcription
  * isConfident on SpeechRecognitionResult supports testing confidence
  * hasConfidenceRating on SpeechRecognitionResult indicates if confidence was provided from the device
  * new SpeechRecognitionWords class gives details on per transcription words and confidence

### Fix

  * speechRecognizer availabilityDidChange was crashing if invoked due to an invalid parameter type
  * Added iOS platform 10 to example Podfile to resolve compilation warnings

## 0.7.2

### Breaking

  * Upgrade Swift to version 5 to match Flutter. Projects using this plugin must now switch to 5. 
  
## 0.7.1

### Fix

  * Upgrade Kotlin to 1.3.5 to match the Flutter 1.12 version
  * Upgrade Gradle build to 3.5.0 to match the Flutter 1.12 version
  * Android version of the plugin was repeating the system default locale in the `locales` list
  
## 0.7.0

### New

  * locales method returns the list of available languages for speech
  * new optional localeId parameter on listen method supports choosing the comprehension language separately from the current system locale. 

### Breaking

  * `cancel` and `stop` are now async
  
## 0.6.3

### Fix

  * request permission fix on Android to ensure it doesn't conflict with other requests
  
## 0.6.2

### Fix

  * channel invoke wasn't being done on the main thread in iOS
  
## 0.6.1

### Fix

  * listening sound was failing due to timing, now uses play and record mode on iOS. 
   
  ## 0.6.0
### Breaking

  * The filenames for the optional sounds for iOS have changed. 
   
### New

  * Added an optional listenFor parameter to set a max duration to listen for speech and then automatically cancel. 

### Fix

  * Was failing to play sounds because of record mode. Now plays sounds before going into record mode and after coming out. 
  * Status listener was being ignored, now properly notifies on status changes.
  
## 0.5.1
  * Fixes a problem where the recognizer left the AVAudioSession in record mode which meant that subsequent sounds couldn't be played. 

## 0.5.0
Initial draft with limited functionality, supports:
  * initializing speech recognition
  * asking the user for permission if required
  * listening for recognized speech
  * canceling the current recognition session 
  * stopping the current recognition session
* Android and iOS 10+ support

Missing:
  * some error handling
  * testing across multiple OS versions
  * and more, to be discovered...
