import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Notified as words are recognized with the current set of recognized words.
///
/// See the [onResult] argument on the [listen] method for use.
typedef SpeechResultListener = void Function(SpeechRecognitionResult result);

/// Notified if errors occur during recognition or intialization.
///
/// Possible errors per the Android docs are described here:
/// https://developer.android.com/reference/android/speech/SpeechRecognizer
///   "error_audio_error"
///   "error_client"
///   "error_permission"
///   "error_network"
///   "error_network_timeout"
///   "error_no_match"
///   "error_busy"
///   "error_server"
///   "error_speech_timeout"
/// See the [onError] argument on the [initialize] method for use.
typedef SpeechErrorListener = void Function(
    SpeechRecognitionError errorNotification);

/// Notified when recognition status changes.
///
/// See the [onStatus] argument on the [initialize] method for use.
typedef SpeechStatusListener = void Function(String status);

/// Notified when the sound level changes during a listen method.
///
/// [level] is a measure of the decibels of the current sound on
/// the recognition input. See the [onSoundLevelChange] argument on
/// the [listen] method for use.
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
  static const String soundLevelChangeMethod = "soundLevelChange";
  static const String notListeningStatus = "notListening";
  static const String listeningStatus = "listening";

  static const MethodChannel speechChannel =
      const MethodChannel('plugin.csdcorp.com/speech_to_text');
  static final SpeechToText _instance =
      SpeechToText.withMethodChannel(speechChannel);
  bool _initWorked = false;
  bool _recognized = false;
  bool _listening = false;
  bool _cancelOnError = false;
  String _lastRecognized = "";
  String _lastStatus = "";
  double _lastSoundLevel = 0;
  Timer _listenTimer;
  LocaleName _systemLocale;
  SpeechRecognitionError _lastError;
  SpeechResultListener _resultListener;
  SpeechErrorListener errorListener;
  SpeechStatusListener statusListener;
  SpeechSoundLevelChange _soundLevelChange;

  final MethodChannel channel;
  factory SpeechToText() => _instance;

  @visibleForTesting
  SpeechToText.withMethodChannel(this.channel);

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
  SpeechRecognitionError get lastError => _lastError;

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
    bool hasPermission = await channel.invokeMethod('has_permission');
    return hasPermission;
  }

  /// Initialize speech recognition services, returns true if
  /// successful, false if failed.
  ///
  /// This method must be called before any other speech functions.
  /// If this method returns false no further [SpeechToText] methods
  /// should be used. Should only be called once if successful but does protect
  /// itself if called repeatedly. False usually means that the user has denied
  /// permission to use speech. The usual option in that case is to give them
  /// instructions on how to open system settings and grant permission.
  ///
  /// [onError] is an optional listener for errors like
  /// timeout, or failure of the device speech recognition.
  /// [onStatus] is an optional listener for status changes from
  /// listening to not listening.
  Future<bool> initialize(
      {SpeechErrorListener onError, SpeechStatusListener onStatus}) async {
    if (_initWorked) {
      return Future.value(_initWorked);
    }
    errorListener = onError;
    statusListener = onStatus;
    channel.setMethodCallHandler(_handleCallbacks);
    _initWorked = await channel.invokeMethod('initialize');
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
    if (!_initWorked) {
      return;
    }
    _shutdownListener();
    await channel.invokeMethod('stop');
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
    if (!_initWorked) {
      return;
    }
    _shutdownListener();
    await channel.invokeMethod('cancel');
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
  /// that it automatically cancels the listen for you.
  ///
  /// [localeId] is an optional locale that can be used to listen in a language
  /// other than the current system default. See [locales] to find the list of
  /// supported languages for listening.
  ///
  /// [onSoundLevelChange] is an optional listener that is notified when the
  /// sound level of the input changes. Use this to update the UI in response to
  /// more or less input. Currently this is only supported on Android.
  ///
  /// [cancelOnError] if true then listening is automatically canceled on a
  /// permanent error. This defaults to false. When false cancel should be
  /// called from the error handler.
  ///
  /// [partialResults] if true the listen reports results as they are recognized,
  /// when false only final results are reported. Defaults to true.
  Future listen(
      {SpeechResultListener onResult,
      Duration listenFor,
      String localeId,
      SpeechSoundLevelChange onSoundLevelChange,
      cancelOnError = false,
      partialResults = true}) async {
    if (!_initWorked) {
      throw SpeechToTextNotInitializedException();
    }
    _cancelOnError = cancelOnError;
    _recognized = false;
    _resultListener = onResult;
    _soundLevelChange = onSoundLevelChange;
    Map<String, dynamic> listenParams = {"partialResults": partialResults};
    if (null != localeId) {
      listenParams["localeId"] = localeId;
    }
    channel.invokeMethod(listenMethod, listenParams);
    if (null != listenFor) {
      _listenTimer = Timer(listenFor, () {
        cancel();
      });
    }
  }

  /// returns the list of speech locales available on the device.
  ///
  /// This method is useful to find the identifier to use
  /// for the [listen] method, it is the [localeId] member of the
  /// [LocaleName].
  ///
  /// Each [LocaleName] in the returned list has the
  /// identifier for the locale as well as a name for
  /// display. The name is localized for the system locale on
  /// the device.
  Future<List<LocaleName>> locales() async {
    if (!_initWorked) {
      throw SpeechToTextNotInitializedException();
    }
    final List<dynamic> locales = await channel.invokeMethod('locales');
    List<LocaleName> filteredLocales = locales
        .map((locale) {
          var components = locale.split(":");
          if (components.length != 2) {
            return null;
          }
          return LocaleName(components[0], components[1]);
        })
        .where((item) => item != null)
        .toList();
    if (filteredLocales.isNotEmpty) {
      _systemLocale = filteredLocales.first;
    } else {
      _systemLocale = null;
    }
    filteredLocales.sort((ln1, ln2) => ln1.name.compareTo(ln2.name));
    return filteredLocales;
  }

  /// returns the locale that will be used if no localeId is passed
  /// to the [listen] method.
  Future<LocaleName> systemLocale() async {
    if (null == _systemLocale) {
      await locales();
    }
    return Future.value(_systemLocale);
  }

  Future _handleCallbacks(MethodCall call) async {
    // print("SpeechToText call: ${call.method} ${call.arguments}");
    switch (call.method) {
      case textRecognitionMethod:
        if (call.arguments is String) {
          _onTextRecognition(call.arguments);
        }
        break;
      case notifyErrorMethod:
        if (call.arguments is String) {
          await _onNotifyError(call.arguments);
        }
        break;
      case notifyStatusMethod:
        if (call.arguments is String) {
          _onNotifyStatus(call.arguments);
        }
        break;
      case soundLevelChangeMethod:
        if (call.arguments is double) {
          _onSoundLevelChange(call.arguments);
        }
        break;
      default:
    }
  }

  void _onTextRecognition(String resultJson) {
    _recognized = true;
    Map<String, dynamic> resultMap = jsonDecode(resultJson);
    SpeechRecognitionResult speechResult =
        SpeechRecognitionResult.fromJson(resultMap);

    _lastRecognized = speechResult.recognizedWords;
    if (null != _resultListener) {
      _resultListener(speechResult);
    }
  }

  Future<void> _onNotifyError(String errorJson) async {
    if (isNotListening) {
      return;
    }
    Map<String, dynamic> errorMap = jsonDecode(errorJson);
    SpeechRecognitionError speechError =
        SpeechRecognitionError.fromJson(errorMap);
    _lastError = speechError;
    if (_cancelOnError && speechError.permanent) {
      await cancel();
    }
    if (null != errorListener) {
      errorListener(speechError);
    }
  }

  void _onNotifyStatus(String status) {
    _lastStatus = status;
    _listening = status == listeningStatus;
    // print(status);
    if (null != statusListener) {
      statusListener(status);
    }
  }

  void _onSoundLevelChange(double level) {
    if (isNotListening) {
      return;
    }
    _lastSoundLevel = level;
    if (null != _soundLevelChange) {
      _soundLevelChange(level);
    }
  }

  _shutdownListener() {
    _listening = false;
    _recognized = false;
    _listenTimer?.cancel();
    _listenTimer = null;
  }

  @visibleForTesting
  Future processMethodCall(MethodCall call) async {
    return await _handleCallbacks(call);
  }
}

/// A single locale with a [name], localized to the current system locale,
/// and a [localeId] which can be used in the [listen] method to choose a
/// locale for speech recognition.
class LocaleName {
  final String localeId;
  final String name;
  LocaleName(this.localeId, this.name);
}

/// Thrown when a method is called that requires successful
/// initialization first. See [onDbReady]
class SpeechToTextNotInitializedException implements Exception {}
