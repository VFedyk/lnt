import 'package:flutter/material.dart';

import '../../models/review_session_spec.dart';
import 'practice_mode_banner.dart';

/// App bar for an exercise screen.
///
/// Adds the two things a scoped session needs on top of a plain [AppBar]: which
/// text it was started from, and — for an ungraded pass — the practice banner.
AppBar reviewSessionAppBar(
  BuildContext context,
  ReviewSessionSpec spec,
  String title,
) {
  final sourceTitle = spec.sourceTextTitle;
  return AppBar(
    title: sourceTitle == null
        ? Text(title)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              Text(
                sourceTitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
    bottom: spec.graded ? null : const PracticeModeBanner(),
  );
}
