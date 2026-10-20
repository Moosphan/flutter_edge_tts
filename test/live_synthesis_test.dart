import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decode/audio_decode.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const runLiveEdgeTests = bool.fromEnvironment('RUN_LIVE_EDGE_TTS_TEST');

  test(
    'synthesizes MP3 audio through the live Edge endpoint',
    () async {
      final tts = FlutterEdgeTts(
        voice: 'en-US-AriaNeural',
        outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
      );
      addTearDown(tts.close);

      final result = await tts.synthesize('Flutter Edge TTS regression test.');

      expect(result.audioBytes, isNotEmpty);
      expect(
        result.audioBytes.take(3),
        anyOf(<Object>[
          <int>[73, 68, 51],
          <int>[255, 243, 164]
        ]),
      );
    },
    skip: !runLiveEdgeTests,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'exports PCM WAV audio through the live Edge endpoint',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'flutter_edge_tts_wav_test_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final tts = FlutterEdgeTts(voice: 'en-US-AriaNeural');
      addTearDown(tts.close);
      final outputFile = File('${tempDirectory.path}/speech.wav');

      final fileResult = await tts.synthesizeToWavFile(
        'Flutter Edge TTS WAV regression test.',
        audioFilePath: outputFile.path,
      );
      final wav = await outputFile.readAsBytes();
      final header = ByteData.sublistView(wav);
      final decoded = decodeWav(wav);

      expect(wav, fileResult.result.audioBytes);
      expect(wav.length, greaterThan(44));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(header.getUint16(20, Endian.little), 1);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), greaterThan(0));
      expect(header.getUint32(40, Endian.little) + 44, wav.length);
      expect(decoded.sampleRate, 24000);
      expect(decoded.channels, 1);
      expect(decoded.samples, isNotEmpty);
    },
    skip: !runLiveEdgeTests,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
