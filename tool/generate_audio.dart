import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

Uint8List generateWav({
  required int sampleRate,
  required double durationSeconds,
  required double Function(double t) waveform,
}) {
  final numSamples = (sampleRate * durationSeconds).toInt();
  final dataSize = numSamples * 2; // 16-bit mono
  final fileSize = 36 + dataSize;

  final bytes = ByteData(44 + dataSize);

  // RIFF header
  bytes.setUint8(0, 0x52); // 'R'
  bytes.setUint8(1, 0x49); // 'I'
  bytes.setUint8(2, 0x46); // 'F'
  bytes.setUint8(3, 0x46); // 'F'
  bytes.setUint32(4, fileSize, Endian.little);
  bytes.setUint8(8, 0x57);  // 'W'
  bytes.setUint8(9, 0x41);  // 'A'
  bytes.setUint8(10, 0x56); // 'V'
  bytes.setUint8(11, 0x45); // 'E'

  // "fmt " subchunk
  bytes.setUint8(12, 0x66); // 'f'
  bytes.setUint8(13, 0x6D); // 'm'
  bytes.setUint8(14, 0x74); // 't'
  bytes.setUint8(15, 0x20); // ' '
  bytes.setUint32(16, 16, Endian.little); // Subchunk1Size
  bytes.setUint16(20, 1, Endian.little);  // AudioFormat (PCM)
  bytes.setUint16(22, 1, Endian.little);  // NumChannels (1)
  bytes.setUint32(24, sampleRate, Endian.little); // SampleRate
  bytes.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
  bytes.setUint16(32, 2, Endian.little);  // BlockAlign
  bytes.setUint16(34, 16, Endian.little); // BitsPerSample

  // "data" subchunk
  bytes.setUint8(36, 0x64); // 'd'
  bytes.setUint8(37, 0x61); // 'a'
  bytes.setUint8(38, 0x74); // 't'
  bytes.setUint8(39, 0x61); // 'a'
  bytes.setUint32(40, dataSize, Endian.little);

  // Samples
  for (var i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final sampleValue = (waveform(t) * 32767).clamp(-32768, 32767).toInt();
    bytes.setInt16(44 + i * 2, sampleValue, Endian.little);
  }

  return bytes.buffer.asUint8List();
}

void main() {
  const sampleRate = 44100;

  // 1. tap.wav: Clean, crisp wooden click (decaying 880Hz -> 440Hz pop over 35ms)
  final tapBytes = generateWav(
    sampleRate: sampleRate,
    durationSeconds: 0.045,
    waveform: (t) {
      final env = exp(-t * 110.0);
      final freq = 800.0 - t * 6000.0;
      return sin(2 * pi * freq * t) * env * 0.85;
    },
  );
  File('assets/audio/tap.wav').writeAsBytesSync(tapBytes);
  print('Generated assets/audio/tap.wav');

  // 2. escape.wav: Pleasant ascending chime swoosh (440Hz -> 880Hz over 140ms)
  final escapeBytes = generateWav(
    sampleRate: sampleRate,
    durationSeconds: 0.16,
    waveform: (t) {
      final env = (t < 0.02 ? t / 0.02 : 1.0) * exp(-t * 14.0);
      final freq = 520.0 + t * 900.0;
      return (sin(2 * pi * freq * t) * 0.6 + sin(2 * pi * freq * 1.5 * t) * 0.3) * env * 0.8;
    },
  );
  File('assets/audio/escape.wav').writeAsBytesSync(escapeBytes);
  print('Generated assets/audio/escape.wav');

  // 3. blocked.wav: Soft low double-thud (180Hz over 70ms)
  final blockedBytes = generateWav(
    sampleRate: sampleRate,
    durationSeconds: 0.09,
    waveform: (t) {
      final env = exp(-t * 45.0);
      return sin(2 * pi * 160.0 * t) * env * 0.7;
    },
  );
  File('assets/audio/blocked.wav').writeAsBytesSync(blockedBytes);
  print('Generated assets/audio/blocked.wav');
}
