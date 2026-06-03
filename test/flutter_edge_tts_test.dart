import 'package:flutter_edge_tts/flutter_edge_tts.dart';
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
  });

  group('EdgeTtsOutputFormat', () {
    test('exposes file extensions', () {
      expect(
        EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3.fileExtension,
        'mp3',
      );
      expect(EdgeTtsOutputFormat.riff24Khz16BitMonoPcm.fileExtension, 'wav');
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
