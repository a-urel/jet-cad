// The selection mode's view (spec 14b-2 H7): the canvas alone, over the
// controller's service copy, under `runtime` permissions -- rulers, page
// chrome, the drafting and the selection outlines -- with Undo, Redo,
// Export and Print. No palette, no panels, no grips, and nothing that needs
// `geometry` or `structure` (umbrella D11). 14c's table tool picks,
// selects and moves tables.

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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
      required this.callbacks});

  final FloorPlanController controller;
  final PageFlows flows;

  /// Whether the camera fits after the first frame (R-13).
  final bool fitOnStart;

  /// The host's callbacks, read at each call (14c R-5).
  final ServiceCallbacks Function() callbacks;

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
  // Table-groups spec G4: a member acts with its group.
  late final TableSelectTool _tool = TableSelectTool(
      picker: _picker, groups: _c.tableGroups, callbacks: widget.callbacks);
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

  /// ACI 7's foreground follows the paper, as in the shell (fix/post-07,
  /// dark theme spec D4): re-derived in [_onPage] and
  /// [didChangeDependencies], replaced only when the foreground flips.
  /// Assigned in the first [didChangeDependencies]: without a page it reads
  /// the theme, which `initState` cannot.
  late DocumentStyleResolver _resolver;
  bool _hasResolver = false;

  /// The theme's surface, ARGB: the paper with no page (D4). Set in
  /// [didChangeDependencies], the only place this state reads the theme for
  /// the paper.
  late int _surfaceArgb;

  /// The paper under the status captions, ARGB (dark theme spec D6c): set
  /// to [_paperArgb] in [didChangeDependencies] and [_onPage]. Created with
  /// the state, so it exists before the status painter, a `late final`
  /// built at the first `build`, reads it; its first value is replaced in
  /// the first [didChangeDependencies], which runs before that `build`.
  final ValueNotifier<int> _paper = ValueNotifier<int>(0xFFFFFFFF);

  // Spec 14c S7: the status layer repaints on the camera, the statuses and
  // every change of this copy (a move, an undo, a redo; R-4), and (dark
  // theme D6c, F-16) on the paper, which a theme switch with no page
  // changes with no document change.
  final _Bump _changed = _Bump();
  StreamSubscription<DocChange>? _changes;
  late final TableStatusPainter _statusPainter = TableStatusPainter(
    document: _document,
    camera: _c.camera,
    statuses: _c.tableStatuses,
    paper: _paper,
    repaint: Listenable.merge([_c.camera, _c.tableStatuses, _changed, _paper]),
  );

  /// Export and Print need a page, as the shell's do (R-5, review F-4).
  late final DerivedFlag _pageReady = DerivedFlag([widget.flows.ready, _page],
      () => widget.flows.ready.value && _page.value != null);

  /// The paper (D4): the page's background, or with no page the theme's
  /// surface, which the drafting then lies on. It feeds both ACI 7's
  /// foreground and [PaperPalette.forPaper].
  int _paperArgb() => _page.value?.background ?? _surfaceArgb;

  /// A flip rebuilds, which also hands the view the new paper palette: it
  /// switches at exactly the paper where the foreground does.
  ///
  /// The status captions' paper is set on every page change, flip or not:
  /// a status colour over the paper can flip where the paper alone does
  /// not (D6c).
  void _onPage() {
    _paper.value = _paperArgb();
    final next = foregroundFor(_paperArgb());
    if (next == _resolver.foreground) return;
    setState(
        () => _resolver = DocumentStyleResolver(_document, foreground: next));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _surfaceArgb = Theme.of(context).colorScheme.surface.toARGB32();
    _paper.value = _paperArgb();
    // A `build` follows: only a flip builds a new resolver.
    final next = foregroundFor(_paperArgb());
    if (_hasResolver && next == _resolver.foreground) return;
    _hasResolver = true;
    _resolver = DocumentStyleResolver(_document, foreground: next);
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
    _paper.dispose();
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                  // Dark theme spec D5: the chrome (here the sheet edge)
                  // follows the theme, the overlays the paper.
                  chrome: ChromePalette.of(theme.brightness),
                  paper: PaperPalette.forPaper(_paperArgb()),
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
