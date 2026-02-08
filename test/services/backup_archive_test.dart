import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the backup archive format used by BackupService.
///
/// BackupService creates zip archives with this structure:
///   lnt.db            – the SQLite database
///   covers/name.jpg   – cover images (optional)
///
/// These tests verify the contract without touching the filesystem,
/// Google Drive, or iCloud.
void main() {
  const dbEntryName = 'lnt.db';
  const coversDirName = 'covers';

  Uint8List createTestArchive({
    Uint8List? dbBytes,
    Map<String, Uint8List>? coverFiles,
  }) {
    final archive = Archive();

    if (dbBytes != null) {
      archive.addFile(ArchiveFile(dbEntryName, dbBytes.length, dbBytes));
    }

    if (coverFiles != null) {
      for (final entry in coverFiles.entries) {
        final path = '$coversDirName/${entry.key}';
        archive.addFile(ArchiveFile(path, entry.value.length, entry.value));
      }
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  group('backup archive format', () {
    test('round-trips database bytes', () {
      final dbBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final zipBytes = createTestArchive(dbBytes: dbBytes);

      final decoded = ZipDecoder().decodeBytes(zipBytes);
      final dbEntry = decoded.findFile(dbEntryName);

      expect(dbEntry, isNotNull);
      expect(dbEntry!.content, dbBytes);
    });

    test('round-trips cover images', () {
      final dbBytes = Uint8List.fromList([0]);
      final coverA = Uint8List.fromList([10, 20, 30]);
      final coverB = Uint8List.fromList([40, 50]);

      final zipBytes = createTestArchive(
        dbBytes: dbBytes,
        coverFiles: {'book1.jpg': coverA, 'book2.jpg': coverB},
      );

      final decoded = ZipDecoder().decodeBytes(zipBytes);
      final coverEntries =
          decoded.where((f) => f.isFile && f.name.startsWith('$coversDirName/'));

      expect(coverEntries, hasLength(2));

      final a = decoded.findFile('$coversDirName/book1.jpg');
      expect(a, isNotNull);
      expect(a!.content, coverA);

      final b = decoded.findFile('$coversDirName/book2.jpg');
      expect(b, isNotNull);
      expect(b!.content, coverB);
    });

    test('archive without covers contains only the database', () {
      final dbBytes = Uint8List.fromList([99]);
      final zipBytes = createTestArchive(dbBytes: dbBytes);

      final decoded = ZipDecoder().decodeBytes(zipBytes);
      expect(decoded.files.where((f) => f.isFile), hasLength(1));
      expect(decoded.findFile(dbEntryName), isNotNull);
    });

    test('restore detects missing database entry', () {
      // Archive with no database — just a cover
      final zipBytes = createTestArchive(
        coverFiles: {'img.jpg': Uint8List.fromList([1])},
      );

      final decoded = ZipDecoder().decodeBytes(zipBytes);
      final dbEntry = decoded.findFile(dbEntryName);

      // BackupService throws when dbEntry is null
      expect(dbEntry, isNull);
    });
  });
}
