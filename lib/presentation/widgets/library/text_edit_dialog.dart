import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/text_document.dart';
import '../../../utils/constants.dart';
import '../../../utils/cover_image_helper.dart';
import '../../../utils/snackbar_helpers.dart';

abstract class _TextEditDialogConstants {
  static const double coverPickerWidth = 100.0;
  static const double coverPickerHeight = 150.0;
  static const double coverPickerIconSize = 32.0;
  static const int contentMaxLines = 10;
}

class TextEditDialog extends StatefulWidget {
  final TextDocument text;

  const TextEditDialog({super.key, required this.text});

  @override
  State<TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<TextEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _coverImagePath;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.text.title);
    _contentController = TextEditingController(text: widget.text.content);
    _coverImagePath = CoverImageHelper.resolve(widget.text.coverImage);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'],
    );

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

  void _removeCoverImage() {
    setState(() {
      _coverImagePath = null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final clipboardReader = await clipboard.read();
    if (clipboardReader.items.isEmpty) {
      if (mounted) {
        SnackbarHelpers.showError(
          context,
          AppLocalizations.of(context).noImageInClipboard,
        );
      }
      return;
    }

    final item = clipboardReader.items.first;
    FileFormat? format;
    String extension = 'png';
    if (item.canProvide(Formats.png)) {
      format = Formats.png;
      extension = 'png';
    } else if (item.canProvide(Formats.jpeg)) {
      format = Formats.jpeg;
      extension = 'jpg';
    }

    if (format == null) {
      if (mounted) {
        SnackbarHelpers.showError(
          context,
          AppLocalizations.of(context).noImageInClipboard,
        );
      }
      return;
    }

    final completer = Completer<Uint8List?>();
    item.getFile(format, (file) async {
      completer.complete(await file.readAll());
    }, onError: (_) => completer.complete(null));
    final imageBytes = await completer.future;

    if (imageBytes == null) {
      if (mounted) {
        SnackbarHelpers.showError(
          context,
          AppLocalizations.of(context).noImageInClipboard,
        );
      }
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coversDir.exists()) await coversDir.create(recursive: true);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final newPath = p.join(coversDir.path, fileName);
    await File(newPath).writeAsBytes(imageBytes);

    if (mounted) setState(() => _coverImagePath = newPath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editText),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: _TextEditDialogConstants.coverPickerWidth,
                  height: _TextEditDialogConstants.coverPickerHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                    child: _coverImagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: _TextEditDialogConstants.coverPickerIconSize,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: AppConstants.spacingXS),
                              Text(
                                l10n.addCover,
                                style: TextStyle(
                                  fontSize: AppConstants.fontSizeCaption,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                        : SizedBox.expand(
                            child: _coverImagePath!.toLowerCase().endsWith('.svg')
                                ? SvgPicture.file(
                                    File(_coverImagePath!),
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_coverImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                  ),
                ),
              ),
              if (_coverImagePath != null)
                TextButton(
                  onPressed: _removeCoverImage,
                  child: Text(l10n.removeCover),
                )
              else
                TextButton(
                  onPressed: _pasteFromClipboard,
                  child: Text(l10n.pasteFromClipboard),
                ),
              const SizedBox(height: AppConstants.spacingL),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.title),
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
              ),
              const SizedBox(height: AppConstants.spacingL),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.textContent,
                  alignLabelWithHint: true,
                ),
                maxLines: _TextEditDialogConstants.contentMaxLines,
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final relativeCover = _coverImagePath != null
                  ? CoverImageHelper.toRelative(_coverImagePath!)
                  : null;
              final updatedText = widget.text.copyWith(
                title: _titleController.text,
                content: _contentController.text,
                coverImage: relativeCover,
                clearCoverImage:
                    _coverImagePath == null && widget.text.coverImage != null,
              );
              Navigator.pop(context, updatedText);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
