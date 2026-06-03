import 'edge_tts_synthesis_result.dart';

class EdgeTtsFileResult {
  const EdgeTtsFileResult({
    required this.audioFilePath,
    required this.metadataFilePath,
    required this.result,
  });

  final String audioFilePath;
  final String? metadataFilePath;
  final EdgeTtsSynthesisResult result;
}
