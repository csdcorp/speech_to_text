import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'speech_to_text_platform_interface.dart';

const MethodChannel _channel =
    MethodChannel('plugin.csdcorp.com/speech_to_text');

/// An implementation of [SpeechToTextPlatform] that uses method channels.
class MethodChannelSpeechToText extends SpeechToTextPlatform {
  static const String textRecognitionMethod = 'textRecognition';
  static const String notifyErrorMethod = 'notifyError';
  static const String notifyStatusMethod = 'notifyStatus';
  static const String soundLevelChangeMethod = "soundLevelChange";

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
    return await _channel.invokeMethod<bool>('has_permission') ?? false;
  }

  @override
  Future<bool> initialize(
      {debugLogging = false, List<SpeechConfigOption>? options}) async {
    _channel.setMethodCallHandler(_handleCallbacks);
    var params = <String, Object>{
      'debugLogging': debugLogging,
    };
    options?.forEach((option) => params[option.name] = option.value);
    return await _channel.invokeMethod<bool>(
          'initialize',
          params,
        ) ??
        false;
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
  Future<void> stop() {
    return _channel.invokeMethod('stop');
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
  Future<void> cancel() {
    return _channel.invokeMethod('cancel');
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
    Map<String, dynamic> listenParams = {
      "partialResults": partialResults,
      "onDevice": onDevice,
      "listenMode": listenMode,
      "sampleRate": sampleRate,
    };
    if (null != localeId) {
      listenParams["localeId"] = localeId;
    }
    return await _channel.invokeMethod<bool>('listen', listenParams) ?? false;
  }

  /// returns the list of speech locales available on the device.
  ///
  @override
  Future<List<dynamic>> locales() async {
    return await _channel.invokeMethod<List<dynamic>>('locales') ?? [];
  }

  Future _handleCallbacks(MethodCall call) async {
    // print("SpeechToText call: ${call.method} ${call.arguments}");
    switch (call.method) {
      case textRecognitionMethod:
        if (call.arguments is String && null != onTextRecognition) {
          onTextRecognition!(call.arguments);
        }
        break;
      case notifyErrorMethod:
        if (call.arguments is String && null != onError) {
          onError!(call.arguments);
        }
        break;
      case notifyStatusMethod:
        if (call.arguments is String && null != onStatus) {
          onStatus!(call.arguments);
        }
        break;
      case soundLevelChangeMethod:
        if (call.arguments is double && null != onSoundLevel) {
          onSoundLevel!(call.arguments);
        }
        break;
      default:
    }
  }

  @visibleForTesting
  Future processMethodCall(MethodCall call) async {
    return await _handleCallbacks(call);
  }

  @visibleForTesting
  MethodChannel get channel => _channel;
}
