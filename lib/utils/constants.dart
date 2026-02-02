// FILE: lib/utils/constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  // Status levels
  static const int statusIgnored = 0;
  static const int statusUnknown = 1;
  static const int statusLearning2 = 2;
  static const int statusLearning3 = 3;
  static const int statusLearning4 = 4;
  static const int statusKnown = 5;
  static const int statusWellKnown = 99;

  // Default dictionary URLs (examples)
  static const Map<String, String> defaultDictUrls = {
    'Spanish': 'https://www.wordreference.com/es/en/translation.asp?spen=###',
    'French': 'https://www.wordreference.com/fren/###',
    'German': 'https://dict.leo.org/german-english/###',
    'Japanese': 'https://jisho.org/search/###',
    'Chinese':
        'https://www.mdbg.net/chinese/dictionary?page=worddict&wdrst=0&wdqb=###',
    'Korean': 'https://ko.dict.naver.com/#/search?query=###',
    'Italian': 'https://www.wordreference.com/iten/###',
    'Portuguese': 'https://www.wordreference.com/pten/###',
    'Russian': 'https://en.wiktionary.org/wiki/###',
  };

  // File formats
  static const String csvExtension = '.csv';
  static const String txtExtension = '.txt';

  // App info
  static const String appName = 'LNT';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Language Nerd Tools';

  // UI: Dialog
  static const double dialogWidth = 736.0;

  // UI: Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 24.0;

  // UI: Font sizes
  static const double fontSizeXS = 10.0;
  static const double fontSizeCaption = 12.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeSubtitle = 18.0;
  static const double fontSizeTitle = 24.0;

  // UI: Border radii
  static const double borderRadiusS = 4.0;
  static const double borderRadiusM = 8.0;
  static const double borderRadiusL = 12.0;

  // UI: Colors
  static final Color subtitleColor = Colors.grey.shade600;
  static const Color deleteColor = Colors.red;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
}
