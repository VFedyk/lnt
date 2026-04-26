import 'package:url_launcher/url_launcher.dart';
import '../domain/entities/dictionary.dart';
import '../service_locator.dart';

class DictionaryService {
  static String buildLookupUrl(String word, String dictUrl) {
    final encodedWord = Uri.encodeComponent(word.trim());
    return dictUrl.replaceAll('###', encodedWord);
  }

  Future<void> lookupWordExternal(String word, String dictUrl) async {
    if (dictUrl.isEmpty) {
      throw Exception('Dictionary URL not configured');
    }

    final url = buildLookupUrl(word, dictUrl);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch dictionary URL');
    }
  }

  Future<List<Dictionary>> getActiveDictionaries(String languageId) async {
    return await db.dictionaries.getAll(
      languageId: languageId,
      activeOnly: true,
    );
  }

  Future<List<Dictionary>> getAllDictionaries(String languageId) async {
    return await db.dictionaries.getAll(languageId: languageId);
  }

  Future<bool> hasDictionaries(String languageId) async {
    final dicts = await getActiveDictionaries(languageId);
    return dicts.isNotEmpty;
  }
}
