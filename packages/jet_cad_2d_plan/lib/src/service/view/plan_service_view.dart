// 2b spec S4 ("Widgets", "Events", "Painting", "Permissions") and S5's
// view rows: the service mode's view over the controller's service copy.
// Ported from jet_cad_floor_plan/lib/src/host/service_view.dart (the
// per-copy canvas, :38-717) and host/floor_plan_view.dart (the service
// branch of `_modes`, the events record, the flows, the overlay layer and
// the colour opacity, :509-653, :696-721).
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryButton, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../canvas/plan_canvas_view.dart';
import '../../controller/plan_controller.dart';
import '../../editor/editor_layout.dart';
import '../../export/editor_page_flows.dart';
import '../../export/export_dialog.dart';
import '../../export/page_printer.dart';
import '../../export/registries.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../shortcuts/plan_shortcut_guard.dart';
import '../../theme/plan_theme.dart';
import '../../units/unit_detail.dart';
import '../paint/unit_focus_painter.dart';
import '../paint/unit_group_painter.dart';
import '../paint/unit_status_painter.dart';
import '../service_session.dart';
import '../service_tool.dart';
import 'plan_service_bar.dart';
import 'unit_overlays.dart';

/// The service mode's view over [controller]: the service bar over the
/// canvas of the controller's service copy, with the service tool.
///
/// It follows `controller.mode`: nothing in `PlanMode.design`, the copy's
/// canvas in `PlanMode.service`, built afresh for each new copy (a
/// `resetService`, a `restoreService`, a `load`, a `newPlan`). `PlanEditor`
/// shows it in service; a host may mount it alone and switch with
/// `setMode`.
///
/// The events report units by label: [onUnitTap] for a tap on a labelled
/// unit (a locked one too), then [onGroupTap] for a member of a group;
/// [onUnitDoubleTap], [onUnitContextMenu] (a secondary click, or a long
/// press under [PlanLongPress.contextMenu]), [onUnitHover] (on change; null
/// off every labelled unit), [onFloorTap] (a tap that missed every unit, in
/// world millimetres, y up). [onLayoutChanged] follows each drag, then
/// [onUnitsMoved] with every moved unit's detail, ascending by handle,
/// unlabelled units included; never on undo, redo, a reset or a restore.
/// [onMergeRequested] and [onSplitRequested] are the bar's Merge and Split:
/// the view only asks; the host sets the groups.
///
/// The design permissions do not govern service: drags follow
/// `PlanPermissions.serviceMove`, Merge and Split
/// `PlanPermissions.serviceMerge`, the rest these options.
class PlanServiceView extends StatefulWidget {
  const PlanServiceView({
    super.key,
    required this.controller,
    this.bar = const PlanServiceBar(),
    this.onUnitTap,
    this.onUnitDoubleTap,
    this.onUnitContextMenu,
    this.onGroupTap,
    this.onUnitHover,
    this.onMergeRequested,
    this.onSplitRequested,
    this.onLayoutChanged,
    this.onUnitsMoved,
    this.onFloorTap,
    this.longPress = PlanLongPress.toggleSelection,
    this.floorDrag = PlanFloorDrag.pan,
    this.userCamera = true,
    this.shortcuts = true,
    this.autofocus = true,
    this.unitOverlayBuilder,
    this.unitOverlayLayout = const PlanOverlayLayout(),
    this.unitOverlayModes = const {PlanMode.service},
    this.onExport,
    this.onExportDialog,
    this.onPageFlowError,
    this.printer,
    this.exportName = 'plan',
    this.theme,
    this.serviceSidePanel,
    this.breakpoints = const PlanLayoutBreakpoints(),
    this.layout,
  });

  final PlanController controller;

  /// The host's panel beside the plan in service (orders, a table's detail).
  /// On a desktop layout it is docked on the right, 320 logical pixels wide
  /// (`Key('service-side-panel')`); on a phone or a tablet it opens as a
  /// drawer over the plan from the bar's last button
  /// (`Key('service-right-button')`). Null: no panel and no button.
  ///
  /// The button is in the service bar: with `serviceBar.visible` false on a
  /// phone or a tablet there is no button and the panel cannot be opened (a
  /// host that hides the bar there has no way to open it; keep the bar, or
  /// show its own panel).
  final Widget? serviceSidePanel;

  /// The widths at which the layout changes, as `PlanEditor.breakpoints`.
  final PlanLayoutBreakpoints breakpoints;

  /// Forces one layout whatever the width, as `PlanEditor.layout`.
  final PlanEditorLayout? layout;

  /// The bar, read at each build.
  final PlanServiceBar bar;

  final void Function(String label)? onUnitTap;
  final void Function(String label)? onUnitDoubleTap;
  final void Function(String label, Offset globalPosition)? onUnitContextMenu;
  final void Function(String groupId, String label)? onGroupTap;
  final void Function(String? label)? onUnitHover;
  final void Function(Set<String> labels)? onMergeRequested;
  final void Function(String groupId)? onSplitRequested;
  final VoidCallback? onLayoutChanged;
  final void Function(List<PlanUnitDetail> moved)? onUnitsMoved;
  final void Function(Offset world)? onFloorTap;

  /// What a long press on a unit does, read at each press.
  final PlanLongPress longPress;

  /// What a drag on the floor does, read at each press.
  final PlanFloorDrag floorDrag;

  /// False: no pan, pinch, trackpad or wheel zoom by the user; taps,
  /// selection and moves are unchanged, the controller's camera commands
  /// still act. Read at each build and each press.
  final bool userCamera;

  /// False binds no chord (Undo, Redo, Export, Print) and leaves the
  /// tool's idle Escape to the host; the controller's commands stay
  /// callable.
  final bool shortcuts;

  /// Whether the view takes the focus when it is mounted.
  final bool autofocus;

  /// The host's widget per labelled unit with geometry; null: no layer.
  final PlanUnitOverlayBuilder? unitOverlayBuilder;

  /// Where the overlays sit; validated at build (an [ArgumentError]).
  final PlanOverlayLayout unitOverlayLayout;

  /// The modes that show the overlays: this view shows them when the set
  /// holds `PlanMode.service`.
  final Set<PlanMode> unitOverlayModes;

  /// Receives Export's bytes; without it Export is not offered.
  final void Function(PlanExport export)? onExport;

  /// The host's export dialog, in place of the Material one.
  final PlanExportDialog? onExportDialog;

  /// Where an Export or Print flow's error goes.
  final void Function(Object error)? onPageFlowError;

  /// The platform's print dialog when null.
  final PagePrinter? printer;

  /// Exports are named `<exportName>.<extension>`.
  final String exportName;

  /// A per-view theme over the ambient `PlanTheme`, field by field.
  final PlanTheme? theme;

  @override
  State<PlanServiceView> createState() => _PlanServiceViewState();
}

class _PlanServiceViewState extends State<PlanServiceView> {
  late EditorPageFlows _flows = _flowsFor(widget.controller);

  PlanController get _c => widget.controller;

  /// floor_plan_view.dart:512-535: one per controller; settings and hooks
  /// read from the current widget at each call. In service no design flag
  /// gates the flows (EditorPageFlows reads the mode).
  EditorPageFlows _flowsFor(PlanController c) => EditorPageFlows(
        controller: c,
        settings: () => (
          onExport: widget.onExport,
          printer: widget.printer ?? const PrintingPagePrinter(),
          exportName: widget.exportName,
        ),
        hooks: () => (
          exportDialog: widget.onExportDialog,
          onError: widget.onPageFlowError,
        ),
        unitColourOpacity: _unitColourOpacity,
      );

  /// floor_plan_view.dart:540-546: the ambient extension with the view's
  /// theme over it, else the view's, else the default.
  double _unitColourOpacity() {
    final theme = mounted
        ? (Theme.of(context).extension<PlanTheme>()?.merge(widget.theme) ??
            widget.theme)
        : widget.theme;
    return theme?.unitColourOpacity ?? kUnitColourOpacity;
  }

  @override
  void initState() {
    super.initState();
    _listen(_c);
  }

  void _listen(PlanController c) {
    c.addListener(_onController);
    c.mode.addListener(_onController);
  }

  void _unlisten(PlanController c) {
    c.removeListener(_onController);
    c.mode.removeListener(_onController);
  }

  /// A mode switch, a new copy or new permissions: rebuilt.
  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, _c);
  }

  @override
  void didUpdateWidget(PlanServiceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _unlisten(oldWidget.controller);
      _listen(widget.controller);
      _flows.dispose();
      _flows = _flowsFor(widget.controller);
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  @override
  void dispose() {
    _unlisten(_c);
    _flows.dispose();
    super.dispose();
  }

  /// The overlay layer, made once per widget the host hands in (today's
  /// floor_plan_view.dart:663-669): a host's rebuild builds every overlay
  /// again (G-5), this view's own rebuilds none.
  PlanServiceView? _overlaysOf;
  Widget? _overlays;

  Widget? _overlayLayer() {
    final w = widget;
    if (!identical(w, _overlaysOf)) {
      _overlaysOf = w;
      final builder = w.unitOverlayBuilder;
      _overlays =
          builder == null || !w.unitOverlayModes.contains(PlanMode.service)
              ? null
              : UnitOverlayLayer(
                  controller: w.controller,
                  builder: builder,
                  layout: w.unitOverlayLayout);
    }
    return _overlays;
  }

  /// floor_plan_view.dart:578-593: the events of the current widget, a new
  /// record only for a new widget, so a hover's read allocates nothing.
  PlanServiceView? _eventsOf;
  late ServiceEvents<PlanUnitDetail> _events;

  ServiceEvents<PlanUnitDetail> _serviceEvents() {
    final w = widget;
    if (!identical(w, _eventsOf)) {
      _eventsOf = w;
      _events = (
        onUnitsMoved: w.onUnitsMoved,
        onUnitDoubleTap: w.onUnitDoubleTap,
        onFloorTap: w.onFloorTap,
        onUnitHover: w.onUnitHover,
      );
    }
    return _events;
  }

  /// floor_plan_view.dart:595-602: the fit-on-start answer, once per copy.
  DraftDocument? _fitFor;
  bool _fit = false;
  bool _fitIsRequest = false;

  bool _fitOnStartFor(DraftDocument document) {
    if (!identical(_fitFor, document)) {
      _fitFor = document;
      _fitIsRequest = !_c.owesFirstFit;
      _fit = _c.takeFitOnStart();
    }
    return _fit;
  }

  // The side panel's drawer, open on a phone or a tablet only.
  bool _panelOpen = false;
  PlanEditorLayout? _builtLayout;

  @override
  Widget build(BuildContext context) {
    validatePlanServiceBar(widget.bar);
    if (widget.unitOverlayBuilder != null) {
      validatePlanOverlayLayout(widget.unitOverlayLayout);
    }
    final c = _c;
    final session = c.mode.value == PlanMode.service ? c.serviceSession : null;
    final overlays = _overlayLayer();
    return PlanTextKeys(
      child: PlanThemeScope(
        view: widget.theme,
        child: session == null
            ? _closedPanel()
            : LayoutBuilder(builder: (context, constraints) {
                final layout = widget.layout ??
                    widget.breakpoints.layoutFor(constraints.maxWidth);
                // A layout change closes the drawer, as the editor's does.
                if (layout != _builtLayout) {
                  _builtLayout = layout;
                  _panelOpen = false;
                }
                return _ServiceCanvas(
                  key: ObjectKey(session.document),
                  controller: c,
                  session: session,
                  flows: _flows,
                  fitOnStart: _fitOnStartFor(session.document),
                  startFitIsRequest: _fitIsRequest,
                  callbacks: () => (
                    onUnitTap: widget.onUnitTap,
                    onLayoutChanged: widget.onLayoutChanged,
                    onGroupTap: widget.onGroupTap,
                    onMergeRequested: widget.onMergeRequested,
                    onSplitRequested: widget.onSplitRequested,
                  ),
                  options: () => (
                    longPress: widget.longPress,
                    onUnitContextMenu: widget.onUnitContextMenu,
                    floorDrag: widget.floorDrag,
                  ),
                  userCamera: () => widget.userCamera,
                  events: _serviceEvents,
                  overlays: overlays,
                  bar: widget.bar,
                  shortcuts: widget.shortcuts,
                  autofocus: widget.autofocus,
                  layout: layout,
                  sidePanel: widget.serviceSidePanel,
                  panelOpen: _panelOpen,
                  onTogglePanel: () => setState(() => _panelOpen = !_panelOpen),
                  onClosePanel: () => setState(() => _panelOpen = false),
                );
              }),
      ),
    );
  }

  // Leaving service closes the drawer: it is not open when service returns.
  Widget _closedPanel() {
    _panelOpen = false;
    _builtLayout = null;
    return const SizedBox.shrink();
  }
}

const double _kSidePanelWidth = 320;

/// The canvas over one service copy: today's ServiceView
/// (service_view.dart:38-712), keyed by the copy.
class _ServiceCanvas extends StatefulWidget {
  const _ServiceCanvas({
    super.key,
    required this.controller,
    required this.session,
    required this.flows,
    required this.fitOnStart,
    required this.startFitIsRequest,
    required this.callbacks,
    required this.options,
    required this.userCamera,
    required this.events,
    required this.overlays,
    required this.bar,
    required this.shortcuts,
    required this.autofocus,
    required this.layout,
    required this.sidePanel,
    required this.panelOpen,
    required this.onTogglePanel,
    required this.onClosePanel,
  });

  final PlanController controller;
  final ServiceSession session;
  final EditorPageFlows flows;
  final bool fitOnStart;
  final bool startFitIsRequest;
  final ServiceCallbacks Function() callbacks;
  final ServiceOptions Function() options;
  final bool Function() userCamera;
  final ServiceEvents<PlanUnitDetail> Function() events;
  final Widget? overlays;
  final PlanServiceBar bar;
  final bool shortcuts;
  final bool autofocus;
  final PlanEditorLayout layout;
  final Widget? sidePanel;
  final bool panelOpen;
  final VoidCallback onTogglePanel;
  final VoidCallback onClosePanel;

  @override
  State<_ServiceCanvas> createState() => _ServiceCanvasState();
}

class _ServiceCanvasState extends State<_ServiceCanvas> {
  late final PlanController _c = widget.controller;
  late final ServiceSession _s = widget.session;
  late final DraftDocument _document = _s.document;
  late final bool _fitOnStart = widget.fitOnStart;
  late final bool _startFitIsRequest = widget.startFitIsRequest;
  final GesturePolicy _policy = GesturePolicy.forPlatform();

  /// The host as the copy's tool reads it: the tool lives in the session,
  /// so the view reaches it through `ServiceSession.host`, set when this
  /// canvas mounts and `ServiceHost.none` again when it goes.
  late final ServiceHost _host = ServiceHost(
    callbacks: () => widget.callbacks(),
    options: () => widget.options(),
    userCamera: () => widget.userCamera(),
    toGlobal: _toGlobal,
    events: _toolEvents,
    idleKeys: () => widget.shortcuts,
  );

  /// service_view.dart:148-163: the host's events as the tool reports them,
  /// the moves by instance; rebuilt only for a new host record.
  ServiceEvents<Handle> _toolEvents() {
    final host = widget.events();
    if (!identical(host, _hostEvents)) {
      _hostEvents = host;
      _events = (
        onUnitsMoved: host.onUnitsMoved == null ? null : _moved,
        onUnitDoubleTap: host.onUnitDoubleTap,
        onFloorTap: host.onFloorTap,
        onUnitHover: host.onUnitHover,
      );
    }
    return _events;
  }

  ServiceEvents<PlanUnitDetail>? _hostEvents;
  ServiceEvents<Handle> _events = kNoServiceEvents;

  /// service_view.dart:165-179: the moved instances as the controller's
  /// fresh details, ascending by handle, labelled or not; nothing when this
  /// copy is no longer the plan shown.
  void _moved(List<Handle> instances) {
    final report = widget.events().onUnitsMoved;
    if (report == null || !identical(_c.activeDocument, _document)) return;
    final details = _c.unitDetails;
    final at = <Handle, int>{
      for (final (i, h) in _c.unitDetailInstances.indexed) h: i
    };
    report(List.unmodifiable([
      for (final h in instances)
        if (at[h] case final i?) details[i]
    ]));
  }

  final GlobalKey _canvas = GlobalKey();

  Offset _toGlobal(Offset local) {
    final box = _canvas.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box.localToGlobal(local) : local;
  }

  // service_view.dart:189-231: a secondary click on a unit.
  int? _secondary;
  Offset _secondaryAt = Offset.zero;

  static bool _isPrecise(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ||
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  void _onSecondaryDown(PointerDownEvent e) {
    if (InputClaim.claimed(e) ||
        !_isPrecise(e.kind) ||
        e.buttons & kSecondaryButton == 0 ||
        _s.tool.phase != ToolPhase.idle) {
      return;
    }
    _secondary = e.pointer;
    _secondaryAt = e.localPosition;
  }

  void _onSecondaryUp(PointerUpEvent e) {
    if (e.pointer != _secondary) return;
    _secondary = null;
    if ((e.localPosition - _secondaryAt).distance > kTouchSlop) return;
    final report = widget.options().onUnitContextMenu;
    if (report == null) return;
    final world = _c.camera.value
        .screenToWorld(Vector2(e.localPosition.dx, e.localPosition.dy));
    final hit = _s.tool.picker.pick(world);
    if (hit == null) return;
    final label =
        contextSelect(hit, _s.selection, group: _s.tool.groupKeysOf(hit));
    if (label != null) report(label, e.position);
  }

  void _onSecondaryCancel(PointerCancelEvent e) {
    if (e.pointer == _secondary) _secondary = null;
  }

  // The paper and the resolver: plan_canvas.dart:106-118, :255-278
  // (service_view.dart:247-275, :402-451).
  late StyleResolver _resolver;
  int _foreground = -1;
  bool _darkCanvas = false;
  late int _surfaceArgb;
  late Brightness _brightness;

  /// The paper under the status captions (service_view.dart:269-274).
  final ValueNotifier<int> _paper = ValueNotifier<int>(0xFFFFFFFF);

  /// The resolved theme; notifies only on a different value
  /// (service_view.dart:276-280).
  final ValueNotifier<PlanTheme?> _theme = ValueNotifier<PlanTheme?>(null);

  /// Every change of this copy (service_view.dart:282-289).
  final _Bump _changed = _Bump();
  StreamSubscription<DocChange>? _changes;

  // The painters, mounted as service_view.dart:290-351 mounted today's,
  // over the copy's unit index.
  late final UnitStatusPainter _statusPainter = UnitStatusPainter(
    document: _document,
    units: _s.units,
    camera: _c.camera,
    statuses: _c.unitStatuses,
    unitGroups: _c.unitGroups,
    groupStatuses: _c.groupStatuses,
    paper: _paper,
    theme: _theme,
    darkCanvas: () => _darkCanvas,
    repaint: Listenable.merge([
      _c.camera,
      _c.unitStatuses,
      _c.unitGroups,
      _c.groupStatuses,
      _changed,
      _paper,
      _theme
    ]),
  );

  late final Listenable _groupRepaint = Listenable.merge(
      [_c.camera, _c.unitGroups, _c.unitFocus, _changed, _paper, _theme]);

  late final UnitGroupPainter _framePainter =
      _groupPainter(UnitGroupLayer.frames);
  late final UnitGroupPainter _chipPainter =
      _groupPainter(UnitGroupLayer.chips);

  UnitGroupPainter _groupPainter(UnitGroupLayer layer) => UnitGroupPainter(
        layer: layer,
        document: _document,
        units: _s.units,
        camera: _c.camera,
        groups: _c.unitGroups,
        paper: _paper,
        unitFocus: _c.unitFocus,
        theme: _theme,
        repaint: _groupRepaint,
      );

  late final UnitFocusPainter _focusPainter = UnitFocusPainter(
    document: _document,
    units: _s.units,
    camera: _c.camera,
    focus: _c.unitFocus,
    paper: _paper,
    theme: _theme,
    repaint:
        Listenable.merge([_c.camera, _c.unitFocus, _changed, _paper, _theme]),
  );

  /// Export and Print need a page (service_view.dart:377-379).
  late final _Flag _pageReady = _Flag(
      Listenable.merge([widget.flows.ready, _s.page]),
      () => widget.flows.ready.value && _s.page.value != null);

  /// Merge and Split (service_view.dart:381-400).
  late final _Flag _canMerge =
      _Flag(_c.mergeCandidate, () => _c.mergeCandidate.value != null);
  late final _Flag _canSplit = _Flag(
      Listenable.merge([_c.selectedUnits, _c.unitGroups, _c.selectedGroup]),
      () => _c.selectedGroup.value != null);

  int _paperArgb() => displayPaperFor(
      page: _s.page.value?.background,
      surface: _surfaceArgb,
      brightness: _brightness);

  StyleResolver? _nextResolver() {
    final paper = _paperArgb();
    final foreground = foregroundFor(paper);
    final dark =
        darkCanvasFor(page: _s.page.value?.background, brightness: _brightness);
    if (foreground == _foreground && dark == _darkCanvas) return null;
    _foreground = foreground;
    _darkCanvas = dark;
    return canvasResolverFor(_document, paper: paper, dark: dark);
  }

  void _onPage() {
    _paper.value = _paperArgb();
    final next = _nextResolver();
    if (next == null) return;
    setState(() => _resolver = next);
  }

  Color _canvasColour(ColorScheme scheme) =>
      _theme.value?.canvasBackground ?? scheme.surface;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _theme.value = PlanThemeScope.of(context);
    _surfaceArgb = _canvasColour(theme.colorScheme).toARGB32();
    _brightness = theme.brightness;
    _paper.value = _paperArgb();
    if (_nextResolver() case final next?) _resolver = next;
  }

  @override
  void initState() {
    super.initState();
    _pageReady;
    _canMerge;
    _canSplit;
    _s.page.addListener(_onPage);
    _changes = _document.changes.listen((_) => _changed.bump());
    // Last: nothing above that throws leaves the tool bound to this view.
    _s.host = _host;
  }

  @override
  void dispose() {
    if (identical(_s.host, _host)) _s.host = ServiceHost.none;
    _s.page.removeListener(_onPage);
    _changes?.cancel();
    _changed.dispose();
    _paper.dispose();
    _theme.dispose();
    _pageReady.dispose();
    _canMerge.dispose();
    _canSplit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = PlanStrings.of(context);
    final flows = widget.flows;
    final callbacks = widget.callbacks();
    final keys = widget.shortcuts;
    final paper = _paperArgb();
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
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              if (widget.bar.visible)
                _bar(widget.bar, scheme, strings, flows, callbacks),
              Expanded(child: _body(scheme, _canvasOf(theme, scheme, paper))),
            ],
          ),
        ),
      ),
    );
  }

  /// The canvas, with the host's panel docked beside it (desktop) or as a
  /// drawer over it (phone, tablet); the plan fills what is left.
  Widget _body(ColorScheme scheme, Widget canvas) {
    final panel = widget.sidePanel;
    if (panel == null) return canvas;
    if (widget.layout == PlanEditorLayout.desktop) {
      return Row(
        children: [
          Expanded(child: canvas),
          SizedBox(
            key: const Key('service-side-panel'),
            width: _kSidePanelWidth,
            child: ColoredBox(color: scheme.surfaceContainerLow, child: panel),
          ),
        ],
      );
    }
    return PlanDrawerHost(
      canvas: canvas,
      open: widget.panelOpen ? PlanDrawerSide.right : null,
      onClose: widget.onClosePanel,
      right: KeyedSubtree(key: const Key('service-side-panel'), child: panel),
    );
  }

  Widget _canvasOf(ThemeData theme, ColorScheme scheme, int paper) =>
      ColoredBox(
        color: _canvasColour(scheme),
        child: Listener(
          key: _canvas,
          onPointerDown: _onSecondaryDown,
          onPointerUp: _onSecondaryUp,
          onPointerCancel: _onSecondaryCancel,
          child: PlanCanvasView(
            controller: _c,
            document: _document,
            index: _s.index,
            resolver: _resolver,
            camera: _c.camera,
            page: _s.page,
            policy: _policy,
            selection: _s.selection,
            tools: _s.tools,
            outlines: _s.outlines,
            chrome: ChromePalette.of(theme.brightness),
            paper: planPaperPaletteFor(paper, _theme.value),
            selectionStrokePixels:
                _theme.value?.selectionWidth ?? kSelectionStrokePixels,
            sheetArgb: _darkCanvas ? paper : null,
            fitRequests: _c.fitRequests,
            fitOnStart: _fitOnStart,
            startFitIsRequest: _startFitIsRequest,
            onFitted: _c.fitted,
            framing: _c.framingFor,
            cameraEpoch: () => _c.cameraEpoch,
            userCamera: widget.userCamera(),
            onCanvasPlaced: _c.canvasPlaced,
            rulers: false,
            grid: false,
            autofocus: widget.autofocus,
            // Today's order (spec S4 "Painting"): the group
            // frames, then the colours and statuses, under the
            // drafting; the focus veil, then the chips, above it.
            underlay: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('unit-group-layer'),
                    painter: _framePainter,
                    size: Size.infinite,
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('unit-status-layer'),
                    painter: _statusPainter,
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
            overlay: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('unit-focus-layer'),
                    painter: _focusPainter,
                    size: Size.infinite,
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('unit-group-chips'),
                    painter: _chipPainter,
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
            unitOverlays: widget.overlays,
          ),
        ),
      );

  /// service_view.dart:610-636: the host's leading, the actions, the
  /// host's trailing; the host's widgets under the shortcut guard.
  Widget _bar(PlanServiceBar bar, ColorScheme scheme, PlanStrings strings,
      EditorPageFlows flows, ServiceCallbacks callbacks) {
    final row = Row(
      children: [
        ...bar.leading,
        ..._actions(bar.actions, strings, flows, callbacks),
        ...bar.trailing,
      ],
    );
    final guarded = bar.leading.isEmpty && bar.trailing.isEmpty
        ? row
        : PlanShortcutGuard(controller: _c, child: row);
    // Off the desktop the bar may be wider than the screen: the buttons
    // scroll and the side panel's button stays pinned at the end.
    final compact = widget.layout != PlanEditorLayout.desktop;
    final panelButton = compact && widget.sidePanel != null
        ? ExcludeFocus(
            child: IconButton(
              key: const Key('service-right-button'),
              tooltip: strings.openServicePanel,
              icon: const Icon(Icons.tune),
              isSelected: widget.panelOpen,
              onPressed: widget.onTogglePanel,
            ),
          )
        : null;
    return Container(
      key: const Key('service-bar'),
      height: _theme.value?.serviceBarHeight ?? kServiceBarHeight,
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: !compact
          ? guarded
          : Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: guarded,
                  ),
                ),
                if (panelButton != null) panelButton,
              ],
            ),
    );
  }

  /// service_view.dart:638-689; Merge and Split also need serviceMerge.
  List<Widget> _actions(List<PlanServiceAction> actions, PlanStrings strings,
      EditorPageFlows flows, ServiceCallbacks callbacks) {
    final merges = _c.permissions.serviceMerge;
    final children = <Widget>[];
    int? lastGroup;
    for (final action in actions) {
      final button = switch (action) {
        PlanServiceAction.undo => _button(
            'service-undo', strings.undo, Icons.undo, _c.canUndo, _c.undo),
        PlanServiceAction.redo => _button(
            'service-redo', strings.redo, Icons.redo, _c.canRedo, _c.redo),
        PlanServiceAction.merge => !merges || callbacks.onMergeRequested == null
            ? null
            : _button('service-merge', strings.merge, Icons.merge_type,
                _canMerge, _merge),
        PlanServiceAction.split => !merges || callbacks.onSplitRequested == null
            ? null
            : _button('service-split', strings.split, Icons.call_split,
                _canSplit, _split),
        PlanServiceAction.export => flows.canExport
            ? _button(
                'service-export',
                strings.exportEllipsis,
                Icons.ios_share_outlined,
                _pageReady,
                () => flows.export(context))
            : null,
        PlanServiceAction.print => _button(
            'service-print',
            strings.printEllipsis,
            Icons.print_outlined,
            _pageReady,
            () => flows.print(context)),
      };
      if (button == null) continue;
      final group = switch (action) {
        PlanServiceAction.undo || PlanServiceAction.redo => 0,
        PlanServiceAction.merge || PlanServiceAction.split => 1,
        PlanServiceAction.export || PlanServiceAction.print => 2,
      };
      if (lastGroup != null && group != lastGroup) {
        children.add(const SizedBox(width: 8));
      }
      lastGroup = group;
      children.add(button);
    }
    return children;
  }

  /// Exactly the selected labels: the host decides what a selection
  /// spanning a group means.
  void _merge() =>
      widget.callbacks().onMergeRequested?.call(_c.selectedUnits.value);

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

/// A flag computed from other state (plan_editor.dart's `_Flag`).
final class _Flag extends ChangeNotifier implements ValueListenable<bool> {
  _Flag(this._source, this._compute) {
    _last = _compute();
    _source.addListener(_update);
  }

  final Listenable _source;
  final bool Function() _compute;
  late bool _last;

  @override
  bool get value => _compute();

  void _update() {
    final now = _compute();
    if (now == _last) return;
    _last = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_update);
    super.dispose();
  }
}
