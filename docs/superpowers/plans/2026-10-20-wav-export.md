# WAV Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reliable `.wav` file export by decoding Edge's working 24 kHz MP3 response locally and writing PCM16 RIFF/WAVE, without changing existing synthesis APIs.

**Architecture:** The two new file APIs force the existing WebSocket request path to `audio-24khz-96kbitrate-mono-mp3`, decode the completed response through `audio_decode`/minimp3, then pass the resulting PCM16 samples to a small pure-Dart RIFF writer. Existing APIs, stream events, output-format semantics, and the deterministic rejection of Edge's unavailable `riff-*` format remain unchanged. File and metadata writes share one atomic helper so failed conversion cannot overwrite a valid target.

**Tech Stack:** Flutter/Dart, `audio_decode` 1.3.3 native assets (minimp3), `flutter_test`, `dart:io`.

## Global Constraints

- Raise the package SDK floors from Dart `>=3.3.0 <4.0.0` to `>=3.10.0 <4.0.0` and Flutter `>=3.19.0` to `>=3.38.0`, because `audio_decode` requires Dart `^3.10.0`, which is first shipped by the Flutter 3.38 line.
- Add only `audio_decode: ^1.3.3`; do not use `glint_audio_pure`, FFmpeg, a platform channel, or Edge's `riff-*`/`raw-*` endpoint formats. Version 1.3.5 cannot resolve with this Flutter SDK because its `code_assets: ^2.0.0` dependency requires `hooks` versions incompatible with Flutter's pinned `meta: 1.17.0`; 1.3.3 uses compatible `code_assets: ^1.2.1` and preserves the required minimp3 implementation.
- WAV output must be standard little-endian RIFF/WAVE, PCM format tag `1`, 16 bits/sample, and preserve the decoder-reported sample rate and channel count.
- Expose only `synthesizeToWavFile` and `synthesizeSsmlToWavFile`; do not alter the behavior, signatures, or output bytes of existing `synthesize`, `synthesizeToFile`, `synthesizeSsml`, `synthesizeSsmlToFile`, or stream APIs.
- Force only the WAV export request to `EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3`; retain the caller's voice and metadata configuration.
- On invalid decoded geometry, decoder failure, malformed input, empty PCM, odd PCM byte length, or a RIFF/data length beyond `0xFFFFFFFF`, throw `EdgeTtsException` and leave an existing target file unchanged.
- Perform local file writes to a unique sibling temporary file and rename it only after the complete WAV and optional metadata have been written successfully; clean up temporary files on failure.
- Keep Edge's `riff24Khz16BitMonoPcm` rejected with `unsupported_output_format`.
- Add deterministic unit tests before each production change, add an opt-in live WAV integration test behind `RUN_LIVE_EDGE_TTS_TEST=true`, and document the new API in English and Simplified Chinese.

---

### Task 1: Add and verify the decoder dependency

**Files:**
- Modify: `pubspec.yaml:16-22`
- Modify: `CHANGELOG.md:1-8`
- Test: `test/flutter_edge_tts_test.dart`

**Interfaces:**
- Consumes: `audio_decode: ^1.3.3` exposes `PcmAudio`, `decodeMp3`, and `encodeWav`.
- Produces: a package baseline whose Dart constraint is compatible with the native-assets decoder.

- [ ] **Step 1: Add a failing compilation-level test that imports `audio_decode` and constructs a mono 24 kHz `PcmAudio`.**

```dart
import 'dart:typed_data';
import 'package:audio_decode/audio_decode.dart';

test('decoder dependency provides PCM audio geometry', () {
  final pcm = PcmAudio(
    sampleRate: 24000,
    channels: 1,
    samples: Int16List.fromList(<int>[0, 1]),
  );

  expect(pcm.frameCount, 2);
});
```

- [ ] **Step 2: Run the test and verify package resolution fails because `audio_decode` is not yet declared.**

Run: `flutter test test/flutter_edge_tts_test.dart`

Expected: compilation failure referring to `package:audio_decode/audio_decode.dart`.

- [ ] **Step 3: Update `pubspec.yaml` with `sdk: ">=3.10.0 <4.0.0"`, `flutter: ">=3.38.0"`, and `audio_decode: ^1.3.3`, then run `flutter pub get`.**

```yaml
environment:
  sdk: ">=3.10.0 <4.0.0"
  flutter: ">=3.38.0"

dependencies:
  audio_decode: ^1.3.3
```

- [ ] **Step 4: Run the focused test and verify it passes, then record the new feature and Dart floor in `CHANGELOG.md`.**

Run: `flutter test test/flutter_edge_tts_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add pubspec.yaml pubspec.lock test/flutter_edge_tts_test.dart CHANGELOG.md
git commit -m "build: add native MP3 decoder for WAV export"
```

### Task 2: Implement and test the strict PCM16 RIFF/WAVE encoder

**Files:**
- Create: `lib/src/utils/edge_tts_wav_encoder.dart`
- Modify: `lib/flutter_edge_tts.dart`
- Test: `test/edge_tts_wav_encoder_test.dart`

**Interfaces:**
- Consumes: `PcmAudio(sampleRate, channels, samples)` from `audio_decode`.
- Produces: `EdgeTtsWavEncoder.encodePcm16(PcmAudio audio) -> Uint8List`.

- [ ] **Step 1: Write failing tests for valid 24 kHz mono PCM output and invalid geometry.**

```dart
test('encodes decoder PCM as a canonical 16-bit RIFF/WAVE file', () {
  final wav = EdgeTtsWavEncoder.encodePcm16(PcmAudio(
    sampleRate: 24000,
    channels: 1,
    samples: Int16List.fromList(<int>[-32768, 0, 32767]),
  ));
  final data = ByteData.sublistView(wav);
  expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  expect(data.getUint16(20, Endian.little), 1);
  expect(data.getUint16(22, Endian.little), 1);
  expect(data.getUint32(24, Endian.little), 24000);
  expect(data.getUint16(34, Endian.little), 16);
  expect(data.getUint32(40, Endian.little), 6);
  expect(data.getInt16(44, Endian.little), -32768);
});

test('rejects unusable decoder geometry', () {
  expect(
    () => EdgeTtsWavEncoder.encodePcm16(PcmAudio(
      sampleRate: 0,
      channels: 1,
      samples: Int16List.fromList(<int>[0]),
    )),
    throwsA(isA<EdgeTtsException>()),
  );
});
```

- [ ] **Step 2: Run the encoder test and verify it fails because `EdgeTtsWavEncoder` does not exist.**

Run: `flutter test test/edge_tts_wav_encoder_test.dart`

Expected: compilation failure for missing `EdgeTtsWavEncoder`.

- [ ] **Step 3: Implement a 44-byte PCM16 RIFF/WAVE writer. Validate sample rate, channels, non-empty samples, frame alignment, and 32-bit RIFF chunk bounds before allocation; copy `Int16List` samples little-endian.**

```dart
final wav = Uint8List(44 + pcmBytes.length);
final header = ByteData.sublistView(wav);
// RIFF size = 36 + data length; format tag = 1; bits = 16.
```

- [ ] **Step 4: Export the encoder from `lib/flutter_edge_tts.dart`, run the focused test, and verify it passes.**

Run: `flutter test test/edge_tts_wav_encoder_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/flutter_edge_tts.dart lib/src/utils/edge_tts_wav_encoder.dart test/edge_tts_wav_encoder_test.dart
git commit -m "feat: add PCM16 WAV encoder"
```

### Task 3: Add WAV file synthesis APIs and atomic file persistence

**Files:**
- Modify: `lib/src/flutter_edge_tts.dart:1-350`
- Test: `test/flutter_edge_tts_test.dart`
- Test: `test/live_synthesis_test.dart`

**Interfaces:**
- Consumes: `EdgeTtsWavEncoder.encodePcm16`, `decodeMp3`, existing `synthesizeSsml` and `EdgeTtsFileResult`.
- Produces: `synthesizeToWavFile` and `synthesizeSsmlToWavFile`, both returning `Future<EdgeTtsFileResult>` with WAV bytes in `result.audioBytes`.

- [ ] **Step 1: Write failing public-API tests that reference both new method names and assert their return type. Add an opt-in live test which calls `synthesizeToWavFile`, then asserts `RIFF`, `WAVE`, PCM tag 1, non-empty data, and that the on-disk bytes equal `result.audioBytes`.**

```dart
expect(
  tts.synthesizeToWavFile(
    'hello',
    audioFilePath: output.path,
  ),
  isA<Future<EdgeTtsFileResult>>(),
);
```

- [ ] **Step 2: Run the deterministic API test and verify it fails because the methods do not exist.**

Run: `flutter test test/flutter_edge_tts_test.dart`

Expected: compilation failure for missing WAV API methods.

- [ ] **Step 3: Implement the two public methods. Build text SSML using the existing builder; clone only the resolved config's output format to `audio24Khz96KbitrateMonoMp3`; synthesize once; call `decodeMp3`; call `EdgeTtsWavEncoder.encodePcm16`; wrap decode failures in `EdgeTtsException('wav_decode_failed', ...)`.**

- [ ] **Step 4: Extract existing audio/metadata persistence into `_writeSynthesisResultToFile`. Implement the helper with sibling temporary files and `rename`, preserving an existing destination until all writes succeed. Use it for both the old generic file API and the new WAV API so metadata behavior remains consistent.**

- [ ] **Step 5: Run deterministic tests, then the opt-in live test.**

Run: `flutter test test/flutter_edge_tts_test.dart && flutter test test/live_synthesis_test.dart --dart-define=RUN_LIVE_EDGE_TTS_TEST=true -r expanded`

Expected: focused tests PASS; live test reports a non-empty valid PCM WAV.

- [ ] **Step 6: Commit.**

```bash
git add lib/src/flutter_edge_tts.dart test/flutter_edge_tts_test.dart test/live_synthesis_test.dart
git commit -m "feat: export Edge synthesis as WAV files"
```

### Task 4: Document, build, and release-check the feature

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/wav-export-research.md`

**Interfaces:**
- Consumes: the final public WAV methods and documented SDK floor.
- Produces: discoverable API documentation that distinguishes local WAV conversion from the unavailable Edge WAV endpoint.

- [ ] **Step 1: Write a README example in both languages showing `synthesizeToWavFile`, and state that it locally converts Edge MP3; retain the warning that `riff-24khz-16bit-mono-pcm` is unavailable.**

- [ ] **Step 2: Run `flutter analyze` and make only documentation or analyzer-required corrections.**

Run: `flutter analyze`

Expected: `No issues found!`.

- [ ] **Step 3: Run the full verification matrix.**

Run:

```bash
flutter test
flutter test test/live_synthesis_test.dart --dart-define=RUN_LIVE_EDGE_TTS_TEST=true -r expanded
flutter build macos --debug
flutter pub publish --dry-run
git diff --check
```

Expected: all commands exit 0. The live test and macOS build validate real native MP3 decoding and Flutter native-asset integration.

- [ ] **Step 4: Commit.**

```bash
git add README.md README.zh-CN.md docs/wav-export-research.md
git commit -m "docs: document local WAV export"
```
