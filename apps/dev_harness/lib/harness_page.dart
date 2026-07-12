import 'package:flutter/widgets.dart';
import 'package:jet_cad/jet_cad.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ribbon/cad_ribbon.dart';
import 'ribbon/ribbon_model.dart';
import 'status_bar.dart';

/// Dev harness page: owns the live [CadDocument] / [ViewportController] session
/// and renders the shadcn ribbon + viewport + status bar.
///
/// Public package API only — if something here needs an import from
/// package:jet_cad/src/..., the package surface is wrong.
class HarnessPage extends StatefulWidget {
  const HarnessPage({super.key});

  @override
  State<HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<HarnessPage> {
  CadDocument? _doc;
  ViewportController? _controller;
  String _status = 'starting…';
  Set<EntityId> _selection = const {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final libPath = FfiKernelBridge.locateLibrary();
      if (libPath == null) {
        if (!mounted) return;
        setState(() => _status =
            'native lib not found — run packages/jet_cad/tool/run_harness.sh');
        return;
      }
      final bridge = FfiKernelBridge(libPath);
      final doc =
          await CadDocument.create(bridge, target: const TextureTarget());
      final controller = ViewportController(document: doc);
      controller.selectionChanges.listen((event) {
        if (!mounted) return;
        setState(() => _selection = event.selection);
      });
      // Disposed mid-await: dispose() only frees the stored fields, so the
      // just-created session would leak its native handle. Free it here.
      if (!mounted) {
        controller.dispose();
        doc.dispose();
        return;
      }
      setState(() {
        _doc = doc;
        _controller = controller;
        _status = 'ready';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'FAILED: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(() => _status = 'ready');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '$e');
    }
  }

  List<RibbonTool> _quickActions(
      CadDocument doc, ViewportController controller) {
    return [
      RibbonTool('Undo', LucideIcons.undo2, onPressed: () => _guard(doc.undo)),
      RibbonTool('Redo', LucideIcons.redo2, onPressed: () => _guard(doc.redo)),
      RibbonTool('Fit', LucideIcons.maximize,
          onPressed: () => _guard(controller.fitAll)),
    ];
  }

  /// Stepped viewport-navigation tools for the status bar. Each maps a single
  /// press to a fixed increment of the gesture the viewport already supports.
  List<RibbonTool> _navTools(ViewportController controller) {
    const step = 40.0;
    void orbit(Offset delta) => _guard(() async {
          await controller.orbitStart(Offset.zero);
          await controller.orbitTo(delta);
        });
    return [
      RibbonTool('Zoom out', LucideIcons.zoomOut,
          onPressed: () => _guard(() => controller.zoomBy(0.8))),
      RibbonTool('Zoom in', LucideIcons.zoomIn,
          onPressed: () => _guard(() => controller.zoomBy(1.25))),
      RibbonTool('Rotate CCW', LucideIcons.rotateCcw,
          onPressed: () => orbit(const Offset(-step, 0))),
      RibbonTool('Rotate CW', LucideIcons.rotateCw,
          onPressed: () => orbit(const Offset(step, 0))),
      RibbonTool('Pan left', LucideIcons.arrowLeft,
          onPressed: () =>
              _guard(() => controller.panBy(const Offset(-step, 0)))),
      RibbonTool('Pan up', LucideIcons.arrowUp,
          onPressed: () =>
              _guard(() => controller.panBy(const Offset(0, -step)))),
      RibbonTool('Pan down', LucideIcons.arrowDown,
          onPressed: () =>
              _guard(() => controller.panBy(const Offset(0, step)))),
      RibbonTool('Pan right', LucideIcons.arrowRight,
          onPressed: () =>
              _guard(() => controller.panBy(const Offset(step, 0)))),
    ];
  }

  List<RibbonTab> _tabs(CadDocument doc, ViewportController controller) {
    void addBox() => _guard(() async {
          await doc.makeBox(const Vec3(40, 30, 20));
          await controller.fitAll();
        });
    return [
      const RibbonTab('File', [
        RibbonGroup('Document', [
          RibbonTool('New', LucideIcons.file),
          RibbonTool('Open', LucideIcons.folderOpen),
          RibbonTool('Save', LucideIcons.save),
          RibbonTool('Export', LucideIcons.fileOutput),
        ]),
      ]),
      const RibbonTab('Sketch', [
        RibbonGroup('Draw', [
          RibbonTool('Line', LucideIcons.minus),
          RibbonTool('Rect', LucideIcons.square),
          RibbonTool('Circle', LucideIcons.circle),
          RibbonTool('Arc', LucideIcons.spline),
          RibbonTool('Polygon', LucideIcons.triangle),
        ]),
      ]),
      RibbonTab('Model', [
        RibbonGroup('Primitives', [
          RibbonTool('Box', LucideIcons.box, onPressed: addBox),
          const RibbonTool('Cylinder', LucideIcons.cylinder),
          const RibbonTool('Sphere', LucideIcons.circle),
          const RibbonTool('Cone', LucideIcons.cone),
        ]),
        const RibbonGroup('Features', [
          RibbonTool('Extrude', LucideIcons.layers),
          RibbonTool('Revolve', LucideIcons.rotate3d),
          RibbonTool('Fillet', LucideIcons.spline),
          RibbonTool('Chamfer', LucideIcons.triangle),
          RibbonTool('Shell', LucideIcons.copy),
        ]),
        const RibbonGroup('Boolean', [
          RibbonTool('Union', LucideIcons.plus),
          RibbonTool('Subtract', LucideIcons.minus),
          RibbonTool('Intersect', LucideIcons.copy),
        ]),
      ]),
      const RibbonTab('Modify', [
        RibbonGroup('Transform', [
          RibbonTool('Move', LucideIcons.move),
          RibbonTool('Rotate', LucideIcons.rotate3d),
          RibbonTool('Scale', LucideIcons.scale3d),
          RibbonTool('Mirror', LucideIcons.copy),
        ]),
      ]),
      RibbonTab('View', [
        RibbonGroup('Camera', [
          RibbonTool('Fit', LucideIcons.maximize,
              onPressed: () => _guard(controller.fitAll)),
          const RibbonTool('Isometric', LucideIcons.box),
          const RibbonTool('Front', LucideIcons.square),
          const RibbonTool('Top', LucideIcons.grid3x3),
          const RibbonTool('Wireframe', LucideIcons.grid3x3),
        ]),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final doc = _doc;
    final controller = _controller;

    final Widget body;
    if (doc == null || controller == null) {
      body = Center(
        child: ShadCard(
          width: 360,
          padding: const EdgeInsets.all(16),
          child: Text(_status, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = Column(
        children: [
          CadRibbon(
            tabs: _tabs(doc, controller),
            quickActions: _quickActions(doc, controller),
            initialTab: 'Model',
          ),
          Expanded(child: JetCadViewport(controller: controller)),
          StatusBar(
            status: _status,
            selection: _selection.map((e) => e.value).toList(),
            navTools: _navTools(controller),
          ),
        ],
      );
    }

    return ColoredBox(
      color: theme.colorScheme.background,
      child: SafeArea(child: body),
    );
  }
}
