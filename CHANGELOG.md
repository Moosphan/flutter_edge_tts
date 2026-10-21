## 0.0.3

* Added `synthesizeToWavFile` and `synthesizeSsmlToWavFile`, which locally
  decode Edge MP3 output to PCM16 RIFF/WAVE files.
* Added the native MP3 decoder dependency required for local WAV export.
* Raised the minimum supported SDKs to Dart 3.10.0 and Flutter 3.38.0 for
  native-assets support.
* Restored compatibility with Edge's v2 Sec-MS-GEC authentication protocol.
* Kept direct Edge WAV output unsupported because the upstream endpoint
  completes WAV requests without returning audio.
* Updated the example's WAV option to use the local conversion API rather than
  Edge's unavailable RIFF output format.

## 0.0.2

* Added `pub.dev` screenshots metadata for package previews.
* Updated README previews to use stable hosted image URLs and tighter sizing.
* Removed maintainer-only publishing sections from the public README.
* Improved the publish helper messaging to avoid hard-coded local proxy examples.

## 0.0.1

* Initial open-source release candidate.
* Added a shared Dart implementation for Android, iOS, macOS, Windows, and Linux.
* Added voice listing, text synthesis, SSML synthesis, file output, and stream APIs.
* Added metadata parsing for sentence and word boundary events.
* Added a richer example app with voice/format selection and synthesis diagnostics.
* Added desktop example runners for macOS, Windows, and Linux.
