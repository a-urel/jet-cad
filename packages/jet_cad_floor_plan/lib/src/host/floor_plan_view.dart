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
    this.serviceMoves = true,
    this.onTableContextMenu,
    this.longPress = FloorPlanLongPress.toggleSelection,
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

  /// Whether staff may move tables in the selection mode (spec 14d S5).
  /// When false, a drag from a table pans as one on the floor does; taps
  /// and long presses are unchanged. Read at each press.
  final bool serviceMoves;

  /// A table's context menu was asked for in the selection mode (spec 14d
  /// S6): a secondary click, or a long press under
  /// [FloorPlanLongPress.contextMenu]. Its number and the pointer's global
  /// position. An unselected table is first selected alone, a selected one
  /// keeps the selection, so the menu acts on `selectedTables`; a locked
  /// table is reported without a selection change; an unnumbered one is
  /// not reported. On the web the browser's own menu opens too, unless the
  /// host calls `BrowserContextMenu.disableContextMenu()` (S8).
  final void Function(String number, Offset globalPosition)? onTableContextMenu;

  /// What a long press on a table does in the selection mode (spec 14d
  /// S7).
  final FloorPlanLongPress longPress;

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
                    ),
                options: () => (
                      serviceMoves: widget.serviceMoves,
                      longPress: widget.longPress,
                      onTableContextMenu: widget.onTableContextMenu,
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
