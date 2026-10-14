import 'package:flutter/widgets.dart';

import '../../domain/entities/text_document.dart';
import '../../service_locator.dart';
import '../../services/settings_service.dart';
import '../../utils/cover_image_helper.dart';
import 'base_controller.dart';

/// State for [TextEditScreen]: title, content and cover edits, plus the reader
/// font size the content field is rendered with.
class TextEditController extends BaseController {
  final TextDocument text;

  final TextEditingController titleController;
  final TextEditingController contentController;

  /// Absolute path of the current cover, or null.
  String? coverImagePath;

  double fontSize;

  /// Completes once [fontSize] is final. Immediate when it was passed in.
  late final Future<void> ready;

  TextEditController({required this.text, double? fontSize})
      : titleController = TextEditingController(text: text.title),
        contentController = TextEditingController(text: text.content),
        coverImagePath = CoverImageHelper.resolve(text.coverImage),
        fontSize = fontSize ?? SettingsService.defaultReaderFontSize {
    titleController.addListener(safeNotify);
    contentController.addListener(safeNotify);
    ready = fontSize == null ? _loadFontSize() : Future.value();
  }

  Future<void> _loadFontSize() async {
    fontSize = await settings.getReaderFontSize();
    safeNotify();
  }

  void setCoverImagePath(String? path) {
    coverImagePath = path;
    safeNotify();
  }

  void clearCover() => setCoverImagePath(null);

  String? get _relativeCover =>
      coverImagePath == null ? null : CoverImageHelper.toRelative(coverImagePath!);

  bool get isDirty =>
      titleController.text != text.title ||
      contentController.text != text.content ||
      _relativeCover != _originalRelativeCover;

  String? get _originalRelativeCover {
    final resolved = CoverImageHelper.resolve(text.coverImage);
    return resolved == null ? null : CoverImageHelper.toRelative(resolved);
  }

  TextDocument buildResult() => text.copyWith(
        title: titleController.text,
        content: contentController.text,
        coverImage: _relativeCover,
        clearCoverImage: coverImagePath == null && text.coverImage != null,
      );

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }
}
