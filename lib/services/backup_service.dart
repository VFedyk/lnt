import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';
import 'settings_service.dart';

const _backupFileName = 'lnt_backup.db';
const _icloudContainerId = 'iCloud.lnt-db-backup';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  // ── helpers ──

  Future<String> _getDbPath() async {
    await DatabaseService.instance.database;
    return DatabaseService.instance.currentDbPath!;
  }

  Future<void> _restoreFromFile(File downloaded) async {
    final dbPath = await _getDbPath();
    await DatabaseService.instance.closeDatabase();
    final dbDir = Directory(dbPath).parent;
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    await downloaded.copy(dbPath);
  }

  // ── Google Drive ──

  Future<drive.DriveApi> _googleDriveApi() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) throw Exception('Failed to get auth client');
    return drive.DriveApi(client);
  }

  Future<DateTime> backupToGoogleDrive() async {
    final dbPath = await _getDbPath();
    final api = await _googleDriveApi();

    // Check for existing backup to update
    final existing = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id)',
    );

    final media = drive.Media(
      File(dbPath).openRead(),
      File(dbPath).lengthSync(),
    );

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

    await _restoreFromFile(tempFile);
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
    final dbPath = await _getDbPath();
    await ICloudStorage.upload(
      containerId: _icloudContainerId,
      filePath: dbPath,
      destinationRelativePath: _backupFileName,
    );
    await SettingsService.instance.setICloudLastBackup(DateTime.now());
  }

  Future<void> restoreFromICloud() async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$_backupFileName');
    if (tempFile.existsSync()) tempFile.deleteSync();

    await ICloudStorage.download(
      containerId: _icloudContainerId,
      relativePath: _backupFileName,
      destinationFilePath: tempFile.path,
    );

    await _restoreFromFile(tempFile);
  }

  Future<DateTime?> getICloudBackupDate() async {
    return SettingsService.instance.getICloudLastBackup();
  }
}
