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
    player.onPlayerStateChanged
        .listen((s) => s == PlayerState.completed ? _onStop?.call() : null);
  }

  @override
  Future stop() async {
    player.stop();
  }

  @override
  Future setAsset(String assetPath,
      {bool preload = true, Duration? initialPosition}) async {
    // return player.setAsset(assetPath);
  }
}
