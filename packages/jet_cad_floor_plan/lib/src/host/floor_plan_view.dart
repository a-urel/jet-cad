// The host's view (spec 14b-2 H5): the design mode's editor or the
// selection mode's canvas, for a [FloorPlanController], keyed by the
// controller's active plan.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;

import '../l10n/strings.dart';
import '../export/page_printer.dart';
import '../planner_shell.dart';
import '../service/table_select_tool.dart' show ServiceEvents;
import '../shell_commands.dart';
import 'floor_plan_controller.dart';
import 'floor_plan_types.dart';
import 'page_flows.dart';
import 'service_view.dart';
import 'table_detail.dart';
import 'table_overlay.dart';

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
    this.userCamera = true,
    this.tableOverlayBuilder,
    this.tableOverlayLayout = const FloorPlanOverlayLayout(),
    this.tableOverlayModes = const {FloorPlanMode.selection},
    this.onTablesMoved,
    this.onTableDoubleTap,
    this.onFloorTap,
    this.onTableHover,
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

  /// Whether the user moves the camera in this view (host embedding API
  /// spec G-3): pan by dragging (the middle button in the design mode, the
  /// floor in the selection mode), two-finger pinch, trackpad and wheel
  /// zoom. False locks them all, for a kiosk or a wall display: a drag on
  /// the floor then does nothing; taps, selections and table moves are
  /// unchanged, and the controller's [FloorPlanController.panBy],
  /// [FloorPlanController.zoomBy], [FloorPlanController.centerOn] and fits
  /// still act. Read at each build and each press.
  final bool userCamera;

  /// The host's widget on each table (host embedding API spec G-5): called
  /// per numbered table with geometry, again for one table only when its
  /// [FloorPlanTableOverlay] changes, and again for every table each time
  /// the host rebuilds this view, whatever the function (a closure written
  /// in `build` or a method tear-off); never on pan or zoom. Null builds no
  /// overlay layer at all.
  ///
  /// The widgets sit above the plan, its statuses and the selection
  /// outlines, inside the canvas and clipped to it, placed by
  /// [tableOverlayLayout], in the modes of [tableOverlayModes]. They live
  /// as long as the plan the view shows: a mode switch, a
  /// `FloorPlanController.resetLayout`, a restore or a load builds them
  /// afresh, so a host keeps its state in its own objects, not in an
  /// overlay's `State`. Each table's widget is its own, so two tables
  /// sharing a number get two. While staff drag tables, the widgets stay at
  /// the tables' last places and move on the drop. They ignore pointers
  /// unless [tableOverlayLayout] is [FloorPlanOverlayLayout.interactive].
  final FloorPlanTableOverlayBuilder? tableOverlayBuilder;

  /// Where and how [tableOverlayBuilder]'s widgets sit on their tables
  /// (spec G-6, G-7). Read at each build; an [ArgumentError] for a layout
  /// [FloorPlanOverlayLayout] rejects.
  final FloorPlanOverlayLayout tableOverlayLayout;

  /// The modes that show [tableOverlayBuilder]'s widgets: the selection
  /// mode only, by default.
  final Set<FloorPlanMode> tableOverlayModes;

  /// Tables were moved in the selection mode (host embedding API spec
  /// E-1): after a drag ends, every moved table, numbered or not, ascending
  /// by handle, with its new geometry, as
  /// [FloorPlanController.tableDetails] reads it; once per drag, after
  /// [onLayoutChanged]. Undo, Redo, `resetLayout` and
  /// `restoreServiceLayout` do not call it (they fire
  /// `serviceLayoutChanges`), and it is not called for a drag whose
  /// [onLayoutChanged] replaced the plan shown (a `resetLayout`, a `load`,
  /// a mode switch): the tables it moved are gone. The list is
  /// unmodifiable. Read at each call.
  final void Function(List<FloorPlanTableDetail> moved)? onTablesMoved;

  /// A table was tapped twice in the selection mode (spec E-2): a second
  /// tap on the same table whose down is within `kDoubleTapTimeout` (300
  /// ms) of the first tap's down and within `kDoubleTapSlop` (100 logical
  /// pixels) of it, both timed and measured from the raw pointer events. A
  /// locked table reports it; an unnumbered one does not. With Shift, Ctrl
  /// or Cmd held on either tap it is no double tap (each tap toggles). The
  /// single tap is **not delayed**: both taps report [onTableTap] (and
  /// select) as before, then this fires; a third tap starts anew. So a host
  /// that acts on a tap acts on each tap of a double tap too. Read at each
  /// call.
  final void Function(String number)? onTableDoubleTap;

  /// A tap in the selection mode missed every table (spec E-3): the world
  /// point of its down, in millimetres with y up. Called after the tap's
  /// own effect (the selection cleared, or kept with a modifier held), with
  /// or without a modifier. Read at each call.
  final void Function(Offset world)? onFloorTap;

  /// The mouse or stylus pointer moved onto a numbered table, or off it
  /// (null: over the floor or an unnumbered table), in the selection mode
  /// (spec E-4): only when the number changes, and null when the pointer
  /// leaves the canvas or moves onto an interactive overlay
  /// (`interactive: true`, which takes the pointer off the canvas); never
  /// for touch. A table is under the pointer when the point is on its top
  /// or in its box: no reach. A mode switch, `resetLayout`, a restore or a
  /// load builds the view afresh and sends no null: a host clears its
  /// hover state when the mode or the plan changes. Without it, a hover
  /// does no work. Read at each move.
  final void Function(String? number)? onTableHover;

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

class _FloorPlanViewState extends State<FloorPlanView> {
  late PageFlows _flows = _flowsFor(widget.controller);

  /// The plan last measured (R-13 as amended): each plan shown, a mode's
  /// or a new copy's, is measured once, after its first frame.
  DraftDocument? _measuredFor;

  /// After the frame that first shows [document] in mode [shown], the
  /// controller is told where that mode's canvas starts in this view.
  void _measureAfterFrame(FloorPlanMode shown, DraftDocument document) {
    if (identical(_measuredFor, document)) return;
    _measuredFor = document;
    final c = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(c, widget.controller)) return;
      final origin = _canvasOrigin();
      if (origin != null) c.canvasMeasured(shown, origin);
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

  /// The fit-on-start answer, taken once per plan shown (R-13), and
  /// whether that fit performs only a request (Task 2 review R-1): not the
  /// plan's own first fit.
  DraftDocument? _fitFor;
  bool _fit = true;
  bool _fitIsRequest = false;

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

  /// Reports this view's language to the controller (spec Q0 N1): it
  /// settles an empty plan nothing has touched, and a new plan takes it.
  /// Again on every change of the language, and on a controller swap.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.reportLanguage(FloorPlanStrings.of(context));
  }

  @override
  void didUpdateWidget(FloorPlanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _flows.dispose();
      _flows = _flowsFor(widget.controller);
      widget.controller.reportLanguage(FloorPlanStrings.of(context));
    }
  }

  @override
  void dispose() {
    _flows.dispose();
    super.dispose();
  }

  /// The view events (spec E-1 to E-4) of the current widget, read at each
  /// call (R-5): the record is rebuilt only when the widget is a new one,
  /// so a hover's read allocates nothing.
  ServiceEvents<FloorPlanTableDetail> _serviceEvents() {
    final w = widget;
    if (!identical(w, _eventsOf)) {
      _eventsOf = w;
      _events = (
        onTablesMoved: w.onTablesMoved,
        onTableDoubleTap: w.onTableDoubleTap,
        onFloorTap: w.onFloorTap,
        onTableHover: w.onTableHover,
      );
    }
    return _events;
  }

  FloorPlanView? _eventsOf;
  late ServiceEvents<FloorPlanTableDetail> _events;

  bool _fitOnStartFor(DraftDocument document) {
    if (!identical(_fitFor, document)) {
      _fitFor = document;
      _fitIsRequest = !widget.controller.owesFirstFit;
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

  /// The overlay layer for [mode], or null when the host shows none there
  /// (spec G-5).
  Widget? _tableOverlays(FloorPlanController c, FloorPlanMode mode) {
    final builder = widget.tableOverlayBuilder;
    if (builder == null || !widget.tableOverlayModes.contains(mode)) {
      return null;
    }
    return TableOverlayLayer(
        controller: c, builder: builder, layout: widget.tableOverlayLayout);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tableOverlayBuilder != null) {
      validateOverlayLayout(widget.tableOverlayLayout);
    }
    // Made here, once per build of this view (the host's), not in the
    // listener's builder: a layer gets a new widget, and builds every
    // overlay again (G-5), only when the host rebuilds the view.
    final serviceOverlays =
        _tableOverlays(widget.controller, FloorPlanMode.selection);
    final designOverlays =
        _tableOverlays(widget.controller, FloorPlanMode.design);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final document = c.activeDocument;
        _measureAfterFrame(c.mode.value, document);
        if (c.mode.value == FloorPlanMode.selection) {
          return ServiceView(
              key: ObjectKey(document),
              controller: c,
              flows: _flows,
              fitOnStart: _fitOnStartFor(document),
              startFitIsRequest: _fitIsRequest,
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
                  ),
              userCamera: () => widget.userCamera,
              tableOverlays: serviceOverlays,
              events: _serviceEvents);
        }
        c.startSymbols();
        return PlannerShell(
          key: ObjectKey(document),
          document: document,
          selection: c.activeSelection,
          camera: c.cameraController,
          fitOnStart: _fitOnStartFor(document),
          startFitIsRequest: _fitIsRequest,
          fitRequests: c.fitRequests,
          fileCommands: _commands(FloorPlanStrings.of(context)),
          onFitted: c.fitted,
          framing: c.framingFor,
          cameraEpoch: () => c.cameraEpoch,
          userCamera: widget.userCamera,
          onCanvasPlaced: c.canvasPlaced,
          onSettle: c.registerSettle,
          symbols: c.symbols,
          thumbnails: c.thumbnails,
          tableOverlays: designOverlays,
        );
      },
    );
  }
}
