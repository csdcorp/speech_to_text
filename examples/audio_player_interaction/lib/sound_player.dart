import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract class SoundPlayer {
  bool get isPlaying;
  Future setAsset(String assetPath,
      {bool preload = true, Duration initialPosition});
  Future play(String assetToPlay, {bool loop = false});
  Future stop();
  set onStop(void Function()? callback);
}

class AudioSoundPlayer implements SoundPlayer {
  final AudioPlayer player = AudioPlayer();
  void Function()? _onStop;

  @override
  bool get isPlaying => false;

  @override
  set onStop(void Function()? callback) {
    _onStop = callback;
  }

  @override
  Future play(String assetToPlay, {bool loop = false}) async {
    if (loop) {
      await player.play(AssetSource(assetToPlay));
    } else {
      await player.play(AssetSource(
        assetToPlay,
      ));
    }
    player.onPlayerStateChanged.listen((s) => _listen(s));
  }

  void _listen(PlayerState s) {
    logIt('Player state changed: $s');
    if (s == PlayerState.completed) {
      stop();
    }
  }

  @override
  Future stop() async {
    _onStop?.call();
  }

  @override
  Future setAsset(String assetPath,
      {bool preload = true, Duration? initialPosition}) async {
    // return player.setAsset(assetPath);
  }

  void logIt(String msg) {
    debugPrint('SoundLoop: $msg');
  }
}
