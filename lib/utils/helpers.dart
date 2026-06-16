// FILE: lib/utils/helpers.dart
import 'dart:io';
import 'package:intl/intl.dart';

class PlatformHelper {
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static bool get isApple => Platform.isMacOS || Platform.isIOS;
}

class DateHelper {
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy HH:mm').format(date);
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays > 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Relative time for a *future* date (e.g. a next-review due date). Past or
  /// now reads as "Due now".
  static String formatRelativeFuture(DateTime date) {
    final difference = date.difference(DateTime.now());

    if (difference.inSeconds <= 0) {
      return 'Due now';
    } else if (difference.inDays > 365) {
      return 'in ${(difference.inDays / 365).floor()} year${difference.inDays > 730 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      return 'in ${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''}';
    } else if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Soon';
    }
  }
}

class TextHelper {
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static int countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).length;
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
