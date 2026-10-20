import 'dart:io';
import 'dart:typed_data';

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
    'exports a locally-decoded WAV file from live Edge MP3 audio',
    () async {
      final directory = await Directory.systemTemp.createTemp('edge_tts_wav_');
      addTearDown(() => directory.delete(recursive: true));
      final outputFile = File('${directory.path}/speech.wav');
      final tts = FlutterEdgeTts(voice: 'en-US-AriaNeural');
      addTearDown(tts.close);

      final result = await tts.synthesizeToWavFile(
        'Flutter Edge TTS WAV regression test.',
        audioFilePath: outputFile.path,
      );
      final wavBytes = await outputFile.readAsBytes();

      expect(result.audioFilePath, outputFile.path);
      expect(wavBytes.length, greaterThan(44));
      expect(wavBytes.take(4), <int>[82, 73, 70, 70]);
      expect(wavBytes.skip(8).take(4), <int>[87, 65, 86, 69]);
      expect(wavBytes.skip(36).take(4), <int>[100, 97, 116, 97]);
      final header = ByteData.sublistView(wavBytes);
      expect(header.getUint16(22, Endian.little), anyOf(1, 2));
      expect(header.getUint32(24, Endian.little), greaterThan(0));
      expect(header.getUint16(34, Endian.little), 16);
    },
    skip: !runLiveEdgeTests,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
