// The selection mode's view (spec 14b-2 H7): the canvas alone, over the
// controller's service copy, under `runtime` permissions -- rulers, page
// chrome, the drafting and the selection outlines -- with Undo, Redo,
// Export and Print. No palette, no panels, no grips, and nothing that needs
// `geometry` or `structure` (umbrella D11). 14c's table tool picks,
// selects and moves tables. Table-groups spec G5: Merge and Split, when the
// host asks for them.

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryButton, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../l10n/strings.dart';
import '../parametric/catalog.dart';
import '../planner_view.dart';
import '../service/table_focus_painter.dart';
import '../service/table_group_painter.dart';
import '../service/table_picker.dart';
import '../service/table_select_tool.dart';
import '../service/table_status_painter.dart';
import '../shell_commands.dart';
import '../shortcut_guard.dart';
import '../tables/table_label_system.dart';
import 'bars.dart';
import 'floor_plan_controller.dart';
import 'floor_plan_theme.dart';
import 'page_flows.dart';
import 'table_detail.dart';

/// The canvas over [controller]'s service copy (H7). Built per copy: the
/// view is keyed by it, so a [FloorPlanController.resetLayout] or a load
/// builds a new one.
class ServiceView extends StatefulWidget {
  const ServiceView(
      {super.key,
      required this.controller,
      required this.flows,
      required this.fitOnStart,
      this.startFitIsRequest = false,
      required this.callbacks,
      this.options = _defaultOptions,
      this.userCamera = _always,
      this.tableOverlays,
      this.events = _noEvents,
      this.onCanvasMoved,
      this.bar = const FloorPlanServiceBar(),
      this.shortcuts = true,
      this.autofocus = true});

  final FloorPlanController controller;
  final PageFlows flows;

  /// Whether the camera fits after the first frame (R-13).
  final bool fitOnStart;

  /// Whether that fit performs only a host's request (Task 2 review R-1):
  /// see [PlannerView.startFitIsRequest].
  final bool startFitIsRequest;

  /// The host's callbacks, read at each call (14c R-5).
  final ServiceCallbacks Function() callbacks;

  /// The host's service options, read at each press (spec 14d S5-S7).
  final ServiceOptions Function() options;

  static ServiceOptions _defaultOptions() => kDefaultServiceOptions;

  /// Whether the user's pan and zoom move the camera (host embedding API
  /// spec G-3), read at each build and each press: false builds no camera
  /// gestures and turns a drag on the floor into nothing.
  final bool Function() userCamera;

  static bool _always() => true;

  /// The host's widgets on the tables (host embedding API spec G-5), above
  /// the selection outlines; null for none.
  final Widget? tableOverlays;

  /// The host's view events (spec E-1 to E-4), read at each call (R-5); a
  /// hover reads them at each button-less move, so a caller hands back a
  /// record it keeps while nothing changed.
  final ServiceEvents<FloorPlanTableDetail> Function() events;

  static ServiceEvents<FloorPlanTableDetail> _noEvents() => kNoServiceEvents;

  /// The canvas moved in the view (host embedding API spec S-10): called
  /// once after the first frame laid out with a bar height other than the
  /// last frame's (a theme's `serviceBarHeight` changed while this copy is
  /// shown), so the view measures the canvas again (R-13). Null: nothing.
  final VoidCallback? onCanvasMoved;

  /// The host's bar (host embedding API spec C-1), read at each build: the
  /// default is today's bar.
  final FloorPlanServiceBar bar;

  /// Whether the view binds its keys (host embedding API spec C-7, S-16),
  /// read at each build and key: false binds no chord (Undo, Redo, Export,
  /// Print) and leaves the table tool's idle Escape to the host. A drag's
  /// keys stay; the controller's commands stay callable.
  final bool shortcuts;

  /// Whether the view takes the focus when it is mounted (spec C-7, S-21):
  /// its own `Focus` and its canvas's. A press on the canvas takes the
  /// focus either way.
  final bool autofocus;

  @override
  State<ServiceView> createState() => _ServiceViewState();
}

/// The service bar's height with no theme, in logical pixels (spec T-1's
/// `serviceBarHeight`).
const double kServiceBarHeight = 44;

class _ServiceViewState extends State<ServiceView> {
  late final FloorPlanController _c = widget.controller;
  late final DraftDocument _document = _c.activeDocument;
  late final SelectionController _selection = _c.activeSelection;
  late final bool _fitOnStart = widget.fitOnStart;
  late final bool _startFitIsRequest = widget.startFitIsRequest;
  late final SpatialIndex _index = SpatialIndex(_document);
  late final PageNotifier _page = PageNotifier(_document);
  late final OutlineCache _outlines = OutlineCache(_document, _selection);
  // Spec 14c S3: the table tool, over this copy's tables.
  late final TablePicker _picker = TablePicker(_document);
  // Table-groups spec G4: a member acts with its group.
  late final TableSelectTool _tool = TableSelectTool(
      picker: _picker,
      groups: _c.tableGroups,
      callbacks: widget.callbacks,
      options: widget.options,
      userCamera: widget.userCamera,
      toGlobal: _toGlobal,
      events: _toolEvents,
      idleKeys: () => widget.shortcuts);

  /// The host's events as the tool reports them (spec E-1 to E-4): the
  /// same record, but for the moves, which the tool reports by instance.
  /// Rebuilt only when the host's record is a new one, so a hover's read
  /// allocates nothing.
  ServiceEvents<Handle> _toolEvents() {
    final host = widget.events();
    if (!identical(host, _hostEvents)) {
      _hostEvents = host;
      _events = (
        onTablesMoved: host.onTablesMoved == null ? null : _moved,
        onTableDoubleTap: host.onTableDoubleTap,
        onFloorTap: host.onFloorTap,
        onTableHover: host.onTableHover,
      );
    }
    return _events;
  }

  ServiceEvents<FloorPlanTableDetail>? _hostEvents;
  ServiceEvents<Handle> _events = kNoServiceEvents;

  /// Spec E-1: the moved instances as the controller's fresh details,
  /// ascending by handle, numbered or not. Nothing when this copy is no
  /// longer the plan shown (the host's `onLayoutChanged` replaced it).
  void _moved(List<Handle> instances) {
    final report = widget.events().onTablesMoved;
    if (report == null || !identical(_c.activeDocument, _document)) return;
    final details = _c.tableDetails;
    final at = <Handle, int>{
      for (final (i, h) in _c.tableDetailInstances.indexed) h: i
    };
    report(List.unmodifiable([
      for (final h in instances)
        if (at[h] case final i?) details[i]
    ]));
  }

  /// The canvas, whose origin is the interaction layer's (no rulers).
  final GlobalKey _canvas = GlobalKey();

  Offset _toGlobal(Offset local) {
    final box = _canvas.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box.localToGlobal(local) : local;
  }

  // Spec 14d S6: a secondary click on a table. The interaction layer never
  // sees a press without the primary button (V-1), so the view listens.
  int? _secondary;
  Offset _secondaryAt = Offset.zero;

  static bool _isPrecise(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ||
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  void _onSecondaryDown(PointerDownEvent e) {
    // A secondary click on an interactive overlay is the overlay's
    // (host embedding API spec G-5).
    if (InputClaim.claimed(e) ||
        !_isPrecise(e.kind) ||
        e.buttons & kSecondaryButton == 0 ||
        _tool.phase != ToolPhase.idle) {
      return;
    }
    _secondary = e.pointer;
    _secondaryAt = e.localPosition;
  }

  void _onSecondaryUp(PointerUpEvent e) {
    if (e.pointer != _secondary) return;
    _secondary = null;
    if ((e.localPosition - _secondaryAt).distance > kTouchSlop) return;
    final report = widget.options().onTableContextMenu;
    // A host without a menu: a right click is nothing, as before 14d; the
    // selection rule exists for the menu's sake (review F-2).
    if (report == null) return;
    final world = _c.cameraController.value
        .screenToWorld(Vector2(e.localPosition.dx, e.localPosition.dy));
    final hit = _picker.pick(world);
    if (hit == null) return;
    final number =
        contextSelect(hit, _selection, group: _tool.groupKeysOf(hit));
    if (number != null) report(number, e.position);
  }

  void _onSecondaryCancel(PointerCancelEvent e) {
    if (e.pointer == _secondary) _secondary = null;
  }

  late final ToolController _tools = ToolController(
      initial: _tool,
      context: ToolContext(
          document: _document,
          index: _index,
          camera: _c.cameraController,
          selection: _selection));
  final GesturePolicy _policy = GesturePolicy.forPlatform();

  // The copy's own systems, as the shell installs the design's (R-4): a
  // 14c move regenerates and re-stamps as in the design mode. Last in,
  // first out.
  late final ParametricSystem _parametric = installParametric(_document);
  late final TableLabelSystem _tableLabels = TableLabelSystem(_document)
    ..install();

  /// ACI 7's foreground follows the paper, as in the shell (fix/post-07,
  /// dark theme spec D4), and on a dark canvas every colour is re-toned
  /// (dark canvas decision note K3): re-derived in [_onPage] and
  /// [didChangeDependencies], replaced only when its key ([_foreground],
  /// [_darkCanvas]) changes. Assigned in the first [didChangeDependencies]:
  /// without a page it reads the theme, which `initState` cannot.
  late StyleResolver _resolver;

  /// [_resolver]'s key; -1 until the first [didChangeDependencies].
  int _foreground = -1;
  bool _darkCanvas = false;

  /// The theme's surface, ARGB: the paper with no page (D4), or the host's
  /// `canvasBackground` in its place (host embedding API spec T-1). Set in
  /// [didChangeDependencies], the only place this state reads the theme for
  /// the paper.
  late int _surfaceArgb;

  /// The theme's brightness (decision note K1). Set in
  /// [didChangeDependencies].
  late Brightness _brightness;

  /// The paper under the status captions, ARGB (dark theme spec D6c): set
  /// to [_paperArgb] in [didChangeDependencies] and [_onPage]. Created with
  /// the state, so it exists before the status painter, a `late final`
  /// built at the first `build`, reads it; its first value is replaced in
  /// the first [didChangeDependencies], which runs before that `build`.
  final ValueNotifier<int> _paper = ValueNotifier<int>(0xFFFFFFFF);

  /// The resolved look (host embedding API spec T-2, T-3): set from the
  /// scope above in [didChangeDependencies]; it notifies only when the
  /// theme is a different value. Null: today's look.
  final ValueNotifier<FloorPlanTheme?> _theme =
      ValueNotifier<FloorPlanTheme?>(null);

  // Spec 14c S7: the status layer repaints on the camera, the statuses and
  // every change of this copy (a move, an undo, a redo; R-4), and (dark
  // theme D6c, F-16) on the paper, which a theme switch with no page
  // changes with no document change. Table-groups spec G3: and on the
  // groups and their statuses. Host embedding API spec T-3: and on the
  // resolved theme, which joins every painter's rebuild key.
  final _Bump _changed = _Bump();
  StreamSubscription<DocChange>? _changes;
  late final TableStatusPainter _statusPainter = TableStatusPainter(
    document: _document,
    camera: _c.cameraController,
    statuses: _c.tableStatuses,
    tableGroups: _c.tableGroups,
    groupStatuses: _c.groupStatuses,
    paper: _paper,
    theme: _theme,
    repaint: Listenable.merge([
      _c.cameraController,
      _c.tableStatuses,
      _c.tableGroups,
      _c.groupStatuses,
      _changed,
      _paper,
      _theme
    ]),
  );

  // Table-groups spec G3: the group frames (under the status fills) and
  // label chips (above the drafting) repaint on the camera, the groups,
  // every change of this copy, the paper and the theme; zone spec Z14: and
  // on the focus, which fades a group with no focused member.
  late final Listenable _groupRepaint = Listenable.merge([
    _c.cameraController,
    _c.tableGroups,
    _c.tableFocus,
    _changed,
    _paper,
    _theme
  ]);
  late final TableGroupPainter _framePainter =
      _groupPainter(TableGroupLayer.frames);
  late final TableGroupPainter _chipPainter =
      _groupPainter(TableGroupLayer.chips);

  TableGroupPainter _groupPainter(TableGroupLayer layer) => TableGroupPainter(
        layer: layer,
        document: _document,
        picker: _picker,
        camera: _c.cameraController,
        groups: _c.tableGroups,
        paper: _paper,
        tableFocus: _c.tableFocus,
        theme: _theme,
        repaint: _groupRepaint,
      );

  // Zone spec Z11, Z13, Z16: the veil over the tables outside the host's
  // focus, above the drafting and under the chips; it repaints on the
  // camera, the focus, every change of this copy, the paper and the theme.
  late final TableFocusPainter _focusPainter = TableFocusPainter(
    document: _document,
    camera: _c.cameraController,
    focus: _c.tableFocus,
    paper: _paper,
    theme: _theme,
    repaint: Listenable.merge(
        [_c.cameraController, _c.tableFocus, _changed, _paper, _theme]),
  );

  /// The bar height the last build laid out; null before the first.
  double? _barHeight;

  /// Whether a [ServiceView.onCanvasMoved] call is due after this frame.
  bool _canvasMoveDue = false;

  /// The bar's height (spec T-1): the theme's, else [kServiceBarHeight].
  /// After the first frame laid out with another height than the last, the
  /// view is told the canvas moved, once (S-10). Read only while the bar is
  /// shown (spec C-1): a hidden bar has no height.
  double _barHeightNow() {
    final height = _theme.value?.serviceBarHeight ?? kServiceBarHeight;
    final last = _barHeight;
    _barHeight = height;
    if (last != null && last != height && !_canvasMoveDue) {
      _canvasMoveDue = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _canvasMoveDue = false;
        if (mounted) widget.onCanvasMoved?.call();
      });
    }
    return height;
  }

  /// Export and Print need a page, as the shell's do (R-5, review F-4).
  late final DerivedFlag _pageReady = DerivedFlag([widget.flows.ready, _page],
      () => widget.flows.ready.value && _page.value != null);

  /// Table-groups spec G5: Split follows the selection **and** the groups.
  /// `selectedGroup` updates after `selectedTables` and `tableGroups` have
  /// notified, so the flag listens to all three: one that missed
  /// `selectedGroup` would compute before it moved and stay stale. (Merge
  /// reads `mergeCandidate`, which updates with `selectedGroup`.)
  late final List<Listenable> _groupSources = [
    _c.selectedTables,
    _c.tableGroups,
    _c.selectedGroup
  ];

  /// Merge: the selected numbers span two or more units (G5), which the
  /// controller's `mergeCandidate` says (spec C-3): one source for the
  /// button and a host's own bar.
  late final DerivedFlag _canMerge =
      DerivedFlag([_c.mergeCandidate], () => _c.mergeCandidate.value != null);

  /// Split: the selection is exactly one group (G5, `selectedGroup`).
  late final DerivedFlag _canSplit =
      DerivedFlag(_groupSources, () => _c.selectedGroup.value != null);

  /// The paper (D4, dark canvas K1–K2): [kDarkCanvasPaper] on a dark
  /// canvas, else the page's background, or with no page the theme's
  /// surface, which the drafting then lies on. It feeds ACI 7's foreground,
  /// [PaperPalette.forPaper], the sheet's fill and the status captions.
  int _paperArgb() => displayPaperFor(
      page: _page.value?.background,
      surface: _surfaceArgb,
      brightness: _brightness);

  /// A new resolver when the key moved, else null; records the new key.
  StyleResolver? _nextResolver() {
    final paper = _paperArgb();
    final foreground = foregroundFor(paper);
    final dark =
        darkCanvasFor(page: _page.value?.background, brightness: _brightness);
    if (foreground == _foreground && dark == _darkCanvas) return null;
    _foreground = foreground;
    _darkCanvas = dark;
    return canvasResolverFor(_document, paper: paper, dark: dark);
  }

  /// A key change rebuilds, which also hands the view the new paper palette
  /// and sheet fill: they switch at exactly the paper where the key does.
  ///
  /// The status captions' paper is set on every page change, a key change
  /// or not: a status colour over the paper can flip where the paper alone
  /// does not (D6c).
  void _onPage() {
    _paper.value = _paperArgb();
    final next = _nextResolver();
    if (next == null) return;
    setState(() => _resolver = next);
  }

  /// The canvas around the page and a page-less plan's paper: the host's
  /// `canvasBackground`, else the theme's surface (spec T-1).
  Color _canvasColour(ColorScheme scheme) =>
      _theme.value?.canvasBackground ?? scheme.surface;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _theme.value = FloorPlanThemeScope.of(context);
    _surfaceArgb = _canvasColour(theme.colorScheme).toARGB32();
    _brightness = theme.brightness;
    _paper.value = _paperArgb();
    // A `build` follows: only a key change builds a new resolver.
    if (_nextResolver() case final next?) _resolver = next;
  }

  @override
  void initState() {
    super.initState();
    _parametric;
    _tableLabels;
    // Built now, so dispose never builds one over a controller in teardown.
    _canMerge;
    _canSplit;
    _page.addListener(_onPage);
    _changes = _document.changes.listen((_) => _changed.bump());
  }

  @override
  void dispose() {
    _page.removeListener(_onPage);
    _changes?.cancel();
    _changed.dispose();
    _paper.dispose();
    _theme.dispose();
    _pageReady.dispose();
    _canMerge.dispose();
    _canSplit.dispose();
    _tools.dispose();
    _tool.dispose();
    _outlines.dispose();
    _tableLabels.dispose();
    _parametric.dispose();
    _index.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = FloorPlanStrings.of(context);
    final flows = widget.flows;
    // Read here, so a host that rebuilds `FloorPlanView` with a callback
    // added or dropped shows or hides its button (G5); a press reads them
    // again (14c R-5).
    final callbacks = widget.callbacks();
    // Host embedding API spec C-7, S-16: without the shortcuts no chord is
    // bound, so every key reaches the host.
    final keys = widget.shortcuts;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (keys)
          for (final chord in kUndoChords) chord: _c.undo,
        if (keys)
          for (final chord in kRedoChords) chord: _c.redo,
        if (keys && flows.canExport)
          for (final chord in kExportChords) chord: () => flows.export(context),
        if (keys)
          for (final chord in kPrintChords) chord: () => flows.print(context),
      },
      child: Focus(
        autofocus: widget.autofocus,
        child: Column(
          children: [
            // Host embedding API spec C-1: with `visible: false` no bar, and
            // the canvas takes its height.
            if (widget.bar.visible)
              _bar(widget.bar, scheme, strings, flows, callbacks),
            Expanded(
              child: ColoredBox(
                color: _canvasColour(scheme),
                child: Listener(
                  key: _canvas,
                  onPointerDown: _onSecondaryDown,
                  onPointerUp: _onSecondaryUp,
                  onPointerCancel: _onSecondaryCancel,
                  child: PlannerView(
                    document: _document,
                    index: _index,
                    resolver: _resolver,
                    camera: _c.cameraController,
                    page: _page,
                    policy: _policy,
                    selection: _selection,
                    tools: _tools,
                    outlines: _outlines,
                    // Dark theme spec D5: the chrome (here the sheet edge)
                    // follows the theme, the overlays the paper.
                    chrome: ChromePalette.of(theme.brightness),
                    // Host embedding API spec T-1: the host's selection
                    // colour for the paper's set, its width.
                    paper: paperPaletteFor(_paperArgb(), _theme.value),
                    selectionStrokePixels:
                        _theme.value?.selectionWidth ?? kSelectionStrokePixels,
                    sheetArgb: _darkCanvas ? _paperArgb() : null,
                    fitRequests: _c.fitRequests,
                    fitOnStart: _fitOnStart,
                    startFitIsRequest: _startFitIsRequest,
                    onFitted: _c.fitted,
                    framing: _c.framingFor,
                    cameraEpoch: () => _c.cameraEpoch,
                    userCamera: widget.userCamera(),
                    onCanvasPlaced: _c.canvasPlaced,
                    // The service shows the plan, not the drafting aids.
                    rulers: false,
                    grid: false,
                    autofocus: widget.autofocus,
                    // Table-groups spec G3: the frames under the status fills.
                    underlay: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            key: const Key('table-group-layer'),
                            painter: _framePainter,
                            size: Size.infinite,
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            key: const Key('table-status-layer'),
                            painter: _statusPainter,
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                    tableOverlays: widget.tableOverlays,
                    // Above the drafting: the focus's veil (zone spec Z13),
                    // then the label chips (G3, F-11).
                    overlay: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            key: const Key('table-focus-layer'),
                            painter: _focusPainter,
                            size: Size.infinite,
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            key: const Key('table-group-chips'),
                            painter: _chipPainter,
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The bar (spec C-1): the host's [FloorPlanServiceBar.leading], the
  /// actions in the host's order under today's rules (Merge and Split each
  /// only with its callback, G5; Export only with `onExport`), 8 px
  /// between two shown actions of different groups, then the host's
  /// [FloorPlanServiceBar.trailing]. The default is today's row exactly.
  /// The host's widgets sit under a [ShellShortcutGuard] (S-19): a host
  /// field there takes its keystrokes, and Undo's and Redo's chords do not
  /// reach the plan from it.
  Widget _bar(FloorPlanServiceBar bar, ColorScheme scheme,
      FloorPlanStrings strings, PageFlows flows, ServiceCallbacks callbacks) {
    final row = Row(
      children: [
        ...bar.leading,
        ..._actions(bar.actions, strings, flows, callbacks),
        ...bar.trailing,
      ],
    );
    return Container(
      key: const Key('service-bar'),
      height: _barHeightNow(),
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: bar.leading.isEmpty && bar.trailing.isEmpty
          ? row
          : ShellShortcutGuard(child: row),
    );
  }

  /// [actions]' buttons in their order, each shown under today's rule, an
  /// 8 px gap where a shown button's group differs from the last shown
  /// one's (the history; the groups; the page).
  List<Widget> _actions(List<FloorPlanServiceAction> actions,
      FloorPlanStrings strings, PageFlows flows, ServiceCallbacks callbacks) {
    final children = <Widget>[];
    int? lastGroup;
    for (final action in actions) {
      final button = switch (action) {
        FloorPlanServiceAction.undo => _button(
            'service-undo', strings.undo, Icons.undo, _c.canUndo, _c.undo),
        FloorPlanServiceAction.redo => _button(
            'service-redo', strings.redo, Icons.redo, _c.canRedo, _c.redo),
        // Table-groups spec G5: each shown only when the host passed its
        // callback; disabled when the selection does not qualify.
        FloorPlanServiceAction.merge => callbacks.onMergeRequested == null
            ? null
            : _button('service-merge', strings.merge, Icons.merge_type,
                _canMerge, _merge),
        FloorPlanServiceAction.split => callbacks.onSplitRequested == null
            ? null
            : _button('service-split', strings.split, Icons.call_split,
                _canSplit, _split),
        FloorPlanServiceAction.export => flows.canExport
            ? _button(
                'service-export',
                strings.exportEllipsis,
                Icons.ios_share_outlined,
                _pageReady,
                () => flows.export(context))
            : null,
        FloorPlanServiceAction.print => _button(
            'service-print',
            strings.printEllipsis,
            Icons.print_outlined,
            _pageReady,
            () => flows.print(context)),
      };
      if (button == null) continue;
      final group = switch (action) {
        FloorPlanServiceAction.undo || FloorPlanServiceAction.redo => 0,
        FloorPlanServiceAction.merge || FloorPlanServiceAction.split => 1,
        FloorPlanServiceAction.export || FloorPlanServiceAction.print => 2,
      };
      if (lastGroup != null && group != lastGroup) {
        children.add(const SizedBox(width: 8));
      }
      lastGroup = group;
      children.add(button);
    }
    return children;
  }

  /// Exactly the selected numbers: the host decides what a selection
  /// spanning a group means (G5).
  void _merge() =>
      widget.callbacks().onMergeRequested?.call(_c.selectedTables.value);

  void _split() {
    final id = _c.selectedGroup.value;
    if (id != null) widget.callbacks().onSplitRequested?.call(id);
  }

  Widget _button(String key, String tooltip, IconData icon,
          ValueListenable<bool> enabled, VoidCallback onPressed) =>
      ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (_, on, __) => IconButton(
          key: Key(key),
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: on ? onPressed : null,
        ),
      );
}

/// A notifier whose every [bump] is one notification.
final class _Bump extends ChangeNotifier {
  void bump() => notifyListeners();
}
