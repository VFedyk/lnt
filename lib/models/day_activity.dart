class DayActivity {
  final int textsCompleted;
  final int wordsAdded;
  final int wordsReviewed;

  const DayActivity({
    this.textsCompleted = 0,
    this.wordsAdded = 0,
    this.wordsReviewed = 0,
  });

  int get total => textsCompleted + wordsAdded + wordsReviewed;
}
