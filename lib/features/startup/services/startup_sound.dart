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
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.play(
      AssetSource('audio/pulsepath_startup.wav'),
      volume: 0.65,
    );
  }

  @override
  Future<void> dispose() => _player.dispose();
}
