import 'dart:typed_data';

import 'package:audio_decode/audio_decode.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_edge_tts/src/utils/edge_tts_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decoder dependency provides PCM audio geometry', () {
    final pcm = PcmAudio(
      sampleRate: 24000,
      channels: 1,
      samples: Int16List.fromList(<int>[0, 1]),
    );

    expect(pcm.frameCount, 2);
  });

  group('EdgeTtsSsmlBuilder', () {
    test('builds SSML with inferred locale and escaped text', () {
      const config = EdgeTtsConfig(voice: 'en-US-AriaNeural');
      final ssml = EdgeTtsSsmlBuilder.build(
        text: 'Tom & Jerry <3',
        config: config,
      );

      expect(ssml, contains('xml:lang="en-US"'));
      expect(ssml, contains('name="en-US-AriaNeural"'));
      expect(ssml, contains('Tom &amp; Jerry &lt;3'));
    });

    test('throws when locale cannot be inferred', () {
      const config = EdgeTtsConfig(voice: 'AriaNeural');

      expect(
        () => EdgeTtsSsmlBuilder.build(text: 'hello', config: config),
        throwsA(isA<EdgeTtsException>()),
      );
    });
  });

  group('EdgeTtsUtils', () {
    test('escape helper is publicly available through the builder', () {
      final escaped = EdgeTtsSsmlBuilder.escapeText('A & B < C');

      expect(escaped, 'A &amp; B &lt; C');
    });

    test('generates the v2 Sec-MS-GEC token expected by Edge', () {
      expect(
        EdgeTtsUtils.generateSecMsGecV2(
          '6A5AA1D4EAFF4E9FB37E23D68491D6F4',
          unixTimestamp: 1700000000,
        ),
        '2CD23A2CA0B2595A-'
        'F3C846C370E05F9CC83ACC5F995C5F5D87A4D0F14CE8936A0F902E64099E38A2',
      );
    });
  });

  group('EdgeTtsOutputFormat', () {
    test('exposes file extensions', () {
      expect(
        EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3.fileExtension,
        'mp3',
      );
      expect(EdgeTtsOutputFormat.riff24Khz16BitMonoPcm.fileExtension, 'wav');
    });

    test('rejects formats that the Edge Read Aloud endpoint does not return',
        () {
      expect(
        () => EdgeTtsOutputFormat.riff24Khz16BitMonoPcm.requireSupported(),
        throwsA(
          isA<EdgeTtsException>().having(
            (error) => error.code,
            'code',
            'unsupported_output_format',
          ),
        ),
      );
    });
  });

  group('EdgeTtsException', () {
    test('includes cause in debug string when provided', () {
      const exception = EdgeTtsException(
        'sample',
        'Something failed',
        cause: 'network',
      );

      expect(exception.toString(), contains('cause=network'));
    });
  });
}
