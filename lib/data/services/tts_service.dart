import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  FlutterTts? _tts;
  String _currentLanguage = '';

  Future<FlutterTts> _getInstance() async {
    if (_tts == null) {
      _tts = FlutterTts();
      await _tts!.awaitSpeakCompletion(false);
    }
    return _tts!;
  }

  Future<void> speak(String text, String languageCode) async {
    if (text.isEmpty || languageCode.isEmpty) return;
    final tts = await _getInstance();
    if (languageCode != _currentLanguage) {
      await tts.setLanguage(languageCode);
      _currentLanguage = languageCode;
    }
    await tts.speak(text);
  }

  Future<void> stop() async {
    await _tts?.stop();
  }
}
