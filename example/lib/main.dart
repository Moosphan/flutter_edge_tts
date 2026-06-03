import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const EdgeTtsExampleApp());
}

class EdgeTtsExampleApp extends StatelessWidget {
  const EdgeTtsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F9FF);
    const surface = Color(0xFFFFFFFF);
    const surfaceSoft = Color(0xFFEFF4FF);
    const surfaceStrong = Color(0xFFDDE6F7);
    const primary = Color(0xFF630ED4);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      surface: background,
    ).copyWith(
      surface: background,
      surfaceContainerLow: surfaceSoft,
      surfaceContainerHighest: surfaceStrong,
      primaryContainer: const Color(0xFF7C3AED),
      secondaryContainer: const Color(0xFFDCD5FD),
      outlineVariant: const Color(0xFFCCD5E6),
      onSurface: const Color(0xFF121C2A),
      onSurfaceVariant: const Color(0xFF5F5A7C),
    );

    return MaterialApp(
      title: 'Voice Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: background,
        useMaterial3: true,
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: const Color(0xFF121C2A),
              displayColor: const Color(0xFF121C2A),
            ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFD9E3F6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFD9E3F6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: primary, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: const EdgeTtsExamplePage(),
    );
  }
}

class EdgeTtsExamplePage extends StatefulWidget {
  const EdgeTtsExamplePage({super.key});

  @override
  State<EdgeTtsExamplePage> createState() => _EdgeTtsExamplePageState();
}

class _EdgeTtsExamplePageState extends State<EdgeTtsExamplePage> {
  static const _mobileBreakpoint = 840.0;

  final TextEditingController _textController = TextEditingController(
    text:
        'Hello from flutter_edge_tts. This example uses live Edge voices, responsive layouts, and local file export.',
  );

  late FlutterEdgeTts _edgeTts;
  late final AudioPlayer _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  List<EdgeTtsVoice> _voices = const <EdgeTtsVoice>[];
  String _selectedLocale = 'en-US';
  String _selectedVoice = 'en-US-AriaNeural';
  EdgeTtsOutputFormat _selectedFormat =
      EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3;

  bool _sentenceBoundary = false;
  bool _wordBoundary = false;
  bool _loadingVoices = false;
  bool _synthesizing = false;

  double _speed = 1.0;
  int _volume = 80;
  int _pitch = 0;

  String _status = 'Ready';
  String? _audioPath;
  String? _metadataPath;
  int _audioBytes = 0;
  int _metadataItems = 0;
  PlayerState _playerState = PlayerState.stopped;
  bool _playbackBusy = false;

  @override
  void initState() {
    super.initState();
    _edgeTts = FlutterEdgeTts(voice: _selectedVoice);
    _audioPlayer = AudioPlayer();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playerState = state;
        if (state != PlayerState.stopped) {
          _playbackBusy = false;
        }
        if (state == PlayerState.completed) {
          _status = 'Playback complete';
        }
      });
    });
    _loadVoices();
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    unawaited(_audioPlayer.dispose());
    _textController.dispose();
    _edgeTts.close();
    super.dispose();
  }

  List<String> get _availableLocales {
    final locales = _voices.map((voice) => voice.locale).toSet().toList()
      ..sort();
    return locales;
  }

  List<EdgeTtsVoice> get _localeVoices {
    final voices = _voices
        .where((voice) => voice.locale == _selectedLocale)
        .toList(growable: false);
    if (voices.isNotEmpty) {
      return voices;
    }
    return _voices;
  }

  bool get _hasVoices => _voices.isNotEmpty;

  bool get _voiceLoadFailed => !_loadingVoices && _voices.isEmpty;

  bool get _canPlayAudio =>
      _audioPath != null &&
      _selectedFormat.isContainerFormat &&
      !_synthesizing &&
      !_playbackBusy;

  bool get _isPlaying => _playerState == PlayerState.playing;

  bool get _isPaused => _playerState == PlayerState.paused;

  EdgeTtsVoice? get _currentVoice {
    for (final voice in _voices) {
      if (voice.shortName == _selectedVoice) {
        return voice;
      }
    }
    return null;
  }

  String _formatLabel(EdgeTtsOutputFormat format) {
    switch (format) {
      case EdgeTtsOutputFormat.audio16Khz32KbitrateMonoMp3:
        return 'MP3 16kHz / 32kbps';
      case EdgeTtsOutputFormat.audio16Khz64KbitrateMonoMp3:
        return 'MP3 16kHz / 64kbps';
      case EdgeTtsOutputFormat.audio24Khz48KbitrateMonoMp3:
        return 'MP3 24kHz / 48kbps';
      case EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3:
        return 'MP3 24kHz / 96kbps';
      case EdgeTtsOutputFormat.audio48Khz96KbitrateMonoMp3:
        return 'MP3 48kHz / 96kbps';
      case EdgeTtsOutputFormat.raw24Khz16BitMonoPcm:
        return 'PCM 24kHz / 16-bit';
      case EdgeTtsOutputFormat.riff24Khz16BitMonoPcm:
        return 'WAV 24kHz / 16-bit';
      case EdgeTtsOutputFormat.webm24Khz16BitMonoOpus:
        return 'WebM 24kHz / Opus';
      case EdgeTtsOutputFormat.ogg24Khz16BitMonoOpus:
        return 'Ogg 24kHz / Opus';
    }
  }

  List<String> get _voiceTraits {
    final voice = _currentVoice;
    if (voice == null) {
      return const <String>['Warm', 'Energetic', 'Calm'];
    }

    final traits = <String>{};
    if (voice.gender.toLowerCase().contains('female')) {
      traits.add('Warm');
    } else {
      traits.add('Focused');
    }
    if (voice.shortName.contains('Multilingual')) {
      traits.add('Flexible');
    } else {
      traits.add('Natural');
    }
    if (voice.status.toLowerCase() == 'ga') {
      traits.add('Production');
    } else {
      traits.add('Preview');
    }
    return traits.toList(growable: false);
  }

  Future<void> _loadVoices() async {
    setState(() {
      _loadingVoices = true;
      _status = 'Loading live voice catalog...';
    });

    try {
      final voices = await _edgeTts.getVoices();
      voices.sort((a, b) {
        final localeCompare = a.locale.compareTo(b.locale);
        if (localeCompare != 0) {
          return localeCompare;
        }
        return a.shortName.compareTo(b.shortName);
      });

      final locales = voices.map((voice) => voice.locale).toSet().toList()
        ..sort();
      var selectedLocale = _selectedLocale;
      if (!locales.contains(selectedLocale) && locales.isNotEmpty) {
        selectedLocale = locales.first;
      }

      final localeVoices = voices
          .where((voice) => voice.locale == selectedLocale)
          .toList(growable: false);
      var selectedVoice = _selectedVoice;
      if (!localeVoices.any((voice) => voice.shortName == selectedVoice) &&
          localeVoices.isNotEmpty) {
        selectedVoice = localeVoices.first.shortName;
      }

      setState(() {
        _voices = voices;
        _selectedLocale = selectedLocale;
        _selectedVoice = selectedVoice;
        _status = voices.isEmpty
            ? 'No voices returned from the live catalog'
            : 'Loaded ${voices.length} voices across ${locales.length} locales';
      });
      _recreateClient();
    } on Object catch (error) {
      setState(() {
        _status = 'Failed to load voices: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingVoices = false;
        });
      }
    }
  }

  void _recreateClient() {
    _edgeTts.close();
    _edgeTts = FlutterEdgeTts(
      voice: _selectedVoice,
      voiceLocale: _selectedLocale,
      outputFormat: _selectedFormat,
      enableSentenceBoundary: _sentenceBoundary,
      enableWordBoundary: _wordBoundary,
    );
  }

  EdgeTtsProsody _buildProsody() {
    final hz = _pitch * 20;
    final pitch = hz == 0 ? '+0Hz' : '${hz > 0 ? '+' : ''}${hz}Hz';
    return EdgeTtsProsody(
      rate: _speed.toStringAsFixed(1),
      volume: '$_volume',
      pitch: pitch,
    );
  }

  Future<void> _synthesize() async {
    FocusScope.of(context).unfocus();

    if (!_hasVoices) {
      setState(() {
        _status = 'Voices are unavailable. Retry loading the live catalog first.';
      });
      return;
    }

    setState(() {
      _synthesizing = true;
      _status = 'Synthesizing with $_selectedVoice...';
      _audioPath = null;
      _metadataPath = null;
      _audioBytes = 0;
      _metadataItems = 0;
      _playerState = PlayerState.stopped;
    });

    try {
      await _audioPlayer.stop();
      _edgeTts.updateConfig(
        EdgeTtsConfig(
          voice: _selectedVoice,
          voiceLocale: _selectedLocale,
          outputFormat: _selectedFormat,
          enableSentenceBoundary: _sentenceBoundary,
          enableWordBoundary: _wordBoundary,
        ),
      );

      final directory = await getTemporaryDirectory();
      final audioPath =
          '${directory.path}/edge_tts_sample.${_selectedFormat.fileExtension}';
      final metadataPath = '${directory.path}/edge_tts_sample.json';

      final result = await _edgeTts.synthesizeToFile(
        _textController.text,
        audioFilePath: audioPath,
        metadataFilePath: metadataPath,
        prosody: _buildProsody(),
      );

      setState(() {
        _audioPath = result.audioFilePath;
        _metadataPath = result.metadataFilePath;
        _audioBytes = result.result.audioBytes.length;
        _metadataItems = result.result.metadata.length;
        _status = result.audioFilePath.endsWith('.pcm')
            ? 'Synthesis complete. Raw PCM export is ready, but direct playback is unavailable for this format.'
            : 'Synthesis complete. Playing generated audio...';
      });
      if (_selectedFormat.isContainerFormat) {
        await _playAudio(autoPlay: true);
      }
    } on Object catch (error) {
      setState(() {
        _status = 'Synthesis failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _synthesizing = false;
        });
      }
    }
  }

  void _clearText() {
    _textController.clear();
    setState(() {});
  }

  Future<void> _playAudio({bool autoPlay = false}) async {
    final path = _audioPath;
    if (path == null) {
      return;
    }
    if (!_selectedFormat.isContainerFormat) {
      setState(() {
        _status =
            'Playback is only available for MP3, WAV, OGG, or WebM output formats.';
      });
      return;
    }

    setState(() {
      _playbackBusy = true;
      if (!autoPlay) {
        _status = 'Starting playback...';
      }
    });

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      if (mounted) {
        setState(() {
          _status = 'Playing generated audio';
          _playbackBusy = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = 'Playback failed: $error';
          _playbackBusy = false;
        });
      }
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _audioPlayer.pause();
      if (mounted) {
        setState(() {
          _status = 'Playback paused';
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = 'Pause failed: $error';
        });
      }
    }
  }

  Future<void> _resumeAudio() async {
    try {
      await _audioPlayer.resume();
      if (mounted) {
        setState(() {
          _status = 'Playing generated audio';
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = 'Resume failed: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFF8F9FF)),
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  if (isMobile)
                    _MobileHeader(status: _loadingVoices ? 'Syncing' : 'Ready')
                  else
                    const _DesktopHeader(),
                  Expanded(
                    child: isMobile
                        ? _buildMobileBody(context)
                        : _buildDesktopBody(context),
                  ),
                  if (!isMobile) const _DesktopFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _buildTextSection(context, mobile: true),
        const SizedBox(height: 18),
        _buildVoiceSettings(context, mobile: true),
        const SizedBox(height: 18),
        _buildParametersCard(context),
        const SizedBox(height: 18),
        _buildResultSummary(context, mobile: true),
        const SizedBox(height: 18),
        _buildPrimaryButton(context, mobile: true),
      ],
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildTextSection(context, mobile: false),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                children: <Widget>[
                  _buildVoiceSettings(context, mobile: false),
                  const SizedBox(height: 20),
                  _buildParametersCard(context),
                  const SizedBox(height: 20),
                  _buildPrimaryButton(context, mobile: false),
                  const SizedBox(height: 16),
                  _buildStatusPanel(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSection(BuildContext context, {required bool mobile}) {
    final isDesktop = !mobile;
    return _SurfaceCard(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: <Widget>[
                  Text(
                    'Text Input',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF5F5A7C),
                          letterSpacing: 1.1,
                        ),
                  ),
                  const Spacer(),
                  _GhostActionButton(
                    icon: Icons.delete_outline,
                    label: 'Clear',
                    onTap: _clearText,
                  ),
                ],
              ),
            ),
          SizedBox(
            height: isDesktop ? 470 : 180,
            child: TextField(
              controller: _textController,
              onChanged: (_) => setState(() {}),
              expands: true,
              maxLines: null,
              minLines: null,
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: isDesktop
                    ? 'Type or paste your text here to begin synthesis...'
                    : 'Enter your text here...',
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${_textController.text.characters.length} / 5000 characters',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF7B7487),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              if (mobile)
                TextButton(
                  onPressed: _clearText,
                  child: const Text('Clear'),
                )
              else ...<Widget>[
                const _InlineMetaChip(
                  icon: Icons.auto_awesome,
                  label: 'AI Assistant',
                ),
                const SizedBox(width: 14),
                const _InlineMetaChip(
                  icon: Icons.history,
                  label: 'Autosaved',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSettings(BuildContext context, {required bool mobile}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useSingleColumnMobile = mobile && screenWidth < 460;
    final locales = _availableLocales;
    final localeVoices = _localeVoices;
    final selectedVoice =
        localeVoices.any((voice) => voice.shortName == _selectedVoice)
            ? _selectedVoice
            : (localeVoices.isNotEmpty ? localeVoices.first.shortName : null);

    final languageControl = _SelectionCard(
      icon: Icons.translate,
      label: 'Language',
      child: DropdownButtonFormField<String>(
        key: ValueKey('locale:$_selectedLocale:${locales.length}'),
        isExpanded: true,
        initialValue: locales.contains(_selectedLocale)
            ? _selectedLocale
            : (locales.isNotEmpty ? locales.first : null),
        items: locales
            .map(
              (locale) => DropdownMenuItem<String>(
                value: locale,
                child: Text(
                  locale,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: locales.isEmpty
            ? null
            : (value) {
                if (value == null) {
                  return;
                }
                final voices = _voices
                    .where((voice) => voice.locale == value)
                    .toList(growable: false);
                setState(() {
                  _selectedLocale = value;
                  if (voices.isNotEmpty) {
                    _selectedVoice = voices.first.shortName;
                  }
                });
                _recreateClient();
              },
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    final characterControl = _SelectionCard(
      icon: Icons.record_voice_over_outlined,
      label: 'Character',
      child: DropdownButtonFormField<String>(
        key: ValueKey('voice:$selectedVoice:${localeVoices.length}'),
        isExpanded: true,
        initialValue: selectedVoice,
        items: localeVoices
            .map(
              (voice) => DropdownMenuItem<String>(
                value: voice.shortName,
                child: Text(
                  voice.shortName
                      .replaceFirst('${voice.locale}-', '')
                      .replaceAll('Neural', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: localeVoices.isEmpty
            ? null
            : (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedVoice = value;
                });
                _recreateClient();
              },
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _SectionLabel(
                icon: mobile ? Icons.translate : null,
                title: 'Voice Settings',
              ),
            ),
            if (_loadingVoices)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_voiceLoadFailed)
              TextButton.icon(
                onPressed: _loadVoices,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingVoices)
          Text(
            'Fetching the live voice catalog...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7B7487),
                ),
          )
        else if (_voiceLoadFailed)
          Text(
            'Voice list failed to load, so language and character stay disabled until networking is available.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFB3261E),
                ),
          ),
        const SizedBox(height: 14),
        if (mobile)
          useSingleColumnMobile
              ? Column(
                  children: <Widget>[
                    languageControl,
                    const SizedBox(height: 12),
                    characterControl,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: languageControl),
                    const SizedBox(width: 12),
                    Expanded(child: characterControl),
                  ],
                )
        else ...<Widget>[
          languageControl,
          const SizedBox(height: 12),
          characterControl,
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _voiceTraits
              .map((trait) => _TraitChip(label: trait))
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        _SelectionCard(
          icon: Icons.audiotrack_rounded,
          label: 'Format',
          child: DropdownButtonFormField<EdgeTtsOutputFormat>(
            key: ValueKey('format:${_selectedFormat.name}'),
            isExpanded: true,
            initialValue: _selectedFormat,
            items: EdgeTtsOutputFormat.values
                .map(
                  (format) => DropdownMenuItem<EdgeTtsOutputFormat>(
                    value: format,
                    child: Text(
                      _formatLabel(format),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedFormat = value;
              });
              _recreateClient();
            },
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );

    return mobile
        ? content
        : _SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: content,
          );
  }

  Widget _buildParametersCard(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionLabel(icon: Icons.tune, title: 'Parameters'),
          const SizedBox(height: 18),
          _SliderTile(
            label: 'Speed',
            valueText: '${_speed.toStringAsFixed(1)}x',
            min: 0.5,
            max: 2.0,
            value: _speed,
            onChanged: (value) => setState(() => _speed = value),
          ),
          const SizedBox(height: 18),
          _SliderTile(
            label: 'Volume',
            valueText: '$_volume%',
            min: 0,
            max: 100,
            value: _volume.toDouble(),
            onChanged: (value) => setState(() => _volume = value.round()),
          ),
          const SizedBox(height: 18),
          _SliderTile(
            label: 'Pitch',
            valueText: _pitch == 0 ? '0' : '${_pitch > 0 ? '+' : ''}$_pitch',
            min: -5,
            max: 5,
            value: _pitch.toDouble(),
            onChanged: (value) => setState(() => _pitch = value.round()),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _sentenceBoundary,
            onChanged: (value) {
              setState(() => _sentenceBoundary = value);
              _recreateClient();
            },
            title: const Text('Sentence boundaries'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _wordBoundary,
            onChanged: (value) {
              setState(() => _wordBoundary = value);
              _recreateClient();
            },
            title: const Text('Word boundaries'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, {required bool mobile}) {
    final button = FilledButton.icon(
      onPressed: _synthesizing || _loadingVoices || !_hasVoices
          ? null
          : _synthesize,
      style: FilledButton.styleFrom(
        minimumSize: Size(double.infinity, mobile ? 56 : 64),
        backgroundColor: const Color(0xFF7C3AED),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mobile ? 999 : 18),
        ),
      ),
      icon: Icon(
        mobile ? Icons.play_circle_fill : Icons.play_arrow_rounded,
        size: mobile ? 22 : 28,
      ),
      label: Text(
        mobile ? 'Synthesize & Play' : 'Synthesize & Play',
        style: TextStyle(
          fontSize: mobile ? 18 : 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (mobile) {
      return button;
    }

    return Column(
      children: <Widget>[
        button,
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFFEADDFF),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8C8FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  size: 32,
                  color: Color(0xFF630ED4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'High-fidelity neural synthesis ready to generate',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5F5A7C),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultSummary(BuildContext context, {required bool mobile}) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionLabel(
            icon: mobile ? Icons.graphic_eq_rounded : null,
            title: 'Result',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _isPaused
                    ? _resumeAudio
                    : (_canPlayAudio ? () => _playAudio() : null),
                icon: Icon(
                  _isPaused ? Icons.play_arrow_rounded : Icons.volume_up_rounded,
                ),
                label: Text(_isPaused ? 'Resume' : 'Play'),
              ),
              OutlinedButton.icon(
                onPressed: _isPlaying ? _pauseAudio : null,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pause'),
              ),
              if (!_selectedFormat.isContainerFormat && _audioPath != null)
                const _InfoBadge(label: 'Raw format: export only'),
            ],
          ),
          const SizedBox(height: 14),
          _ResultRow(label: 'Status', value: _status),
          _ResultRow(label: 'Audio bytes', value: '$_audioBytes'),
          _ResultRow(label: 'Metadata items', value: '$_metadataItems'),
          _ResultRow(label: 'Audio path', value: _audioPath ?? '-'),
          _ResultRow(label: 'Metadata path', value: _metadataPath ?? '-'),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildResultSummary(context, mobile: false),
        const SizedBox(height: 16),
        _SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Text(
            _selectedFormat.isContainerFormat
                ? 'This demo writes generated audio and metadata to the local temporary directory and plays supported formats directly inside the app.'
                : 'This demo writes generated audio and metadata to the local temporary directory. Raw PCM export is preserved for integration scenarios, but direct playback is disabled for that format.',
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9E3F6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF5F5A7C),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        height: 72,
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_voice_rounded),
              color: const Color(0xFF630ED4),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Voice Studio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF630ED4),
                        ),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF7B7487),
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.account_circle_outlined),
              color: const Color(0xFF630ED4),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFD9E3F6)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Voice Studio',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF630ED4),
                ),
          ),
          const SizedBox(width: 36),
          const _HeaderNavItem(label: 'Editor', active: true),
          const SizedBox(width: 24),
          const _HeaderNavItem(label: 'Library'),
          const SizedBox(width: 24),
          const _HeaderNavItem(label: 'Voices'),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
            color: const Color(0xFF5F5A7C),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.account_circle_outlined),
            color: const Color(0xFF5F5A7C),
          ),
        ],
      ),
    );
  }
}

class _DesktopFooter extends StatelessWidget {
  const _DesktopFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFD9E3F6)),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Text('© 2026 Voice Studio'),
          const Spacer(),
          TextButton(onPressed: () {}, child: const Text('Privacy')),
          TextButton(onPressed: () {}, child: const Text('Terms')),
          TextButton(onPressed: () {}, child: const Text('API status')),
        ],
      ),
    );
  }
}

class _HeaderNavItem extends StatelessWidget {
  const _HeaderNavItem({
    required this.label,
    this.active = false,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF630ED4) : const Color(0xFF5F5A7C);
    return Container(
      padding: EdgeInsets.only(bottom: active ? 6 : 0),
      decoration: active
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF630ED4), width: 2),
              ),
            )
          : null,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E3F6)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(31, 41, 55, 0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.icon,
  });

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF5F5A7C),
            fontWeight: FontWeight.w700,
          ),
    );

    if (icon == null) {
      return text;
    }

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: const Color(0xFF5F5A7C)),
        const SizedBox(width: 8),
        Expanded(child: text),
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.label,
    required this.child,
    required this.icon,
  });

  final String label;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E3F6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: const Color(0xFF630ED4)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF7B7487),
                        ),
                  ),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFDCD5FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF4B3F7B),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.valueText,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF5F5A7C),
                  ),
            ),
            const Spacer(),
            Text(
              valueText,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF630ED4),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: const Color(0xFF7C3AED),
            inactiveTrackColor: const Color(0xFFDCD5FD),
            thumbColor: const Color(0xFF630ED4),
            overlayColor: const Color(0x22630ED4),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF7B7487),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF121C2A),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetaChip extends StatelessWidget {
  const _InlineMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: const Color(0xFF7B7487)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF7B7487),
              ),
        ),
      ],
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  const _GhostActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: const Color(0xFF630ED4)),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF630ED4),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
