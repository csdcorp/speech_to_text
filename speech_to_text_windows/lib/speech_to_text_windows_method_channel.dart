import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
// For the method channel implementation of [SpeechToTextPlatform] that uses method channels
class SpeechToTextWindowsMethodChannel extends SpeechToTextPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('speech_to_text_windows');

  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}