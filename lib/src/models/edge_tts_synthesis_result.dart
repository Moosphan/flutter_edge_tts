import 'dart:typed_data';

import 'edge_tts_metadata.dart';

class EdgeTtsSynthesisResult {
  const EdgeTtsSynthesisResult({
    required this.audioBytes,
    required this.metadata,
    required this.requestId,
  });

  final Uint8List audioBytes;
  final List<EdgeTtsMetadataItem> metadata;
  final String requestId;
}
