import 'edge_tts_output_format.dart';

class EdgeTtsConfig {
  const EdgeTtsConfig({
    required this.voice,
    this.outputFormat = EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
    this.voiceLocale,
    this.enableSentenceBoundary = false,
    this.enableWordBoundary = false,
  });

  final String voice;
  final EdgeTtsOutputFormat outputFormat;
  final String? voiceLocale;
  final bool enableSentenceBoundary;
  final bool enableWordBoundary;

  EdgeTtsConfig copyWith({
    String? voice,
    EdgeTtsOutputFormat? outputFormat,
    String? voiceLocale,
    bool? enableSentenceBoundary,
    bool? enableWordBoundary,
  }) {
    return EdgeTtsConfig(
      voice: voice ?? this.voice,
      outputFormat: outputFormat ?? this.outputFormat,
      voiceLocale: voiceLocale ?? this.voiceLocale,
      enableSentenceBoundary:
          enableSentenceBoundary ?? this.enableSentenceBoundary,
      enableWordBoundary: enableWordBoundary ?? this.enableWordBoundary,
    );
  }
}
