import 'dart:typed_data';

import 'package:audio_decode/audio_decode.dart';

import '../models/edge_tts_exception.dart';

/// Encodes decoded signed PCM16 samples as a canonical RIFF/WAVE file.
class EdgeTtsWavEncoder {
  const EdgeTtsWavEncoder._();

  static const int _headerLength = 44;
  static const int _bitsPerSample = 16;
  static const int _bytesPerSample = _bitsPerSample ~/ 8;
  static const int _maxUint32 = 0xFFFFFFFF;

  /// Returns a PCM-format WAV file that preserves [audio]'s geometry.
  static Uint8List encodePcm16(PcmAudio audio) {
    final sampleRate = audio.sampleRate;
    final channels = audio.channels;
    final sampleCount = audio.samples.length;

    if (sampleRate < 1 || channels < 1 || channels > 0xFFFF) {
      throw const EdgeTtsException(
        'invalid_wav_pcm',
        'Decoded PCM must have a positive sample rate and between 1 and '
            '65535 channels.',
      );
    }
    if (sampleCount == 0) {
      throw const EdgeTtsException(
        'empty_wav_pcm',
        'Decoded MP3 did not contain PCM samples for WAV export.',
      );
    }
    if (sampleCount % channels != 0) {
      throw const EdgeTtsException(
        'invalid_wav_pcm',
        'Decoded PCM samples are not aligned to complete audio frames.',
      );
    }

    final blockAlign = channels * _bytesPerSample;
    final byteRate = sampleRate * blockAlign;
    final pcmByteLength = sampleCount * _bytesPerSample;
    final riffChunkLength = 36 + pcmByteLength;
    if (blockAlign > 0xFFFF ||
        byteRate > _maxUint32 ||
        pcmByteLength > _maxUint32 ||
        riffChunkLength > _maxUint32) {
      throw const EdgeTtsException(
        'wav_too_large',
        'PCM data is too large for a standard RIFF/WAVE file.',
      );
    }

    final wavBytes = Uint8List(_headerLength + pcmByteLength);
    final header = ByteData.sublistView(wavBytes);
    wavBytes.setRange(0, 4, 'RIFF'.codeUnits);
    header.setUint32(4, riffChunkLength, Endian.little);
    wavBytes.setRange(8, 12, 'WAVE'.codeUnits);
    wavBytes.setRange(12, 16, 'fmt '.codeUnits);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    wavBytes.setRange(36, 40, 'data'.codeUnits);
    header.setUint32(40, pcmByteLength, Endian.little);

    for (var index = 0; index < sampleCount; index++) {
      header.setInt16(
        _headerLength + index * _bytesPerSample,
        audio.samples[index],
        Endian.little,
      );
    }
    return wavBytes;
  }
}
