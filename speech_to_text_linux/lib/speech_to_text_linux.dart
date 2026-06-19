import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

export 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart'
    show SpeechListenOptions;

/// The Vosk model directory must be supplied to [initialize] as a Linux
/// platform option named `modelPath`, for example:
///
/// ```dart
/// await speech.initialize(options: [
///   SpeechConfigOption('linux', 'modelPath', '/opt/vosk/model'),
/// ]);
/// ```
class SpeechToTextLinux extends SpeechToTextPlatform {
  static const MethodChannel _channel = MethodChannel('speech_to_text_linux');

  /// Registers this class as the default instance of [SpeechToTextPlatform]
  static void registerWith() {
    SpeechToTextPlatform.instance = SpeechToTextLinux();
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking microphone permission: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async {
    // set up method call handler so native callbacks reach the listeners.
    _channel.setMethodCallHandler(_handleMethodCall);

    final Map<String, dynamic> params = {
      'debugLogging': debugLogging,
    };

    // process linux-specific options (e.g `modelPath`).
    if (options != null) {
      for (final option in options) {
        if (option.platform == 'linux') {
          params[option.name] = option.value;
        }
      }
    }

    try {
      final bool? result =
          await _channel.invokeMethod<bool>('initialize', params);
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Linux speech recognition: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> listen({
    String? localeId,
    @Deprecated('Use SpeechListenOptions.partialResults instead')
    partialResults = true,
    @Deprecated('Use SpeechListenOptions.onDevice instead') onDevice = false,
    @Deprecated('Use SpeechListenOptions.listenMode instead')
    int listenMode = 0,
    @Deprecated('Use SpeechListenOptions.sampleRate instead') sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    final Map<String, dynamic> params = {
      'localeId': localeId,
      'partialResults': options?.partialResults ?? partialResults,
      'onDevice': options?.onDevice ?? onDevice,
      'listenMode': options?.listenMode.index ?? listenMode,
      'sampleRate': options?.sampleRate ?? sampleRate,
      'autoPunctuation': options?.autoPunctuation ?? false,
      'enableHapticFeedback': options?.enableHapticFeedback ?? false,
      'cancelOnError': options?.cancelOnError ?? false,
    };

    try {
      final bool? result = await _channel.invokeMethod<bool>('listen', params);
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting speech recognition: $e');
      }
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping speech recognition: $e');
      }
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (e) {
      if (kDebugMode) {
        print('Error canceling speech recognition: $e');
      }
    }
  }

  @override
  Future<List<dynamic>> locales() async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod<List<dynamic>>('locales');
      return result ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting supported locales: $e');
      }
      return [];
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'textRecognition':
          if (call.arguments is String && onTextRecognition != null) {
            onTextRecognition!(call.arguments);
          }
          break;
        case 'notifyError':
          if (call.arguments is String && onError != null) {
            onError!(call.arguments);
          }
          break;
        case 'notifyStatus':
          if (call.arguments is String && onStatus != null) {
            onStatus!(call.arguments);
          }
          break;
        case 'soundLevelChange':
          if (call.arguments is double && onSoundLevel != null) {
            onSoundLevel!(call.arguments);
          }
          break;
        default:
          if (kDebugMode) {
            print('Unknown method call: ${call.method}');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling method call ${call.method}: $e');
      }
    }
  }
}
