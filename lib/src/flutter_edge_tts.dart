import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models/edge_tts_config.dart';
import 'models/edge_tts_exception.dart';
import 'models/edge_tts_file_result.dart';
import 'models/edge_tts_metadata.dart';
import 'models/edge_tts_output_format.dart';
import 'models/edge_tts_prosody.dart';
import 'models/edge_tts_stream_event.dart';
import 'models/edge_tts_synthesis_result.dart';
import 'models/edge_tts_voice.dart';
import 'ssml/edge_tts_ssml_builder.dart';
import 'utils/edge_tts_utils.dart';

class FlutterEdgeTts {
  FlutterEdgeTts({
    required String voice,
    EdgeTtsOutputFormat outputFormat =
        EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
    String? voiceLocale,
    bool enableSentenceBoundary = false,
    bool enableWordBoundary = false,
    this.userAgent = _defaultUserAgent,
    this.origin = _defaultOrigin,
    this.enableLogging = false,
    this.connectionTimeout = const Duration(seconds: 20),
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _config = EdgeTtsConfig(
          voice: voice,
          outputFormat: outputFormat,
          voiceLocale: voiceLocale,
          enableSentenceBoundary: enableSentenceBoundary,
          enableWordBoundary: enableWordBoundary,
        );

  static const String _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _voicesUrl =
      'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list';
  static const String _wssUrl =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const String _chromiumFullVersion = '143.0.3650.75';
  static const String _secMsGecVersion = '1-$_chromiumFullVersion';
  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0';
  static const String _defaultOrigin =
      'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold';
  static const String _jsonXmlDelimiter = '\r\n\r\n';
  static const String _audioDelimiter = 'Path:audio\r\n';

  final http.Client _httpClient;
  final Set<WebSocket> _activeSockets = <WebSocket>{};

  EdgeTtsConfig _config;
  final String userAgent;
  final String origin;
  final bool enableLogging;
  final Duration connectionTimeout;

  EdgeTtsConfig get config => _config;

  Map<String, String> get _baseHeaders => <String, String>{
        HttpHeaders.userAgentHeader: userAgent,
        HttpHeaders.acceptEncodingHeader: 'gzip, deflate, br, zstd',
        HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
      };

  Map<String, String> get _voiceHeaders => <String, String>{
        ..._baseHeaders,
        'Authority': 'speech.platform.bing.com',
        'Sec-CH-UA':
            '" Not;A Brand";v="99", "Microsoft Edge";v="143", "Chromium";v="143"',
        'Sec-CH-UA-Mobile': '?0',
        HttpHeaders.acceptHeader: '*/*',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Dest': 'empty',
      };

  Map<String, String> _buildWebSocketHeaders() => <String, String>{
        ..._baseHeaders,
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Origin': origin,
        'Sec-WebSocket-Version': '13',
        HttpHeaders.cookieHeader: 'muid=${EdgeTtsUtils.generateMuid()};',
      };

  void updateConfig(EdgeTtsConfig config) {
    _config = config;
  }

  Future<List<EdgeTtsVoice>> getVoices() async {
    final uri = Uri.parse(_voicesUrl).replace(
      queryParameters: <String, String>{
        'trustedclienttoken': _trustedClientToken,
      },
    );
    final response = await _httpClient.get(
      uri,
      headers: _voiceHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EdgeTtsException(
        'voices_request_failed',
        'Voice request failed with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const EdgeTtsException(
        'invalid_voices_payload',
        'Voice list response was not a JSON array.',
      );
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(EdgeTtsVoice.fromJson)
        .toList(growable: false);
  }

  Stream<EdgeTtsStreamEvent> synthesizeStream(
    String text, {
    EdgeTtsProsody prosody = const EdgeTtsProsody(),
    EdgeTtsConfig? config,
    bool escapeText = true,
  }) {
    final resolvedConfig = config ?? _config;
    final ssml = EdgeTtsSsmlBuilder.build(
      text: text,
      config: resolvedConfig,
      prosody: prosody,
      escapeText: escapeText,
    );
    return synthesizeSsmlStream(ssml, config: resolvedConfig);
  }

  Stream<EdgeTtsStreamEvent> synthesizeSsmlStream(
    String ssml, {
    EdgeTtsConfig? config,
  }) {
    final resolvedConfig = config ?? _config;
    final requestId = EdgeTtsUtils.generateRequestId();
    final controller = StreamController<EdgeTtsStreamEvent>();
    WebSocket? socket;

    Future<void> cleanup() async {
      if (socket != null) {
        _activeSockets.remove(socket);
        await socket!.close();
      }
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    controller.onListen = () {
      unawaited(() async {
        try {
          socket = await _connectSocket();
          _activeSockets.add(socket!);
          socket!.pingInterval = const Duration(seconds: 30);

          socket!.listen(
            (dynamic message) {
              try {
                _handleMessage(message: message, controller: controller);
              } on Object catch (error) {
                controller.addError(error);
              }
            },
            onDone: () async {
              if (!controller.isClosed) {
                await controller.close();
              }
              _activeSockets.remove(socket);
            },
            onError: (Object error, StackTrace stackTrace) async {
              controller.addError(
                EdgeTtsException(
                  'websocket_error',
                  'Edge TTS websocket stream failed.',
                  cause: error,
                ),
                stackTrace,
              );
              await cleanup();
            },
            cancelOnError: true,
          );

          final timestamp = EdgeTtsUtils.formatJsTimestamp();
          socket!.add(
            _buildSpeechConfigMessage(resolvedConfig, timestamp: timestamp),
          );
          socket!.add(
            _buildSsmlRequest(
              ssml: ssml,
              requestId: requestId,
              timestamp: timestamp,
            ),
          );
        } on Object catch (error, stackTrace) {
          controller.addError(
            error is EdgeTtsException
                ? error
                : EdgeTtsException(
                    'synthesis_failed',
                    'Failed to start synthesis.',
                    cause: error,
                  ),
            stackTrace,
          );
          await cleanup();
        }
      }());
    };

    controller.onCancel = cleanup;
    return controller.stream;
  }

  Future<EdgeTtsSynthesisResult> synthesize(
    String text, {
    EdgeTtsProsody prosody = const EdgeTtsProsody(),
    EdgeTtsConfig? config,
    bool escapeText = true,
  }) async {
    final ssml = EdgeTtsSsmlBuilder.build(
      text: text,
      config: config ?? _config,
      prosody: prosody,
      escapeText: escapeText,
    );
    return synthesizeSsml(ssml, config: config);
  }

  Future<EdgeTtsFileResult> synthesizeToFile(
    String text, {
    required String audioFilePath,
    String? metadataFilePath,
    EdgeTtsProsody prosody = const EdgeTtsProsody(),
    EdgeTtsConfig? config,
    bool escapeText = true,
  }) async {
    final ssml = EdgeTtsSsmlBuilder.build(
      text: text,
      config: config ?? _config,
      prosody: prosody,
      escapeText: escapeText,
    );
    return synthesizeSsmlToFile(
      ssml,
      audioFilePath: audioFilePath,
      metadataFilePath: metadataFilePath,
      config: config,
    );
  }

  Future<EdgeTtsSynthesisResult> synthesizeSsml(
    String ssml, {
    EdgeTtsConfig? config,
  }) async {
    final bytesBuilder = BytesBuilder(copy: false);
    final metadataItems = <EdgeTtsMetadataItem>[];
    final requestId = EdgeTtsUtils.generateRequestId();

    await for (final event in synthesizeSsmlStream(ssml, config: config)) {
      if (event is EdgeTtsAudioChunkEvent) {
        bytesBuilder.add(event.chunk);
      } else if (event is EdgeTtsMetadataEvent) {
        metadataItems.addAll(event.metadata.items);
      }
    }

    final audioBytes = bytesBuilder.takeBytes();
    if (audioBytes.isEmpty) {
      throw const EdgeTtsException(
        'empty_audio',
        'No audio bytes were returned by the synthesis request.',
      );
    }

    return EdgeTtsSynthesisResult(
      audioBytes: audioBytes,
      metadata: List<EdgeTtsMetadataItem>.unmodifiable(metadataItems),
      requestId: requestId,
    );
  }

  Future<EdgeTtsFileResult> synthesizeSsmlToFile(
    String ssml, {
    required String audioFilePath,
    String? metadataFilePath,
    EdgeTtsConfig? config,
  }) async {
    final result = await synthesizeSsml(ssml, config: config);
    final audioFile = File(audioFilePath);
    await audioFile.parent.create(recursive: true);
    await audioFile.writeAsBytes(result.audioBytes, flush: true);

    String? savedMetadataPath;
    if (metadataFilePath != null && result.metadata.isNotEmpty) {
      final metadataFile = File(metadataFilePath);
      await metadataFile.parent.create(recursive: true);
      final metadata = EdgeTtsMetadata(items: result.metadata);
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
        flush: true,
      );
      savedMetadataPath = metadataFile.path;
    }

    return EdgeTtsFileResult(
      audioFilePath: audioFile.path,
      metadataFilePath: savedMetadataPath,
      result: result,
    );
  }

  Future<void> close() async {
    for (final socket in List<WebSocket>.from(_activeSockets)) {
      await socket.close();
    }
    _activeSockets.clear();
    _httpClient.close();
  }

  Future<void> dispose() => close();

  Future<WebSocket> _connectSocket() async {
    final url = await _buildSynthesisUrl();
    _log('Connecting websocket: $url');
    final uri = Uri.parse(url);
    final requestUri = uri.replace(scheme: uri.scheme == 'wss' ? 'https' : 'http');
    final httpClient = HttpClient()..userAgent = userAgent;
    try {
      final request = await httpClient
          .openUrl('GET', requestUri)
          .timeout(connectionTimeout);
      request.headers.set(HttpHeaders.hostHeader, uri.host);
      request.headers.set(HttpHeaders.upgradeHeader, 'websocket');
      request.headers.set(HttpHeaders.connectionHeader, 'Upgrade');
      request.headers.set(
        'Sec-WebSocket-Key',
        EdgeTtsUtils.generateWebSocketKey(),
      );
      request.headers.set('Sec-WebSocket-Version', '13');
      request.headers.set(
        'Sec-WebSocket-Extensions',
        'permessage-deflate; client_max_window_bits',
      );
      for (final entry in _buildWebSocketHeaders().entries) {
        request.headers.set(entry.key, entry.value);
      }

      final response = await request.close().timeout(connectionTimeout);
      if (response.statusCode != HttpStatus.switchingProtocols) {
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(connectionTimeout);
        throw EdgeTtsException(
          'websocket_upgrade_failed',
          'Edge TTS websocket upgrade failed with status '
          '${response.statusCode}.',
          cause: body.isEmpty ? null : body,
        );
      }

      final socket = await response.detachSocket().timeout(connectionTimeout);
      return WebSocket.fromUpgradedSocket(
        socket,
        serverSide: false,
        compression: CompressionOptions.compressionDefault,
      );
    } on Object catch (error) {
      throw EdgeTtsException(
        'connection_failed',
        'Failed to connect to the Edge TTS websocket.',
        cause: error,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<String> _buildSynthesisUrl() async {
    final connectionId = EdgeTtsUtils.generateConnectionId();
    final secMsGec = EdgeTtsUtils.generateSecMsGec(_trustedClientToken);
    return '$_wssUrl'
        '?TrustedClientToken=$_trustedClientToken'
        '&Sec-MS-GEC=$secMsGec'
        '&Sec-MS-GEC-Version=$_secMsGecVersion'
        '&ConnectionId=$connectionId';
  }

  String _buildSpeechConfigMessage(
    EdgeTtsConfig config, {
    required String timestamp,
  }) {
    final body = jsonEncode(<String, dynamic>{
      'context': <String, dynamic>{
        'synthesis': <String, dynamic>{
          'audio': <String, dynamic>{
            'metadataoptions': <String, String>{
              'sentenceBoundaryEnabled': '${config.enableSentenceBoundary}',
              'wordBoundaryEnabled': '${config.enableWordBoundary}',
            },
            'outputFormat': config.outputFormat.value,
          },
        },
      },
    });
    return 'X-Timestamp:$timestamp\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config$_jsonXmlDelimiter$body';
  }

  String _buildSsmlRequest({
    required String ssml,
    required String requestId,
    required String timestamp,
  }) {
    return 'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${timestamp}Z\r\n'
        'Path:ssml$_jsonXmlDelimiter${ssml.trim()}';
  }

  void _handleMessage({
    required dynamic message,
    required StreamController<EdgeTtsStreamEvent> controller,
  }) {
    final bytes = switch (message) {
      String value => Uint8List.fromList(utf8.encode(value)),
      List<int> value => Uint8List.fromList(value),
      _ => throw EdgeTtsException(
          'invalid_message_type',
          'Received unsupported websocket message type: ${message.runtimeType}.',
        ),
    };
    final text = utf8.decode(bytes, allowMalformed: true);

    if (text.contains('Path:turn.start') || text.contains('Path:response')) {
      _log('Received control message.');
      return;
    }

    if (text.contains('Path:turn.end')) {
      _log('Received turn end.');
      unawaited(controller.close());
      return;
    }

    if (text.contains('Path:audio.metadata')) {
      final payload = _extractAfterDelimiter(bytes, _jsonXmlDelimiter);
      final decoded = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      controller.add(EdgeTtsMetadataEvent(EdgeTtsMetadata.fromJson(decoded)));
      return;
    }

    if (text.contains('Path:audio')) {
      final payload = _extractAfterDelimiter(bytes, _audioDelimiter);
      controller.add(EdgeTtsAudioChunkEvent(payload));
      return;
    }

    _log('Ignoring unknown message: $text');
  }

  Uint8List _extractAfterDelimiter(List<int> bytes, String delimiter) {
    final delimiterBytes = utf8.encode(delimiter);
    final index = EdgeTtsUtils.indexOfSublist(bytes, delimiterBytes);
    if (index < 0) {
      throw EdgeTtsException(
        'invalid_message_format',
        'Could not find delimiter $delimiter in websocket payload.',
      );
    }
    return Uint8List.fromList(bytes.sublist(index + delimiterBytes.length));
  }

  void _log(String message) {
    if (enableLogging) {
      // ignore: avoid_print
      print('[flutter_edge_tts] $message');
    }
  }
}
