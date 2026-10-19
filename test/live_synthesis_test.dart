import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
