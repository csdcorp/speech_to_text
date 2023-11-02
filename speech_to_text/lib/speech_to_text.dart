import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

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

/// A single locale with a [name], localized to the current system locale,
/// and a [localeId] which can be used in the [SpeechToText.listen] method to choose a
/// locale for speech recognition.
class LocaleName {
  final String localeId;
  final String name;

  LocaleName(this.localeId, this.name);
}

/// Notified as words are recognized with the current set of recognized words.
///
/// See the [onResult] argument on the [SpeechToText.listen] method for use.
typedef SpeechResultListener = void Function(SpeechRecognitionResult result);

/// Notified if errors occur during recognition or initialization.
///
/// Possible errors per the Android docs are described here:
/// https://developer.android.com/reference/android/speech/SpeechRecognizer
/// * "error_audio_error"
/// * "error_client"
/// * "error_permission"
/// * "error_network"
/// * "error_network_timeout"
/// * "error_no_match"
/// * "error_busy"
/// * "error_server"
/// * "error_speech_timeout"
/// * "error_language_not_supported"
/// * "error_language_unavailable"
/// * "error_server_disconnected"
/// * "error_too_many_requests"
///
/// iOS errors are not well documented in the iOS SDK, so far these are the
/// errors that have been observed:
/// * "error_speech_recognizer_disabled"
/// * "error_retry"
/// * "error_no_match"
///
/// Both platforms use this message for an unrecognized error:
/// * "error_unknown ($errorCode)" where `$errorCode` provides more detail
///
/// See the [onError] argument on the [SpeechToText.initialize] method for use.
typedef SpeechErrorListener = void Function(
    SpeechRecognitionError errorNotification);

/// Notified when recognition status changes.
///
/// See the [onStatus] argument on the [SpeechToText.initialize] method for use.
typedef SpeechStatusListener = void Function(String status);

/// Notified when the sound level changes during a listen method.
///
/// [level] is a measure of the decibels of the current sound on
/// the recognition input. See the [onSoundLevelChange] argument on
/// the [SpeechToText.listen] method for use.
typedef SpeechSoundLevelChange = Function(double level);

/// An interface to device specific speech recognition services.
///
/// The general flow of a speech recognition session is as follows:
/// ```Dart
/// SpeechToText speech = SpeechToText();
/// bool isReady = await speech.initialize();
/// if ( isReady ) {
///   await speech.listen( resultListener: resultListener );
/// }
/// ...
/// // At some point later
/// speech.stop();
/// ```
class SpeechToText {
  static const String listenMethod = 'listen';
  static const String textRecognitionMethod = 'textRecognition';
  static const String notifyErrorMethod = 'notifyError';
  static const String notifyStatusMethod = 'notifyStatus';
  static const String soundLevelChangeMethod = 'soundLevelChange';
  static const String listeningStatus = 'listening';
  static const String notListeningStatus = 'notListening';
  static const String doneStatus = 'done';

  /// This one is kind of a faux status, it's used internally
  /// to tell the status notifier that the final result has been seen
  /// since the status notifier wants to tell the world that it is 'done'
  /// only when both the final result and the done from the underlying platform
  /// has been seen.
  static const String _finalStatus = 'final';

  /// Sent when speech recognition completes with no results having been seen
  /// This allows the done status to be sent from the plugin to clients
  /// even without a final speech result.
  static const String _doneNoResultStatus = 'doneNoResult';
  static const defaultFinalTimeout = Duration(milliseconds: 2000);
  static const _minFinalTimeout = Duration(milliseconds: 50);

  /// on Android SDK 29 the recognizer stop method did not work properly so the
  /// plugin destroys the recognizer instead. If this causes problems
  /// this option overrides that behaviour and forces the plugin to use
  /// the stop command instead, even on SDK 29.
  static final SpeechConfigOption androidAlwaysUseStop =
      SpeechConfigOption('android', 'alwaysUseStop', true);

  /// Some Android builds do not properly define the default speech
  /// recognition intent. This option forces a workaround to lookup the
  /// intent by querying the intent manager.
  static final SpeechConfigOption androidIntentLookup =
      SpeechConfigOption('android', 'intentLookup', true);

  /// If your application does not need Bluetooth support on Android and
  /// you'd rather not have to ask for Bluetooth permission pass this option
  /// to disable Bluetooth support on Android.
  static final SpeechConfigOption androidNoBluetooth =
      SpeechConfigOption('android', 'noBluetooth', true);

  /// This option does nothing yet, may disable Bluetooth on iOS if there is
  /// a need.
  static final SpeechConfigOption iosNoBluetooth =
      SpeechConfigOption('ios', 'noBluetooth', true);

  static final SpeechToText _instance = SpeechToText.withMethodChannel();
  bool _initWorked = false;

  /// True when any words have been recognized during the current listen session.
  bool _recognized = false;

  /// True as soon as the platform reports it has started listening which
  /// happens some time after the listen method is called.
  bool _listening = false;
  bool _cancelOnError = false;

  /// True if the user has requested to cancel recognition when a permanent
  /// error occurs.
  bool _partialResults = false;

  /// True when the results callback has already been called with a
  /// final result.
  bool _notifiedFinal = false;

  /// True when the internal status callback has been called with the
  /// done status. Note that this does not mean the user callback has
  /// been called since that is only called after the final result has been
  /// seen.
  bool _notifiedDone = false;

  int _listenStartedAt = 0;
  int _lastSpeechEventAt = 0;
  Duration? _pauseFor;
  Duration? _listenFor;
  Duration _finalTimeout = defaultFinalTimeout;

  /// True if not listening or the user called cancel / stop, false
  /// if cancel/stop were invoked by timeout or error condition.
  bool _userEnded = false;
  String _lastRecognized = '';
  String _lastStatus = '';
  double _lastSoundLevel = 0;
  Timer? _listenTimer;
  Timer? _notifyFinalTimer;
  LocaleName? _systemLocale;
  SpeechRecognitionError? _lastError;
  SpeechRecognitionResult? _lastSpeechResult;
  SpeechResultListener? _resultListener;
  SpeechErrorListener? errorListener;
  SpeechStatusListener? statusListener;
  SpeechSoundLevelChange? _soundLevelChange;

  factory SpeechToText() => _instance;

  @visibleForTesting
  SpeechToText.withMethodChannel();

  /// True if words have been recognized during the current [listen] call.
  ///
  /// Goes false as soon as [cancel] is called.
  bool get hasRecognized => _recognized;

  /// The last set of recognized words received.
  ///
  /// This is maintained across [cancel] calls but cleared on the next
  /// [listen].
  String get lastRecognizedWords => _lastRecognized;

  /// The last status update received, see [initialize] to register
  /// an optional listener to be notified when this changes.
  String get lastStatus => _lastStatus;

  /// The last sound level received during a listen event.
  ///
  /// The sound level is a measure of how loud the current
  /// input is during listening. Use the [onSoundLevelChange]
  /// argument in the [listen] method to get notified of
  /// changes.
  double get lastSoundLevel => _lastSoundLevel;

  /// True if [initialize] succeeded
  bool get isAvailable => _initWorked;

  /// True if [listen] succeeded and [stop] or [cancel] has not been called.
  ///
  /// Also goes false when listening times out if listenFor was set.
  bool get isListening => _listening;

  bool get isNotListening => !isListening;

  /// The last error received or null if none, see [initialize] to
  /// register an optional listener to be notified of errors.
  SpeechRecognitionError? get lastError => _lastError;

  /// True if an error has been received, see [lastError] for details
  bool get hasError => null != lastError;

  /// Returns true if the user has already granted permission to access the
  /// microphone, does not prompt the user.
  ///
  /// This method can be called before [initialize] to check if permission
  /// has already been granted. If this returns false then the [initialize]
  /// call will prompt the user for permission if it is allowed to do so.
  /// Note that applications cannot ask for permission again if the user has
  /// denied them permission in the past.
  Future<bool> get hasPermission async {
    var hasPermission = await SpeechToTextPlatform.instance.hasPermission();
    return hasPermission;
  }

  /// Initialize speech recognition services, returns true if
  /// successful, false if failed.
  ///
  /// This method must be called before any other speech functions.
  ///
  /// If this method returns false no further [SpeechToText] methods
  /// should be used. Should only be called once if successful but does protect
  /// itself if called repeatedly. False usually means that the user has denied
  /// permission to use speech. The usual option in that case is to give them
  /// instructions on how to open system settings and grant permission.
  ///
  /// [onError] is an optional listener for errors like
  /// timeout, or failure of the device speech recognition.
  ///
  /// [onStatus] is an optional listener for status changes. There are three
  /// possible status values:
  /// * `listening` when speech recognition begins after calling the [listen]
  /// method.
  /// * `notListening` when speech recognition is no longer listening to the
  /// microphone after a timeout, [cancel] or [stop] call.
  /// * `done` when all results have been delivered.
  ///
  /// [debugLogging] controls whether there is detailed logging from the
  /// underlying platform code. It is off by default, usually only useful
  /// for troubleshooting issues with a particular OS version or device,
  /// fairly verbose
  ///
  /// [finalTimeout] a duration to wait for a final result from the device
  /// speech recognition service. If no final result is received within this
  /// time the last partial result is returned as final. This defaults to
  /// two seconds. A duration of fifty milliseconds or less disables the
  /// check and final results will only be returned from the device.
  ///
  /// [options] pass platform specific configuration options to the
  /// platform specific implementation.
  Future<bool> initialize(
      {SpeechErrorListener? onError,
      SpeechStatusListener? onStatus,
      debugLogging = false,
      Duration finalTimeout = defaultFinalTimeout,
      List<SpeechConfigOption>? options}) async {
    if (_initWorked) {
      return Future.value(_initWorked);
    }
    _finalTimeout = finalTimeout;
    if (finalTimeout <= _minFinalTimeout) {}
    errorListener = onError;
    statusListener = onStatus;
    SpeechToTextPlatform.instance.onTextRecognition = _onTextRecognition;
    SpeechToTextPlatform.instance.onError = _onNotifyError;
    SpeechToTextPlatform.instance.onStatus = _onNotifyStatus;
    SpeechToTextPlatform.instance.onSoundLevel = _onSoundLevelChange;
    _initWorked = await SpeechToTextPlatform.instance
        .initialize(debugLogging: debugLogging, options: options);
    return _initWorked;
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
  Future<void> stop() async {
    _userEnded = true;
    return _stop();
  }

  Future<void> _stop() async {
    if (!_initWorked) {
      return;
    }
    // print('Stop triggered');
    _shutdownListener();
    await SpeechToTextPlatform.instance.stop();
    if (_finalTimeout > _minFinalTimeout) {
      _notifyFinalTimer = Timer(_finalTimeout, _onFinalTimeout);
    }
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
  Future<void> cancel() async {
    _userEnded = true;
    return _cancel();
  }

  Future<void> _cancel() async {
    if (!_initWorked) {
      return;
    }
    _shutdownListener();
    await SpeechToTextPlatform.instance.cancel();
  }

  /// Starts a listening session for speech and converts it to text,
  /// invoking the provided [onResult] method as words are recognized.
  ///
  /// Cannot be used until a successful [initialize] call. There is a
  /// time limit on listening imposed by both Android and iOS. The time
  /// depends on the device, network, etc. Android is usually quite short,
  /// especially if there is no active speech event detected, on the order
  /// of ten seconds or so.
  ///
  /// When listening is done always invoke either [cancel] or [stop] to
  /// end the session, even if it times out. [cancelOnError] provides an
  /// automatic way to ensure this happens.
  ///
  /// [onResult] is an optional listener that is notified when words
  /// are recognized.
  ///
  /// [listenFor] sets the maximum duration that it will listen for, after
  /// that it automatically stops the listen for you. The system may impose
  /// a shorter maximum listen due to resource limitations or other reasons.
  /// The plugin ensures that listening is no longer than this but it may be
  /// shorter.
  ///
  /// [pauseFor] sets the maximum duration of a pause in speech with no words
  /// detected, after that it automatically stops the listen for you. On some
  /// systems, notably Android, there is a system imposed pause of from one to
  /// three seconds that cannot be overridden. The plugin ensures that the
  /// pause is no longer than the pauseFor value but it may be shorter.
  ///
  /// [localeId] is an optional locale that can be used to listen in a language
  /// other than the current system default. See [locales] to find the list of
  /// supported languages for listening.
  ///
  /// [onSoundLevelChange] is an optional listener that is notified when the
  /// sound level of the input changes. Use this to update the UI in response to
  /// more or less input. The values currently differ between Android and iOS,
  /// haven't yet been able to determine from the Android documentation what the
  /// value means. On iOS the value returned is in decibels.
  ///
  /// [cancelOnError] if true then listening is automatically canceled on a
  /// permanent error. This defaults to false. When false cancel should be
  /// called from the error handler.
  ///
  /// [partialResults] if true the listen reports results as they are recognized,
  /// when false only final results are reported. Defaults to true.
  ///
  /// [onDevice] if true the listen attempts to recognize locally with speech never
  /// leaving the device. If it cannot do this the listen attempt will fail. This is
  /// usually only needed for sensitive content where privacy or security is a concern.
  ///
  /// [listenMode] tunes the speech recognition engine to expect certain
  /// types of spoken content. It defaults to [ListenMode.confirmation] which
  /// is the most common use case, words or short phrases to confirm a command.
  /// [ListenMode.dictation] is for longer spoken content, sentences or
  /// paragraphs, while [ListenMode.search] expects a sequence of search terms.
  ///
  /// [sampleRate] optional for compatibility with certain iOS devices, some devices
  /// crash with `sampleRate != device's supported sampleRate`, try 44100 if seeing
  /// crashes.
  Future listen(
      {SpeechResultListener? onResult,
      Duration? listenFor,
      Duration? pauseFor,
      String? localeId,
      SpeechSoundLevelChange? onSoundLevelChange,
      cancelOnError = false,
      partialResults = true,
      onDevice = false,
      ListenMode listenMode = ListenMode.confirmation,
      sampleRate = 0}) async {
    if (!_initWorked) {
      throw SpeechToTextNotInitializedException();
    }
    _lastError = null;
    _lastRecognized = '';
    _userEnded = false;
    _lastSpeechResult = null;
    _cancelOnError = cancelOnError;
    _recognized = false;
    _notifiedFinal = false;
    _notifiedDone = false;
    _resultListener = onResult;
    _soundLevelChange = onSoundLevelChange;
    _partialResults = partialResults;
    _notifyFinalTimer?.cancel();
    _notifyFinalTimer = null;
    try {
      var started = await SpeechToTextPlatform.instance.listen(
          partialResults: partialResults || null != pauseFor,
          onDevice: onDevice,
          listenMode: listenMode.index,
          sampleRate: sampleRate,
          localeId: localeId);
      if (started) {
        _listenStartedAt = clock.now().millisecondsSinceEpoch;
        _lastSpeechEventAt = _listenStartedAt;
        _setupListenAndPause(pauseFor, listenFor);
      }
    } on PlatformException catch (e) {
      throw ListenFailedException(e.message, e.details, e.stacktrace);
    }
  }

  /// Call this while [listen] is active to change the pauseFor duration.
  /// This will restart the timer for the new duration. It is useful for
  /// allowing a long first pause then dynamically shortening it once
  /// the user starts speaking.
  void changePauseFor(Duration pauseFor) {
    //Setup new pauseFor only if listen is active and pauseFor is different
    if (isNotListening) {
      throw ListenNotStartedException();
    }

    if (_pauseFor != pauseFor) {
      _listenTimer?.cancel();
      _listenTimer = null;
      // ignoreElapsePause ensures that the timer waits for the full pauseFor
      // duration before stopping the listen
      _setupListenAndPause(pauseFor, _listenFor, ignoreElapsedPause: true);
    }
  }

  void _setupListenAndPause(
      Duration? initialPauseFor, Duration? initialListenFor,
      {bool ignoreElapsedPause = false}) {
    _pauseFor = null;
    _listenFor = null;
    if (null == initialPauseFor && null == initialListenFor) {
      return;
    }
    var pauseFor = initialPauseFor;
    var listenFor = initialListenFor;
    if (null != pauseFor) {
      var remainingMillis = pauseFor.inMilliseconds -
          (ignoreElapsedPause ? 0 : _elapsedSinceSpeechEvent);
      pauseFor = Duration(milliseconds: max(remainingMillis, 0));
    }
    if (null != listenFor) {
      var remainingMillis = listenFor.inMilliseconds - _elapsedListenMillis;
      listenFor = Duration(milliseconds: max(remainingMillis, 0));
    }
    Duration minDuration;
    if (null == pauseFor) {
      _listenFor = Duration(milliseconds: listenFor!.inMilliseconds);
      minDuration = listenFor;
    } else if (null == listenFor) {
      _pauseFor = Duration(milliseconds: pauseFor.inMilliseconds);
      minDuration = pauseFor;
    } else {
      _listenFor = Duration(milliseconds: listenFor.inMilliseconds);
      _pauseFor = Duration(milliseconds: pauseFor.inMilliseconds);
      var minMillis = min(listenFor.inMilliseconds - _elapsedListenMillis,
          pauseFor.inMilliseconds);
      minDuration = Duration(milliseconds: minMillis);
    }
    // print('Waiting for ${minDuration.inMilliseconds}');
    _listenTimer = Timer(minDuration, _stopOnPauseOrListen);
  }

  /// Milliseconds since the last listen was started, this is used for
  /// the listen for calculations
  int get _elapsedListenMillis =>
      clock.now().millisecondsSinceEpoch - _listenStartedAt;

  /// Milliseconds since the last speech event was detected, this
  /// is used for the pause calculations
  int get _elapsedSinceSpeechEvent =>
      clock.now().millisecondsSinceEpoch - _lastSpeechEventAt;

  void _stopOnPauseOrListen() {
    // print('Stop? $_elapsedListenMillis / $_elapsedSinceSpeechEvent');
    var listenFor = _listenFor;
    var pauseFor = _pauseFor;
    if (null != listenFor && _elapsedListenMillis >= listenFor.inMilliseconds) {
      _stop();
    } else if (null != pauseFor &&
        _elapsedSinceSpeechEvent >= pauseFor.inMilliseconds) {
      _stop();
    } else {
      _setupListenAndPause(_pauseFor, _listenFor);
    }
  }

  /// Returns the list of speech locales available on the device or those
  /// supported by the speech recognizer on the device.
  ///
  /// Being on this list does not guarantee that the device will be able to
  /// recognize the locale. It is just a list of locales that the device can
  /// recognize if the language is installed. You may have to advise users
  /// of your application to install their desired language on their device.
  ///
  /// This method is useful to find the identifier to use
  /// for the [listen] method, it is the [localeId] member of the
  /// [LocaleName].
  ///
  /// Each [LocaleName] in the returned list has the
  /// identifier for the locale as well as a name for
  /// display. The name is localized for the system locale on
  /// the device.
  ///
  /// Android: The list of languages is based on the locales supported by
  /// the on device recognizer. This list may not be the complete list of
  /// languages available for online recognition. Unfortunately there is no
  /// way to get the list of languages supported by the online recognizer.
  Future<List<LocaleName>> locales() async {
    final locales = await SpeechToTextPlatform.instance.locales();
    var filteredLocales = locales
        .map((locale) {
          var components = locale.split(':');
          if (components.length != 2) {
            return null;
          }
          return LocaleName(components[0], components[1]);
        })
        .where((item) => item != null)
        .toList()
        .cast<LocaleName>();
    if (filteredLocales.isNotEmpty) {
      _systemLocale = filteredLocales.first;
    } else {
      _systemLocale = null;
    }
    filteredLocales.sort((ln1, ln2) => ln1.name.compareTo(ln2.name));
    return filteredLocales;
  }

  /// Returns the locale that will be used if no localeId is passed
  /// to the [listen] method.
  Future<LocaleName?> systemLocale() async {
    if (null == _systemLocale) {
      await locales();
    }
    return Future.value(_systemLocale);
  }

  void _onTextRecognition(String resultJson) {
    // print('onTextRecognition');
    Map<String, dynamic> resultMap = jsonDecode(resultJson);
    var speechResult = SpeechRecognitionResult.fromJson(resultMap);
    _notifyResults(speechResult);
  }

  void _onFinalTimeout() {
    // print('onFinalTimeout $_finalTimeout');
    if (_notifiedFinal) return;
    if (_lastSpeechResult != null && null != _resultListener) {
      var finalResult = _lastSpeechResult!.toFinal();
      _notifyResults(finalResult);
    }
  }

  void _notifyResults(SpeechRecognitionResult speechResult) {
    if (_notifiedFinal) return;
    if (_lastSpeechResult == null || _lastSpeechResult != speechResult) {
      _lastSpeechEventAt = clock.now().millisecondsSinceEpoch;
    }
    _lastSpeechResult = speechResult;
    if (!_partialResults && !speechResult.finalResult) {
      return;
    }
    _recognized = true;
    // print("Recognized text $resultJson");

    _lastRecognized = speechResult.recognizedWords;
    if (speechResult.finalResult) {
      _notifyFinalTimer?.cancel();
      _notifyFinalTimer = null;
      // This ensures we only notify with one final result
      _notifiedFinal = true;
    }
    if (null != _resultListener) {
      _resultListener!(speechResult);
    }
    if (_notifiedFinal) {
      _onNotifyStatus(_finalStatus);
    }
  }

  Future<void> _onNotifyError(String errorJson) async {
    if (isNotListening && _userEnded) {
      return;
    }
    Map<String, dynamic> errorMap = jsonDecode(errorJson);
    var speechError = SpeechRecognitionError.fromJson(errorMap);
    _lastError = speechError;
    if (null != errorListener) {
      errorListener!(speechError);
    }
    if (_cancelOnError && speechError.permanent) {
      await _cancel();
    }
  }

  void _onNotifyStatus(String status) {
    // print('status $status');
    switch (status) {
      case doneStatus:
        _notifiedDone = true;
        if (!_notifiedFinal) return;
        break;
      case _finalStatus:
        if (!_notifiedDone) return;

        // the [_finalStatus] is just to indicate that it can send the
        // [doneStatus] if [_notifiedDone] has already happened.
        status = doneStatus;
        break;
      case _doneNoResultStatus:
        _notifiedDone = true;
        status = doneStatus;
        break;
    }
    _lastStatus = status;
    _listening = status == listeningStatus;
    // print(status);
    if (null != statusListener) {
      statusListener!(status);
    }
  }

  void _onSoundLevelChange(double level) {
    if (isNotListening) {
      return;
    }
    _lastSoundLevel = level;
    if (null != _soundLevelChange) {
      _soundLevelChange!(level);
    }
  }

  void _shutdownListener() {
    _listening = false;
    _recognized = false;
    _listenTimer?.cancel();
    _listenTimer = null;
    _notifyFinalTimer?.cancel();
    _notifyFinalTimer = null;
    _listenTimer = null;
  }
}

/// Thrown when a method is called that requires successful
/// initialization first.
class SpeechToTextNotInitializedException implements Exception {}

/// Thrown when listen fails to properly start a speech listening session
/// on the device.
class ListenFailedException implements Exception {
  final String? message;
  final String? details;
  final String? stackTrace;

  ListenFailedException(this.message, [this.details, this.stackTrace]);
}

class ListenNotStartedException implements Exception {}
