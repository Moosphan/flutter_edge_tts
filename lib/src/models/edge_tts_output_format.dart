import 'edge_tts_exception.dart';

enum EdgeTtsOutputFormat {
  audio16Khz32KbitrateMonoMp3(
    value: 'audio-16khz-32kbitrate-mono-mp3',
    fileExtension: 'mp3',
  ),
  audio16Khz64KbitrateMonoMp3(
    value: 'audio-16khz-64kbitrate-mono-mp3',
    fileExtension: 'mp3',
  ),
  audio24Khz48KbitrateMonoMp3(
    value: 'audio-24khz-48kbitrate-mono-mp3',
    fileExtension: 'mp3',
  ),
  audio24Khz96KbitrateMonoMp3(
    value: 'audio-24khz-96kbitrate-mono-mp3',
    fileExtension: 'mp3',
  ),
  audio48Khz96KbitrateMonoMp3(
    value: 'audio-48khz-96kbitrate-mono-mp3',
    fileExtension: 'mp3',
  ),
  webm24Khz16BitMonoOpus(
    value: 'webm-24khz-16bit-mono-opus',
    fileExtension: 'webm',
  ),
  ogg24Khz16BitMonoOpus(
    value: 'ogg-24khz-16bit-mono-opus',
    fileExtension: 'ogg',
  ),
  raw24Khz16BitMonoPcm(
    value: 'raw-24khz-16bit-mono-pcm',
    fileExtension: 'pcm',
  ),
  riff24Khz16BitMonoPcm(
    value: 'riff-24khz-16bit-mono-pcm',
    fileExtension: 'wav',
  );

  const EdgeTtsOutputFormat({required this.value, required this.fileExtension});

  final String value;
  final String fileExtension;

  bool get isContainerFormat =>
      fileExtension == 'mp3' ||
      fileExtension == 'webm' ||
      fileExtension == 'ogg' ||
      fileExtension == 'wav';

  /// Ensures that the Edge Read Aloud websocket can generate this format.
  ///
  /// The upstream endpoint accepts a WAV request but ends the turn without
  /// returning bytes, so fail deterministically instead of surfacing the
  /// misleading [EdgeTtsException] `empty_audio` error.
  void requireSupported() {
    if (this == EdgeTtsOutputFormat.riff24Khz16BitMonoPcm) {
      throw const EdgeTtsException(
        'unsupported_output_format',
        'The Edge Read Aloud endpoint does not return WAV audio. '
            'Use raw24Khz16BitMonoPcm or an MP3, WebM, or Ogg format instead.',
      );
    }
  }
}
