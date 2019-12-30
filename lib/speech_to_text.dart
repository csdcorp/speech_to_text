import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Notified as words are recognized with the current set of recognized words.
typedef SpeechResultListener = void Function(SpeechRecognitionResult result);

/// Notified if errors occur during recognition or intialization.
typedef SpeechErrorListener = void Function(
    SpeechRecognitionError errorNotification);

/// Notified when recognition status changes.
typedef SpeechStatusListener = void Function(String status);

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
  static const String textRecognitionMethod = 'textRecognition';
  static const String notifyErrorMethod = 'notifyError';
  static const String notifyStatusMethod = 'notifyStatus';
  static const String notListeningStatus = "notListening";
  static const String listeningStatus = "listening";
  static const String _onRmsChangedMethod = "onRmsChanged";

  static const MethodChannel speechChannel =
  const MethodChannel('plugin.csdcorp.com/speech_to_text');
  static final SpeechToText _instance =
  SpeechToText.withMethodChannel(speechChannel);
  bool _initWorked = false;
  bool _recognized = false;
  bool _listening = false;
  String _lastRecognized = "";
  String _lastStatus = "";
  Timer _listenTimer;
  LocaleName _systemLocale;
  SpeechRecognitionError _lastError;
  SpeechResultListener _resultListener;
  SpeechErrorListener errorListener;
  SpeechStatusListener statusListener;
  Function(double rms) _rmsChanged;

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

  /// The last status update received
  String get lastStatus => _lastStatus;

  /// True if [initialize] succeeded
  bool get isAvailable => _initWorked;

  /// True if [listen] succeeded and [cancel] has not been called.
  bool get isListening => _listening;

  /// The last error received or null if none
  SpeechRecognitionError get lastError => _lastError;

  /// True if an error has been received, see [lastError] for details
  bool get hasError => null != lastError;

  /// Initialize speech recognition services, returns true if
  /// successful, false if failed.
  ///
  /// This method must be called before any other speech functions.
  /// If this method returns false no further [SpeechToText] methods
  /// should be used. Should only be called once but does protect
  /// itself if called repeatedly.
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
  /// Stopping a listen will cause a final result to be sent. *Note:* Cannot
  /// be used until a successful [initialize] call. Should only be
  /// used after a successful [listen] call.
  Future<void> stop() async {
    if (!_initWorked) {
      return;
    }
    await channel.invokeMethod('stop');
    _shutdownListener();
  }

  /// Notes whether the sound level does not change audio stream.
  onRmsChanged(Function(double rms) rmsChanged) {
    this._rmsChanged = rmsChanged;
  }

  /// Cancels the current listen for speech if active, does nothing if not.
  ///
  /// Canceling means that there will be no final result returned from the
  /// recognizer. *Note* Cannot be used until a successful [initialize] call.
  /// Should only be used after a successful [listen] call.
  Future<void> cancel() async {
    if (!_initWorked) {
      return;
    }
    await channel.invokeMethod('cancel');
    _shutdownListener();
  }

  /// Listen for speech and convert to text invoking the provided [interimListener]
  /// as words are recognized.
  ///
  /// Cannot be used until a successful [initialize] call.
  Future listen(
      {SpeechResultListener onResult,
        Duration listenFor,
        String localeId}) async {
    if (!_initWorked) {
      throw SpeechToTextNotInitializedException();
    }
    _recognized = false;
    _resultListener = onResult;
    if (null != localeId) {
      channel.invokeMethod('listen', localeId);
    } else {
      channel.invokeMethod('listen');
    }
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
    print("SpeechToText call: ${call.method} ${call.arguments}");
    switch (call.method) {
      case textRecognitionMethod:
        if (call.arguments is String) {
          _onTextRecognition(call.arguments);
        }
        break;
      case notifyErrorMethod:
        if (call.arguments is String) {
          _onNotifyError(call.arguments);
        }
        break;
      case notifyStatusMethod:
        if (call.arguments is String) {
          _onNotifyStatus(call.arguments);
        }
        break;
      case _onRmsChangedMethod:
        if (call.arguments is double) {
          _rmsChanged(call.arguments);
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

  void _onNotifyError(String errorJson) {
    Map<String, dynamic> errorMap = jsonDecode(errorJson);
    SpeechRecognitionError speechError =
    SpeechRecognitionError.fromJson(errorMap);
    _lastError = speechError;
    if (null != errorListener) {
      errorListener(speechError);
    }
  }

  void _onNotifyStatus(String status) {
    _lastStatus = status;
    _listening = status == listeningStatus;
    if (null != statusListener) {
      statusListener(status);
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
    return _handleCallbacks(call);
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