### Task 3: `PlacementTool`, the draw fixture, and `LineTool`

Package: `packages/jet_cad_2d_flutter`.

**Files:**
- Create: `lib/src/draw/placement_tool.dart`
- Create: `lib/src/draw/line_tool.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`. Add `export 'src/draw/placement_tool.dart';` and `export 'src/draw/line_tool.dart';`. Check that `select_tool.dart`, `snap_settings.dart` and `grip_cache.dart` are already exported (the app imports them through the barrel today, so they are).
- Create: `test/support/draw_fixture.dart`
- Test: `test/draw/placement_tool_test.dart` (B1–B9), `test/draw/line_tool_test.dart` (L1–L6)

**Interfaces:**
- Consumes:
  - Task 1: `addDrafted`, `addDraftedRegion`, `linePayload`,
    `isDegenerateSegment`.
  - 03: `resolveDragPoint`, `dragGridStepMm`, `kSnapAperturePixels`,
    `DragPoint`, `SnapResult` and `drawSnapMarker`; the style constants
    `kPreviewColor`, `kPreviewStrokePixels`, `kSnapMarkerColor` and
    `kSnapMarkerStrokePixels`.
  - `grip_fixture.dart`: `gripCamera`, `pointerAt`, `screenOf`, `snapshot`.
  - `selection_fixture.dart`: `addEntity`.
- Produces:

  ```dart
  abstract class PlacementTool extends Tool {
    PlacementTool({ValueListenable<bool>? fill});
    final ValueListenable<bool>? fill;
    final List<Vector2> points;
    bool acceptingSelf;                 // true only inside accept(), for a self-snap (Ruling 05-4)
    final Path band;                    // reset per frame, never reallocated (D12)
    final Paint bandPaint;              // preview colour, stroke; width set per frame
    bool get isPending;                 // points.isNotEmpty; TextTool overrides
    Vector2 get hoverPoint;             // the resolved hover, exact
    bool get hoverVisible;
    SnapKind? get hoverKind;
    Vector2? get orthoBase;             // default: points.last, or null
    Vector2? selfSnap(Vector2 raw, double apertureWorld);   // default null
    void accept(Vector2 point, ToolContext ctx);
    void finish(ToolContext ctx);       // default no-op; Enter while pending
    void hovered(Vector2 raw);          // default no-op; every hover's raw world point
    void clearShape();                  // default points.clear()
    void paintRubberBand(Canvas canvas, Vector2 origin, double scale);
    bool commit(ToolContext ctx, DraftCommand Function() build);
    bool commitShape(ToolContext ctx, EntityKind kind, GeometryPayload payload, {bool fillable = false});
  }
  class LineTool extends PlacementTool { LineTool(); }
  ```

  And the fixture, in `test/support/draw_fixture.dart`: `DrawScene`,
  `drawScene({bool snapToGrid = false})`, `DrawRig`,
  `drawRig(DraftDocument doc, PlacementTool tool, {bool flipY = true, bool objectSnap = true})`,
  `worldAt`, `hoverAt`, `clickAt`, `downAt`, `keyDown`,
  `kAnchorStart = (7137.3, 3161.7)`.

- [ ] **Step 1: The fixture.** Create `test/support/draw_fixture.dart`:

```dart
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draw/placement_tool.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/page_notifier.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/snap_settings.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'grip_fixture.dart' show gripCamera, pointerAt;
import 'selection_fixture.dart' show addEntity;

/// The anchor line's start: off every lattice, so a snapped point that went
/// through any arithmetic shows in the low bits (M-05k).
const double kAnchorX = 7137.3, kAnchorY = 3161.7;

final class DrawScene {
  DrawScene._(this.document, this.anchor);
  final DraftDocument document;
  final Handle anchor;
}

/// Spec 05, Testing: a 1:20 page anchored at (7000, 3000), grid snap off
/// unless asked, and one line from ([kAnchorX], [kAnchorY]) to
/// (7300.9, 3190.1). The root stays the identity.
DrawScene drawScene({bool snapToGrid = false}) {
  final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: snapToGrid)));
  final anchor = addEntity(doc, doc.rootHandle, EntityKind.line,
      [kAnchorX, kAnchorY, 7300.9, 3190.1], []);
  doc.commands.clearHistory();
  expect(doc.tree[doc.rootHandle]!.transform.isIdentity, isTrue);
  return DrawScene._(doc, anchor);
}

/// Everything a drawing tool test drives, wired as the shell wires it.
final class DrawRig {
  DrawRig(this.document, this.tool,
      {required this.camera, bool objectSnap = true})
      : index = SpatialIndex(document),
        selection = SelectionController(document) {
    outlines = OutlineCache(document, selection);
    page = PageNotifier(document);
    snap = SnapSettings(objectSnap: objectSnap);
    context = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final PlacementTool tool;
  final CameraController camera;
  final SpatialIndex index;
  final SelectionController selection;
  late final OutlineCache outlines;
  late final PageNotifier page;
  late final SnapSettings snap;
  late final ToolContext context;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    outlines.dispose();
    page.dispose();
    snap.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

/// The standard camera (spec 05, Testing): 03's `gripCamera`, centred on
/// the scene. Every tool test runs it for both [flipY] values.
DrawRig drawRig(DraftDocument doc, PlacementTool tool,
    {bool flipY = true, bool objectSnap = true}) {
  final rig = DrawRig(doc, tool,
      camera: gripCamera(centre: Vector2(7200, 3150), flipY: flipY),
      objectSnap: objectSnap);
  addTearDown(rig.dispose);
  return rig;
}

/// The world point the layer would hand the tool for screen [s].
Vector2 worldAt(DrawRig rig, Offset s) =>
    rig.camera.value.screenToWorld(Vector2(s.dx, s.dy));

void hoverAt(DrawRig rig, Offset s, {bool shift = false}) => rig.tool
    .onPointerMove(pointerAt(rig.camera, s, buttons: 0, shift: shift),
        rig.context);

/// A press with no hover before it (AR4, M-05z).
void downAt(DrawRig rig, Offset s, {bool shift = false}) => rig.tool
    .onPointerDown(pointerAt(rig.camera, s, shift: shift), rig.context);

/// Hover, press, release: what a mouse click delivers.
void clickAt(DrawRig rig, Offset s, {bool shift = false}) {
  hoverAt(rig, s, shift: shift);
  downAt(rig, s, shift: shift);
  rig.tool.onPointerUp(
      pointerAt(rig.camera, s, buttons: 0, shift: shift), rig.context);
}

KeyEventResult keyDown(
        DrawRig rig, LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    rig.tool.onKey(
        KeyDownEvent(
            physicalKey: physical, logicalKey: key, timeStamp: Duration.zero),
        rig.context);
```

  If `analyze` reports an import as unused once Tasks 3–6 are done (for
  example `KeyEventResult`), remove it then. The fixture must stay clean.

- [ ] **Step 2: Write the failing tests.** Create
  `test/draw/placement_tool_test.dart`:

```dart
import 'dart:ui' show Rect, Size;

import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;
import '../support/spy_canvas.dart';

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The newest entity's handle: the tools allocate ascending.
Handle newest(DraftDocument doc) =>
    doc.entities.handleAt(doc.entities.liveSlots.reduce((a, b) =>
        doc.entities.handleAt(a).value > doc.entities.handleAt(b).value
            ? a
            : b));

void main() {
  for (final flipY in const [true, false]) {
    group('flipY $flipY', () {
      test('B1 a point is the layer\'s world point, not the screen (M-05a)',
          () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        final a = screenOf(rig.camera, 7010.5, 3020.25);
        final b = screenOf(rig.camera, 7090.75, 3070.5);
        clickAt(rig, a);
        clickAt(rig, b);
        final p = payloadOf(s.document, newest(s.document));
        final wa = worldAt(rig, a), wb = worldAt(rig, b);
        expect(p.coords.toList(), [wa.x, wa.y, wb.x, wb.y],
            reason: 'exact: the stored values are the resolved points');
      });

      test('B2 a line started near an endpoint begins exactly on it '
          '(exit criterion 3)', () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        clickAt(rig,
            screenOf(rig.camera, kAnchorX, kAnchorY) + const Offset(3, -2));
        clickAt(rig, screenOf(rig.camera, 7050, 3050));
        final p = payloadOf(s.document, newest(s.document));
        expect(p.coords[0], kAnchorX);
        expect(p.coords[1], kAnchorY);
      });

      test('B3 the hover marker is drawn at the snapped point, and nothing '
          'when the raw point wins', () {
        final s = drawScene();
        final rig = drawRig(s.document, LineTool(), flipY: flipY);
        final at = screenOf(rig.camera, kAnchorX, kAnchorY);
        hoverAt(rig, at + const Offset(2, 2));
        final spy = SpyCanvas();
        rig.tool.paintOverlay(spy, rig.camera.value, const Size(800, 600));
        final squares = spy.named('drawRect').toList();
        expect(squares, hasLength(1), reason: 'an endpoint: a square');
        final r = squares.single.args[0] as Rect;
        expect(r.center.dx, closeTo(at.dx, 1e-6));
        expect(r.center.dy, closeTo(at.dy, 1e-6));
        hoverAt(rig, screenOf(rig.camera, 7050, 3050));
        final none = SpyCanvas();
        rig.tool.paintOverlay(none, rig.camera.value, const Size(800, 600));
        expect(none.calls, isEmpty, reason: 'grid off, nothing hit');
      });
    });
  }

  test('B4 Escape mid-shape is byte-identical; an idle Escape is ignored '
      '(M-05m)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    expect(rig.tool.isPending, isTrue);
    expect(
        keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
        KeyEventResult.handled);
    expect(rig.tool.isPending, isFalse);
    expect(snapshot(s.document), before);
    expect(
        keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
        KeyEventResult.ignored,
        reason: 'idle: it bubbles to the shell, which returns to Select');
  });

  test('B5 undo keys are swallowed mid-shape and pass through when idle', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    expect(keyDown(rig, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
        KeyEventResult.ignored);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    expect(keyDown(rig, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
        KeyEventResult.handled);
    expect(
        rig.tool.onKey(
            const KeyUpEvent(
                physicalKey: PhysicalKeyboardKey.keyZ,
                logicalKey: LogicalKeyboardKey.keyZ,
                timeStamp: Duration.zero),
            rig.context),
        KeyEventResult.ignored);
  });

  test('B6 a pan mid-shape re-resolves the hover, and the next click lands '
      'at the new camera\'s point (Review Focus 3)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    final screen = screenOf(rig.camera, 7060, 3040);
    hoverAt(rig, screen);
    final before = Vector2.copy(rig.tool.hoverPoint);
    var notified = 0;
    rig.tool.addListener(() => notified++);
    rig.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(37, -21)
            .multiply(rig.camera.value.worldToScreenMatrix));
    expect(notified, greaterThan(0), reason: 'the camera listener fired');
    expect(rig.tool.hoverPoint, isNot(before));
    downAt(rig, screen);
    final p = payloadOf(s.document, newest(s.document));
    final w = worldAt(rig, screen);
    expect(p.coords[2], w.x);
    expect(p.coords[3], w.y);
  });

  test('B7 shift pins the ortho axis from the last point, and a shift press '
      're-resolves at once', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010.5, 3020.25));
    final first = Vector2.copy(rig.tool.points.last);
    hoverAt(rig, screenOf(rig.camera, 7090, 3031));
    expect(rig.tool.hoverPoint.y, isNot(first.y));
    rig.tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            logicalKey: LogicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero),
        rig.context);
    expect(rig.tool.hoverPoint.y, first.y,
        reason: '|dx| > |dy|: y pinned to the base, exactly');
  });

  test('B8 a denied commit drops the shape and allocates no handle', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    s.document.commands.permissions = DraftPermissions.runtime;
    final seed = s.document.handleSeed.current;
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7090, 3050));
    expect(snapshot(s.document), before);
    expect(s.document.handleSeed.current, seed);
    expect(rig.tool.isPending, isFalse);
  });

  test('B9 a tool switch mid-shape is byte-identical and detaches the '
      'camera; a pointer exit keeps the shape', () {
    final s = drawScene();
    final line = LineTool();
    final rig = drawRig(s.document, line);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    rig.tool.onPointerExit(rig.context);
    expect(line.isPending, isTrue, reason: 'click by click, not a drag');
    expect(line.hoverVisible, isFalse);
    final before = snapshot(s.document);
    rig.tools.activate(SelectTool());
    expect(line.isPending, isFalse);
    expect(snapshot(s.document), before);
    var notified = 0;
    line.addListener(() => notified++);
    rig.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(5, 5)
            .multiply(rig.camera.value.worldToScreenMatrix));
    expect(notified, 0, reason: 'the camera listener is detached');
  });
}
```

  Create `test/draw/line_tool_test.dart`:

```dart
import 'dart:ui' show Path, Rect;

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;
import '../support/spy_canvas.dart';

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> linesOf(DraftDocument doc, Handle anchor) {
  final out = <Handle>[
    for (final slot in doc.entities.liveSlots)
      if (doc.entities.kindAt(slot) == EntityKind.line &&
          doc.entities.handleAt(slot) != anchor)
        doc.entities.handleAt(slot),
  ];
  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

void main() {
  for (final flipY in const [true, false]) {
    test('L1 flipY $flipY: a chain shares its snapped joint exactly (M-05k)',
        () {
      final s = drawScene();
      final rig = drawRig(s.document, LineTool(), flipY: flipY);
      clickAt(rig, screenOf(rig.camera, 7010, 3020));
      clickAt(rig,
          screenOf(rig.camera, kAnchorX, kAnchorY) + const Offset(2, -3));
      clickAt(rig, screenOf(rig.camera, 7090, 3110));
      final lines = linesOf(s.document, s.anchor);
      expect(lines, hasLength(2));
      final first = payloadOf(s.document, lines[0]);
      final second = payloadOf(s.document, lines[1]);
      expect(first.coords[2], kAnchorX);
      expect(first.coords[3], kAnchorY);
      expect(second.coords[0], first.coords[2]);
      expect(second.coords[1], first.coords[3]);
      expect(s.document.commands.undoDepth, 2, reason: 'one per segment');
    });
  }

  test('L2 clicking the current start again ends the chain', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    final end = screenOf(rig.camera, 7090, 3050);
    clickAt(rig, end);
    final depth = s.document.commands.undoDepth;
    clickAt(rig, end + const Offset(1, 1));
    expect(s.document.commands.undoDepth, depth);
    expect(rig.tool.isPending, isFalse);
  });

  test('L3 before the first segment, a second click on the start is refused '
      'and the tool stays pending (M-05x)', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    final start = screenOf(rig.camera, 7010, 3020);
    clickAt(rig, start);
    final before = snapshot(s.document);
    clickAt(rig, start);
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });

  test('L4 Enter ends the chain, the segments stay, and each undo removes '
      'one', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7050, 3060));
    clickAt(rig, screenOf(rig.camera, 7090, 3020));
    keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
    expect(rig.tool.isPending, isFalse);
    expect(linesOf(s.document, s.anchor), hasLength(2));
    s.document.commands.undo();
    expect(linesOf(s.document, s.anchor), hasLength(1));
    s.document.commands.undo();
    expect(linesOf(s.document, s.anchor), isEmpty);
  });

  test('L5 a zero-length segment is refused under Tolerance', () {
    final s = drawScene(snapToGrid: true);
    final rig = drawRig(s.document, LineTool(), objectSnap: false);
    final a = screenOf(rig.camera, 7010.02, 3020.01);
    clickAt(rig, a);
    final before = snapshot(s.document);
    clickAt(rig, a + const Offset(0.5, 0.5)); // same lattice point
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });

  test('L6 the rubber band is one path from the start to the hover', () {
    final s = drawScene();
    final rig = drawRig(s.document, LineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    hoverAt(rig, screenOf(rig.camera, 7090, 3060));
    final origin = Vector2(7000, 3000);
    final spy = SpyCanvas();
    rig.tool.paintWorldOverlay(spy, origin, rig.camera.value.scale);
    final paths = spy.named('drawPath').toList();
    expect(paths, hasLength(1));
    expect(paths.single.color?.toARGB32(), kPreviewColor.toARGB32());
    final bounds = (paths.single.args[0] as Path).getBounds();
    final a = rig.tool.points.single, h = rig.tool.hoverPoint;
    final want = Rect.fromPoints(Offset(a.x - origin.x, a.y - origin.y),
        Offset(h.x - origin.x, h.y - origin.y));
    expect(bounds.left, closeTo(want.left, 1e-3));
    expect(bounds.bottom, closeTo(want.bottom, 1e-3));
  });
}
```

- [ ] **Step 3: Run them and see them fail.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/placement_tool_test.dart test/draw/line_tool_test.dart`
  Expected: compile errors, because `placement_tool.dart` and
  `line_tool.dart` do not exist.

- [ ] **Step 4: Implement `lib/src/draw/placement_tool.dart`.**

```dart
import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Path, Size;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../selection_style.dart';
import '../snap_marker.dart';
import '../tool.dart';
import '../viewport_transform.dart';

/// Spec 05 D3: what every drawing tool shares.
/// - Points resolve through the tool's own placed points first, then 03's
///   `resolveDragPoint` (D4).
/// - The hover marker, and a camera listener while a shape is pending.
/// - Escape, Enter and shift; every other key-down is swallowed mid-shape.
/// - One command per finished shape, checked against the permissions
///   before its handle is allocated (Ruling 05-3).
///
/// Placement is click by click: only a primary press places a point, and a
/// move with the button held is a hover (Ruling 05-13).
abstract class PlacementTool extends Tool {
  PlacementTool({this.fill});

  /// Spec 05 D13: the shell's Fill toggle. Null, or false: outlines only.
  final ValueListenable<bool>? fill;

  /// The placed points, as exact world values (invariant 1).
  final List<Vector2> points = <Vector2>[];

  /// True only while [accept] runs on a self-snap's stored point (Ruling
  /// 05-4).
  bool acceptingSelf = false;

  /// Spec 05 D12: reset each frame, never reallocated.
  final Path band = Path();
  final Paint bandPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;

  final DragPoint _hover = DragPoint();
  final SnapResult _scratch = SnapResult();
  final Paint _markerPaint = Paint()
    ..color = kSnapMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;
  bool _hoverVisible = false;
  Offset _lastScreen = Offset.zero;
  bool _lastShift = false;
  ToolContext? _listening;

  @override
  ToolPhase get phase => ToolPhase.idle;

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  bool get isPending => points.isNotEmpty;
  Vector2 get hoverPoint => _hover.point;
  bool get hoverVisible => _hoverVisible;
  SnapKind? get hoverKind => _hover.objectKind;

  /// Spec 05 D4: the last placed point, or none.
  Vector2? get orthoBase => points.isEmpty ? null : points.last;

  /// A stored placed point this raw point should land on exactly, or null.
  Vector2? selfSnap(Vector2 raw, double apertureWorld) => null;

  void accept(Vector2 point, ToolContext ctx);

  /// Enter while a shape is pending.
  void finish(ToolContext ctx) {}

  /// Every hover's raw world point (the arc tracks it).
  void hovered(Vector2 raw) {}

  void clearShape() => points.clear();

  /// Coordinates handed to [canvas] are `world − origin` (Ruling 03-3).
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale);

  /// Spec 05 D4, in exactly this order: the self-snap wins outright, even
  /// over a nearer entity endpoint; otherwise 03's chain, unchanged.
  /// Returns the self-snap's stored point when one won.
  Vector2? _resolve(ToolContext ctx, Vector2 raw, bool shift) {
    final cam = ctx.camera.value;
    final aperture = kSnapAperturePixels / cam.scale;
    final self = selfSnap(raw, aperture);
    if (self != null) {
      _hover.point.setFrom(self);
      _hover.objectKind = SnapKind.endpoint; // Ruling 05-2
      _hover.grid = false;
      return self;
    }
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: shift ? orthoBase : null,
      index: ctx.index,
      apertureWorld: aperture,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _scratch,
      out: _hover,
    );
    return null;
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _lastShift = e.shift;
    _resolve(ctx, e.world, e.shift);
    _hoverVisible = true;
    hovered(e.world);
    notifyListeners();
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (e.buttons & kPrimaryButton == 0) return;
    _lastScreen = e.screen;
    _lastShift = e.shift;
    // Spec 05 D4: `e.world`, the layer's inverse camera at this event;
    // never `e.screen` (M-05a).
    final self = _resolve(ctx, e.world, e.shift);
    _hoverVisible = true;
    acceptingSelf = self != null;
    try {
      accept(self ?? Vector2.copy(_hover.point), ctx);
    } finally {
      acceptingSelf = false;
    }
    _syncCamera(ctx);
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}

  /// The shape stays: placement is click by click, not a drag.
  @override
  void onPointerExit(ToolContext ctx) {
    _hoverVisible = false;
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    final key = event.logicalKey;
    if ((key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight) &&
        event is! KeyRepeatEvent) {
      _lastShift = event is KeyDownEvent;
      if (_hoverVisible) _reresolve(ctx);
    }
    if (event is KeyUpEvent || !isPending) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape) {
        cancel(ctx);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        finish(ctx);
        _syncCamera(ctx);
        notifyListeners();
        return KeyEventResult.handled;
      }
    }
    // Every other key-down and repeat mid-shape: undo and redo never land
    // on a half-placed shape (spec 05 D3, as 03 D5 during a drag).
    return KeyEventResult.handled;
  }

  /// Every cancel path (Escape, `ToolController.activate`, the layer's
  /// deactivate and dispose) drops the pending shape and never touches the
  /// document (invariant 3).
  @override
  void cancel(ToolContext ctx) {
    clearShape();
    _syncCamera(ctx);
    notifyListeners();
  }

  /// Ruling 05-3: the permission check runs before [build], so a denied
  /// shape allocates no handle. Returns whether the command ran.
  bool commit(ToolContext ctx, DraftCommand Function() build) {
    if (!ctx.document.commands.permissions.allows(Capability.geometry)) {
      return false;
    }
    ctx.execute(build());
    return true;
  }

  /// Spec 05 D13: with Fill on and a [fillable] shape, one region when the
  /// boundary can fill, and the plain boundary when it cannot.
  bool commitShape(ToolContext ctx, EntityKind kind, GeometryPayload payload,
          {bool fillable = false}) =>
      commit(ctx, () {
        if (fillable && (fill?.value ?? false)) {
          final region = addDraftedRegion(ctx.document, kind, payload);
          if (region != null) return region;
        }
        return addDrafted(ctx.document, kind, payload);
      });

  void _reresolve(ToolContext ctx) {
    final world = ctx.camera.value
        .screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));
    _resolve(ctx, world, _lastShift);
    hovered(world);
    notifyListeners();
  }

  void _syncCamera(ToolContext ctx) {
    if (isPending && _listening == null) {
      _listening = ctx;
      ctx.camera.addListener(_onCamera);
    } else if (!isPending && _listening != null) {
      _listening!.camera.removeListener(_onCamera);
      _listening = null;
    }
  }

  void _onCamera() {
    final ctx = _listening;
    if (ctx != null) _reresolve(ctx);
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {
    if (!_hoverVisible) return;
    final m = camera.worldToScreenMatrix;
    final p = _hover.point;
    drawSnapMarker(
        canvas,
        Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f),
        _hover.objectKind,
        grid: _hover.grid,
        paint: _markerPaint);
  }

  @override
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {
    bandPaint.strokeWidth = kPreviewStrokePixels / scale;
    paintRubberBand(canvas, origin, scale);
  }

  @override
  void dispose() {
    _listening?.camera.removeListener(_onCamera);
    _listening = null;
    super.dispose();
  }
}
```

  Implement `lib/src/draw/line_tool.dart`:

```dart
import 'dart:ui' show Canvas;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D6: AutoCAD's LINE. Each click commits one segment, and its end
/// is the next segment's start: the same stored values. Fill does not
/// apply.
class LineTool extends PlacementTool {
  LineTool();

  int _segments = 0;

  @override
  String get name => 'Line';

  /// The current start ends the chain, but only once a segment is committed
  /// (M-05x). Before that, a second click on the start is a zero-length
  /// segment and is refused.
  @override
  Vector2? selfSnap(Vector2 raw, double apertureWorld) =>
      _segments > 0 &&
              points.isNotEmpty &&
              raw.distanceTo(points.last) <= apertureWorld
          ? points.last
          : null;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    if (acceptingSelf) {
      clearShape();
      return;
    }
    final start = points.last;
    if (isDegenerateSegment(start, point)) return;
    if (commit(ctx,
        () => addDrafted(ctx.document, EntityKind.line, linePayload(start, point)))) {
      _segments++;
      points
        ..clear()
        ..add(point);
    } else {
      clearShape();
    }
  }

  @override
  void finish(ToolContext ctx) => clearShape();

  @override
  void clearShape() {
    super.clearShape();
    _segments = 0;
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final a = points.last, h = hoverPoint;
    band
      ..reset()
      ..moveTo(a.x - origin.x, a.y - origin.y)
      ..lineTo(h.x - origin.x, h.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
```

  Add the two exports to `lib/jet_cad_2d_flutter.dart`, after `export
  'src/draw_sink.dart';`.

- [ ] **Step 5: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/`
  Expected: `All tests passed!`: 9 in B, counting the three flipY-grouped
  tests twice (12 test cases), and 7 in L (L1 twice). Paste the count.

- [ ] **Step 6: Gate and commit.** Run the `jet_cad_2d_flutter` line.

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/support/draw_fixture.dart packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart packages/jet_cad_2d_flutter/test/draw/line_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(draw): PlacementTool and the chained line tool

A shared base resolves each point through the tool's own placed points,
then 03's resolveDragPoint; draws the hover marker; follows the camera
while a shape is pending; takes Escape, Enter and shift and swallows
every other key mid-shape; and commits one command, checking permissions
before a handle is allocated. LineTool chains segments on the same stored
joint. 02's Tool API is unchanged. Spec 05 D3, D4, D6.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

