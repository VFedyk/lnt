import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/term.dart';

class TermStatusUI {
  static Color colorFor(int status) {
    switch (status) {
      case TermStatus.ignored:
        return Colors.grey.shade400;
      case TermStatus.unknown:
        return Colors.red.shade400;
      case TermStatus.learning2:
        return Colors.orange.shade400;
      case TermStatus.learning3:
        return Colors.yellow.shade700;
      case TermStatus.learning4:
        return Colors.lightGreen.shade500;
      case TermStatus.known:
        return Colors.green.shade600;
      case TermStatus.wellKnown:
        return Colors.blue.shade400;
      default:
        return Colors.red.shade400;
    }
  }

  static String localizedNameFor(int status, AppLocalizations l10n) {
    switch (status) {
      case TermStatus.ignored:
        return l10n.statusIgnored;
      case TermStatus.unknown:
        return l10n.statusUnknown;
      case TermStatus.learning2:
        return l10n.statusLearning2;
      case TermStatus.learning3:
        return l10n.statusLearning3;
      case TermStatus.learning4:
        return l10n.statusLearning4;
      case TermStatus.known:
        return l10n.statusKnown;
      case TermStatus.wellKnown:
        return l10n.statusWellKnown;
      default:
        return l10n.statusUnknown;
    }
  }
}

class PartOfSpeechUI {
  static String localizedNameFor(String pos, AppLocalizations l10n) {
    switch (pos) {
      case PartOfSpeech.noun:
        return l10n.posNoun;
      case PartOfSpeech.verb:
        return l10n.posVerb;
      case PartOfSpeech.adjective:
        return l10n.posAdjective;
      case PartOfSpeech.adverb:
        return l10n.posAdverb;
      case PartOfSpeech.pronoun:
        return l10n.posPronoun;
      case PartOfSpeech.preposition:
        return l10n.posPreposition;
      case PartOfSpeech.conjunction:
        return l10n.posConjunction;
      case PartOfSpeech.interjection:
        return l10n.posInterjection;
      case PartOfSpeech.article:
        return l10n.posArticle;
      case PartOfSpeech.numeral:
        return l10n.posNumeral;
      case PartOfSpeech.particle:
        return l10n.posParticle;
      case PartOfSpeech.other:
        return l10n.posOther;
      default:
        return pos;
    }
  }
}
