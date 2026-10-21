import 'dart:typed_data';

import 'package:audio_decode/audio_decode.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_edge_tts/src/utils/edge_tts_wav_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes decoder PCM as a canonical 16-bit RIFF/WAVE file', () {
    final wav = EdgeTtsWavEncoder.encodePcm16(
      PcmAudio(
        sampleRate: 24000,
        channels: 1,
        samples: Int16List.fromList(<int>[-32768, 0, 32767]),
      ),
    );
    final data = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(data.getUint32(4, Endian.little), 42);
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
    expect(data.getUint32(16, Endian.little), 16);
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 24000);
    expect(data.getUint32(28, Endian.little), 48000);
    expect(data.getUint16(32, Endian.little), 2);
    expect(data.getUint16(34, Endian.little), 16);
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(data.getUint32(40, Endian.little), 6);
    expect(data.getInt16(44, Endian.little), -32768);
    expect(data.getInt16(46, Endian.little), 0);
    expect(data.getInt16(48, Endian.little), 32767);
  });

  test('rejects unusable decoder geometry', () {
    expect(
      () => EdgeTtsWavEncoder.encodePcm16(
        PcmAudio(
          sampleRate: 0,
          channels: 1,
          samples: Int16List.fromList(<int>[0]),
        ),
      ),
      throwsA(
        isA<EdgeTtsException>().having(
          (error) => error.code,
          'code',
          'invalid_wav_pcm',
        ),
      ),
    );
  });

  test('rejects unsupported channel counts', () {
    expect(
      () => EdgeTtsWavEncoder.encodePcm16(
        PcmAudio(
          sampleRate: 24000,
          channels: 3,
          samples: Int16List.fromList(<int>[0, 0, 0]),
        ),
      ),
      throwsA(
        isA<EdgeTtsException>().having(
          (error) => error.code,
          'code',
          'invalid_wav_pcm',
        ),
      ),
    );
  });

  test('rejects empty decoded audio', () {
    expect(
      () => EdgeTtsWavEncoder.encodePcm16(
        PcmAudio(sampleRate: 24000, channels: 1, samples: Int16List(0)),
      ),
      throwsA(
        isA<EdgeTtsException>().having(
          (error) => error.code,
          'code',
          'empty_wav_pcm',
        ),
      ),
    );
  });
}
