import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

export 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart'
    show SpeechListenOptions;

const String _defaultModelName = 'vosk-model-small-en-us-0.15';
const String _defaultModelUrl =
    'https://alphacephei.com/vosk/models/$_defaultModelName.zip';

/// By default [initialize] downloads and caches the small en-US Vosk model
/// under the application support directory on first launch. Override that
/// behaviour with these Linux platform options:
///
/// * `modelPath` (String) - use an existing model on disk; skips download.
/// * `autoDownloadModel` (bool) - pass `false` to disable the default
///   download (initialization will fail if no `modelPath` is supplied).
/// * `modelName` (String) - cache folder name; must match the folder
///   contained in the downloaded archive.
/// * `modelUrl` (String) - URL of the model zip to fetch.
///
/// ```dart
/// // Default: small en-US model is fetched & cached.
/// await speech.initialize();
///
/// // Explicit path:
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
    _channel.setMethodCallHandler(_handleMethodCall);

    final Map<String, dynamic> params = {
      'debugLogging': debugLogging,
    };

    String? modelPath;
    bool? autoDownloadExplicit;
    String modelName = _defaultModelName;
    String modelUrl = _defaultModelUrl;

    if (options != null) {
      for (final option in options) {
        // only care if we are on linux
        if (option.platform != 'linux') continue;
        switch (option.name) {
          case 'modelPath':
            modelPath = option.value as String?;
            break;
          case 'autoDownloadModel':
            autoDownloadExplicit = option.value == true;
            break;
          case 'modelName':
            if (option.value is String && (option.value as String).isNotEmpty) {
              modelName = option.value;
            }
            break;
          case 'modelUrl':
            if (option.value is String && (option.value as String).isNotEmpty) {
              modelUrl = option.value;
            }
            break;
          default:
            params[option.name] = option.value;
        }
      }
    }

    final shouldDownload = (modelPath == null || modelPath.isEmpty) &&
        (autoDownloadExplicit ?? true);

    if (shouldDownload) {
      try {
        modelPath = await _ensureCachedModel(modelName, modelUrl);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to download Vosk model: $e');
        }
        return false;
      }
    }

    if (modelPath != null && modelPath.isNotEmpty) {
      params['modelPath'] = modelPath;
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

  // download & cache VOSK model
  Future<String> _ensureCachedModel(String modelName, String modelUrl) async {
    final supportDir = await getApplicationSupportDirectory();
    final cacheRoot = Directory(p.join(supportDir.path, 'speech_to_text_linux'));
    if (!cacheRoot.existsSync()) {
      cacheRoot.createSync(recursive: true);
    }
    final modelDir = Directory(p.join(cacheRoot.path, modelName));
    if (modelDir.existsSync() &&
        File(p.join(modelDir.path, 'am', 'final.mdl')).existsSync()) {
      return modelDir.path;
    }

    if (modelDir.existsSync()) {
      modelDir.deleteSync(recursive: true);
    }

    if (kDebugMode) {
      print('Downloading Vosk model from $modelUrl');
    }
    final response = await http.get(Uri.parse(modelUrl));
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to download Vosk model (HTTP ${response.statusCode})');
    }
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    await extractArchiveToDiskAsync(archive, cacheRoot.path);
    if (!modelDir.existsSync()) {
      throw Exception(
          'Vosk model archive did not contain expected folder "$modelName"');
    }
    return modelDir.path;
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
