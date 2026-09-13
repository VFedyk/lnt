import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  FlutterTts? _tts;
  String _currentLanguage = '';

  Future<FlutterTts> _getInstance() async {
    if (_tts == null) {
      final tts = FlutterTts();
      await tts.awaitSpeakCompletion(false);
      if (!kIsWeb && Platform.isIOS) {
        // The default session category (soloAmbient) is muted by the silent
        // switch / Control Center silent mode. Speech is always user-initiated,
        // so play it regardless, ducking any background audio meanwhile.
        await tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers],
        );
      }
      _tts = tts;
    }
    return _tts!;
  }

  Future<void> speak(String text, String languageCode) async {
    if (text.isEmpty || languageCode.isEmpty) return;
    final tts = await _getInstance();
    if (languageCode != _currentLanguage) {
      // iOS returns 0 when no installed voice matches; don't cache the code
      // then, so a voice installed later is picked up on the next attempt.
      final result = await tts.setLanguage(languageCode);
      if (result != 0) _currentLanguage = languageCode;
    }
    await tts.speak(text);
  }

  Future<void> stop() async {
    await _tts?.stop();
  }
}
