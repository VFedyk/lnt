import 'package:sqflite/sqflite.dart';
import '../services/data_change_notifier.dart';

/// Base class for all repositories providing database access
abstract class BaseRepository {
  final Future<Database> Function() getDatabase;
  final DomainNotifier? onChange;

  BaseRepository(this.getDatabase, {this.onChange});

  /// Notify listeners that data in this domain changed.
  void notifyChange() => onChange?.notify();
}
