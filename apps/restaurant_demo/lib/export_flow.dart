// The demo's own export dialog: one list of the choices -- each exporter,
// an image one at each resolution --, the one last made marked, a tap on
// one answers it. The planner's flows take it as `onExportDialog`, and the
// demo's own service bar asks it too (or the library's
// `showPlanExportDialog`, while the switch is off).
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Asks for an exporter and a resolution, starting from [initial]; null
/// cancels. A [PlanExportDialog].
Future<PlanExportAnswer?> showDemoExportDialog(BuildContext context,
    PlanExportAnswer initial, List<PlanExporter> exporters) {
  final words = PlanStrings.of(context);
  final choices = <(PlanExportAnswer, String, String)>[
    for (final e in exporters)
      if (e.mimeType.startsWith('image/'))
        for (final dpi in PlanExportDpi.values)
          (
            PlanExportAnswer(
                exporter: e.id, choice: PlanExportChoice(dpi: dpi)),
            '${e.extension.toUpperCase()}, ${dpi.value} dpi',
            'demo-export-${e.extension}-${dpi.value}'
          )
      else
        (
          PlanExportAnswer(exporter: e.id, choice: initial.choice),
          e.extension.toUpperCase(),
          'demo-export-${e.extension}'
        ),
  ];
  return showShadDialog<PlanExportAnswer>(
    context: context,
    builder: (context) => ShadDialog(
      key: const Key('demo-export-dialog'),
      title: Text(words.exportTitle),
      actions: [
        ShadButton.ghost(
          key: const Key('demo-export-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(words.cancel),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (answer, label, key) in choices)
            ShadButton.ghost(
              key: Key(key),
              mainAxisAlignment: MainAxisAlignment.start,
              onPressed: () => Navigator.of(context).pop(answer),
              leading: SizedBox(
                  width: 18,
                  child: answer == initial
                      ? const Icon(LucideIcons.check, size: 18)
                      : null),
              child: Text(label),
            ),
        ],
      ),
    ),
  );
}
