// The host's view (spec 14b-2 H5): the design mode's editor or the
// selection mode's canvas, for a [FloorPlanController], keyed by the
// controller's active plan.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../export/page_printer.dart';
import '../planner_shell.dart';
import '../shell_commands.dart';
import 'floor_plan_controller.dart';
import 'floor_plan_types.dart';
import 'page_flows.dart';
import 'service_view.dart';

/// The planner, embedded (spec 14b-2 H5): in the design mode today's editor
/// over the designed plan, with Export and Print and no file dialogs; in
/// the selection mode the canvas over the service copy.
///
/// [onExport] receives Export's bytes; without it Export is not offered.
/// [printer] defaults to the platform's print dialog. Exports are named
/// [exportName] with `.pdf` or `.png`.
class FloorPlanView extends StatefulWidget {
  const FloorPlanView({
    super.key,
    required this.controller,
    this.onExport,
    this.printer,
    this.exportName = 'plan',
  });

  final FloorPlanController controller;
  final void Function(FloorPlanExport export)? onExport;
  final PagePrinter? printer;
  final String exportName;

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

class _FloorPlanViewState extends State<FloorPlanView> {
  late PageFlows _flows = _flowsFor(widget);

  /// The fit-on-start answer, taken once per plan shown (R-13).
  DraftDocument? _fitFor;
  bool _fit = true;

  PageFlows _flowsFor(FloorPlanView w) => PageFlows(
        controller: w.controller,
        onExport: w.onExport,
        printer: w.printer ?? const PrintingPagePrinter(),
        exportName: w.exportName,
      );

  @override
  void didUpdateWidget(FloorPlanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.onExport != widget.onExport ||
        oldWidget.printer != widget.printer ||
        oldWidget.exportName != widget.exportName) {
      _flows.dispose();
      _flows = _flowsFor(widget);
    }
  }

  @override
  void dispose() {
    _flows.dispose();
    super.dispose();
  }

  bool _fitOnStartFor(DraftDocument document) {
    if (!identical(_fitFor, document)) {
      _fitFor = document;
      _fit = widget.controller.takeFitOnStart();
    }
    return _fit;
  }

  List<ShellCommand> _commands(BuildContext context) => [
        if (_flows.canExport)
          ShellCommand(
              id: 'export',
              label: 'Export…',
              icon: Icons.ios_share_outlined,
              shortcuts: kExportChords,
              enabled: _flows.ready,
              run: () => _flows.export(context)),
        ShellCommand(
            id: 'print',
            label: 'Print…',
            icon: Icons.print_outlined,
            shortcuts: kPrintChords,
            enabled: _flows.ready,
            run: () => _flows.print(context)),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          final document = c.activeDocument;
          if (c.mode.value == FloorPlanMode.selection) {
            return ServiceView(
                key: ObjectKey(document),
                controller: c,
                flows: _flows,
                fitOnStart: _fitOnStartFor(document));
          }
          c.startSymbols();
          return PlannerShell(
            key: ObjectKey(document),
            document: document,
            selection: c.activeSelection,
            camera: c.camera,
            fitOnStart: _fitOnStartFor(document),
            fitRequests: c.fitRequests,
            fileCommands: _commands(context),
            onSettle: c.registerSettle,
            symbols: c.symbols,
            thumbnails: c.thumbnails,
          );
        },
      );
}
