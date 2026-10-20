import 'dart:typed_data';

import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_edge_tts/src/utils/edge_tts_utils.dart';
import 'package:flutter_edge_tts/src/utils/edge_tts_wav_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('EdgeTtsWavEncoder', () {
    test('wraps 24 kHz 16-bit mono PCM in a WAV container', () {
      final wav = EdgeTtsWavEncoder.wrap24Khz16BitMono(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );
      final header = ByteData.sublistView(wav);

      expect(wav.sublist(0, 4), <int>[82, 73, 70, 70]);
      expect(wav.sublist(8, 12), <int>[87, 65, 86, 69]);
      expect(wav.sublist(12, 16), <int>[102, 109, 116, 32]);
      expect(header.getUint32(4, Endian.little), 40);
      expect(header.getUint16(20, Endian.little), 1);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 24000);
      expect(header.getUint32(28, Endian.little), 48000);
      expect(header.getUint16(32, Endian.little), 2);
      expect(header.getUint16(34, Endian.little), 16);
      expect(wav.sublist(36, 40), <int>[100, 97, 116, 97]);
      expect(header.getUint32(40, Endian.little), 4);
      expect(wav.sublist(44), <int>[1, 2, 3, 4]);
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
