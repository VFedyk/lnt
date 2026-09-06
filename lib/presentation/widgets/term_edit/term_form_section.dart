import 'package:flutter/material.dart';

import '../../../domain/entities/term.dart';
import '../../../domain/value_objects/term_status.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';
import '../../controllers/term_edit_controller.dart';
import '../../theme/term_status_ui.dart';

/// Term text field + status row + inline romanization for the Edit tab.
class TermFormSection extends StatelessWidget {
  final TermEditController controller;
  final Term originalTerm;

  const TermFormSection({
    super.key,
    required this.controller,
    required this.originalTerm,
  });

  Widget _buildTermField(AppLocalizations l10n) {
    return TextField(
      controller: controller.termController,
      decoration: InputDecoration(
        labelText: l10n.term,
        border: const OutlineInputBorder(),
        suffixIcon: originalTerm.text != originalTerm.lowerText
            ? IconButton(
                icon: const Icon(Icons.history),
                tooltip: l10n.useOriginal(originalTerm.text),
                onPressed: () {
                  controller.termController.text = originalTerm.text;
                },
              )
            : null,
      ),
      onChanged: (_) => controller.maybeAutoFillRomanization(),
    );
  }

  Widget _buildStatusRow(AppLocalizations l10n) {
    return Row(
      children: [
        Text(l10n.status, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: AppConstants.spacingS),
        Chip(
          avatar: CircleAvatar(
            backgroundColor: TermStatusUI.colorFor(controller.status),
            radius: AppConstants.spacingS,
          ),
          label: Text(
            TermStatusUI.localizedNameFor(controller.status, l10n),
            style: const TextStyle(fontSize: AppConstants.fontSizeCaption),
          ),
        ),
        const Spacer(),
        if (controller.status == TermStatus.ignored)
          TextButton(
            onPressed: () => controller.updateStatus(TermStatus.unknown),
            child: Text(l10n.unignore),
          )
        else ...[
          if (controller.status != TermStatus.wellKnown)
            TextButton(
              onPressed: () => controller.updateStatus(TermStatus.wellKnown),
              child: Text(l10n.markWellKnown),
            ),
          TextButton(
            onPressed: () => controller.updateStatus(TermStatus.ignored),
            child: Text(l10n.ignore),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTermField(l10n),
        const SizedBox(height: AppConstants.spacingM),
        _buildStatusRow(l10n),
        const SizedBox(height: AppConstants.spacingM),
        TextField(
          controller: controller.romanizationController,
          decoration: InputDecoration(
            labelText: l10n.romanizationPronunciation,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
