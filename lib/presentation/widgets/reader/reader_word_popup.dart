import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// Shows a modal popup anchored to [anchorRect] (the tapped word, in global
/// coordinates). With a null rect the popup is centered.
Future<T?> showReaderWordPopup<T>({
  required BuildContext context,
  Rect? anchorRect,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (dialogContext, _, _) {
      return CustomSingleChildLayout(
        delegate: ReaderWordPopupLayoutDelegate(
          anchorRect: anchorRect,
          padding: MediaQuery.paddingOf(dialogContext) +
              const EdgeInsets.all(AppConstants.spacingS),
        ),
        child: builder(dialogContext),
      );
    },
  );
}

/// Places the popup below the word when it fits, above otherwise, and on the
/// side with more room when neither fits. Centered horizontally on the word and
/// clamped to the padded screen.
class ReaderWordPopupLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect? anchorRect;
  final EdgeInsets padding;

  static const double gap = AppConstants.spacingXS;

  const ReaderWordPopupLayoutDelegate({
    required this.anchorRect,
    required this.padding,
  });

  Rect _area(Size size) => Rect.fromLTRB(
    padding.left,
    padding.top,
    size.width - padding.right,
    size.height - padding.bottom,
  );

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final area = _area(constraints.biggest);
    final anchor = anchorRect;
    double maxHeight = area.height;
    if (anchor != null) {
      final above = anchor.top - gap - area.top;
      final below = area.bottom - (anchor.bottom + gap);
      maxHeight = above > below ? above : below;
    }
    return BoxConstraints(
      maxWidth: area.width < 0 ? 0 : area.width,
      maxHeight: maxHeight < 0 ? 0 : maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final area = _area(size);
    final anchor = anchorRect;
    if (anchor == null) {
      return Offset(
        area.left + (area.width - childSize.width) / 2,
        area.top + (area.height - childSize.height) / 2,
      );
    }

    final maxX = area.right - childSize.width;
    final x = (anchor.center.dx - childSize.width / 2).clamp(
      area.left,
      maxX < area.left ? area.left : maxX,
    );

    final belowTop = anchor.bottom + gap;
    final aboveTop = anchor.top - gap - childSize.height;
    final fitsBelow = belowTop + childSize.height <= area.bottom;
    final fitsAbove = aboveTop >= area.top;
    final spaceBelow = area.bottom - belowTop;
    final spaceAbove = anchor.top - gap - area.top;

    final double y;
    if (fitsBelow) {
      y = belowTop;
    } else if (fitsAbove) {
      y = aboveTop;
    } else if (spaceBelow >= spaceAbove) {
      y = belowTop;
    } else {
      y = aboveTop;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(ReaderWordPopupLayoutDelegate oldDelegate) =>
      oldDelegate.anchorRect != anchorRect || oldDelegate.padding != padding;
}

/// Card used by the reader's word popups. Not a [Dialog]: its internal `Align`
/// expands to the incoming constraints, which defeats the layout delegate.
class ReaderWordPopupCard extends StatelessWidget {
  final Widget child;

  const ReaderWordPopupCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 6,
      shadowColor: scheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(child: child),
    );
  }
}
