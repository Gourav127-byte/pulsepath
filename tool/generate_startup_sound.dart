import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const sampleRate = 44100;
  const durationSeconds = 3.0;
  final pcm = Int16List((sampleRate * durationSeconds).round());
  const tones = [
    _Tone(110, 0.03, 0.16, 0.18),
    _Tone(82, 0.21, 0.18, 0.14),
    _Tone(392, 0.58, 0.38, 0.17),
    _Tone(523.25, 0.85, 0.42, 0.19),
    _Tone(659.25, 1.13, 0.48, 0.19),
    _Tone(783.99, 2.21, 0.48, 0.16),
    _Tone(1046.5, 2.33, 0.55, 0.10),
  ];

  for (var index = 0; index < pcm.length; index++) {
    final time = index / sampleRate;
    var sample = _shimmerSample(time);
    for (final tone in tones) {
      sample += tone.sample(time);
    }
    pcm[index] = (sample.clamp(-0.9, 0.9) * 32767).round();
  }

  final data = ByteData(44 + pcm.lengthInBytes);
  _ascii(data, 0, 'RIFF');
  data.setUint32(4, 36 + pcm.lengthInBytes, Endian.little);
  _ascii(data, 8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _ascii(data, 36, 'data');
  data.setUint32(40, pcm.lengthInBytes, Endian.little);
  for (var index = 0; index < pcm.length; index++) {
    data.setInt16(44 + index * 2, pcm[index], Endian.little);
  }

  final file = File('assets/audio/pulsepath_startup.wav');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('Generated ${file.path} (${file.lengthSync()} bytes)');
}

double _shimmerSample(double time) {
  const start = 1.45;
  const duration = 0.54;
  final local = time - start;
  if (local < 0 || local > duration) return 0;
  final phase =
      2 *
      math.pi *
      (720 * local + 0.5 * (1380 - 720) * local * local / duration);
  return math.sin(phase) * _envelope(local / duration) * 0.12;
}

double _envelope(double progress) {
  return (progress / 0.08).clamp(0.0, 1.0) *
      ((1 - progress) / 0.34).clamp(0.0, 1.0);
}

void _ascii(ByteData data, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    data.setUint8(offset + index, value.codeUnitAt(index));
  }
}

class _Tone {
  const _Tone(this.frequency, this.start, this.duration, this.volume);

  final double frequency;
  final double start;
  final double duration;
  final double volume;

  double sample(double time) {
    final local = time - start;
    if (local < 0 || local > duration) return 0;
    return math.sin(2 * math.pi * frequency * local) *
        _envelope(local / duration) *
        volume;
  }
}
