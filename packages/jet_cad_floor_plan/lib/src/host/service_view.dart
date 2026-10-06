// The selection mode's view (spec 14b-2 H7): the canvas alone, over the
// controller's service copy, under `runtime` permissions -- rulers, page
// chrome, the drafting and the selection outlines -- with Undo, Redo,
// Export and Print. No palette, no panels, no grips, and nothing that needs
// `geometry` or `structure` (umbrella D11). 14c's table tool picks,
// selects and moves tables.

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryButton, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../parametric/catalog.dart';
import '../planner_view.dart';
import '../service/table_picker.dart';
import '../service/table_select_tool.dart';
import '../service/table_status_painter.dart';
import '../shell_commands.dart';
import '../tables/table_label_system.dart';
import 'floor_plan_controller.dart';
import 'page_flows.dart';

/// The canvas over [controller]'s service copy (H7). Built per copy: the
/// view is keyed by it, so a [FloorPlanController.resetLayout] or a load
/// builds a new one.
class ServiceView extends StatefulWidget {
  const ServiceView(
      {super.key,
      required this.controller,
      required this.flows,
      required this.fitOnStart,
      required this.callbacks,
      this.options = _defaultOptions});

  final FloorPlanController controller;
  final PageFlows flows;

  /// Whether the camera fits after the first frame (R-13).
  final bool fitOnStart;

  /// The host's callbacks, read at each call (14c R-5).
  final ServiceCallbacks Function() callbacks;

  /// The host's service options, read at each press (spec 14d S5-S7).
  final ServiceOptions Function() options;

  static ServiceOptions _defaultOptions() => kDefaultServiceOptions;

  @override
  State<ServiceView> createState() => _ServiceViewState();
}

class _ServiceViewState extends State<ServiceView> {
  late final FloorPlanController _c = widget.controller;
  late final DraftDocument _document = _c.activeDocument;
  late final SelectionController _selection = _c.activeSelection;
  late final bool _fitOnStart = widget.fitOnStart;
  late final SpatialIndex _index = SpatialIndex(_document);
  late final PageNotifier _page = PageNotifier(_document);
  late final OutlineCache _outlines = OutlineCache(_document, _selection);
  // Spec 14c S3: the table tool, over this copy's tables.
  late final TablePicker _picker = TablePicker(_document);
  late final TableSelectTool _tool = TableSelectTool(
      picker: _picker,
      callbacks: widget.callbacks,
      options: widget.options,
      toGlobal: _toGlobal);

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
    if (!_isPrecise(e.kind) ||
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
    final world = _c.camera.value
        .screenToWorld(Vector2(e.localPosition.dx, e.localPosition.dy));
    final hit = _picker.pick(world);
    if (hit == null) return;
    final number = contextSelect(hit, _selection);
    if (number != null) report?.call(number, e.position);
  }

  void _onSecondaryCancel(PointerCancelEvent e) {
    if (e.pointer == _secondary) _secondary = null;
  }

  late final ToolController _tools = ToolController(
      initial: _tool,
      context: ToolContext(
          document: _document,
          index: _index,
          camera: _c.camera,
          selection: _selection));
  final GesturePolicy _policy = GesturePolicy.forPlatform();

  // The copy's own systems, as the shell installs the design's (R-4): a
  // 14c move regenerates and re-stamps as in the design mode. Last in,
  // first out.
  late final ParametricSystem _parametric = installParametric(_document);
  late final TableLabelSystem _tableLabels = TableLabelSystem(_document)
    ..install();

  late DocumentStyleResolver _resolver = _resolverFor(_page.value);

  // Spec 14c S7: the status layer repaints on the camera, the statuses and
  // every change of this copy (a move, an undo, a redo; R-4).
  final _Bump _changed = _Bump();
  StreamSubscription<DocChange>? _changes;
  late final TableStatusPainter _statusPainter = TableStatusPainter(
    document: _document,
    camera: _c.camera,
    statuses: _c.tableStatuses,
    repaint: Listenable.merge([_c.camera, _c.tableStatuses, _changed]),
  );

  /// Export and Print need a page, as the shell's do (R-5, review F-4).
  late final DerivedFlag _pageReady = DerivedFlag([widget.flows.ready, _page],
      () => widget.flows.ready.value && _page.value != null);

  DocumentStyleResolver _resolverFor(PageComponent? page) =>
      DocumentStyleResolver(_document,
          foreground: foregroundFor(page?.background ?? 0xFFFFFFFF));

  void _onPage() {
    final next = foregroundFor(_page.value?.background ?? 0xFFFFFFFF);
    if (next == _resolver.foreground) return;
    setState(() => _resolver = _resolverFor(_page.value));
  }

  @override
  void initState() {
    super.initState();
    _parametric;
    _tableLabels;
    _page.addListener(_onPage);
    _changes = _document.changes.listen((_) => _changed.bump());
  }

  @override
  void dispose() {
    _page.removeListener(_onPage);
    _changes?.cancel();
    _changed.dispose();
    _pageReady.dispose();
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
    final scheme = Theme.of(context).colorScheme;
    final flows = widget.flows;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        for (final chord in kUndoChords) chord: _c.undo,
        for (final chord in kRedoChords) chord: _c.redo,
        if (flows.canExport)
          for (final chord in kExportChords) chord: () => flows.export(context),
        for (final chord in kPrintChords) chord: () => flows.print(context),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Container(
              key: const Key('service-bar'),
              height: 44,
              color: scheme.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _button(
                      'service-undo', 'Undo', Icons.undo, _c.canUndo, _c.undo),
                  _button(
                      'service-redo', 'Redo', Icons.redo, _c.canRedo, _c.redo),
                  const SizedBox(width: 8),
                  if (flows.canExport)
                    _button(
                        'service-export',
                        'Export…',
                        Icons.ios_share_outlined,
                        _pageReady,
                        () => flows.export(context)),
                  _button('service-print', 'Print…', Icons.print_outlined,
                      _pageReady, () => flows.print(context)),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: scheme.surface,
                child: Listener(
                  key: _canvas,
                  onPointerDown: _onSecondaryDown,
                  onPointerUp: _onSecondaryUp,
                  onPointerCancel: _onSecondaryCancel,
                  child: PlannerView(
                    document: _document,
                    index: _index,
                    resolver: _resolver,
                    camera: _c.camera,
                    page: _page,
                    policy: _policy,
                    selection: _selection,
                    tools: _tools,
                    outlines: _outlines,
                    fitRequests: _c.fitRequests,
                    fitOnStart: _fitOnStart,
                    onFitted: _c.fitted,
                    // The service shows the plan, not the drafting aids.
                    rulers: false,
                    grid: false,
                    underlay: RepaintBoundary(
                      child: CustomPaint(
                        key: const Key('table-status-layer'),
                        painter: _statusPainter,
                        size: Size.infinite,
                      ),
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
