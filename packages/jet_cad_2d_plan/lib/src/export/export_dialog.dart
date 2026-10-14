// The Export dialog over the registry (spec P5): the format, one segment
// per exporter, and for an image format its resolution; Export or Cancel.
// Escape cancels (a dismissible route pops on Escape). Ported from
// jet_cad_floor_plan/lib/src/export/export_dialog.dart.
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'registries.dart';

/// A host's export dialog (`PlanEditor.onExportDialog`): it starts from
/// [initial] over [exporters] and answers null to cancel.
typedef PlanExportDialog = Future<PlanExportAnswer?> Function(
    BuildContext context,
    PlanExportAnswer initial,
    List<PlanExporter> exporters);

/// Whether [exporter] writes a raster image, whose resolution the dialog
/// asks for.
bool isRasterExporter(PlanExporter exporter) =>
    exporter.mimeType.startsWith('image/');

/// Asks for the export's exporter and resolution, starting from [initial]
/// (from the first exporter when [initial] names none of [exporters]).
/// Null when cancelled (Cancel, Escape or a tap outside).
Future<PlanExportAnswer?> showPlanExportDialog(BuildContext context,
        PlanExportAnswer initial, List<PlanExporter> exporters) =>
    showDialog<PlanExportAnswer>(
      context: context,
      builder: (_) => _ExportDialog(initial: initial, exporters: exporters),
    );

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.initial, required this.exporters});

  final PlanExportAnswer initial;
  final List<PlanExporter> exporters;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late PlanExportAnswer _answer =
      widget.exporters.any((e) => e.id == widget.initial.exporter)
          ? widget.initial
          : widget.initial.copyWith(exporter: widget.exporters.first.id);

  PlanExporter get _exporter =>
      widget.exporters.firstWhere((e) => e.id == _answer.exporter);

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final strings = PlanStrings.of(context);
    return AlertDialog(
      key: const Key('export-dialog'),
      title: Text(strings.exportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            key: const Key('export-format'),
            showSelectedIcon: false,
            segments: [
              for (final e in widget.exporters)
                ButtonSegment(
                    value: e.id,
                    label: Text(e.extension.toUpperCase(),
                        key: Key('export-format-${e.id}'))),
            ],
            selected: {_answer.exporter},
            onSelectionChanged: (s) =>
                setState(() => _answer = _answer.copyWith(exporter: s.single)),
          ),
          if (isRasterExporter(_exporter)) ...[
            const SizedBox(height: 12),
            SegmentedButton<PlanExportDpi>(
              key: const Key('export-dpi'),
              showSelectedIcon: false,
              segments: [
                for (final d in PlanExportDpi.values)
                  ButtonSegment(
                      value: d,
                      label: Text(strings.dpi(d.value),
                          key: Key('export-dpi-${d.value}'))),
              ],
              selected: {_answer.choice.dpi},
              onSelectionChanged: (s) => setState(() => _answer = _answer
                  .copyWith(choice: _answer.choice.copyWith(dpi: s.single))),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('export-cancel'),
          onPressed: _cancel,
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('export-ok'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(_answer),
          child: Text(strings.exportAction),
        ),
      ],
    );
  }
}
