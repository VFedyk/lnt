class TermStatus {
  static const int ignored = 0;
  static const int unknown = 1;
  static const int learning2 = 2;
  static const int learning3 = 3;
  static const int learning4 = 4;
  static const int known = 5;
  static const int wellKnown = 99;

  static const List<int> allStatuses = [
    ignored,
    unknown,
    learning2,
    learning3,
    learning4,
    known,
    wellKnown,
  ];

  static bool isReviewable(int s) => s != ignored && s != wellKnown;
  static bool isLearning(int s) => s >= learning2 && s <= learning4;
  static bool isMastered(int s) => s == known || s == wellKnown;

  static String nameFor(int status) {
    switch (status) {
      case ignored:
        return 'Ignored';
      case unknown:
        return 'Unknown';
      case learning2:
        return 'Learning 2';
      case learning3:
        return 'Learning 3';
      case learning4:
        return 'Learning 4';
      case known:
        return 'Known';
      case wellKnown:
        return 'Well Known';
      default:
        return 'Unknown';
    }
  }
}
