import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../domain/entities/language.dart';
import '../../domain/entities/text_document.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/constants.dart';
import '../../utils/cover_image_helper.dart';
import '../../utils/dialog_helpers.dart';
import '../../utils/snackbar_helpers.dart';
import '../controllers/text_edit_controller.dart';
import '../widgets/reader/reader_context_menu.dart';

abstract class _TextEditScreenConstants {
  static const double coverWidth = 60.0;
  static const double coverHeight = 90.0;
  static const double coverIconSize = 24.0;
}

/// Full-screen text editor. The content field uses the reader's font size,
/// line height and text direction so a text wraps the same way in both.
///
/// Pops the updated [TextDocument], or null on cancel; the caller writes it.
class TextEditScreen extends StatefulWidget {
  final TextDocument text;
  final Language language;

  /// The reader passes its current size; otherwise the stored setting is used.
  final double? fontSize;

  const TextEditScreen({
    super.key,
    required this.text,
    required this.language,
    this.fontSize,
  });

  @override
  State<TextEditScreen> createState() => _TextEditScreenState();
}

class _TextEditScreenState extends State<TextEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditController(
      text: widget.text,
      fontSize: widget.fontSize,
    );
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  TextDirection get _direction =>
      widget.language.rightToLeft ? TextDirection.rtl : TextDirection.ltr;

  Future<bool> _confirmDiscard() async {
    if (!_controller.isDirty) return true;
    final l10n = AppLocalizations.of(context);
    final ok = await DialogHelpers.showConfirmationDialog(
      context,
      title: l10n.discardChanges,
      message: l10n.discardChangesBody,
      confirmText: l10n.discardChanges,
      isDestructive: true,
    );
    return ok == true;
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.buildResult());
    }
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'],
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return;
    final newPath = await CoverImageHelper.importFile(sourcePath);
    _controller.setCoverImagePath(newPath);
  }

  void _showNoImage() {
    if (!mounted) return;
    SnackbarHelpers.showError(
      context,
      AppLocalizations.of(context).noImageInClipboard,
    );
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final reader = await clipboard.read();
    if (reader.items.isEmpty) return _showNoImage();

    final item = reader.items.first;
    FileFormat? format;
    String extension = 'png';
    if (item.canProvide(Formats.png)) {
      format = Formats.png;
    } else if (item.canProvide(Formats.jpeg)) {
      format = Formats.jpeg;
      extension = 'jpg';
    }
    if (format == null) return _showNoImage();

    final completer = Completer<Uint8List?>();
    item.getFile(format, (file) async {
      completer.complete(await file.readAll());
    }, onError: (_) => completer.complete(null));
    final bytes = await completer.future;
    if (bytes == null) return _showNoImage();

    final newPath = await CoverImageHelper.saveBytes(bytes, extension);
    _controller.setCoverImagePath(newPath);
  }

  Widget _buildCover(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final path = _controller.coverImagePath;
    final radius = BorderRadius.circular(AppConstants.borderRadiusM);
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        width: _TextEditScreenConstants.coverWidth,
        height: _TextEditScreenConstants.coverHeight,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: path == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: _TextEditScreenConstants.coverIconSize,
                      color: scheme.onSurfaceVariant,
                    ),
                    Text(
                      l10n.addCover,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppConstants.fontSizeXS,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : SizedBox.expand(
                  child: path.toLowerCase().endsWith('.svg')
                      ? SvgPicture.file(File(path), fit: BoxFit.cover)
                      : Image.file(File(path), fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCover(l10n),
          const SizedBox(width: AppConstants.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _controller.titleController,
                  textDirection: _direction,
                  decoration: InputDecoration(labelText: l10n.title),
                  validator: (v) =>
                      v?.isEmpty == true ? l10n.required : null,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _controller.coverImagePath != null
                      ? TextButton(
                          onPressed: _controller.clearCover,
                          child: Text(l10n.removeCover),
                        )
                      : TextButton(
                          onPressed: _pasteFromClipboard,
                          child: Text(l10n.pasteFromClipboard),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.editText),
            actions: [
              TextButton(onPressed: _save, child: Text(l10n.save)),
            ],
          ),
          body: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildHeader(l10n),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    // Same padding as ReaderContent's ListView, so lines wrap alike.
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    child: TextFormField(
                      controller: _controller.contentController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      textDirection: _direction,
                      style: TextStyle(
                        fontSize: _controller.fontSize,
                        height: ReaderScreenConstants.lineHeight,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: l10n.textContent,
                      ),
                      validator: (v) =>
                          v?.isEmpty == true ? l10n.required : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
