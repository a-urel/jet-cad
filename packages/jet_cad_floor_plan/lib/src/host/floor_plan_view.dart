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
    this.onTableTap,
    this.onLayoutChanged,
    this.onGroupTap,
    this.onMergeRequested,
    this.onSplitRequested,
  });

  final FloorPlanController controller;
  final void Function(FloorPlanExport export)? onExport;
  final PagePrinter? printer;
  final String exportName;

  /// A table was tapped in the selection mode (14c S8): its number. A
  /// locked table reports its tap too; an unnumbered one reports none.
  final void Function(String number)? onTableTap;

  /// Tables were moved in the selection mode, one call per drag (14c S8).
  final void Function()? onLayoutChanged;

  /// A member of a group was tapped in the selection mode (table-groups
  /// spec G4): the group's id and the tapped number, after [onTableTap]. A
  /// locked member reports its tap too.
  final void Function(String groupId, String number)? onGroupTap;

  /// The service bar's Merge was pressed (G5): the selected numbers. The
  /// planner only asks; the host decides and calls
  /// [FloorPlanController.setTableGroups].
  final void Function(Set<String> numbers)? onMergeRequested;

  /// The service bar's Split was pressed (G5): the selected group's id. The
  /// planner only asks, as for [onMergeRequested].
  final void Function(String groupId)? onSplitRequested;

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

class _FloorPlanViewState extends State<FloorPlanView> {
  late PageFlows _flows = _flowsFor(widget.controller);

  /// The fit-on-start answer, taken once per plan shown (R-13).
  DraftDocument? _fitFor;
  bool _fit = true;

  /// One per controller: the settings are read from the current widget
  /// at each call (review F-1).
  PageFlows _flowsFor(FloorPlanController c) => PageFlows(
        controller: c,
        settings: () => (
          onExport: widget.onExport,
          printer: widget.printer ?? const PrintingPagePrinter(),
          exportName: widget.exportName,
        ),
      );

  @override
  void didUpdateWidget(FloorPlanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _flows.dispose();
      _flows = _flowsFor(widget.controller);
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

  List<ShellCommand> _commands() => [
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
                fitOnStart: _fitOnStartFor(document),
                callbacks: () => (
                      onTableTap: widget.onTableTap,
                      onLayoutChanged: widget.onLayoutChanged,
                      onGroupTap: widget.onGroupTap,
                      onMergeRequested: widget.onMergeRequested,
                      onSplitRequested: widget.onSplitRequested,
                    ));
          }
          c.startSymbols();
          return PlannerShell(
            key: ObjectKey(document),
            document: document,
            selection: c.activeSelection,
            camera: c.camera,
            fitOnStart: _fitOnStartFor(document),
            fitRequests: c.fitRequests,
            fileCommands: _commands(),
            onFitted: c.fitted,
            onSettle: c.registerSettle,
            symbols: c.symbols,
            thumbnails: c.thumbnails,
          );
        },
      );
}
