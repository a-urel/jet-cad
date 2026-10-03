// The selection mode's view (spec 14b-2 H7): the canvas alone, over the
// controller's service copy, under `runtime` permissions -- rulers, page
// chrome, the drafting and the selection outlines -- with Undo, Redo,
// Export and Print. No palette, no panels, no grips, and nothing that needs
// `geometry` or `structure` (umbrella D11). 14c adds the table tool.

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../parametric/catalog.dart';
import '../planner_view.dart';
import '../shell_commands.dart';
import '../tables/table_label_system.dart';
import 'floor_plan_controller.dart';
import 'page_flows.dart';

/// A tool that does nothing (H7): the selection mode's pointer acts on the
/// camera only, until 14c's `TableSelectTool`.
class IdleTool extends Tool {
  @override
  String get name => 'Idle';

  @override
  ToolPhase get phase => ToolPhase.idle;

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerExit(ToolContext ctx) {}

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;

  @override
  void cancel(ToolContext ctx) {}

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}
}

/// The canvas over [controller]'s service copy (H7). Built per copy: the
/// view is keyed by it, so a [FloorPlanController.resetLayout] or a load
/// builds a new one.
class ServiceView extends StatefulWidget {
  const ServiceView(
      {super.key,
      required this.controller,
      required this.flows,
      required this.fitOnStart});

  final FloorPlanController controller;
  final PageFlows flows;

  /// Whether the camera fits after the first frame (R-13).
  final bool fitOnStart;

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
  final IdleTool _idle = IdleTool();
  late final ToolController _tools = ToolController(
      initial: _idle,
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
  }

  @override
  void dispose() {
    _page.removeListener(_onPage);
    _pageReady.dispose();
    _tools.dispose();
    _idle.dispose();
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
