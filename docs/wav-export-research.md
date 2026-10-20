# WAV 导出支持方案调研

> 调研日期：2026-10-20<br>
> 目标：在不破坏现有 Edge TTS 字节、文件和流式 API 的前提下，给
> `flutter_edge_tts` 增加可靠的 `.wav` 文件导出。

## 结论

建议采用“**Edge 输出 MP3 + 本地 MPEG-2/1 Layer III 解码 + RIFF/WAVE 封装**”的批量文件方案，作为新增 API，而不是继续请求 Edge 的
`riff-24khz-16bit-mono-pcm`。

推荐的公共 API 形态为 `synthesizeToWavFile` 和
`synthesizeSsmlToWavFile`（名称可在实现时确定），并保持现有
`synthesize`、`synthesizeToFile`、`synthesizeStream` 的行为和返回格式不变。
WAV API 内部固定请求当前已验证可用的
`audio-24khz-96kbitrate-mono-mp3`，解码得到 PCM16，再写入标准 RIFF/WAVE
文件。这样 Edge 端点是否实现 WAV 不再影响导出功能；由于输入是 MP3，导出
WAV 是“解码后的 PCM 容器”，**不会恢复 MP3 已丢失的音质**。

首选实现是一个独立的、可审计许可证的 `minimp3` FFI/native-codec 层：
`lieff/minimp3` 是单头文件、ISO conformance 测试通过的 MP3 解码器，README
明确列出 MPEG-2 Layer 3 每帧 576 个采样，并以 CC0-1.0 发布。Dart 侧只负责
编排、错误处理和 WAV 封装。若项目必须支持 Web，Web 继续保留 MP3/PCM API；
WAV 转换层在 Web 端应返回明确的 `wav_conversion_unavailable`，或另行接入
Web Audio/`AudioDecoder` 实现，不能把 `dart:ffi` 当成 Web 通用方案。

原生实现应使用 Dart 的 native-assets build hooks，而不是把预编译 `.so` /
`.dylib` / `.dll` 人工放进包里。Dart 官方文档说明此机制可编译或下载 C/Rust
native assets，并在构建时自动调用；但 build hooks 从 Dart 3.10 才开始提供，
所以当前包的 `sdk: >=3.3.0` 约束必须在实现前升级，或改用传统 Flutter 插件的
五平台构建脚本。[Dart Hooks / native assets](https://dart.dev/tools/hooks)
是这一兼容性结论的一手来源。

## 已确认的约束

### Edge 端点

仓库当前的实测回归测试只把 MP3 音频头（ID3 或 MPEG frame）作为在线成功条件：
[`test/live_synthesis_test.dart`](../test/live_synthesis_test.dart)。Issue #2
记录了请求 WAV 后得到 `empty_audio`：
[#2 输出音频格式不支持 wav？](https://github.com/Moosphan/flutter_edge_tts/issues/2)。
当前实现因此对 `riff-24khz-16bit-mono-pcm` 提前抛出
`unsupported_output_format`，该行为不应改回“盲目请求 WAV”。

Issue #3 的 403 修复和 v2 `Sec-MS-GEC` 认证已在当前分支验证；新的 WAV 方案
应复用这条已经工作的 MP3 请求链路，而不是增加第二条 Edge 协议实现。

### WAV 文件格式

PCM WAV 至少需要 `RIFF`、`WAVE`、`fmt ` 和 `data` 四个 chunk。`fmt ` 中的
`WAVEFORMATEX` 字段包括格式码（PCM 为 1）、声道数、采样率、字节率、块对齐和
位深；所有整数按 little-endian 写入。Microsoft 的字段定义见
[`WAVEFORMATEX`](https://learn.microsoft.com/en-us/windows/win32/api/mmreg/ns-mmreg-waveformatex)。

第一版只接受解码器报告的 PCM16、正采样率和 1/2 声道，使用 44 字节标准头；
PCM 数据长度超过 RIFF 32-bit chunk 上限时失败并提示暂不支持，而不是写出
损坏的文件。文件应先写到同目录临时文件，成功后再原子替换目标文件，避免
网络或解码中断留下一个看似有效的半截 WAV。

## 候选方案比较

| 方案 | 可行性 | 优点 | 主要问题 / 结论 |
| --- | --- | --- | --- |
| Edge 请求 `riff-24khz-16bit-mono-pcm`，直接保存 | 不可行（当前上游行为） | 理论上无损、实现最简单 | 当前请求正常结束但无音频字节，正是 Issue #2；不能作为实现方案。 |
| Edge 请求 `raw-24khz-16bit-mono-pcm`，加 44 字节 WAV 头 | 暂不可行 | 若端点恢复 PCM，这是质量最佳、无需 MP3 解码的路径 | 当前 live 验证同样没有可依赖的 PCM 音频；应保留为未来能力探测，不应作为默认路径。 |
| 纯 Dart MP3 解码器 | 暂不可行 | Web、移动端和桌面共用 Dart；无需 native 构建 | 当前可查的 `glint_audio_pure` 文档把范围写为 **MPEG-1 Layer III**，而 Edge 返回的 24 kHz MPEG-2 frame 需要 MPEG-2 支持；此前实验因此不能作为可靠实现。见 [`glint_audio_pure`](https://pub.dev/packages/glint_audio_pure) 及其 [API/范围说明](https://github.com/CrispStrobe/glint/blob/main/bindings/dart_pure/README.md)。除非上游明确加入 MPEG-2 并通过 Edge fixture，否则不应接入。 |
| [`audio_decode`](https://pub.dev/packages/audio_decode)（现成 native-assets 包） | 技术上可行，但当前不能直接采用 | 已使用 `minimp3` 经 FFI 解码 MP3 为 PCM，不需要自己维护 C binding | 当前发布版要求 Dart `^3.10.0`，并引入 `hooks`、`code_assets` 和 C 工具链；与本包 `>=3.3.0` SDK 基线冲突，且需先在 Flutter 全平台验证构建和运行。可作为提高 SDK 下限后的原型/对照实现，不能作为零风险普通依赖。其 [pubspec 元数据](https://pub.dev/api/packages/audio_decode) 是版本、依赖和 SDK 约束的一手来源。 |
| [`audio_decoder`](https://pub.dev/packages/audio_decoder)（Flutter 平台插件） | 可作为应用层备选，不推荐成为核心默认依赖 | 公共 API 提供 MP3 转 WAV，且可委托平台解码能力 | 依赖 Flutter 插件和各平台实现，当前版本要求 Dart `^3.10.8`；会让轻量网络 TTS 包承担平台二进制、构建和发布维护面。实现前仍须用真实 Edge MPEG-2 fixture 验证其输出元数据。 |
| `minimp3` C 源码 + `dart:ffi`/native assets | **推荐（原生平台，前提是提高 Dart SDK 下限）** | 单一解码内核覆盖 MPEG-1/2 Layer III；小、快、CC0；可逐帧解码并直接产出 PCM | Native-assets hooks 需要 Dart 3.10；否则需用传统 Flutter 插件构建。Web 仍要条件导入并返回“不支持”或另有 Web 实现。官方项目：[README](https://github.com/lieff/minimp3/blob/master/README.md)、[许可证](https://github.com/lieff/minimp3/blob/master/LICENSE)、[Dart Hooks](https://dart.dev/tools/hooks)。 |
| 各平台系统解码器 + Flutter platform channel | 可行但维护成本高 | 使用系统 MP3 解码器，不携带 C 源码；可利用 Android MediaCodec、Apple AVFoundation、Windows Media Foundation 等 | 需要 5 套平台实现和不同的采样/尾帧行为；Linux/Web 仍需额外方案。Flutter 官方说明平台通道按平台分别实现，见 [platform channels](https://docs.flutter.dev/platform-integration/platform-channels)。不适合当前轻量、纯 Dart 的包作为第一版。 |
| 外部 `ffmpeg` 可执行文件 | 不推荐 | 格式覆盖最全，验证工具成熟 | 手机和 Web 没有可假设的 ffmpeg 可执行文件；需随应用分发二进制、处理进程/沙箱和许可证。FFmpeg 自身许可取决于构建选项，见 [FFmpeg legal](https://ffmpeg.org/legal.html)，不适合公共包默认依赖。 |

## 推荐架构

### 分层

1. `EdgeMp3Source`：复用现有 WebSocket、认证、元数据和取消逻辑，固定选择
   已验证的 MP3 输出。不得修改现有 `EdgeTtsOutputFormat` 的含义。
2. `Mp3Decoder`：定义很小的接口，例如输入 `Uint8List`，输出
   `{pcm16, sampleRate, channels}`。原生实现通过 FFI/native assets；解码器只
   允许 MPEG-1/2 Layer III，遇到无效帧、采样率或声道变化时返回结构化错误。
3. `WavPcmEncoder`：纯 Dart 实现 RIFF/WAVE PCM16 头和数据拼接；不承担 MP3
   解码，不改变采样值。建议同时提供 `encode(Uint8List pcm16, ...)` 的纯单元测试
   API，方便未来 raw PCM 端点恢复后直接复用。
4. `WavFileWriter`：收集完输入后写临时文件，校验长度与头部字段，再原子替换
   目标；metadata JSON 继续沿用现有结果。

### API 与兼容性

- 新增 `synthesizeToWavFile` / `synthesizeSsmlToWavFile`，返回现有
  `EdgeTtsFileResult`，其中 `result.audioBytes` 是最终 WAV 字节。
- 新 API 的 `config.outputFormat` 只保留 voice/metadata 设置，内部覆盖为 MP3；
  文档明确“输出 WAV 是本地转换，不是 Edge 的 `riff-*` 响应”。
- 不改变 `synthesize` 返回的 MP3/PCM/WebM/Ogg 字节，不改变
  `synthesizeStream` 的事件类型或 chunk 语义，也不把现有 `riff24...` 枚举值
  伪装成可用格式。
- Web 端使用条件导入：若没有可用解码器，抛出
  `wav_conversion_unavailable`，并保留用户请求 MP3 后在应用层用 Web Audio
  转换的选择。Dart 官方 C interop 入口为 [`dart:ffi`](https://dart.dev/interop/c-interop)。

### 可靠性细节

- `synthesizeToWavFile` 为批量 API；标准 WAV 头要写入最终 data 长度，因此不把
  未完成的 WAV chunk 暴露为“实时 WAV 流”。现有 MP3 流式 API 保持不变。
- 先写 `path.tmp.<requestId>`，在所有解码帧成功且 RIFF 长度校验通过后 rename；
  失败时删除临时文件并保留原目标文件。
- 对输入 MP3 做 ID3 跳过、跨 chunk 缓冲和最后一帧 flush；以解码器报告的实际
  `sampleRate/channels` 写头，不硬编码为 24 kHz，避免未来 Edge 输出变体时生成
  错误 WAV。
- 若将来 Edge 的 raw PCM 端点重新返回数据，新增 `PcmWavEncoder` 快速路径；
  通过 capability probe 或显式配置选择，失败后才回退 MP3 解码，不能默默把空
  响应写成 WAV。

## 测试与验收清单

### 不联网单元测试

- WAV 头：`RIFF/WAVE/fmt/data` 标识、PCM=1、little-endian、采样率、声道、
  blockAlign、byteRate、data 和 RIFF 长度一致。
- 空 PCM、奇数长度 PCM、超 32-bit chunk、非法声道/采样率均得到明确错误。
- `minimp3` MPEG-1、MPEG-2 Layer III fixture（至少包含 Edge 24 kHz 响应）、
  ID3 前缀、跨输入 chunk 和截断帧；解码失败不得生成目标文件。
- 现有 `synthesize`、`synthesizeToFile`、`synthesizeStream` 回归测试确保
  新 API 不改旧行为。

### 在线与跨平台测试

- 在线测试必须显式通过
  `--dart-define=RUN_LIVE_EDGE_TTS_TEST=true`，默认 CI 不访问 Edge；检查 MP3
  非空、WAV data 非空、头部长度与 `data` 长度一致。
- Android/iOS/macOS/Windows/Linux 真机或 runner 各跑一次 FFI 加载、解码和写文件；
  额外验证 arm64/x64 与 release 构建。
- Web 构建验证条件导入和 `wav_conversion_unavailable`，同时确认原有 MP3 API
  可用。
- 可选地用系统 `ffprobe`/Python `wave` 读取生成文件，检查采样率、声道、位深、
  时长与解码器报告一致；该工具只做测试验证，不成为运行时依赖。

## 许可与发布检查

`minimp3` 仓库标记 CC0-1.0，仍应在 `NOTICE` 或第三方声明中记录来源、版本和
校验哈希。若改用其他 MP3 解码器，必须在选择依赖前审查其许可证；不能把 GPL
或 LGPL 代码静默放入当前 MIT 包。发布前应运行 `flutter pub publish --dry-run`
并检查所有平台二进制/头文件随包发布的许可证文本。

## 实施顺序

1. 先提交独立 WAV 编码器和 `Mp3Decoder` 接口、许可证/NOTICE、离线 fixtures
   与单元测试，不接入公开 API。
2. 决定兼容性基线：提高到 Dart 3.10+ 后接入 native assets，或维持 Dart 3.3
   并创建传统 Flutter plugin 的五平台构建。完成真实 MPEG-2 fixture 验证后再开启
   API。
3. 增加两个 WAV 文件 API、临时文件/原子替换和文档；运行完整矩阵后再发布。
4. 若 native assets 无法在目标 Flutter/Dart 最低版本稳定构建，则退回“平台专用
   codec 插件”路线，保持核心包不强制引入原生依赖。
