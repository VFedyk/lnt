sealed class TermEvent {}

class TermWritten extends TermEvent {
  final String id;
  final int status;
  TermWritten(this.id, this.status);
}

class TermsBulkWritten extends TermEvent {
  final List<({String id, int status})> terms;
  TermsBulkWritten(this.terms);
}
