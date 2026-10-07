// The host's view (spec 14b-2 H5): the design mode's editor or the
// selection mode's canvas, for a [FloorPlanController], keyed by the
// controller's active plan.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform, kRulerThickness;

import '../l10n/strings.dart';
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

/// Where each mode's canvas starts in the view, before a frame has shown it
/// (R-13 as amended): the editor's top bar (44), left panel (240) and
/// rulers; the service bar (44). A test seam: a wrong seed is measured and
/// corrected after the frame.
@visibleForTesting
final Map<FloorPlanMode, Offset> floorPlanCanvasSeeds = {
  FloorPlanMode.design:
      const Offset(240 + kRulerThickness, 44 + kRulerThickness),
  FloorPlanMode.selection: const Offset(0, 44),
};

class _FloorPlanViewState extends State<FloorPlanView> {
  late PageFlows _flows = _flowsFor(widget.controller);

  // R-13, amended by the human (2026-10-07, "planın yeri korunsun"): a mode
  // switch keeps the plan where it is on the screen. The camera's numbers
  // are in the canvas's coordinates and the two modes' canvases start at
  // different places in the view, so a switch shifts the camera by the
  // difference of their origins: seeded, then measured after each frame
  // that follows a switch, a measured difference corrected then.
  final Map<FloorPlanMode, Offset> _canvasAt = Map.of(floorPlanCanvasSeeds);
  late FloorPlanMode _shown = widget.controller.mode.value;

  @override
  void initState() {
    super.initState();
    widget.controller.mode.addListener(_onMode);
    _measureAfterFrame(correct: false);
  }

  void _onMode() {
    final next = widget.controller.mode.value;
    if (next == _shown) return;
    _shift(_canvasAt[_shown]! - _canvasAt[next]!);
    _shown = next;
    _measureAfterFrame(correct: true);
  }

  /// The camera moved by [by] on the screen, its zoom kept.
  void _shift(Offset by) {
    if (by == Offset.zero) return;
    final camera = widget.controller.camera;
    camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(by.dx, by.dy)
            .multiply(camera.value.worldToScreenMatrix));
  }

  /// After the next frame, the shown canvas's origin measured and kept;
  /// with [correct], the camera shifted by what the kept one missed.
  void _measureAfterFrame({required bool correct}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final actual = _canvasOrigin();
      if (actual == null) return;
      final expected = _canvasAt[_shown]!;
      _canvasAt[_shown] = actual;
      if (correct) _shift(expected - actual);
    });
  }

  /// The top left of the shown canvas (its interaction layer's, whose
  /// coordinates the camera's are) in this view, or null before layout.
  Offset? _canvasOrigin() {
    final view = context.findRenderObject();
    if (view is! RenderBox || !view.attached) return null;
    RenderBox? canvas;
    void visit(Element e) {
      if (canvas != null) return;
      if (e.widget is InteractionLayer) {
        final r = e.findRenderObject();
        if (r is RenderBox && r.attached && r.hasSize) canvas = r;
        return;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return canvas?.localToGlobal(Offset.zero, ancestor: view);
  }

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
      oldWidget.controller.mode.removeListener(_onMode);
      widget.controller.mode.addListener(_onMode);
      _shown = widget.controller.mode.value;
    }
  }

  @override
  void dispose() {
    widget.controller.mode.removeListener(_onMode);
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

  List<ShellCommand> _commands(FloorPlanStrings strings) => [
        if (_flows.canExport)
          ShellCommand(
              id: 'export',
              label: strings.exportEllipsis,
              icon: Icons.ios_share_outlined,
              shortcuts: kExportChords,
              enabled: _flows.ready,
              run: () => _flows.export(context)),
        ShellCommand(
            id: 'print',
            label: strings.printEllipsis,
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
            fileCommands: _commands(FloorPlanStrings.of(context)),
            onFitted: c.fitted,
            onSettle: c.registerSettle,
            symbols: c.symbols,
            thumbnails: c.thumbnails,
          );
        },
      );
}
