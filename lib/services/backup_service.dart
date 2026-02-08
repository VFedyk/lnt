import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';
import 'settings_service.dart';

const _backupFileName = 'lnt_backup.zip';
const _icloudContainerId = 'iCloud.lnt-db-backup';
const _dbEntryName = 'lnt.db';
const _coversDirName = 'covers';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  static const _driveScopes = [drive.DriveApi.driveFileScope];
  bool _googleSignInInitialized = false;

  // ── helpers ──

  Future<String> _getDbPath() async {
    await DatabaseService.instance.database;
    return DatabaseService.instance.currentDbPath!;
  }

  Future<String> _getCoversDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$_coversDirName';
  }

  Future<File> _createBackupArchive() async {
    final dbPath = await _getDbPath();
    final coversDir = await _getCoversDir();
    final tempDir = await getTemporaryDirectory();
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

    // Extract database
    final dbEntry = archive.findFile(_dbEntryName);
    if (dbEntry == null) throw Exception('Backup archive has no database');

    await DatabaseService.instance.closeDatabase();
    final dbDir = Directory(dbPath).parent;
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    await File(dbPath).writeAsBytes(dbEntry.content as List<int>);

    // Extract cover images
    final coversDirObj = Directory(coversDir);
    if (!await coversDirObj.exists()) {
      await coversDirObj.create(recursive: true);
    }
    for (final file in archive) {
      if (file.isFile && file.name.startsWith('$_coversDirName/')) {
        final name = file.name.substring('$_coversDirName/'.length);
        if (name.isNotEmpty) {
          await File(
            '$coversDir/$name',
          ).writeAsBytes(file.content as List<int>);
        }
      }
    }

    // Reopen the database so the app can continue without restart
    await DatabaseService.instance.database;
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
    await SettingsService.instance.setGoogleDriveLastBackup(now);
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
    return SettingsService.instance.getGoogleDriveLastBackup();
  }

  // ── iCloud ──

  Future<void> backupToICloud() async {
    final archive = await _createBackupArchive();
    await ICloudStorage.upload(
      containerId: _icloudContainerId,
      filePath: archive.path,
      destinationRelativePath: _backupFileName,
    );
    await SettingsService.instance.setICloudLastBackup(DateTime.now());
  }

  Future<void> restoreFromICloud() async {
    final files = await ICloudStorage.gather(containerId: _icloudContainerId);
    final hasBackup = files.any((f) => f.relativePath == _backupFileName);
    if (!hasBackup) {
      throw Exception('No backup found on iCloud');
    }

    final tempDir = await getTemporaryDirectory();
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

    // The native layer may not have flushed the file yet — poll briefly.
    for (var i = 0; i < 10; i++) {
      if (tempFile.existsSync() && tempFile.lengthSync() > 0) break;
      await Future.delayed(const Duration(milliseconds: 500));
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
    return SettingsService.instance.getICloudLastBackup();
  }
}
