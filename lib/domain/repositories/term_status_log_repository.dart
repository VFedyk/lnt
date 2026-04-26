import '../entities/daily_status_snapshot.dart';

abstract class TermStatusLogRepository {
  Future<void> logChange(String termId, int status, DateTime changedAt);
  Future<List<DailyStatusSnapshot>> getDailySnapshots({
    required String languageId,
    required DateTime from,
    required DateTime to,
  });
}
