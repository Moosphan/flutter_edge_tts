# flutter_edge_tts

[![Version](https://img.shields.io/pub/v/flutter_edge_tts.svg)](https://pub.dev/packages/flutter_edge_tts)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform: Android+iOS+macOS+Windows+Linux](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-0a7ea4)](#平台支持)

<table>
  <tr>
    <td><strong>中文</strong></td>
    <td><a href="README.md">English</a></td>
  </tr>
</table>

**基于 Microsoft Edge 在线语音合成服务的 Flutter 免费 TTS 工具包。**

`flutter_edge_tts` 以共享 Dart 合成层为核心，为 Android、iOS、macOS、Windows 和 Linux 提供统一的音色加载、文本与 SSML 合成、文件输出以及合成元数据解析能力。

## 特性

- 免费、开源的 Flutter TTS 工具包
- 面向移动端与桌面端的共享 Dart 实现
- 基于 Microsoft Edge 在线语音合成服务的实时音色发现
- 支持文本合成为字节、文件或流式事件
- 支持原始 SSML 合成
- 支持句子边界和单词边界元数据
- 支持 MP3、WebM、Ogg、PCM、WAV 等输出格式
- 截至 2026-06-03，live endpoint 当前返回 322 个音色，覆盖 142 个 locale、75 种语言

## 平台支持

- Android
- iOS
- macOS
- Windows
- Linux

## 效果预览

<table>
  <tr>
    <td align="center"><strong>移动端</strong></td>
    <td align="center"><strong>桌面端</strong></td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://raw.githubusercontent.com/Moosphan/flutter_edge_tts/main/doc/images/screenshot_iphone_preview1.png" alt="iPhone 预览 1" width="200">
      <img src="https://raw.githubusercontent.com/Moosphan/flutter_edge_tts/main/doc/images/screenshot_iphone_preview2.png" alt="iPhone 预览 2" width="200">
    </td>
    <td align="center">
      <img src="https://raw.githubusercontent.com/Moosphan/flutter_edge_tts/main/doc/images/flutter_edge_tts_preview_mac1.png" alt="macOS 预览 1" width="320"><br>
      <img src="https://raw.githubusercontent.com/Moosphan/flutter_edge_tts/main/doc/images/flutter_edge_tts_preview_mac2.png" alt="macOS 预览 2" width="320">
    </td>
  </tr>
</table>

## 安装

```yaml
dependencies:
  flutter_edge_tts: ^0.0.2
```

```bash
flutter pub get
```

## 快速开始

```dart
import 'package:flutter_edge_tts/flutter_edge_tts.dart';

final tts = FlutterEdgeTts(
  voice: 'en-US-AriaNeural',
  outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
);

final result = await tts.synthesize('Hello from Flutter.');
print(result.audioBytes.length);

await tts.close();
```

## 核心 API

### 获取音色列表

```dart
final voices = await tts.getVoices();
print(voices.first.shortName);
```

### 文本合成

```dart
final result = await tts.synthesize(
  'Hello from Flutter.',
  prosody: const EdgeTtsProsody(
    rate: '1.05',
    pitch: '+10Hz',
    volume: '100',
  ),
);
```

### 合成到文件

```dart
final result = await tts.synthesizeToFile(
  'Hello from Flutter.',
  audioFilePath: '/tmp/edge.mp3',
  metadataFilePath: '/tmp/edge.json',
);
```

### 流式事件合成

```dart
final stream = tts.synthesizeStream(
  'Hello from Flutter.',
  prosody: const EdgeTtsProsody(rate: '1.1', pitch: '+20Hz'),
);

await for (final event in stream) {
  if (event is EdgeTtsAudioChunkEvent) {
    print(event.chunk.length);
  } else if (event is EdgeTtsMetadataEvent) {
    print(event.metadata.items.length);
  }
}
```

### 原始 SSML 合成

```dart
final ssml = '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
  <voice name="en-US-AriaNeural">
    <prosody rate="1.05" pitch="+10Hz">
      Hello from raw SSML.
    </prosody>
  </voice>
</speak>
''';

final result = await tts.synthesizeSsml(ssml);
```

## 配置方式

```dart
final tts = FlutterEdgeTts(
  voice: 'en-US-AriaNeural',
  voiceLocale: 'en-US',
  outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
  enableSentenceBoundary: true,
  enableWordBoundary: true,
);
```

```dart
tts.updateConfig(
  tts.config.copyWith(
    voice: 'en-GB-SoniaNeural',
    enableWordBoundary: true,
  ),
);
```

## 音色命名与兼容性

常见音色名称通常类似：

- `en-US-AriaNeural`
- `en-US-AndrewMultilingualNeural`

音色名前缀中的 locale 表示该音色的主语言区域。当前包也会利用这一命名规则，在没有显式传入 `voiceLocale` 时自动推断默认值。

更广的 Microsoft Azure Speech 生态中还存在 `Neural`、`MultilingualNeural`、`Neural HD`、`MAI-Voice-1` 等音色家族。当前包围绕 Edge Read Aloud 风格的传输链路实现，而不是完整 Azure Speech SDK 封装，因此标准 `Neural` 音色是最稳妥的默认选择。更偏 Azure 专有能力的高级音色，建议先在你的环境中验证，再作为正式支持项开放。

在实际接入中，优先使用 `getVoices()` 的动态返回结果，而不是完全依赖手工硬编码。

## 元数据

启用句子边界或单词边界元数据后，合成结果除了音频外，还会返回结构化元数据。这适合用于跟读高亮、字幕时间轴、无障碍阅读辅助和语言学习界面。

## 示例应用

仓库自带一个可运行 demo，位置在 [example/lib/main.dart](example/lib/main.dart)。它演示了音色加载、音色选择、输出格式切换、元数据开关以及文件合成。

## 说明

- 高级文本 API 默认会做 XML 转义；原始 SSML 仍应由调用方保证内容安全。
- 当前包不内置播放器，播放能力由宿主应用自行接入。
- 音色数与语言数来自 live endpoint，后续可能随上游变化而变化。
- 上游服务行为可能随时间变化。如果请求头、WebSocket 消息格式或音色接口发生变化，包可能需要同步升级。

## 项目

- Repository: [Moosphan/flutter_edge_tts](https://github.com/Moosphan/flutter_edge_tts)
- Issue tracker: [GitHub Issues](https://github.com/Moosphan/flutter_edge_tts/issues)

## License

[MIT](LICENSE)
