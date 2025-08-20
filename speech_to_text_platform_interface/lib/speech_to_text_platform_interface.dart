import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_speech_to_text.dart';

/// Holds a configuration option for a specific platform implementation.
///
/// These options should be used rarely as the plugin interface should
/// try, as far as possible, to be identical on all platforms. These
/// options allow specific behaviour only available on or required on
/// a platform to be tailored.
class SpeechConfigOption {
  /// Defines the platform implementation the option is for, this is
  /// meaningful only to the implementation.
  final String platform;

  /// The name of the option, meaningful only to the implementation.
  final String name;

  /// Value of the option, meaningful only to the implementation.
  final dynamic value;

  SpeechConfigOption(this.platform, this.name, this.value);
}

/// Describes the goal of your speech recognition to the system.
///
/// Currently only supported on **iOS**.
///
/// See also:
/// * https://developer.apple.com/documentation/speech/sfspeechrecognitiontaskhint
enum ListenMode {
  /// The device default.
  deviceDefault,

  /// When using captured speech for text entry.
  ///
  /// Use this when you are using speech recognition for a task that's similar to the keyboard's built-in dictation function.
  dictation,

  /// When using captured speech to specify search terms.
  ///
  /// Use this when you are using speech recognition to identify search terms.
  search,

  /// When using captured speech for short, confirmation-style requests.
  ///
  /// Use this when you are using speech recognition to handle confirmation commands, such as "yes", "no" or "maybe".
  confirmation,
}

/// Options for the [listen] method. Previously options were provided as
/// separate parameters to listen however as the number of options grew
/// this became unwieldy. The options are now provided as a single object
/// with named parameters. The old style is still supported but deprecated.
/// If both are used the old style arguments are ignored.
class SpeechListenOptions {
  final cancelOnError;
  final partialResults;
  final onDevice;
  final ListenMode listenMode;
  final sampleRate;
  final autoPunctuation;
  final enableHapticFeedback;
  final Duration? pauseFor;
  final Duration? listenFor;
  final String? localeId;

  SpeechListenOptions({
    /// If true the listen session will automatically be canceled on a permanent error.
    this.cancelOnError = false,

    /// If true the listen session will report partial results as they
    /// are recognized. When false only the final results will be reported.
    this.partialResults = true,

    /// If true the listen session will only use on device recognition. If
    /// it cannot do this the listen attempt will fail. This is usually only
    /// needed for sensitive content where privacy or security is a concern.
    /// If false the listen session will use both on device and network
    /// recognition.
    this.onDevice = false,

    /// The listen mode to use, currently only supported on iOS.
    this.listenMode = ListenMode.confirmation,

    /// The sample rate to use, currently only needed on iOS for some use
    /// cases. Occasionally some devices crash with `sampleRate != device's
    /// supported sampleRate`, try 44100 if seeing crashes.
    this.sampleRate = 0,

    /// If true the listen session will automatically add punctuation to
    /// the recognized text. This is only supported on iOS.
    this.autoPunctuation = false,

    /// If true haptic feedback will be enabled during the listen session.
    /// Usually haptics are suppressed during speech recognition to avoid
    /// interference with the microphone. Currently only supported on iOS.
    this.enableHapticFeedback = false,

    /// The length of time to pause before the speech input is considered
    /// complete. This is used to determine when to stop listening for speech
    /// input.
    this.pauseFor = null,

    /// The length of time to listen for speech input before stopping.
    /// This is used to limit the duration of the listen session. If null,
    /// the listen session will continue until the user stops it or a timeout
    /// occurs.
    this.listenFor = null,

    /// The locale to use for the listen session, if null the system default
    /// locale will be used. This is only supported on iOS and Android.
    this.localeId = null,
  });

  SpeechListenOptions copyWith({
    bool? cancelOnError,
    bool? partialResults,
    bool? onDevice,
    ListenMode? listenMode,
    int? sampleRate,
    bool? autoPunctuation,
    bool? enableHapticFeedback,
    Duration? pauseFor,
    Duration? listenFor,
    String? localeId,
  }) {
    return SpeechListenOptions(
        cancelOnError: cancelOnError ?? this.cancelOnError,
        partialResults: partialResults ?? this.partialResults,
        onDevice: onDevice ?? this.onDevice,
        listenMode: listenMode ?? this.listenMode,
        sampleRate: sampleRate ?? this.sampleRate,
        autoPunctuation: autoPunctuation ?? this.autoPunctuation,
        enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
        pauseFor: pauseFor ?? this.pauseFor,
        listenFor: listenFor ?? this.listenFor,
        localeId: localeId ?? this.localeId);
  }
}

/// The interface that implementations of url_launcher must implement.
///
/// Platform implementations should extend this class rather than implement it as `speech_to_text`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [SpeechToTextPlatform] methods.
abstract class SpeechToTextPlatform extends PlatformInterface {
  /// Constructs a SpeechToTextPlatform.
  SpeechToTextPlatform() : super(token: _token);

  static final Object _token = Object();

  static SpeechToTextPlatform _instance = MethodChannelSpeechToText();

  /// The default instance of [SpeechToTextPlatform] to use.
  ///
  /// Defaults to [MethodChannelSpeechToText].
  static SpeechToTextPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [SpeechToTextPlatform] when they register themselves.
  static set instance(SpeechToTextPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  void Function(String results)? onTextRecognition;
  void Function(String error)? onError;
  void Function(String status)? onStatus;
  void Function(double level)? onSoundLevel;

  /// Returns true if the user has already granted permission to access the
  /// microphone, does not prompt the user.
  ///
  /// This method can be called before [initialize] to check if permission
  /// has already been granted. If this returns false then the [initialize]
  /// call will prompt the user for permission if it is allowed to do so.
  /// Note that applications cannot ask for permission again if the user has
  /// denied them permission in the past.
  Future<bool> hasPermission() {
    throw UnimplementedError('hasPermission() has not been implemented.');
  }

  /// Initialize speech recognition services, returns true if
  /// successful, false if failed.
  ///
  /// This method must be called before any other speech functions.
  /// If this method returns false no further [SpeechToText] methods
  /// should be used. False usually means that the user has denied
  /// permission to use speech.
  ///
  /// [options] can be used to control the behaviour of platform specific
  /// implementations.
  ///
  /// [debugLogging] controls whether there is detailed logging from the underlying
  /// plugins. It is off by default, usually only useful for troubleshooting issues
  /// with a particular OS version or device, fairly verbose
  Future<bool> initialize(
      {debugLogging = false, List<SpeechConfigOption>? options}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Stops the current listen for speech if active, does nothing if not.
  ///
  /// Stopping a listen session will cause a final result to be sent. Each
  /// listen session should be ended with either [stop] or [cancel], for
  /// example in the dispose method of a Widget. [cancel] is automatically
  /// invoked by a permanent error if [cancelOnError] is set to true in the
  /// [listen] call.
  ///
  /// *Note:* Cannot be used until a successful [initialize] call. Should
  /// only be used after a successful [listen] call.
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Cancels the current listen for speech if active, does nothing if not.
  ///
  /// Canceling means that there will be no final result returned from the
  /// recognizer. Each listen session should be ended with either [stop] or
  /// [cancel], for example in the dispose method of a Widget. [cancel] is
  /// automatically invoked by a permanent error if [cancelOnError] is set
  /// to true in the [listen] call.
  ///
  /// *Note* Cannot be used until a successful [initialize] call. Should only
  /// be used after a successful [listen] call.
  Future<void> cancel() {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  /// Starts a listening session for speech and converts it to text.
  ///
  /// Cannot be used until a successful [initialize] call. There is a
  /// time limit on listening imposed by both Android and iOS. The time
  /// depends on the device, network, etc. Android is usually quite short,
  /// especially if there is no active speech event detected, on the order
  /// of ten seconds or so.
  ///
  /// [localeId] is an optional locale that can be used to listen in a language
  /// other than the current system default. See [locales] to find the list of
  /// supported languages for listening.
  ///
  /// [partialResults] if true the listen reports results as they are recognized,
  /// when false only final results are reported. Defaults to true.
  ///
  /// [onDevice] if true the listen attempts to recognize locally with speech never
  /// leaving the device. If it cannot do this the listen attempt will fail. This is
  /// usually only needed for sensitive content where privacy or security is a concern.
  ///
  /// [sampleRate] optional for compatibility with certain iOS devices, some devices
  /// crash with `sampleRate != device's supported sampleRate`, try 44100 if seeing
  /// crashes
  ///
  Future<bool> listen(
      {String? localeId,
      @Deprecated('Use SpeechListenOptions.partialResults instead')
      partialResults = true,
      @Deprecated('Use SpeechListenOptions.onDevice instead') onDevice = false,
      @Deprecated('Use SpeechListenOptions.listenMode instead')
      int listenMode = 0,
      @Deprecated('Use SpeechListenOptions.sampleRate instead') sampleRate = 0,
      SpeechListenOptions? options}) {
    throw UnimplementedError('listen() has not been implemented.');
  }

  /// returns the list of speech locales available on the device.
  ///
  Future<List<dynamic>> locales() {
    throw UnimplementedError('locales() has not been implemented.');
  }
}
