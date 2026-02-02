import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/text_document.dart';
import '../utils/constants.dart';

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
    _coverImagePath = widget.text.coverImage;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

  void _removeCoverImage() {
    setState(() {
      _coverImagePath = null;
    });
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
                    image: _coverImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_coverImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _coverImagePath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: _TextEditDialogConstants.coverPickerIconSize,
                              color: AppConstants.subtitleColor,
                            ),
                            const SizedBox(height: AppConstants.spacingXS),
                            Text(
                              l10n.addCover,
                              style: TextStyle(
                                fontSize: AppConstants.fontSizeCaption,
                                color: AppConstants.subtitleColor,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              if (_coverImagePath != null)
                TextButton(
                  onPressed: _removeCoverImage,
                  child: Text(l10n.removeCover),
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
              final updatedText = widget.text.copyWith(
                title: _titleController.text,
                content: _contentController.text,
                coverImage: _coverImagePath,
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
