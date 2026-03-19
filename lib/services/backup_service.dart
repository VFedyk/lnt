import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../service_locator.dart';

const _backupFileName = 'lnt_backup.zip';
const _icloudContainerId = 'iCloud.lnt-db-backup';
const _dbEntryName = 'lnt.db';
const _coversDirName = 'covers';

class BackupService {
  BackupService();

  static const _driveScopes = [drive.DriveApi.driveFileScope];
  bool _googleSignInInitialized = false;

  // ── helpers ──

  Future<String> _getDbPath() async {
    await db.database;
    return db.currentDbPath!;
  }

  Future<String> _getCoversDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$_coversDirName';
  }

  Future<File> _createBackupArchive() async {
    final dbPath = await _getDbPath();
    final coversDir = await _getCoversDir();
    final tempDir = await getTemporaryDirectory();
    if (!tempDir.existsSync()) {
      await tempDir.create(recursive: true);
    }
    final archiveFile = File('${tempDir.path}/$_backupFileName');

    final archive = Archive();

    // Add database file
    final dbBytes = await File(dbPath).readAsBytes();
    archive.addFile(ArchiveFile(_dbEntryName, dbBytes.length, dbBytes));

    // Add cover images
    final coversDirObj = Directory(coversDir);
    if (await coversDirObj.exists()) {
      await for (final entity in coversDirObj.list()) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          final bytes = await entity.readAsBytes();
          archive.addFile(
            ArchiveFile('$_coversDirName/$name', bytes.length, bytes),
          );
        }
      }
    }

    await archiveFile.writeAsBytes(ZipEncoder().encode(archive));
    return archiveFile;
  }

  Future<void> _restoreFromArchive(File archiveFile) async {
    final bytes = await archiveFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dbPath = await _getDbPath();
    final coversDir = await _getCoversDir();

    // Validate before touching any production files.
    final dbEntry = archive.findFile(_dbEntryName);
    if (dbEntry == null) throw Exception('Backup archive has no database');

    // ── Stage phase ──────────────────────────────────────────────────────────
    // Extract everything into a temp directory. If anything fails here,
    // production files are completely untouched.
    final tempDir = await getTemporaryDirectory();
    final stagingDir = Directory('${tempDir.path}/lnt_restore');
    if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
    await stagingDir.create(recursive: true);

    final stagedDb = File('${stagingDir.path}/$_dbEntryName');
    await stagedDb.writeAsBytes(dbEntry.content as List<int>);

    final stagedCovers = Directory('${stagingDir.path}/$_coversDirName');
    await stagedCovers.create(recursive: true);
    for (final entry in archive) {
      if (entry.isFile && entry.name.startsWith('$_coversDirName/')) {
        final name = entry.name.substring('$_coversDirName/'.length);
        if (name.isNotEmpty) {
          await File('${stagedCovers.path}/$name')
              .writeAsBytes(entry.content as List<int>);
        }
      }
    }

    // ── Commit phase ─────────────────────────────────────────────────────────
    // Back up current state, then move staged files into place.
    // On any error, roll back from the .bak copies.
    final dbBak = File('$dbPath.bak');
    final coversBak = Directory('$coversDir.bak');
    bool dbMoved = false;
    bool coversMoved = false;

    try {
      await db.closeDatabase();

      // Rename current files to .bak (atomic on same filesystem).
      if (await File(dbPath).exists()) await File(dbPath).rename(dbBak.path);
      if (await Directory(coversDir).exists()) {
        await Directory(coversDir).rename(coversBak.path);
      }

      // Move staged files to production paths.
      final dbDir = Directory(dbPath).parent;
      if (!await dbDir.exists()) await dbDir.create(recursive: true);
      await _moveFile(stagedDb, dbPath);
      dbMoved = true;
      await _moveDirectory(stagedCovers, coversDir);
      coversMoved = true;

      // Both moves succeeded — discard backups.
      if (await dbBak.exists()) await dbBak.delete();
      if (await coversBak.exists()) await coversBak.delete(recursive: true);
    } catch (e) {
      // Roll back: restore .bak files if we already moved them away.
      try {
        if (dbMoved) {
          final f = File(dbPath);
          if (await f.exists()) await f.delete();
        }
        if (await dbBak.exists()) await dbBak.rename(dbPath);

        if (coversMoved) {
          final d = Directory(coversDir);
          if (await d.exists()) await d.delete(recursive: true);
        }
        if (await coversBak.exists()) await coversBak.rename(coversDir);
      } catch (_) {
        // Best-effort — don't mask the original error.
      }
      rethrow;
    } finally {
      // Always reopen the DB and clean up staging, regardless of outcome.
      await db.database;
      if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
    }
  }

  /// Moves [src] to [destPath], falling back to copy+delete if rename fails
  /// (e.g. cross-device move on some platforms).
  Future<void> _moveFile(File src, String destPath) async {
    try {
      await src.rename(destPath);
    } on FileSystemException {
      await src.copy(destPath);
      await src.delete();
    }
  }

  /// Moves [src] directory to [destPath], falling back to recursive copy+delete
  /// if rename fails (e.g. cross-device move on some platforms).
  Future<void> _moveDirectory(Directory src, String destPath) async {
    try {
      await src.rename(destPath);
    } on FileSystemException {
      final dest = Directory(destPath);
      if (!await dest.exists()) await dest.create(recursive: true);
      await for (final entity in src.list(recursive: true)) {
        if (entity is File) {
          final relative = entity.path.substring(src.path.length + 1);
          final destFile = File('$destPath/$relative');
          await destFile.parent.create(recursive: true);
          await entity.copy(destFile.path);
        }
      }
      await src.delete(recursive: true);
    }
  }

  // ── Google Drive ──

  Future<drive.DriveApi> _googleDriveApi() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: _driveScopes,
    );
    final authz = await account.authorizationClient.authorizeScopes(
      _driveScopes,
    );
    return drive.DriveApi(authz.authClient(scopes: _driveScopes));
  }

  Future<DateTime> backupToGoogleDrive() async {
    final archive = await _createBackupArchive();
    final api = await _googleDriveApi();

    // Check for existing backup to update
    final existing = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id)',
    );

    final media = drive.Media(archive.openRead(), archive.lengthSync());

    if (existing.files != null && existing.files!.isNotEmpty) {
      await api.files.update(
        drive.File(),
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      final driveFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];
      await api.files.create(driveFile, uploadMedia: media);
    }

    final now = DateTime.now();
    await settings.setGoogleDriveLastBackup(now);
    return now;
  }

  Future<void> restoreFromGoogleDrive() async {
    final api = await _googleDriveApi();

    final results = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id)',
    );

    if (results.files == null || results.files!.isEmpty) {
      throw Exception('No backup found on Google Drive');
    }

    final fileId = results.files!.first.id!;
    final response =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$_backupFileName');
    final sink = tempFile.openWrite();
    await response.stream.pipe(sink);
    await sink.close();

    await _restoreFromArchive(tempFile);
  }

  Future<DateTime?> getGoogleDriveBackupDate() async {
    try {
      final api = await _googleDriveApi();
      final results = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(modifiedTime)',
      );
      if (results.files != null && results.files!.isNotEmpty) {
        return results.files!.first.modifiedTime;
      }
    } catch (_) {
      // Fall back to local timestamp
    }
    return settings.getGoogleDriveLastBackup();
  }

  // ── iCloud ──

  Future<void> backupToICloud() async {
    final archive = await _createBackupArchive();
    await ICloudStorage.upload(
      containerId: _icloudContainerId,
      filePath: archive.path,
      destinationRelativePath: _backupFileName,
    );
    await settings.setICloudLastBackup(DateTime.now());
  }

  Future<void> restoreFromICloud({
    void Function(double)? onProgress,
  }) async {
    final files = await ICloudStorage.gather(containerId: _icloudContainerId);
    final hasBackup = files.any((f) => f.relativePath == _backupFileName);
    if (!hasBackup) {
      throw Exception('No backup found on iCloud');
    }

    final tempDir = await getTemporaryDirectory();
    if (!tempDir.existsSync()) {
      await tempDir.create(recursive: true);
    }
    final tempFile = File('${tempDir.path}/$_backupFileName');
    if (tempFile.existsSync()) tempFile.deleteSync();

    final completer = Completer<void>();
    await ICloudStorage.download(
      containerId: _icloudContainerId,
      relativePath: _backupFileName,
      destinationFilePath: tempFile.path,
      onProgress: (stream) {
        stream.listen(
          (progress) {
            // Cap at 0.9: the remaining 10% is reserved for the file-flush
            // phase after the iCloud layer reports completion.
            onProgress?.call((progress * 0.9).clamp(0.0, 0.9));
            if (progress >= 1.0 && !completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );
      },
    );
    await completer.future;

    // iCloud reports progress 1.0 before the native layer finishes copying the
    // file to destinationFilePath. Poll until the file appears and its size
    // has been stable for at least two consecutive checks (~1 s), so we know
    // the write is complete and not still in progress.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    int lastSize = -1;
    int stableCount = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!tempFile.existsSync()) {
        lastSize = -1;
        stableCount = 0;
        continue;
      }
      final size = tempFile.lengthSync();
      if (size > 0 && size == lastSize) {
        stableCount++;
        if (stableCount >= 2) break; // size stable for ≥1 s → write complete
      } else {
        stableCount = 0;
        lastSize = size;
      }
    }

    if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
      throw Exception('Download from iCloud failed');
    }

    await _restoreFromArchive(tempFile);
  }

  Future<DateTime?> getICloudBackupDate() async {
    try {
      final files = await ICloudStorage.gather(containerId: _icloudContainerId);
      final backup = files.where((f) => f.relativePath == _backupFileName);
      if (backup.isNotEmpty) {
        return backup.first.contentChangeDate;
      }
    } catch (_) {
      // Fall back to local timestamp
    }
    return settings.getICloudLastBackup();
  }
}
