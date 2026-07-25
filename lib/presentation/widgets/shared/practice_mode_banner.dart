import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';
import '../../theme/app_theme.dart';

/// Persistent app-bar strip shown during an ungraded practice session, so the
/// user is never left guessing whether their answers counted.
///
/// Use as `AppBar.bottom`.
class PracticeModeBanner extends StatelessWidget
    implements PreferredSizeWidget {
  const PracticeModeBanner({super.key});

  static const double _height = 28.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      height: _height,
      alignment: Alignment.center,
      color: colors.warning,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Text(
        l10n.practiceModeBanner,
        style: TextStyle(
          color: colors.onWarning,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
