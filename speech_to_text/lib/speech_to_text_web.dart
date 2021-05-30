import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

/// Web implementation of the SpeechToText platform interface. This supports
/// the speech to text functionality running in web browsers that have
/// SpeechRecognition support.
class SpeechToTextPlugin extends SpeechToTextPlatform {
  html.SpeechRecognition? _webSpeech;

  /// Registers this class as the default instance of [UrlLauncherPlatform].
  static void registerWith(Registrar registrar) {
    SpeechToTextPlatform.instance = SpeechToTextPlugin();
  }

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
    return true;
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
  /// with a paritcular OS version or device, fairly verbose
  @override
  Future<bool> initialize(
      {debugLogging = false, List<SpeechConfigOption>? options}) async {
    var initialized = false;
    try {
      _webSpeech = html.SpeechRecognition();
      if (null != _webSpeech) {
        _webSpeech!.onError.listen((error) => _onError(error));
        _webSpeech!.onStart.listen((startEvent) => _onSpeechStart(startEvent));
        _webSpeech!.onSpeechStart
            .listen((startEvent) => _onSpeechStart(startEvent));
        _webSpeech!.onEnd.listen((endEvent) => _onSpeechEnd(endEvent));
        _webSpeech!.onSpeechEnd.listen((endEvent) => _onSpeechEnd(endEvent));
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
      partialResults = true,
      onDevice = false,
      int listenMode = 0,
      sampleRate = 0}) async {
    if (null == _webSpeech) return false;
    _webSpeech!.onResult.listen((speechEvent) => _onResult(speechEvent));
    _webSpeech!.interimResults = partialResults;
    _webSpeech!.continuous = partialResults;
    if (null != localeId) {
      _webSpeech!.lang = localeId;
    }
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

  void _onError(html.SpeechRecognitionError event) {
    if (null != onError && null != event.error) {
      var error = SpeechRecognitionError(event.error!, false);
      onError!(jsonEncode(error.toJson()));
    }
  }

  void _onSpeechStart(html.Event event) {
    if (null != onStatus) {
      onStatus!('listening');
    }
  }

  void _onSpeechEnd(html.Event event) {
    if (null != onStatus) {
      onStatus!('not listening');
    }
  }

  void _onResult(html.SpeechRecognitionEvent event) {
    var isFinal = false;
    var recogResults = <SpeechRecognitionWords>[];
    var results = event.results;
    if (null != results) {
      for (var result in results) {
        if (null == result.length) continue;
        for (var altIndex = 0; altIndex < result.length!; ++altIndex) {
          var alt = result.item(altIndex);
          if (null != alt.transcript && null != alt.confidence) {
            recogResults.add(SpeechRecognitionWords(
                alt.transcript!, alt.confidence!.toDouble()));
          }
        }
      }
    }
    var result = SpeechRecognitionResult(recogResults, isFinal);
    if (null != onTextRecognition) {
      onTextRecognition!(jsonEncode(result.toJson()));
    }
  }
}
