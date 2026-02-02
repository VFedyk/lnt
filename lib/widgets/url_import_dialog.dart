import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/text_document.dart';
import '../services/url_import_service.dart';
import '../utils/constants.dart';

abstract class _UrlImportDialogConstants {
  static const double urlCoverWidth = 80.0;
  static const double urlCoverHeight = 120.0;
  static const double contentPreviewHeight = 200.0;
}

class UrlImportDialog extends StatefulWidget {
  final int languageId;
  final int? collectionId;

  const UrlImportDialog({
    super.key,
    required this.languageId,
    this.collectionId,
  });

  @override
  State<UrlImportDialog> createState() => _UrlImportDialogState();
}

class _UrlImportDialogState extends State<UrlImportDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _urlImportService = UrlImportService();

  bool _isLoading = false;
  bool _isFetched = false;
  String? _error;
  String _content = '';
  String? _coverImagePath;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchUrl() async {
    final l10n = AppLocalizations.of(context);
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = l10n.pleaseEnterUrl);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _urlImportService.importFromUrl(url);

      String? coverPath;
      if (result.coverImageUrl != null) {
        coverPath = await _urlImportService.downloadCoverImage(
          result.coverImageUrl!,
        );
      }

      setState(() {
        _titleController.text = result.title;
        _content = result.content;
        _coverImagePath = coverPath;
        _isFetched = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.single.path != null) {
      final sourcePath = result.files.single.path!;
      final sourceFile = File(sourcePath);

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final extension = p.extension(sourcePath);
      final newFileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final newPath = p.join(coversDir.path, newFileName);

      await sourceFile.copy(newPath);

      setState(() {
        _coverImagePath = newPath;
      });
    }
  }

  void _import() {
    final l10n = AppLocalizations.of(context);
    if (_titleController.text.isEmpty) {
      setState(() => _error = l10n.pleaseEnterTitle);
      return;
    }

    final text = TextDocument(
      languageId: widget.languageId,
      collectionId: widget.collectionId,
      title: _titleController.text,
      content: _content,
      sourceUri: _urlController.text.trim(),
      coverImage: _coverImagePath,
    );
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importFromUrl),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l10n.url,
                  hintText: l10n.urlHint,
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: _isLoading
                      ? SizedBox(
                          width: AppConstants.progressIndicatorSize,
                          height: AppConstants.progressIndicatorSize,
                          child: const Padding(
                            padding: EdgeInsets.all(AppConstants.spacingM),
                            child: CircularProgressIndicator(
                              strokeWidth: AppConstants.progressStrokeWidth,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: l10n.fetchContent,
                          onPressed: _fetchUrl,
                        ),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _fetchUrl(),
                enabled: !_isLoading,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_isFetched) ...[
                const SizedBox(height: AppConstants.spacingL),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _pickCoverImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                        child: _coverImagePath != null
                            ? Image.file(
                                File(_coverImagePath!),
                                width: _UrlImportDialogConstants.urlCoverWidth,
                                height: _UrlImportDialogConstants.urlCoverHeight,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: _UrlImportDialogConstants.urlCoverWidth,
                                      height: _UrlImportDialogConstants.urlCoverHeight,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image),
                                    ),
                              )
                            : Container(
                                width: _UrlImportDialogConstants.urlCoverWidth,
                                height: _UrlImportDialogConstants.urlCoverHeight,
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: AppConstants.spacingXS),
                                    Text(
                                      l10n.addCover,
                                      style: TextStyle(
                                        fontSize: AppConstants.fontSizeXS,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: l10n.title,
                          prefixIcon: const Icon(Icons.title),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingL),
                Text(l10n.preview, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppConstants.spacingS),
                Container(
                  height: _UrlImportDialogConstants.contentPreviewHeight,
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingS),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                  ),
                  child: SingleChildScrollView(
                    child: Text(_content, style: const TextStyle(fontSize: AppConstants.fontSizeCaption)),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  l10n.wordsCount(_content.split(RegExp(r'\s+')).length),
                  style: TextStyle(fontSize: AppConstants.fontSizeCaption, color: AppConstants.subtitleColor),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (_isFetched)
          TextButton(onPressed: _import, child: Text(l10n.import)),
      ],
    );
  }
}
