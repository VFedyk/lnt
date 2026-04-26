class RadicalProgress {
  final String radicalChar;
  final int practicedCount;
  final DateTime? lastPracticed;

  const RadicalProgress({
    required this.radicalChar,
    required this.practicedCount,
    this.lastPracticed,
  });
}
