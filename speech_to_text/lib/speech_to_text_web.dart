import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'dart:math';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:speech_to_text/balanced_alternates.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

// TODO: Workaround to fix SpeechRecognition in release mode. Remove this when
// are fix (#276)[https://github.com/dart-lang/web/issues/276].
@JS('webkitSpeechRecognition')
extension type _SpeechRecognition._(web.SpeechRecognition _)
    implements web.SpeechRecognition {
  external factory _SpeechRecognition();
}

/// Web implementation of the SpeechToText platform interface. This supports
/// the speech to text functionality running in web browsers that have
/// SpeechRecognition support.
class SpeechToTextPlugin extends SpeechToTextPlatform {
  web.SpeechRecognition? _webSpeech;
  static const _doneNoResult = 'doneNoResult';
  bool _resultSent = false;
  bool _doneSent = false;
  bool _aggregateResults = true;

  /// Registers this class as the default instance of [SpeechToTextPlatform].
  static void registerWith(Registrar registrar) {
    SpeechToTextPlatform.instance = SpeechToTextPlugin();
  }

  /// Checks if this SpeechRecognition is supported on the current platform.
  static bool get supported =>
      web.window.hasProperty('SpeechRecognition'.toJS).toDart ||
      web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart;

  /// Returns true if the user has already granted permission to access the
  /// microphone, does not prompt the user.
  ///
  /// This method can be called before [initialize] to check if permission
  /// has already been granted. If this returns false then the [initialize]
  /// call will prompt the user for permission if it is allowed to do so.
  /// Note that applications cannot ask for permission again if the user has
  /// denied them permission in the past.
  @override
  Future<bool> hasPermission() async {
    return supported;
  }

  /// Initialize speech recognition services, returns true if
  /// successful, false if failed.
  ///
  /// This method must be called before any other speech functions.
  /// If this method returns false no further [SpeechToText] methods
  /// should be used. False usually means that the user has denied
  /// permission to use speech.
  ///
  /// [debugLogging] controls whether there is detailed logging from the underlying
  /// plugins. It is off by default, usually only useful for troubleshooting issues
  /// with a particular OS version or device, fairly verbose
  @override
  Future<bool> initialize(
      {debugLogging = false, List<SpeechConfigOption>? options}) async {
    if (!supported) {
      var error = SpeechRecognitionError('not supported', true);
      onError?.call(jsonEncode(error.toJson()));
      return false;
    }
    var initialized = false;
    try {
      _webSpeech = _SpeechRecognition();

      if (null != _webSpeech) {
        _aggregateResults =
            BalancedAlternates.isAggregateResultsEnabled(options);

        _webSpeech?.onerror = _onError.toJS;

        _webSpeech?.onstart = _onSpeechStart.toJS;

        _webSpeech?.onspeechstart = _onSpeechStart.toJS;

        _webSpeech?.onend = _onSpeechEnd.toJS;

        _webSpeech?.onnomatch = _onNoMatch.toJS;
        initialized = true;
      }
    } finally {
      if (null == _webSpeech) {
        if (null != onError) {
          var error = SpeechRecognitionError('speech_not_supported', true);
          onError!(jsonEncode(error.toJson()));
        }
      }
    }
    return initialized;
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
  @override
  Future<void> stop() async {
    if (null == _webSpeech) return;
    _webSpeech!.stop();
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
  @override
  Future<void> cancel() async {
    if (null == _webSpeech) return;
    _webSpeech!.abort();
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
  @override
  Future<bool> listen(
      {String? localeId,
      @deprecated partialResults = true,
      @deprecated onDevice = false,
      @deprecated int listenMode = 0,
      @deprecated sampleRate = 0,
      SpeechListenOptions? options}) async {
    if (null == _webSpeech) return false;
    _webSpeech!.onresult = _onResult.toJS;
    _webSpeech!.interimResults = options?.partialResults ?? partialResults;
    _webSpeech!.continuous = options?.partialResults ?? partialResults;
    if (null != localeId) {
      _webSpeech!.lang = localeId;
    }
    _doneSent = false;
    _resultSent = false;
    _webSpeech!.start();
    return true;
  }

  /// returns the list of speech locales available on the device.
  ///
  @override
  Future<List<dynamic>> locales() async {
    var availableLocales = [];
    var lang = _webSpeech?.lang;
    if (null != lang && lang.isNotEmpty) {
      lang = lang.replaceAll(':', '_');
      availableLocales.add('$lang:$lang');
    }
    return availableLocales;
  }

  void _onError(web.SpeechRecognitionErrorEvent event) {
    var error = SpeechRecognitionError(event.error, false);
    onError?.call(jsonEncode(error.toJson()));
    _sendDone(_doneNoResult);
  }

  void _onSpeechStart(web.Event event) {
    onStatus?.call('listening');
  }

  void _onSpeechEnd(web.Event event) {
    onStatus?.call('notListening');
    _sendDone(_resultSent ? 'done' : _doneNoResult);
  }

  void _onNoMatch(web.Event event) {
    _sendDone(_doneNoResult);
  }

  void _sendDone(String status) {
    if (_doneSent) return;
    onStatus?.call(status);
    _doneSent = true;
  }

  void _onResult(web.SpeechRecognitionEvent event) {
    var isFinal = false;
    var recogResults = <SpeechRecognitionWords>[];
    var results = event.results;

    final balanced = BalancedAlternates();
    var resultIndex = 0;
    var longestAlt = 0;
    for (var i = 0; i < results.length; i++) {
      final recognitionResult = results.item(i);

      for (var altIndex = 0;
          altIndex < (recognitionResult.length);
          ++altIndex) {
        longestAlt = max(longestAlt, altIndex);
        final web.SpeechRecognitionAlternative? alt =
            recognitionResult.item(altIndex);

        if (null == alt) continue;

        final transcript = alt.transcript;
        final confidence = alt.confidence;

        balanced.add(resultIndex, transcript, confidence.toDouble());
      }
      ++resultIndex;
    }
    recogResults = balanced.getAlternates(_aggregateResults);
    var result = SpeechRecognitionResult(recogResults, isFinal);
    onTextRecognition?.call(jsonEncode(result.toJson()));
    _resultSent = true;
  }
}
