import 'dart:typed_data';

/// Encodes Edge's raw 24 kHz, 16-bit, mono PCM response as a WAV file.
class EdgeTtsWavEncoder {
  const EdgeTtsWavEncoder._();

  static const int _headerLength = 44;
  static const int _sampleRate = 24000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;

  static Uint8List wrap24Khz16BitMono(Uint8List pcmBytes) {
    return wrapPcm16(
      pcmBytes,
      sampleRate: _sampleRate,
      channels: _channels,
    );
  }

  static Uint8List wrapPcm16(
    Uint8List pcmBytes, {
    required int sampleRate,
    required int channels,
  }) {
    final wavBytes = Uint8List(_headerLength + pcmBytes.length);
    final header = ByteData.sublistView(wavBytes);

    wavBytes.setRange(0, 4, <int>[82, 73, 70, 70]); // RIFF
    header.setUint32(4, wavBytes.length - 8, Endian.little);
    wavBytes.setRange(8, 12, <int>[87, 65, 86, 69]); // WAVE
    wavBytes.setRange(12, 16, <int>[102, 109, 116, 32]); // fmt
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(
        28, sampleRate * channels * _bitsPerSample ~/ 8, Endian.little);
    header.setUint16(32, channels * _bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    wavBytes.setRange(36, 40, <int>[100, 97, 116, 97]); // data
    header.setUint32(40, pcmBytes.length, Endian.little);
    wavBytes.setRange(_headerLength, wavBytes.length, pcmBytes);

    return wavBytes;
  }
}
