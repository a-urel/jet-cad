import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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

/// Owns the document, the index and the camera for the window's lifetime,
/// and lays out the chrome slots -- a top bar, a left panel and a right
/// panel, sized and empty -- so sub-projects 04, 05 and 12 add to a layout
/// rather than invent one.
class PlannerShell extends StatefulWidget {
  const PlannerShell({super.key});

  @override
  State<PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends State<PlannerShell> {
  final FlutterTextMeasurer _measurer = FlutterTextMeasurer();
  late final DraftDocument _document = startupPlan(_measurer);
  late final SpatialIndex _index = SpatialIndex(_document);
  // Fitted to the nominal window; PlannerView re-fits once at the real size.
  late final CameraController _camera = CameraController(
    ViewportTransform.fit(_document.extents, const Size(1440, 900)),
    minScale: kMinScale,
    maxScale: kMaxScale,
  );
  final GesturePolicy _policy = GesturePolicy.forPlatform();

  // Constructed before the tool controller and its context: the selection
  // controller's listener on `document.changes` must prune dead keys before
  // anything downstream (the outline cache, in PlannerView) walks them.
  late final SelectionController _selection = SelectionController(_document);
  late final ToolContext _context = ToolContext(
      document: _document,
      index: _index,
      camera: _camera,
      selection: _selection);
  late final ToolController _tools =
      ToolController(initial: SelectTool(), context: _context);
  late final Listenable _status = Listenable.merge([_selection, _tools]);

  String _statusLine() {
    final base = _tools.active.name;
    return _selection.isEmpty ? base : '$base — ${_selection.length} selected';
  }

  @override
  void dispose() {
    _tools.dispose();
    _selection.dispose();
    _camera.dispose();
    _index.dispose();
    _measurer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Container(
            key: const Key('chrome-top'),
            height: 44,
            color: scheme.surfaceContainer,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListenableBuilder(
                  listenable: _status,
                  builder: (_, __) =>
                      Text(_statusLine(), key: const Key('status-text')),
                ),
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
                      policy: _policy,
                      selection: _selection,
                      tools: _tools,
                    ),
                  ),
                ),
                Container(
                  key: const Key('chrome-right'),
                  width: 280,
                  color: scheme.surfaceContainerLow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
