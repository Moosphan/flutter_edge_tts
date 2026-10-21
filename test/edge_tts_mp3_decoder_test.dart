import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decode/audio_decode.dart';
import 'package:flutter_edge_tts/src/utils/edge_tts_wav_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the committed 24 kHz mono MP3 fixture and writes readable WAV',
      () {
    final mp3 = File('test/fixtures/edge_24khz_mono.mp3').readAsBytesSync();

    final pcm = decodeMp3(mp3);
    final wav = EdgeTtsWavEncoder.encodePcm16(pcm);
    final header = ByteData.sublistView(wav);
    final roundTripped = decodeWav(wav);

    expect(pcm.sampleRate, 24000);
    expect(pcm.channels, 1);
    expect(pcm.samples, isNotEmpty);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 24000);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint16(34, Endian.little), 16);
    expect(roundTripped.sampleRate, pcm.sampleRate);
    expect(roundTripped.channels, pcm.channels);
    expect(roundTripped.samples, orderedEquals(pcm.samples));
  });
}
