import 'package:audioplayers/audioplayers.dart';

abstract interface class StartupSoundPlayer {
  Future<void> play();

  Future<void> dispose();
}

class PulsePathStartupSound implements StartupSoundPlayer {
  PulsePathStartupSound() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(
        AssetSource('audio/pulsepath_startup.wav'),
        volume: 0.65,
      );
    } on Object {
      // Audio playback failure on physical devices (e.g. no audio focus, codec error)
      // must never crash the startup sequence.
    }
  }

  @override
  Future<void> dispose() => _player.dispose();
}
