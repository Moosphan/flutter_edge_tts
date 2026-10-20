## Unreleased

* Restored compatibility with Edge's v2 Sec-MS-GEC authentication protocol.
* Marked WAV output as unsupported because the upstream endpoint completes WAV
  requests without returning audio; use raw PCM, MP3, WebM, or Ogg instead.
* Added `synthesizeToWavFile` and `synthesizeSsmlToWavFile` to export local
  PCM WAV files by decoding Edge MP3 output locally. Existing synthesis and
  streaming APIs are unchanged.

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
