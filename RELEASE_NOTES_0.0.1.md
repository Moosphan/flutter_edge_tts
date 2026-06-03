# flutter_edge_tts 0.0.1

A free Flutter TTS package powered by Microsoft Edge online speech synthesis.

## Highlights

- Free and open-source Flutter TTS package
- Shared Dart synthesis implementation for Android, iOS, macOS, Windows, and Linux
- Voice discovery from the live endpoint
- As of 2026-06-03, the live endpoint returns 322 voices across 142 locales and 75 languages
- Text synthesis to bytes, files, and stream events
- Raw SSML synthesis support
- Sentence and word boundary metadata support
- Multiple output formats including MP3, WebM, Ogg, PCM, and WAV
- Included example app with voice selection, output format selection, and metadata toggles
- Included desktop example runners for macOS, Windows, and Linux

## API surface

- `FlutterEdgeTts`
- `EdgeTtsConfig`
- `EdgeTtsProsody`
- `EdgeTtsOutputFormat`
- `EdgeTtsVoice`
- `EdgeTtsAudioChunkEvent`
- `EdgeTtsMetadataEvent`

## Notes

- The package focuses on synthesis transport and parsing, not audio playback.
- Voice compatibility depends on the live endpoint and should be validated in your own environment.
- Before publishing, make sure screenshots and final repository metadata are in place.
