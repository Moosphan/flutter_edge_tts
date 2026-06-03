import 'dart:typed_data';

import 'edge_tts_metadata.dart';

abstract class EdgeTtsStreamEvent {
  const EdgeTtsStreamEvent();
}

class EdgeTtsAudioChunkEvent extends EdgeTtsStreamEvent {
  const EdgeTtsAudioChunkEvent(this.chunk);

  final Uint8List chunk;
}

class EdgeTtsMetadataEvent extends EdgeTtsStreamEvent {
  const EdgeTtsMetadataEvent(this.metadata);

  final EdgeTtsMetadata metadata;
}
