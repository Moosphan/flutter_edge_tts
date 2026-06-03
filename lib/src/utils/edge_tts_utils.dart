import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class EdgeTtsUtils {
  const EdgeTtsUtils._();

  static final RegExp _voiceLocaleRegExp = RegExp(r'\w{2}-\w{2}');

  static String? inferVoiceLocale(String voiceName) {
    return _voiceLocaleRegExp.firstMatch(voiceName)?.group(0);
  }

  static String xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String generateConnectionId() => _randomHex(16);

  static String generateRequestId() => _randomHex(16);

  static String generateMuid() => _randomHex(16).toUpperCase();

  static String generateWebSocketKey() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(values);
  }

  static String generateSecMsGec(String trustedClientToken) {
    final ticks = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 11644473600;
    final rounded = ticks - (ticks % 300);
    final windowsTicks = rounded * 10000000;
    final digest = sha256.convert(
      utf8.encode('$windowsTicks$trustedClientToken'),
    );
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  static String formatJsTimestamp([DateTime? timestamp]) {
    final utc = (timestamp ?? DateTime.now()).toUtc();
    const weekdays = <String>[
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ];
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[utc.weekday % 7];
    final month = months[utc.month - 1];
    final day = utc.day.toString().padLeft(2, '0');
    final year = utc.year.toString().padLeft(4, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$weekday $month $day $year '
        '$hour:$minute:$second GMT+0000 (Coordinated Universal Time)';
  }

  static int indexOfSublist(List<int> source, List<int> target) {
    if (target.isEmpty) {
      return 0;
    }
    if (source.length < target.length) {
      return -1;
    }
    for (var i = 0; i <= source.length - target.length; i++) {
      var matched = true;
      for (var j = 0; j < target.length; j++) {
        if (source[i + j] != target[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }

  static String _randomHex(int bytes) {
    final random = Random.secure();
    final values = List<int>.generate(bytes, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
