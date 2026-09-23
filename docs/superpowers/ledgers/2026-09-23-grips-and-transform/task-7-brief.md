### Task 7: `SelectTool` — press classes, the three drags, the camera listener, keys, cancel paths

**Files:**
- Modify: `lib/src/select_tool.dart`
- Rewrite: `test/support/grip_fixture.dart` (adds the rig, the pointer
  helpers and the layer pump; keeps everything from Task 4)
- Modify: `test/select_tool_test.dart` (the one D12 test, Ruling 03-21)
- Test: `test/select_tool_drag_test.dart` (T1–T17, W1–W3)

**Interfaces:**
- Consumes:
  - `GripDrag`, `DragKind`, `kRotationStep` (Task 6);
  - `GripCache` (`grips`, `box`, `hot`, `hitTest`, `hitsRotationGrip`) and
    `rotationGripOf` (Task 4);
  - `ToolContext.page/snap/grips`, `Tool.cursor` and
    `selectionPreviewTransform` (Task 5);
  - `resolveDragPoint`, `DragPoint`, `kSnapAperturePixels` and
    `dragGridStepMm` (Task 3).
- Produces:
  - `enum PressClass { rotationGrip, grip, selectedBody, unselectedBody, empty }`
  - on `SelectTool`: `PressClass? get pressClass`, `DragKind? get
    dragKind`, `MouseCursor get cursor`, `Transform2? get
    selectionPreviewTransform`.
  - `bandMode`, `bandScreen` and `bandStart` are unchanged in meaning: they
    are non-null only during a band.
  - fixture:
    - `GripRig`, with fields `document`, `index`, `selection`, `camera`,
      `outlines`, `grips`, `snap`, `page`, `tool`, `context`, `tools`;
    - `GripRig gripRig(DraftDocument, {CameraController? camera, bool objectSnap = false})`;
    - `ToolPointerEvent pointerAt(CameraController, Offset, {int buttons, bool shift, int pointer})`;
    - `void pressAndMove(GripRig, Offset from, Offset to, {bool shift})`;
    - `void release(GripRig, Offset at, {bool shift})`;
    - `void click(GripRig, Offset at, {bool shift})`;
    - `const Size kGripLayerSize`;
    - `Future<void> pumpGripLayer(WidgetTester, GripRig)`;
    - `Offset globalAt(WidgetTester, Offset local)`.

- [ ] **Step 1: Rewrite the fixture.** Replace
  `test/support/grip_fixture.dart` whole with the text below. Everything
  from Task 4 is kept verbatim. The rig and the helpers are new.

```dart
// test/support/grip_fixture.dart
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart'
    show
        Center,
        CustomPaint,
        Directionality,
        Listenable,
        Offset,
        Positioned,
        RepaintBoundary,
        Size,
        SizedBox,
        Stack,
        TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/draft_canvas.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/page_notifier.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/snap_settings.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection_fixture.dart';

// ---- Task 4: the scene, the camera, the readers -------------------------

/// The spec's standard 03 fixture (Testing).
///
/// - Everything sits at x ≈ 7000–7550, y ≈ 3000–3330, so the rebase origin
///   is non-zero.
/// - A closed room.
/// - Arcs with a non-zero start, one of them with a negative sweep.
/// - A group whose own transform is a rotation.
/// - Two instances of one definition.
/// - The root stays the identity.
final class GripScene {
  GripScene._(this.document);

  final DraftDocument document;
  late final Handle line, polyline, room, circle, arcPos, arcNeg, point;
  late final Handle group, groupLeaf, def, defLeaf, instA, instB;
}

GripScene gripScene(
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    PageComponent? page}) {
  final doc = DraftDocument.empty(measurer: measurer);
  final s = GripScene._(doc);
  final root = doc.rootHandle;
  s.line = addEntity(doc, root, EntityKind.line, [7010, 3020, 7130, 3060], []);
  s.polyline = addEntity(doc, root, EntityKind.polyline,
      [7010, 3100, 7040, 3130, 7070, 3100, 7100, 3130, 7130, 3100], []);
  s.room = addEntity(doc, root, EntityKind.polyline,
      [7200, 3000, 7400, 3000, 7400, 3150, 7200, 3150, 7200, 3000], []);
  s.circle = addEntity(doc, root, EntityKind.circle, [7300, 3250], [25]);
  s.arcPos = addEntity(doc, root, EntityKind.arc, [7050, 3200], [40, 0.3, 1.9]);
  s.arcNeg =
      addEntity(doc, root, EntityKind.arc, [7150, 3250], [30, 2.2, -1.4]);
  s.point = addEntity(doc, root, EntityKind.point, [7250, 3300], []);
  s.group = addGroup(doc, root,
      Transform2.translation(7400, 3300).multiply(Transform2.rotation(0.6)));
  s.groupLeaf = addEntity(doc, s.group, EntityKind.line, [0, 0, 40, 0], []);
  s.def = addDefinition(doc, 'Table');
  s.defLeaf = addEntity(doc, s.def, EntityKind.line, [0, 0, 30, 10], []);
  s.instA = addInstance(doc, s.def,
      Transform2.translation(7450, 3050).multiply(Transform2.rotation(0.3)));
  s.instB = addInstance(doc, s.def,
      Transform2.translation(7500, 3200).multiply(Transform2.rotation(-0.5)));
  if (page != null) {
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(root, page));
  }
  // `undoDepth` counts the drag under test only.
  doc.commands.clearHistory();
  expect(doc.tree[root]!.transform.isIdentity, isTrue,
      reason: 'spec, Testing: the root stays the identity');
  return s;
}

/// Zoomed (scale ≠ 1), rotated (not 0°, not 90°), y flipped, and panned so
/// [centre] sits in the middle of [viewport].
CameraController gripCamera(
    {Vector2? centre,
    Size viewport = const Size(800, 600),
    double scale = 1.1,
    double rotation = 0.35}) {
  final c = centre ?? Vector2(7270, 3161);
  final linear =
      Transform2.rotation(rotation).multiply(Transform2.scale(scale, -scale));
  final mid = linear.transformPoint(c);
  return CameraController(ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              viewport.width / 2 - mid.x, viewport.height / 2 - mid.y)
          .multiply(linear)));
}

/// World (x, y) on screen under [camera].
Offset screenOf(CameraController camera, double x, double y) {
  final s = camera.value.worldToScreen(Vector2(x, y));
  return Offset(s.x, s.y);
}

/// The stored payload of [h], as a `read` copy.
GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The codec's output: equal strings are a byte-identical document
/// (invariant 2).
String snapshot(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

// ---- Task 7: the rig, the pointer, the layer ----------------------------

/// Everything a `SelectTool` grip test drives, wired in the shell's order:
/// the selection controller, then the outline cache, then the grip cache
/// (spec D6, Ruling 03-19). Object snap is off unless asked for, so a test
/// that is not about snapping lands on the raw pointer.
final class GripRig {
  GripRig(this.document, {CameraController? camera, bool objectSnap = false})
      : index = SpatialIndex(document),
        selection = SelectionController(document),
        camera = camera ?? gripCamera() {
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines);
    snap = SnapSettings(objectSnap: objectSnap);
    page = PageNotifier(document);
    tool = SelectTool();
    context = ToolContext(
        document: document,
        index: index,
        camera: this.camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    tools = ToolController(initial: tool, context: context);
  }

  final DraftDocument document;
  final SpatialIndex index;
  final SelectionController selection;
  final CameraController camera;
  late final OutlineCache outlines;
  late final GripCache grips;
  late final SnapSettings snap;
  late final PageNotifier page;
  late final SelectTool tool;
  late final ToolContext context;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    grips.dispose();
    outlines.dispose();
    page.dispose();
    snap.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  }
}

GripRig gripRig(DraftDocument document,
    {CameraController? camera, bool objectSnap = false}) {
  final rig = GripRig(document, camera: camera, objectSnap: objectSnap);
  addTearDown(rig.dispose);
  return rig;
}

/// A pointer sample at [screen], resolved through [camera] exactly as
/// `InteractionLayer` does it.
ToolPointerEvent pointerAt(CameraController camera, Offset screen,
        {int buttons = kPrimaryButton, bool shift = false, int pointer = 1}) =>
    ToolPointerEvent(
      screen: screen,
      world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
      pointer: pointer,
      buttons: buttons,
      shift: shift,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
    );

/// Press at [from], then one move to [to]: past the slop in one event.
void pressAndMove(GripRig rig, Offset from, Offset to, {bool shift = false}) {
  rig.tool.onPointerDown(pointerAt(rig.camera, from, shift: shift), rig.context);
  rig.tool.onPointerMove(pointerAt(rig.camera, to, shift: shift), rig.context);
}

void release(GripRig rig, Offset at, {bool shift = false}) => rig.tool
    .onPointerUp(pointerAt(rig.camera, at, shift: shift, buttons: 0), rig.context);

void click(GripRig rig, Offset at, {bool shift = false}) {
  rig.tool.onPointerDown(pointerAt(rig.camera, at, shift: shift), rig.context);
  release(rig, at, shift: shift);
}

/// The layer's box under test, centred in the 800 × 600 surface so a drag
/// can leave it and stay on the surface (W2).
const Size kGripLayerSize = Size(600, 450);

/// Pumps an `InteractionLayer` over the canvas and the overlay, both driven
/// by [rig].
///
/// Teardown order: build [rig] (which registers its dispose) **before**
/// calling this. The empty pump registered here then runs first, while the
/// rig is still live.
Future<void> pumpGripLayer(WidgetTester tester, GripRig rig) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: kGripLayerSize.width,
        height: kGripLayerSize.height,
        child: InteractionLayer(
          tools: rig.tools,
          child: Stack(children: [
            RepaintBoundary(
              child: DraftCanvas(
                  document: rig.document, index: rig.index, camera: rig.camera),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SelectionOverlayPainter(
                    selection: rig.selection,
                    tools: rig.tools,
                    camera: rig.camera,
                    outlines: rig.outlines,
                    repaint: Listenable.merge([
                      rig.selection,
                      rig.tools,
                      rig.camera,
                      rig.outlines,
                      rig.grips,
                    ]),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
  ));
  await tester.pump();
  expect(tester.getSize(find.byType(InteractionLayer)), kGripLayerSize,
      reason: 'a zero-sized layer would receive no pointer events');
}

/// [local] in the layer's box, in the surface's global coordinates.
Offset globalAt(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(InteractionLayer)) + local;
```

- [ ] **Step 2: Write the failing tests.** In `test/select_tool_test.dart`,
  replace the test `'a 5 px move from empty space starts a band; from a hit
  it does not'`, whole, with the test below (Ruling 03-21). Also add `import
  'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;` to that
  file's imports.

```dart
  test(
      'a 5 px move from empty space starts a band; from an unselected hit it '
      'now selects and moves the object (spec 03 D12)', () {
    final doc = DraftDocument.empty();
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);

    final fromEmpty = SelectTool();
    fromEmpty.onPointerDown(ev(camera, const Offset(50, 50)), ctx);
    fromEmpty.onPointerMove(ev(camera, const Offset(55, 50)), ctx);
    expect(fromEmpty.phase, ToolPhase.dragging);
    expect(fromEmpty.dragKind, DragKind.band);

    // 02 pinned "from a hit it does not" (select_tool.dart line 76). Spec 03
    // D12: past the slop, a press on an unselected body selects it and
    // moves the selection.
    final fromHit = SelectTool();
    fromHit.onPointerDown(ev(camera, const Offset(400, 300)), ctx);
    fromHit.onPointerMove(ev(camera, const Offset(405, 300)), ctx);
    expect(fromHit.phase, ToolPhase.dragging);
    expect(fromHit.dragKind, DragKind.move);
    expect(selection.keys, [SelectionKey.root(line)]);
    fromHit.cancel(ctx);
    expect(doc.commands.undoDepth, 1,
        reason: "only the fixture's own AddEntityCommand; the cancelled move "
            'dispatched nothing');
  });
```

Create `test/select_tool_drag_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        PhysicalKeyboardKey,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

Vector2 worldOf(GripRig rig, Offset screen) =>
    rig.camera.value.screenToWorld(Vector2(screen.dx, screen.dy));

/// Every coordinate of [after] is [before]'s plus [delta] — a decision
/// about where geometry landed, so within `Tolerance` (spec D8).
void expectMovedBy(
    GeometryPayload after, GeometryPayload before, Vector2 delta) {
  for (var i = 0; i < before.coords.length; i += 2) {
    expect(after.coords[i], closeTo(before.coords[i] + delta.x, 1e-9));
    expect(after.coords[i + 1], closeTo(before.coords[i + 1] + delta.y, 1e-9));
  }
}

Vector2 rotatedAbout(double x, double y, Vector2 p, double theta) => Vector2(
    p.x + math.cos(theta) * (x - p.x) - math.sin(theta) * (y - p.y),
    p.y + math.sin(theta) * (x - p.x) + math.cos(theta) * (y - p.y));

double normalised(double a) => a > math.pi
    ? a - 2 * math.pi
    : (a <= -math.pi ? a + 2 * math.pi : a);

/// The line's body, 30% along: 38 world units from each end and 25 from
/// its midpoint, so no snap point is within the aperture.
const double bodyX = 7046, bodyY = 3032;

void main() {
  test('a click on a grip or on the rotation grip changes nothing (D12, '
      'M-03as); the cursor says what a press would do', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.polyline)]);
    final vertex = screenOf(rig.camera, 7130, 3060);

    rig.tool.onPointerMove(
        pointerAt(rig.camera, vertex, buttons: 0), rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.precise);
    expect(rig.grips.hot, isNonNegative);

    rig.tool.onPointerDown(pointerAt(rig.camera, vertex), rig.context);
    expect(rig.tool.pressClass, PressClass.grip);
    release(rig, vertex);
    expect(rig.selection.keys, {k(s.line), k(s.polyline)},
        reason: '02 replace-selected the line here; a grip click does nothing');

    final rotation = rotationGripOf(
            rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;
    rig.tool.onPointerMove(
        pointerAt(rig.camera, rotation, buttons: 0), rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.grab);
    rig.tool.onPointerDown(pointerAt(rig.camera, rotation), rig.context);
    expect(rig.tool.pressClass, PressClass.rotationGrip);
    release(rig, rotation);
    expect(rig.selection.length, 2);

    rig.tool.onPointerMove(
        pointerAt(rig.camera, screenOf(rig.camera, bodyX, bodyY), buttons: 0),
        rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.move);
    expect(rig.document.commands.undoDepth, 0);
  });

  test('a body drag moves the selection under a rotated camera (M-03a)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    expect(rig.camera.value.worldToScreenMatrix.b, isNot(closeTo(0, 1e-3)));
    expect(rig.camera.value.scale, isNot(closeTo(1, 1e-3)));
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(37, -21);
    pressAndMove(rig, from, to);
    expect(rig.tool.dragKind, DragKind.move);
    expect(rig.tool.cursor, SystemMouseCursors.move);
    release(rig, to);
    expectMovedBy(payloadOf(rig.document, s.line), before,
        worldOf(rig, to) - worldOf(rig, from));
  });

  test('no command during a drag; release adds exactly one Compound "Move" '
      '(M-03d, invariants 1 and 4)', () async {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;
    final labels = <String>[];
    final sub = doc.changes.listen((c) {
      if (c is CommandApplied) labels.add(c.label);
    });
    addTearDown(sub.cancel);
    rig.selection.replace([k(s.line), k(s.instA)]);
    final seed = doc.handleSeed.current;
    final live = doc.entities.liveCount;
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(20, 5));
    for (final step in const [Offset(30, 9), Offset(44, 12), Offset(51, 17)]) {
      rig.tool.onPointerMove(pointerAt(rig.camera, from + step), rig.context);
      expect(doc.commands.undoDepth, 0,
          reason: 'nothing is dispatched during a drag');
    }
    release(rig, from + const Offset(51, 17));
    expect(doc.commands.undoDepth, 1);
    await Future<void>.delayed(Duration.zero);
    expect(labels, ['Move']);
    expect(doc.handleSeed.current, seed, reason: 'invariant 4');
    expect(doc.entities.liveCount, live);
    expect(doc.tree[doc.rootHandle]!.transform.isIdentity, isTrue,
        reason: 'the root transform is never written');
  });

  test('a drag back to the press pixel, or snapped back onto its base, adds '
      'nothing (M-03p)', () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 0));
    rig.tool.onPointerMove(pointerAt(rig.camera, from), rig.context);
    release(rig, from);
    expect(rig.document.commands.undoDepth, 0,
        reason: 'the same pixel under the same camera is a bit-identical '
            'world point, so Δ == 0');

    // 8 world units along the line from its start: 8.8 px, outside the grip
    // (7 px), inside the aperture (10 px). The base snaps onto the endpoint,
    // and a release 3 px from the endpoint snaps the target onto it too.
    final along = Vector2(7010, 3020) + Vector2(120, 40).normalized() * 8.0;
    final nearEnd = screenOf(rig.camera, along.x, along.y);
    pressAndMove(rig, nearEnd, nearEnd + const Offset(60, -30));
    expect(rig.tool.dragKind, DragKind.move);
    release(rig, screenOf(rig.camera, 7010, 3020) + const Offset(3, 0));
    expect(rig.document.commands.undoDepth, 0,
        reason: 'target == base: Δ is exactly zero');
  });

  test('with grid snap on, on-grid geometry stays on the grid (M-03s)', () {
    final s = gripScene(
        page: PageComponent(originX: 7000, originY: 3000, gridStepMm: 10));
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(53, 29);
    pressAndMove(rig, from, to);
    release(rig, to);
    final after = payloadOf(rig.document, s.line);
    expect(after.coords[0], isNot(7010.0), reason: 'the line really moved');
    for (var i = 0; i < 4; i++) {
      final v = after.coords[i] - (i.isEven ? 7000 : 3000);
      expect(Tolerance.standard.isZero(v - (v / 10).roundToDouble() * 10),
          isTrue,
          reason: 'coordinate $i = ${after.coords[i]} left the 10 mm lattice');
    }
  });

  test('a shift-press-drag on an unselected object adds it and moves ortho '
      'in world axes (M-03f)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final line0 = payloadOf(rig.document, s.line);
    final poly0 = payloadOf(rig.document, s.polyline);
    final from = screenOf(rig.camera, 7025, 3115); // the polyline's body
    final to = screenOf(rig.camera, 7065, 3122);
    pressAndMove(rig, from, to, shift: true);
    expect(rig.selection.keys, {k(s.line), k(s.polyline)},
        reason: 'shift at the press toggles the object in (D2, class 3b)');
    release(rig, to, shift: true);
    final dx = worldOf(rig, to).x - worldOf(rig, from).x;
    for (final (after, before) in [
      (payloadOf(rig.document, s.line), line0),
      (payloadOf(rig.document, s.polyline), poly0),
    ]) {
      for (var i = 0; i < before.coords.length; i += 2) {
        expect(after.coords[i], closeTo(before.coords[i] + dx, 1e-9));
        expect(after.coords[i + 1], before.coords[i + 1],
            reason: 'shift during the drag is ortho: the minor world axis '
                'is pinned exactly');
      }
    }
  });

  test('a centre grip moves the whole selection from the grip itself '
      '(M-03at, Ruling 03-9)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.circle), k(s.line)]);
    final circle0 = payloadOf(rig.document, s.circle);
    final line0 = payloadOf(rig.document, s.line);
    final centre = screenOf(rig.camera, 7300, 3250);
    final to = centre + const Offset(-31, 17);
    pressAndMove(rig, centre, to);
    expect(rig.tool.pressClass, PressClass.grip);
    expect(rig.tool.dragKind, DragKind.move);
    release(rig, to);
    final delta = worldOf(rig, to) - Vector2(7300, 3250);
    expectMovedBy(payloadOf(rig.document, s.circle), circle0, delta);
    expectMovedBy(payloadOf(rig.document, s.line), line0, delta);
    expect(payloadOf(rig.document, s.circle).scalars, [25]);
  });

  test('a stretch released near an endpoint lands on it exactly (M-03au)',
      () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    final drop = screenOf(rig.camera, 7130, 3100) + const Offset(2, -3);
    pressAndMove(rig, vertex, drop);
    expect(rig.tool.dragKind, DragKind.reshape);
    expect(rig.tool.cursor, SystemMouseCursors.precise);
    release(rig, drop);
    final after = payloadOf(rig.document, s.line);
    expect([after.coords[2], after.coords[3]], [7130, 3100],
        reason: "== : the polyline's endpoint, exactly (spec D8)");
    expect([after.coords[0], after.coords[1]], [7010, 3020]);
  });

  test("coincident grips: the greater handle's end moves, the other object "
      'stays (M-03ai)', () {
    final s = gripScene();
    final doc = s.document;
    final wallA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7600, 3400, 7650, 3400], []);
    final wallB = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7650, 3400, 7650, 3450], []);
    doc.commands.clearHistory();
    final rig = gripRig(doc, camera: gripCamera(centre: Vector2(7640, 3420)));
    rig.selection.replace([k(wallA), k(wallB)]);
    final corner = screenOf(rig.camera, 7650, 3400);
    pressAndMove(rig, corner, corner + const Offset(15, 20));
    release(rig, corner + const Offset(15, 20));
    expect(payloadOf(doc, wallA).coords, [7600, 3400, 7650, 3400]);
    final b = payloadOf(doc, wallB);
    expect(b.coords[0], isNot(7650.0));
    expect(b.coords.sublist(2), [7650, 3450]);
  });

  test('a rotation turns about the selection box centre, far from the '
      'origin (M-03j)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    // The line's world box, by hand: (7010, 3020)–(7130, 3060).
    final pivot = Vector2(7070, 3040);
    final grip = rotationGripOf(
            rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;
    final to = grip + const Offset(-45, 38);
    pressAndMove(rig, grip, to);
    expect(rig.tool.pressClass, PressClass.rotationGrip);
    expect(rig.tool.dragKind, DragKind.rotate);
    expect(rig.tool.cursor, SystemMouseCursors.grabbing);
    release(rig, to);
    final w0 = worldOf(rig, grip) - pivot;
    final w1 = worldOf(rig, to) - pivot;
    final theta =
        normalised(math.atan2(w1.y, w1.x) - math.atan2(w0.y, w0.x));
    final after = payloadOf(rig.document, s.line);
    for (var i = 0; i < 4; i += 2) {
      final r = rotatedAbout(before.coords[i], before.coords[i + 1], pivot, theta);
      expect(after.coords[i], closeTo(r.x, 1e-9));
      expect(after.coords[i + 1], closeTo(r.y, 1e-9));
    }
  });

  test('shift steps the rotation by 15° (M-03w)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    final pivot = Vector2(7070, 3040);
    final grip = rotationGripOf(
            rig.grips.box!, rig.camera.value.worldToScreenMatrix)
        .centre;
    final w0 = worldOf(rig, grip) - pivot;
    final a0 = math.atan2(w0.y, w0.x);
    // 0.30 rad from the press: 15° steps round it to π/12; 30° steps would
    // round it to π/6.
    final aim = pivot + Vector2(math.cos(a0 + 0.30), math.sin(a0 + 0.30)) * 70;
    final to = screenOf(rig.camera, aim.x, aim.y);
    pressAndMove(rig, grip, to, shift: true);
    final t = rig.tool.selectionPreviewTransform!;
    expect(math.atan2(t.b, t.a), closeTo(math.pi / 12, 1e-12));
    release(rig, to, shift: true);
    final after = payloadOf(rig.document, s.line);
    for (var i = 0; i < 4; i += 2) {
      final r = rotatedAbout(
          before.coords[i], before.coords[i + 1], pivot, math.pi / 12);
      expect(after.coords[i], closeTo(r.x, 1e-9));
      expect(after.coords[i + 1], closeTo(r.y, 1e-9));
    }
  });

  test('permissions at press: no leaf grips, a refused move stays a click, '
      'an instance still moves (M-03ad, M-03av)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;
    doc.commands.permissions = DraftPermissions.runtime;
    rig.selection.replace([k(s.line), k(s.instA)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    rig.tool.onPointerDown(pointerAt(rig.camera, vertex), rig.context);
    expect(rig.tool.pressClass, PressClass.selectedBody,
        reason: "no leaf grip is live, so the press lands on the line's body");
    final away = vertex + const Offset(30, 10);
    rig.tool.onPointerMove(pointerAt(rig.camera, away), rig.context);
    expect(rig.tool.phase, ToolPhase.pressed,
        reason: 'a move of a selection holding a leaf needs geometry; the '
            'press stays a click (Ruling 03-6)');
    release(rig, away);
    expect(rig.selection.keys, {k(s.line)},
        reason: 'released as a click: replace-select');
    expect(doc.commands.undoDepth, 0);

    rig.selection.replace([k(s.instA)]);
    final a0 = doc.tree[s.instA]! as InstanceNode;
    final body = a0.transform.transformPoint(Vector2(15, 5));
    final from = screenOf(rig.camera, body.x, body.y);
    final to = from + const Offset(-25, 14);
    pressAndMove(rig, from, to);
    release(rig, to);
    expect(doc.commands.undoDepth, 1,
        reason: 'runtime allows transform: a table moves, a wall cannot');
    final a1 = doc.tree[s.instA]! as InstanceNode;
    final delta = worldOf(rig, to) - worldOf(rig, from);
    expect(a1.transform.e, closeTo(a0.transform.e + delta.x, 1e-9));
    expect(a1.transform.f, closeTo(a0.transform.f + delta.y, 1e-9));
  });

  test('a camera change mid-drag re-resolves the target from the last '
      'screen point (M-03ac)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(40, 25);
    final base = worldOf(rig, from);
    pressAndMove(rig, from, to);
    // A trackpad zoom about another point: no pointer event arrives.
    rig.camera.zoomAt(const Offset(10, 10), 1.5);
    final target = worldOf(rig, to);
    final t = rig.tool.selectionPreviewTransform!;
    expect(t.e, closeTo(target.x - base.x, 1e-9));
    expect(t.f, closeTo(target.y - base.y, 1e-9));
    release(rig, to);
    rig.camera.panBy(const Offset(7, 7));
    expect(rig.tool.selectionPreviewTransform, isNull,
        reason: 'the listener left with the drag (Ruling 03-7)');
  });

  test("every key-down and repeat is the drag's; Escape cancels "
      'byte-identically (M-03aa, M-03l)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.instA)]);
    final bytes = snapshot(rig.document);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 25));
    const zDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    const zRepeat = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    const zUp = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    expect(rig.tool.onKey(zDown, rig.context), KeyEventResult.handled);
    expect(rig.tool.onKey(zRepeat, rig.context), KeyEventResult.handled,
        reason: 'Ruling 03-8: a held cmd+Z repeats');
    expect(rig.tool.onKey(zUp, rig.context), KeyEventResult.ignored);
    expect(rig.tool.phase, ToolPhase.dragging);
    const escape = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero);
    expect(rig.tool.onKey(escape, rig.context), KeyEventResult.handled);
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
    expect(rig.document.commands.undoDepth, 0);
    expect(rig.selection.length, 2,
        reason: 'Escape during a drag cancels the drag, not the selection');
  });

  test('tool activation cancels a drag byte-identically (M-03ao)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final bytes = snapshot(rig.document);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 25));
    final other = SelectTool();
    addTearDown(other.dispose);
    rig.tools.activate(other);
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
    rig.tools.activate(rig.tool);
  });

  test('a document change mid-drag: release dispatches nothing (M-03t)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(40, 25);
    pressAndMove(rig, from, to);
    final edited = GeometryPayload(
        coords: Float64List.fromList([7010, 3020, 7140, 3080]),
        scalars: Float64List(0));
    rig.document.commands.execute(SetEntityGeometryCommand(s.line, edited));
    release(rig, to);
    expect(rig.document.commands.undoDepth, 1, reason: 'the external edit only');
    expect(payloadOf(rig.document, s.line), edited);
  });

  testWidgets('a pointer cancel leaves the document byte-identical (M-03ao)',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera: gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final bytes = snapshot(rig.document);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalAt(tester, screenOf(rig.camera, bodyX, bodyY));
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(30, 20));
    expect(rig.tool.dragKind, DragKind.move);
    await gesture.cancel();
    await tester.pump();
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
  });

  testWidgets("a move dragged past the layer's edge continues and lands "
      '(M-03ap)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera: gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final before = payloadOf(rig.document, s.line);
    final fromLocal = screenOf(rig.camera, bodyX, bodyY);
    final outside = Offset(kGripLayerSize.width + 50, fromLocal.dy);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(globalAt(tester, fromLocal));
    await gesture.moveTo(globalAt(tester, fromLocal + const Offset(30, 0)));
    await gesture.moveTo(globalAt(tester, outside));
    await tester.pump();
    expect(rig.tool.dragKind, DragKind.move,
        reason: 'pointer exit is not a cancel path (spec D5, 02 amended)');
    await gesture.up();
    await tester.pump();
    expectMovedBy(payloadOf(rig.document, s.line), before,
        worldOf(rig, outside) - worldOf(rig, fromLocal));
  });

  testWidgets('removing the layer mid-drag cancels byte-identically (M-03ao)',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera: gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final bytes = snapshot(rig.document);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalAt(tester, screenOf(rig.camera, bodyX, bodyY));
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(30, 20));
    expect(rig.tool.dragKind, DragKind.move);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(rig.tool.phase, ToolPhase.idle,
        reason: "the layer's deactivate/dispose cancels the tool");
    expect(snapshot(rig.document), bytes);
    // The captured pointer's up still reaches the unmounted layer's
    // Listener callback; the idle tool ignores it.
    await gesture.up();
  });
}
```

- [ ] **Step 3: Run them to fail.** `CI=true flutter test
  test/select_tool_drag_test.dart test/select_tool_test.dart` → compile
  errors: `PressClass`, `pressClass` and `dragKind` are undefined on
  `SelectTool`.

- [ ] **Step 4: Implement.** In `lib/src/select_tool.dart`, make three
  edits. Line numbers are at the branch point.
  - **Replace lines 1–109** (the imports through `onPointerUp`'s closing
    brace) with block A below.
  - **Keep lines 111–194 unchanged** (`_bandKeys`, `_everyLeafIn`,
    `_topmostGroup`).
  - **Replace lines 196–236** (`_reset` through `onKey`) with block B.
  - **Keep lines 238–386 unchanged** (`_deleteSelection`, `_groupCascade`,
    `paintOverlay`, `_drawDashedRect`). `paintOverlay` reads `bandScreen`,
    which now answers only for a band.

Block A:

```dart
import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Paint, Path, PaintingStyle, Rect, Size;

import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'grip_drag.dart';
import 'selection.dart';
import 'selection_style.dart';
import 'tool.dart';
import 'viewport_transform.dart';

/// A press that moves less than this many screen pixels stays a click
/// (M-02f); past it, a press becomes the drag its class names (spec 03 D2).
const double kBandSlopPixels = 4.0;

/// What a press landed on (spec 03 D2). The first class that hits wins.
enum PressClass { rotationGrip, grip, selectedBody, unselectedBody, empty }

/// Hover, click, shift-click and rubber-band selection (spec 02 D1, D2, D7,
/// D8), Escape and Delete/Backspace (02 D3, D10) — and, since 03, grips:
/// - press classes;
/// - move, rotate and reshape drags with object and grid snap;
/// - one command on release (spec 03 D2, D4, D5).
class SelectTool extends Tool {
  SelectTool();

  @override
  String get name => 'Select';
  ToolPhase _phase = ToolPhase.idle;
  @override
  ToolPhase get phase => _phase;

  final HitPath _hit = HitPath();
  Offset _start = Offset.zero;
  final Vector2 _pressWorld = Vector2.zero();
  bool _pressShift = false;
  PressClass _class = PressClass.empty;
  SelectionKey? _downKey;
  int _pressGrip = -1;

  /// Set when a drag was refused at the slop (Ruling 03-6): the press stays
  /// a click, and later moves do nothing.
  bool _clickOnly = false;
  Offset _end = Offset.zero;
  BandMode? _bandMode;
  int _pointer = -1;

  DragKind? _dragKind;
  GripDrag? _drag;
  ToolContext? _dragCtx;
  Offset _lastScreen = Offset.zero;
  bool _lastShift = false;
  final DragPoint _dragPoint = DragPoint();
  final SnapResult _snapScratch = SnapResult();
  MouseCursor _cursor = MouseCursor.defer;

  /// What the press landed on; null while idle.
  PressClass? get pressClass => _phase == ToolPhase.idle ? null : _class;

  /// The live drag's kind; null unless dragging.
  DragKind? get dragKind => _phase == ToolPhase.dragging ? _dragKind : null;

  /// Non-null only while a band drag is in progress, for the overlay.
  BandMode? get bandMode => dragKind == DragKind.band ? _bandMode : null;

  /// The band rectangle in screen space, for the overlay test.
  Rect? get bandScreen =>
      dragKind == DragKind.band ? Rect.fromPoints(_start, _end) : null;

  /// The band's drag-start corner, for the overlay.
  Offset? get bandStart => dragKind == DragKind.band ? _start : null;

  @override
  MouseCursor get cursor => _cursor;

  @override
  Transform2? get selectionPreviewTransform {
    final kind = dragKind;
    return kind == DragKind.move || kind == DragKind.rotate
        ? _drag?.transform
        : null;
  }

  SelectionKey? _pick(ToolPointerEvent e, ToolContext ctx) {
    if (!ctx.index.pickInto(
        e.world, e.pickRadiusWorld, const QueryFilter.picking(), _hit)) {
      return null;
    }
    return resolveHit(_hit, ctx.document);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (_phase != ToolPhase.idle) return;
    _phase = ToolPhase.pressed;
    _pointer = e.pointer;
    _start = e.screen;
    _pressWorld.setFrom(e.world);
    _pressShift = e.shift;
    _class = _classify(e, ctx);
    notifyListeners();
  }

  /// Spec D2: the rotation grip, then a grip, then the single pick
  /// (selected or not), then empty space.
  PressClass _classify(ToolPointerEvent e, ToolContext ctx) {
    _downKey = null;
    _pressGrip = -1;
    final grips = ctx.grips;
    if (grips != null) {
      final m = ctx.camera.value.worldToScreenMatrix;
      if (grips.hitsRotationGrip(e.screen, m)) return PressClass.rotationGrip;
      final i = grips.hitTest(e.screen, m);
      if (i >= 0) {
        _pressGrip = i;
        return PressClass.grip;
      }
    }
    final key = _pick(e, ctx);
    _downKey = key;
    if (key == null) return PressClass.empty;
    // The single pick decides: an unselected object drawn above a selected
    // one wins the press, exactly as it wins a click in 02.
    return ctx.selection.contains(key)
        ? PressClass.selectedBody
        : PressClass.unselectedBody;
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    switch (_phase) {
      case ToolPhase.idle:
        if (e.buttons != 0) return;
        _hoverAt(e, ctx);
      case ToolPhase.pressed:
        if (e.pointer != _pointer || _clickOnly) return;
        if ((e.screen - _start).distance < kBandSlopPixels) return;
        _beginDrag(e, ctx);
      case ToolPhase.dragging:
        if (e.pointer != _pointer) return;
        if (_dragKind == DragKind.band) {
          _end = e.screen;
          _bandMode =
              _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        } else {
          _follow(e, ctx);
        }
        notifyListeners();
    }
  }

  /// 02's object hover, plus the hot grip and the cursor (spec 03 D5).
  /// Notifies only when the cursor or the hot grip changed.
  void _hoverAt(ToolPointerEvent e, ToolContext ctx) {
    final key = _pick(e, ctx);
    ctx.selection.setHover(key);
    var cursor = MouseCursor.defer;
    var hot = -1;
    final grips = ctx.grips;
    if (grips != null) {
      final m = ctx.camera.value.worldToScreenMatrix;
      if (grips.hitsRotationGrip(e.screen, m)) {
        cursor = SystemMouseCursors.grab;
      } else {
        hot = grips.hitTest(e.screen, m);
        if (hot >= 0) cursor = SystemMouseCursors.precise;
      }
    }
    if (cursor == MouseCursor.defer &&
        key != null &&
        ctx.selection.contains(key)) {
      cursor = SystemMouseCursors.move;
    }
    final hotChanged = grips != null && grips.hot != hot;
    if (grips != null) grips.hot = hot;
    if (cursor == _cursor && !hotChanged) return;
    _cursor = cursor;
    notifyListeners();
  }

  /// Spec D2, past the slop. A drag whose capability is refused never
  /// starts; the press stays a click (Ruling 03-6).
  void _beginDrag(ToolPointerEvent e, ToolContext ctx) {
    switch (_class) {
      case PressClass.empty:
        _phase = ToolPhase.dragging;
        _dragKind = DragKind.band;
        ctx.selection.setHover(null);
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
      case PressClass.selectedBody:
        final drag = GripDrag.move(ctx.document, ctx.selection.keys);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        _moveBase(ctx, drag!);
        _enter(drag, e, ctx);
      case PressClass.unselectedBody:
        final key = _downKey!;
        final next = _pressShift
            ? <SelectionKey>{...ctx.selection.keys, key}
            : <SelectionKey>{key};
        final drag = GripDrag.move(ctx.document, next);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        // Class 3b: select (shift at the press toggles in), then move. The
        // selection change is selection state; it stands after a cancel.
        _pressShift ? ctx.selection.toggle([key]) : ctx.selection.replace([key]);
        _moveBase(ctx, drag!);
        _enter(drag, e, ctx);
      case PressClass.grip:
        final grips = ctx.grips!;
        final ref = grips.grips[_pressGrip];
        // Ruling 03-9: a centre grip moves the whole selection.
        final drag = ref.grip.role == GripRole.move
            ? GripDrag.move(ctx.document, ctx.selection.keys)
            : GripDrag.reshape(ctx.document, ref.key, ref.grip);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        // Spec D8: a grip's base is the grip's own world point, exactly.
        drag!.base.setValues(ref.grip.x, ref.grip.y);
        grips.hot = _pressGrip;
        _enter(drag, e, ctx);
      case PressClass.rotationGrip:
        final box = ctx.grips!.box!;
        final pivot =
            Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);
        final drag = GripDrag.rotate(
            ctx.document, ctx.selection.keys, pivot, _pressWorld);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        _enter(drag!, e, ctx);
    }
  }

  /// Spec D2: a drag needs its capability before it starts.
  static bool _permitted(GripDrag? drag, ToolContext ctx) =>
      drag != null && drag.permittedBy(ctx.document.commands.permissions);

  /// Spec D8: a body drag's base is the press point, resolved by the same
  /// chain as the target but without ortho. With grid snap on, a move from
  /// on-grid geometry is then a lattice vector (M-03s).
  void _moveBase(ToolContext ctx, GripDrag drag) {
    _resolve(ctx, _pressWorld, null);
    drag.base.setFrom(_dragPoint.point);
  }

  void _enter(GripDrag drag, ToolPointerEvent e, ToolContext ctx) {
    _drag = drag;
    _dragKind = drag.kind;
    _dragCtx = ctx;
    _phase = ToolPhase.dragging;
    ctx.selection.setHover(null);
    // Ruling 03-7: a trackpad zoom or a middle-button pan moves the camera
    // with no pointer event; the target follows from the last screen point.
    ctx.camera.addListener(_onCamera);
    _cursor = switch (drag.kind) {
      DragKind.move => SystemMouseCursors.move,
      DragKind.rotate => SystemMouseCursors.grabbing,
      DragKind.reshape || DragKind.band => SystemMouseCursors.precise,
    };
    _follow(e, ctx);
    notifyListeners();
  }

  /// Spec D5: world from screen, every event — `e.world` is the layer's
  /// inverse camera at this event, never a scaled screen delta.
  void _follow(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _lastShift = e.shift;
    _retarget(ctx, e.world, e.shift);
  }

  void _retarget(ToolContext ctx, Vector2 world, bool shift) {
    final drag = _drag!;
    if (drag.kind == DragKind.rotate) {
      // Spec D8: a rotate snaps to nothing; shift steps it by 15°.
      drag.rotateTo(world, step: shift);
      return;
    }
    _resolve(ctx, world, shift ? drag.base : null);
    drag.moveTo(_dragPoint.point);
  }

  void _resolve(ToolContext ctx, Vector2 raw, Vector2? orthoBase) {
    final cam = ctx.camera.value;
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: orthoBase,
      index: ctx.index,
      apertureWorld: kSnapAperturePixels / cam.scale,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _snapScratch,
      out: _dragPoint,
    );
  }

  void _onCamera() {
    final ctx = _dragCtx;
    if (ctx == null || _drag == null) return;
    final world = ctx.camera.value
        .screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));
    _retarget(ctx, world, _lastShift);
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_phase) {
      case ToolPhase.idle:
        return;
      case ToolPhase.pressed:
        // A press that never left the slop is a click. On a grip or on the
        // rotation grip it does nothing (spec 03 D2, D12).
        switch (_class) {
          case PressClass.selectedBody:
          case PressClass.unselectedBody:
            final key = _downKey!;
            e.shift
                ? ctx.selection.toggle([key])
                : ctx.selection.replace([key]);
          case PressClass.empty:
            if (!e.shift) ctx.selection.clear();
          case PressClass.grip:
          case PressClass.rotationGrip:
            break;
        }
      case ToolPhase.dragging:
        if (_dragKind == DragKind.band) {
          final keys = _bandKeys(ctx, e);
          e.shift ? ctx.selection.toggle(keys) : ctx.selection.replace(keys);
        } else {
          // Ruling 03-13: the up carries the final position.
          _follow(e, ctx);
          final command = _drag!.command(ctx.document.commands.permissions);
          _endDrag(ctx);
          _reset();
          notifyListeners();
          // Spec D4: one command or none — never one per move
          // (invariant 1).
          if (command != null) ctx.execute(command);
          return;
        }
    }
    _reset();
    notifyListeners();
  }
```

Block B:

```dart
  void _reset() {
    _phase = ToolPhase.idle;
    _pointer = -1;
    _class = PressClass.empty;
    _downKey = null;
    _pressGrip = -1;
    _clickOnly = false;
    _bandMode = null;
    _dragKind = null;
  }

  /// The single way out of a move, rotate or reshape (Ruling 03-7).
  void _endDrag(ToolContext ctx) {
    if (_drag == null) return;
    (_dragCtx ?? ctx).camera.removeListener(_onCamera);
    ctx.grips?.hot = -1;
    _drag = null;
    _dragCtx = null;
    _dragPoint.reset();
    _cursor = MouseCursor.defer;
  }

  @override
  void onPointerExit(ToolContext ctx) {
    ctx.selection.setHover(null);
    if (_phase == ToolPhase.dragging) cancel(ctx);
  }

  /// Every cancel path — Escape, pointer cancel, `ToolController.activate`,
  /// the layer's deactivate/dispose — leaves the document byte-identical
  /// (spec D5, invariant 2). A selection change made at drag start stands.
  @override
  void cancel(ToolContext ctx) {
    if (_phase == ToolPhase.idle) return;
    _endDrag(ctx);
    _reset();
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (_phase == ToolPhase.dragging &&
        (event is KeyDownEvent || event is KeyRepeatEvent)) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        cancel(ctx);
      }
      // Spec D5 and Ruling 03-8: every key-down and repeat is the drag's,
      // so the shell's cmd+Z never lands mid-drag.
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_phase == ToolPhase.idle) ctx.selection.clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_phase != ToolPhase.idle) return KeyEventResult.ignored;
      _deleteSelection(ctx);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
```

- [ ] **Step 5: Run them to pass.** `CI=true flutter test
  test/select_tool_drag_test.dart test/select_tool_test.dart
  test/interaction_layer_test.dart test/selection_overlay_test.dart` → all
  tests pass. Then run the `jet_cad_2d_flutter` gate line: only the five
  goldens fail. If any other 02 test goes red, stop and report it. It is
  either a D12 change the plan missed, or a defect.
- [ ] **Step 6: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/test/support/grip_fixture.dart packages/jet_cad_2d_flutter/test/select_tool_test.dart packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart
git commit -m "$(cat <<'EOF'
feat(render): SelectTool drags -- press classes, move, rotate, reshape

Spec 03 D2, D5, D8, D12: the four press classes and the capability check
before a drag starts; body and centre-grip moves, the rotation grip about
the box centre with 15 degree shift steps, grip reshapes; world from screen
every event, a camera listener for zooms mid-drag; every key-down and repeat
consumed while dragging; one command on release, none on any cancel path.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
