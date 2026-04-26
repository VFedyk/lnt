import '../entities/radical_progress.dart';

abstract class RadicalProgressRepository {
  Future<Map<String, RadicalProgress>> getAll();
  Future<void> recordCompletion(String radicalChar);
}
