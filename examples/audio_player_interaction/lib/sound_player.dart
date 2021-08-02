import 'package:audioplayers/audioplayers.dart';

abstract class SoundPlayer {
  bool get isPlaying;
  Future setAsset(String assetPath,
      {bool preload = true, Duration initialPosition});
  Future play(String assetToPlay, {bool loop = false});
  Future stop();
  set onStop(void Function()? callback);
}

class AudioSoundPlayer implements SoundPlayer {
  final AudioCache player = AudioCache();
  AudioPlayer? _audio;
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
      _audio = await player.loop(assetToPlay);
    } else {
      _audio = await player.play(
        assetToPlay,
      );
    }
    _audio?.onPlayerStateChanged
        .listen((s) => s == PlayerState.COMPLETED ? _onStop?.call() : null);
  }

  @override
  Future stop() async {
    _audio?.stop();
  }

  @override
  Future setAsset(String assetPath,
      {bool preload = true, Duration? initialPosition}) async {
    // return player.setAsset(assetPath);
  }
}
