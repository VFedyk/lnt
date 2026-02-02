import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/collection.dart';
import '../utils/constants.dart';

abstract class _CollectionDialogConstants {
  static const double coverPickerWidth = 100.0;
  static const double coverPickerHeight = 150.0;
  static const double coverPickerIconSize = 32.0;
  static const int descriptionMaxLines = 2;
}

class CollectionDialog extends StatefulWidget {
  final int languageId;
  final int? parentId;
  final Collection? existingCollection;

  const CollectionDialog({
    super.key,
    required this.languageId,
    this.parentId,
    this.existingCollection,
  });

  bool get isEditing => existingCollection != null;

  @override
  State<CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<CollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _coverImagePath;

  @override
  void initState() {
    super.initState();
    if (widget.existingCollection != null) {
      _nameController.text = widget.existingCollection!.name;
      _descriptionController.text = widget.existingCollection!.description;
      _coverImagePath = widget.existingCollection!.coverImage;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
      title: Text(widget.isEditing ? l10n.editCollection : l10n.newCollection),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: _CollectionDialogConstants.coverPickerWidth,
                  height: _CollectionDialogConstants.coverPickerHeight,
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
                              size: _CollectionDialogConstants.coverPickerIconSize,
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
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.name),
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
                autofocus: !widget.isEditing,
              ),
              const SizedBox(height: AppConstants.spacingS),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.descriptionOptional,
                ),
                maxLines: _CollectionDialogConstants.descriptionMaxLines,
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
              final collection = widget.isEditing
                  ? widget.existingCollection!.copyWith(
                      name: _nameController.text,
                      description: _descriptionController.text,
                      coverImage: _coverImagePath,
                      clearCoverImage:
                          _coverImagePath == null &&
                          widget.existingCollection!.coverImage != null,
                    )
                  : Collection(
                      languageId: widget.languageId,
                      parentId: widget.parentId,
                      name: _nameController.text,
                      description: _descriptionController.text,
                      coverImage: _coverImagePath,
                    );
              Navigator.pop(context, collection);
            }
          },
          child: Text(widget.isEditing ? l10n.save : l10n.create),
        ),
      ],
    );
  }
}
