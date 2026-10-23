// The Export dialog over the registry (spec P5): the format, one segment
// per exporter, and for an image format its resolution; Export or Cancel.
// Escape cancels (a dismissible route pops on Escape). Ported from
// jet_cad_floor_plan/lib/src/export/export_dialog.dart.
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../chrome/segmented.dart';
import '../chrome/shad_scope.dart';
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
    PlanExportAnswer initial, List<PlanExporter> exporters) {
  // Everything the dialog reads is resolved here, with the caller's
  // context: the route is pushed under the root navigator, where a local
  // Theme or ShadTheme of the caller is not in scope, and `showShadDialog`
  // would read a ShadTheme from the caller (a bare MaterialApp has none).
  final theme = planShadThemeOf(context);
  final strings = PlanStrings.of(context);
  return Navigator.of(context, rootNavigator: true).push(
    ShadDialogRoute<PlanExportAnswer>(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (routeContext) => PlanShadScope(
        data: theme,
        // The scope's mouse region fills the page and is opaque, so the
        // route's barrier never hears a tap: a tap outside the card is
        // answered here.
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(routeContext).pop(),
              ),
            ),
            _ExportDialog(
                initial: initial, exporters: exporters, strings: strings),
          ],
        ),
      ),
    ),
  );
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog(
      {required this.initial, required this.exporters, required this.strings});

  final PlanExportAnswer initial;
  final PlanStrings strings;
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
    final strings = widget.strings;
    return ShadDialog(
      key: const Key('export-dialog'),
      title: Text(strings.exportTitle),
      actions: [
        ShadButton.outline(
          key: const Key('export-cancel'),
          onPressed: _cancel,
          child: Text(strings.cancel),
        ),
        ShadButton(
          key: const Key('export-ok'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(_answer),
          child: Text(strings.exportAction),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanSegmented<String>(
            key: const Key('export-format'),
            value: _answer.exporter,
            segments: [
              for (final e in widget.exporters)
                PlanSegment(e.id, e.extension.toUpperCase(),
                    key: Key('export-format-${e.id}')),
            ],
            onChanged: (id) =>
                setState(() => _answer = _answer.copyWith(exporter: id)),
          ),
          if (isRasterExporter(_exporter)) ...[
            const SizedBox(height: 12),
            PlanSegmented<PlanExportDpi>(
              key: const Key('export-dpi'),
              value: _answer.choice.dpi,
              segments: [
                for (final d in PlanExportDpi.values)
                  PlanSegment(d, strings.dpi(d.value),
                      key: Key('export-dpi-${d.value}')),
              ],
              onChanged: (d) => setState(() => _answer =
                  _answer.copyWith(choice: _answer.choice.copyWith(dpi: d))),
            ),
          ],
        ],
      ),
    );
  }
}
