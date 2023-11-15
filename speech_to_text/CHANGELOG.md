# Changelog

## 6.4.1

### Fix
* Removed incorrect MODIFY_PHONE_STATE permission from Android manifest

## 6.4.0

### Fix
* Fix web handling of alternates and multiple phrases was incorrect. Before this change 
multiple phrases were being seen as alternates. This properly combines those phrases into 
a single set of recognized words and produces alternates as appropriate. 

* Android 33+ now returns a valid list from `locales`. It returns the supported on device 
languages. This is (probably) smaller than the full list of online languages but better than 
the current list that only has the default language in it. It also seems to be the only 
option that's available.

## 6.3.0

### New
* New `changePauseFor` method allows the pause duration to be modified during a 
`listen` session. 

### Fix
  * Documentation cleanup and improvements, thanks @Bungeefan
  * Crash on Android versions 11 and below

## 6.2.0

### New
* Upgrades and fixes for Flutter 3.0

### Fix
  * Error status is cleared on each `listen` call. 
  

### Fix
  * Bluetooth permission check no longer crashes on some Android devices

## 6.1.0

### New
* Updated to the latest Kotlin version to meet newer build requirements

## 6.0.0

### New
* Now has minimal support for Mac apps where it will always report speech as unavailable. 
This allows the plugin to be used in apps where speech is an optional capability without 
blocking the deploy to the Mac platform. 

### Fix
  * Cleanup BT code on Android for clarity

## 5.6.1
### Fix
  * Bluetooth permission not granted no longer crashes on Android

## 5.6.0
### New
  * Rejecting Bluetooth permission no longer blocks subsequent recognition 
  using non-bluetooth inputs.

### Fix
  * onDevice recognition for Android should handle switching from onDevice 
  between recognition sessions.

## 5.5.0
### New
  * `initialize` method on the `SpeechToTextProvider` adds the `finalTimeout` and 
  `options` parameters that match the same parameters on `SpeechToText`
  * onDevice support added for Android
  * example app now supports `pauseFor` and `waitFor` parameters

### Fix
   * example app updated for new Android build requirements
   * Result method signature fixed in Android override

## 5.4.3

### New
  * new Android option `androidNoBluetooth` can be used in `initialize` to disable Bluetooth support 
  on Android devices which removes the need for Bluetooth permission. 

## 5.4.2

### New
  * Now asks for Bluetooth permission on SDK 31 and above. When upgrading an already installed app
  the permission will not be requested. Users will have to manually set the permission or clear 
  their app cache to force a re-request. See this [issue](https://github.com/csdcorp/speech_to_text/issues/282)

## 5.4.1

### New
  * Android permission documentation

## 5.4.0

### New
  * Support for bluetooth headsets in Android

## 5.3.0

### New
  * Documentation improvements for `listen` parameters
  * iOS error handling improvements
  
### Fix
  * lastRecognizedWords now cleared before each `listen` call 
  * web issue resolve #242

## 5.2.0

### New
  * Requires `compileSdkVersion 31` to build, check your `build.gradle`
  * Changed the `error_unknown` return to `error_unknown ({error_code})` so that the 
  native Android error code is visible. This is a potentially breaking change if you 
  behaviour for the `error_unkown` value. 
  * Added new SDK 31 error messages for Android 
    * `error_language_not_supported`
    * `error_language_unavailable`
    * `error_server_disconnected`
    * `error_too_many_requests`

### Fix
  * Fix for Android to handle list end on unrecognized content properly #253

## 5.1.1

### Fix
  * Fix for Android compile issue on latest SDK #259

## 5.1.0

### New
  * The example app now supports Web as a run target
  * Improved the example app and its documentation
  * Improved the provider example app
  * Android now handles the `done` condition better, especially in case of error
  * Updated the minimal example in the README file

### Fix
  * Fix for listing available Locales on some Android devices
## 5.0.0
### New
  * Bluetooth headsets now supported on iOS
  * `onStatus` now receives the new `done` status after all listening is complete. This is a potentially 
  breaking change as it adds a new status to handle. 
  * `initialize` and `hasPermission` now checks if speech is supported on web

### Fix
  * removed duplicate `not listening` status sent on iOS
  * iOS now restores all audio options after listening
  * iOS returns speech results faster when also playing a stop sound

## 4.2.2
### Fix
  * handle deprecation of `setMockMethodHandler` #229

## 4.2.1
### Fix
  * minor code format issue that lost me 10 points, this shall not stand!

## 4.2.0
### New
  * Flutter 2.0 / Dart 2.12 null safety features are now the main release

### Fix
  * iOS is now faster starting to listen #207
  * fix for sample rate issue on iOS #109
  * `systemLocale` now reports the device locale rather than the app locale. Previously it was constrained to
  only be one of the localized languages of the application. #200

## 4.1.1-nullsafety
### Fix
* Web support has changed to use the Flutter class definitions and now works in release mode
* `pauseFor` and `listenFor` accuracy improved

## 4.1.0-nullsafety
### New
* New property `finalTimeout` on the `initialize` method to set how long the plugin will wait for a final result 
from the device before manuafacturing one. This used to be a pre-defined value of 100 ms in earlier releases. The
default is now 2 seconds.

## 4.0.0-nullsafety
### New
  * Now supports Flutter 2.0 / Dart 2.12 null safety features.
  * Now supports the web platform

## 3.2.0
### New
* New property `finalTimeout` on the `initialize` method to set how long the plugin will wait for a final result 
from the device before manuafacturing one. This used to be a pre-defined value of 100 ms in earlier releases. The
default is now 2 seconds.

## 3.1.0

### New
  * now compatible with Android SDK 30
  * `initialize` now supports the `options` parameter to supply platform specific options during initialization. 
  * `SpeechToText.androidAlwaysStop` supported as an option. Forces the plugin to use the speech recognizer `stop` 
  method even on SDK versions where that might fail. See https://github.com/csdcorp/speech_to_text/issues/150
  * `SpeechToText.androidIntentLookup` looks up the intent name instead of using the default. This can work around 
  some issues with security exceptions when trying to use the default. See 
  https://github.com/csdcorp/speech_to_text/issues/153

### Fix
  * Phones that don't report extra languages no longer hang on `locales` call

## 3.0.1

### Fix
  * Minor static code analysis improvements (addicted to pub points)

## 3.0.0

### New
  * Now using a platform interface to prepare for web support. Although this should not 
  cause any functional changes it is a major refactoring. 

### Fix
  * Android `stop` now completes even if not initialized
  * iOS onDevice initialization is more reliable
  * No longer crashes on iOS version < 10

## 2.7.0

### New
  * the example had `onDevice` true which is a rarely used flag and was causing confusion 
  * the `partialResults` option for the `SpeechToTextProvider.listen` was defaulted to `false` 
  which is a less common usage and didn't match the default for `SpeechToText.listen` so it 
  has been changed to `true`

## 2.6.0

### New
  * new parameter `onDevice` on the `SpeechToTextProvider` `listen` method supports forcing offline 
  recognition. 
  * Added a new Tips section to the README doc to answer some common questions. 
### Fix
  * Android now correctly returns multiple possible matches with confidence
  * Android now supports the `onDevice` flag properly, note that at least some Android devices need 
  an offline language pack installed for each target language to enable offline recognition. 

## 2.5.0

### New
  * new parameter `localeId` on the `SpeechToTextProvider` `listen` method supports selecting a 
  non default languge for the recognizer when using the provider. 
### Fix
  * A work around for a bug in Android 10(29) that made `stop` and `cancel` not work. The plugin now
  calls `destroy` on the Android `SpeechRecognizer` which terminates the listen session immediately. 
  There is a downside to this approach in that it does not always report results that were in process 
  when `destroy` was called, however it does mean that `stop` works. 
  * The example for `SpeechToTextProvider`, `provider_example.dart` had an error that made it always 
  use the default language and ignore the drop-down selection. This has been corrected. 

## 2.4.1

### Fix
  * Updated the version number in the readme file, which I forget to do, every single time.

## 2.4.0

### New
  * new parameter `sampleRate` on the `listen` method supports some older iOS devices by allowing
  customization to support the expected hardware sample rate. 44100 works with some older devices. 
### Fix
  * `pauseFor` now times out closer to the expected time and more reliably. Duplicate partial results were 
  causing it to extend previously. 
  * `finalResult` is now reliably true on the last result on iOS when `pauseFor` or `listenFor` timeout or 
  `stop` is called directly. Previously it would only return true when the stop happened almost immediately 


## 2.3.0

### New
  * new parameter `onDevice` on the `listen` method enforces on device recognition for sensitive content
  * onSoundLevelChange now supported on iOS
  * added compile troubleshooting help to README.md
  * `SpeechToTextProvider` is an alternate and simpler way to interact with the `SpeechToText` plugin.
  * new `provider_example.dart` example for usage of `SpeechToTextProvider`. 
### Fix
  * on iOS handles some conflicts with other applications better to keep speech working after calls for example


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
