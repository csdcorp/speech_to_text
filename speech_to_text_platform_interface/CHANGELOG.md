## Unreleased
- New `preserveExistingAudioSession` property on `SpeechListenOptions`,
  **defaults to `true`**. When true, an existing `.playback`,
  `.playAndRecord`, or `.multiRoute` audio session that predated
  recognition is kept ACTIVE on `stop` instead of being deactivated —
  fixes the pre-existing behavior where STT could tear down an unrelated
  media / call / WebRTC / LiveKit session on the shared process-wide
  `AVAudioSession`. Standalone STT apps (no other media session in
  play) see identical behavior with the default: their pre-recognition
  category is typically `.soloAmbient`, which isn't in the preserve list,
  so the code falls through to the historical deactivation path. Set to
  `false` explicitly if you have a specific reason to force deactivation
  of another subsystem's audio session at recognition end. Forwarded to
  platforms as the `preserveExistingAudioSession` listen-method argument;
  iOS implements the behavior, other platforms currently ignore the flag.

## 2.5.0
- Added hasOnDeviceSupport, so callers can check whether the device can
  recognize speech offline before requesting onDevice recognition
- New `contextualPhrases` property on `SpeechListenOptions` for biasing
  recognition toward domain-specific vocabulary. Forwarded to platforms as
  the `contextualPhrases` listen-method argument.

## 2.4.0
- New properties on SpeechListenOptions for pauseFor, listenFor and localeId

## 2.3.0
- Added copyWith to SpeechListenOptions

## 2.2.0
- Added options for listen method in place of separate parameters

## 2.1.0
- Updated for Flutter 3.0

## 2.0.1
- fix test method deprecation

## 2.0.0
- null safety / flutter 2.0 compatability is now the main release

## 2.0.0-nullsafety
- prerelease for null safety / flutter 2.0 compatability

## 1.4.2
- bug fix for null options

## 1.4.1
- uses platform options in method channel call

## 1.4.0
- platform specific configuration properties added to initialize

## 1.3.0
- listen changed to bool

## 1.2.0
- Added callback methods

## 1.1.0
- Changed argument types before release
- removed `launch` 

## 1.0.0
- Initial open-source release.