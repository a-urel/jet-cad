import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'page_panel.dart';
import 'planner_view.dart';
import 'startup_plan.dart';

void main() => runApp(const FloorPlannerApp());

class FloorPlannerApp extends StatelessWidget {
  const FloorPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Floor planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2266CC)),
        home: const PlannerShell(),
      );
}

/// Owns the document, the index, the camera and -- since 03 -- the outline
/// cache, the grip cache and the snap settings for the window's lifetime.
/// It lays out the chrome slots.
///
/// [document] and [initialCamera] are a test seam (spec 03, Architecture;
/// Ruling 03-18).
/// - [document] replaces the startup plan, and must carry a
///   `FlutterTextMeasurer`.
/// - [initialCamera] replaces the nominal fit.
/// - `PlannerView` still fits once after its first frame, so a test sets a
///   camera of its own after the first pump.
class PlannerShell extends StatefulWidget {
  const PlannerShell({super.key, this.document, this.initialCamera});

  final DraftDocument? document;
  final ViewportTransform? initialCamera;

  @override
  State<PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends State<PlannerShell> {
  final FlutterTextMeasurer _measurer = FlutterTextMeasurer();
  late final DraftDocument _document =
      widget.document ?? startupPlan(_measurer);
  late final PageNotifier _page = PageNotifier(_document);
  late final SpatialIndex _index = SpatialIndex(_document);
  late final CameraController _camera = CameraController(
    widget.initialCamera ?? _nominalFit(),
    minScale: kMinScale,
    maxScale: kMaxScale,
  );
  final GesturePolicy _policy = GesturePolicy.forPlatform();
  final SnapSettings _snap = SnapSettings();

  // Constructed before the tool controller and its context: the selection
  // controller's listener on `document.changes` must prune dead keys before
  // anything downstream (the outline cache, in PlannerView) walks them.
  late final SelectionController _selection = SelectionController(_document);

  // Spec 03 D6, moved from PlannerView. The order is load-bearing.
  // - The outline cache is built after the selection controller, so the
  //   controller prunes a dead key before the cache walks it.
  // - The grip cache is built after the outline cache, so on a selection
  //   change its listener runs after the outlines have been rebuilt.
  late final OutlineCache _outlines = OutlineCache(_document, _selection);
  late final GripCache _grips = GripCache(_document, _selection, _outlines);

  late final ToolContext _context = ToolContext(
      document: _document,
      index: _index,
      camera: _camera,
      selection: _selection,
      page: _page,
      snap: _snap,
      grips: _grips);
  late final ToolController _tools =
      ToolController(initial: SelectTool(), context: _context);
  late final Listenable _status = Listenable.merge([_selection, _tools]);

  /// Fitted to the nominal window; PlannerView re-fits once at the real
  /// size. A document without a page fits its extents.
  ViewportTransform _nominalFit() {
    final page = _page.value;
    return page != null
        ? fitToPage(page, const Size(1440, 900))
        : ViewportTransform.fit(_document.extents, const Size(1440, 900));
  }

  /// Spec D12, amended at execution: cmd+Z (macOS) / ctrl+Z (everywhere
  /// else) undoes through the command log. There is no redo in 02.
  ///
  /// The binding sits above the [InteractionLayer]'s `Focus`, which returns
  /// the active tool's own `KeyEventResult`; the tool ignores Z, so the event
  /// keeps bubbling and arrives here.
  void _undo() {
    if (_document.commands.canUndo) _document.commands.undo();
  }

  String _statusLine() {
    final base = _tools.active.name;
    return _selection.isEmpty ? base : '$base — ${_selection.length} selected';
  }

  String _zoomLine() {
    final page = _page.value;
    if (page == null) return '';
    final zoom = zoomOf(_camera.value.scale, page, kLogicalPixelsPerMm);
    return '1:${_trimNumber(page.scaleDenominator)} · ${(zoom * 100).round()}%';
  }

  static String _trimNumber(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _tools.dispose();
    _grips.dispose();
    _outlines.dispose();
    _selection.dispose();
    _snap.dispose();
    _page.dispose();
    _camera.dispose();
    _index.dispose();
    _measurer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          // Spec 03 D10: one toggle per press, never per key repeat.
          const SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false):
              _snap.toggleObjectSnap,
        },
        child: Column(
          children: [
            Container(
              key: const Key('chrome-top'),
              height: 44,
              color: scheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ListenableBuilder(
                      listenable: _status,
                      builder: (_, __) =>
                          Text(_statusLine(), key: const Key('status-text')),
                    ),
                    const Spacer(),
                    ListenableBuilder(
                      listenable: _snap,
                      builder: (_, __) => Text(
                          _snap.objectSnap ? 'OSNAP' : 'osnap off',
                          key: const Key('osnap-text')),
                    ),
                    const SizedBox(width: 16),
                    ListenableBuilder(
                      listenable: Listenable.merge([_camera, _page]),
                      builder: (_, __) =>
                          Text(_zoomLine(), key: const Key('zoom-text')),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    key: const Key('chrome-left'),
                    width: 240,
                    color: scheme.surfaceContainerLow,
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: scheme.surface,
                      child: PlannerView(
                        document: _document,
                        index: _index,
                        camera: _camera,
                        page: _page,
                        policy: _policy,
                        selection: _selection,
                        tools: _tools,
                        outlines: _outlines,
                        grips: _grips,
                      ),
                    ),
                  ),
                  Container(
                    key: const Key('chrome-right'),
                    width: 280,
                    color: scheme.surfaceContainerLow,
                    child: PagePanel(document: _document, page: _page),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
