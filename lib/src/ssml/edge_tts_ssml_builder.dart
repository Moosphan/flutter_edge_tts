import '../models/edge_tts_config.dart';
import '../models/edge_tts_exception.dart';
import '../models/edge_tts_prosody.dart';
import '../utils/edge_tts_utils.dart';

class EdgeTtsSsmlBuilder {
  const EdgeTtsSsmlBuilder._();

  static String escapeText(String input) => EdgeTtsUtils.xmlEscape(input);

  static String build({
    required String text,
    required EdgeTtsConfig config,
    EdgeTtsProsody prosody = const EdgeTtsProsody(),
    bool escapeText = true,
  }) {
    final locale =
        config.voiceLocale ?? EdgeTtsUtils.inferVoiceLocale(config.voice);
    if (locale == null) {
      throw const EdgeTtsException(
        'invalid_voice_locale',
        'Could not infer voice locale from voice name.',
      );
    }

    final content = escapeText ? EdgeTtsUtils.xmlEscape(text) : text;
    return '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="$locale">
  <voice name="${config.voice}">
    <prosody pitch="${prosody.pitch}" rate="${prosody.rate}" volume="${prosody.volume}">
      $content
    </prosody>
  </voice>
</speak>
'''
        .trim();
  }
}
