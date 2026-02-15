import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class ReaderFontSizeDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final double initialValue;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const ReaderFontSizeDialog({
    super.key,
    required this.l10n,
    required this.initialValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  State<ReaderFontSizeDialog> createState() => _ReaderFontSizeDialogState();
}

class _ReaderFontSizeDialogState extends State<ReaderFontSizeDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.fontSize),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.l10n.previewText, style: TextStyle(fontSize: _value)),
          Slider(
            value: _value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: _value.round().toString(),
            onChanged: (value) {
              setState(() => _value = value);
              widget.onChanged(value);
            },
          ),
          Text('${_value.round()}pt'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.done),
        ),
      ],
    );
  }
}
