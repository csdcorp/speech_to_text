# Changelog

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
