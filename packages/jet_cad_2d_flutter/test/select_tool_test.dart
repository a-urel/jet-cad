import 'dart:ui' show Offset, Rect;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';

/// A synthetic pointer sample: `screen` converted through [camera] into
/// world space and a pick radius of [kPickRadiusPixels] screen pixels
/// converted into world units at the camera's current scale (spec D7).
ToolPointerEvent ev(CameraController camera, Offset screen,
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

void main() {
  test("hover sets the controller's hover and clears on a miss", () {
    final doc = DraftDocument.empty();
    final lineA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tool = SelectTool();

    // The fixture is not degenerate: verify it actually lands on screen
    // before trusting anything built on top of it.
    final mid = camera.value.worldToScreen(Vector2(1000, 500));
    expect(const Rect.fromLTWH(0, 0, 800, 600).contains(Offset(mid.x, mid.y)),
        isTrue);

    tool.onPointerMove(ev(camera, const Offset(400, 300), buttons: 0), ctx);
    expect(selection.hover, equals(SelectionKey.root(lineA)));
    expect(tool.phase, ToolPhase.idle);

    tool.onPointerMove(ev(camera, const Offset(50, 50), buttons: 0), ctx);
    expect(selection.hover, isNull);
  });

  test('the pick radius is six screen pixels', () {
    // M-02d: two parallel horizontal lines 30 screen px apart (world
    // spacing 30 / scale = 15 at scale 2).
    final doc = DraftDocument.empty();
    final lineA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
    addEntity(doc, doc.rootHandle, EntityKind.line, [990, 485, 1010, 485], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tool = SelectTool();

    tool.onPointerDown(ev(camera, const Offset(400, 303)), ctx);
    tool.onPointerUp(ev(camera, const Offset(400, 303)), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineA)), isTrue);

    tool.onPointerDown(ev(camera, const Offset(400, 310)), ctx);
    tool.onPointerUp(ev(camera, const Offset(400, 310)), ctx);
    expect(selection.isEmpty, isTrue);
  });

  test('click replaces, shift-click toggles', () {
    // M-02h.
    final doc = DraftDocument.empty();
    final lineA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
    final lineB = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 650, 1010, 650], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tool = SelectTool();
    const atA = Offset(400, 300);
    const atB = Offset(400, 0);

    tool.onPointerDown(ev(camera, atA), ctx);
    tool.onPointerUp(ev(camera, atA), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineA)), isTrue);

    tool.onPointerDown(ev(camera, atB), ctx);
    tool.onPointerUp(ev(camera, atB), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineB)), isTrue);

    tool.onPointerDown(ev(camera, atA, shift: true), ctx);
    tool.onPointerUp(ev(camera, atA, shift: true), ctx);
    expect(selection.length, 2);
    expect(selection.contains(SelectionKey.root(lineA)), isTrue);
    expect(selection.contains(SelectionKey.root(lineB)), isTrue);

    tool.onPointerDown(ev(camera, atA, shift: true), ctx);
    tool.onPointerUp(ev(camera, atA, shift: true), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineB)), isTrue);
  });

  test('click on empty space clears; shift-click on empty space does nothing',
      () {
    final doc = DraftDocument.empty();
    final lineA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tool = SelectTool();
    const atA = Offset(400, 300);
    const empty = Offset(50, 50);

    tool.onPointerDown(ev(camera, atA), ctx);
    tool.onPointerUp(ev(camera, atA), ctx);
    expect(selection.length, 1);

    tool.onPointerDown(ev(camera, empty), ctx);
    tool.onPointerUp(ev(camera, empty), ctx);
    expect(selection.isEmpty, isTrue);

    tool.onPointerDown(ev(camera, atA), ctx);
    tool.onPointerUp(ev(camera, atA), ctx);
    expect(selection.length, 1);

    tool.onPointerDown(ev(camera, empty, shift: true), ctx);
    tool.onPointerUp(ev(camera, empty, shift: true), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineA)), isTrue);
  });

  test('a 2 px move keeps the press a click', () {
    // M-02f. The up half only re-confirms a click on empty space clears an
    // already-empty selection, which is non-discriminating on its own —
    // it is here for the phase assertion that precedes it.
    final doc = DraftDocument.empty();
    addEntity(
        doc, doc.rootHandle, EntityKind.line, [5000, 5000, 5010, 5000], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tool = SelectTool();

    tool.onPointerDown(ev(camera, const Offset(100, 100)), ctx);
    expect(tool.phase, ToolPhase.pressed);

    tool.onPointerMove(ev(camera, const Offset(102, 100)), ctx);
    expect(tool.phase, ToolPhase.pressed);

    tool.onPointerUp(ev(camera, const Offset(102, 100)), ctx);
    expect(tool.phase, ToolPhase.idle);
    expect(selection.isEmpty, isTrue);
  });

  test('a 5 px move from empty space starts a band; from a hit it does not',
      () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
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

    final fromHit = SelectTool();
    fromHit.onPointerDown(ev(camera, const Offset(400, 300)), ctx);
    fromHit.onPointerMove(ev(camera, const Offset(405, 300)), ctx);
    expect(fromHit.phase, ToolPhase.pressed);
  });

  test('left-to-right encloses, right-to-left touches', () {
    // M-02a at the tool level, both directions. Fixture mirrors
    // `band_query_test.dart`'s inside/straddling lines.
    final doc = DraftDocument.empty();
    final inside = addEntity(
        doc, doc.rootHandle, EntityKind.line, [100, 1000, 120, 1000], []);
    final straddling = addEntity(
        doc, doc.rootHandle, EntityKind.line, [190, 1000, 230, 1000], []);
    addEntity(doc, doc.rootHandle, EntityKind.line, [300, 1000, 320, 1000], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    // Scale 2.0 with a non-zero translation, not the identity-adjacent
    // scale-1 camera: `sx = 2*wx - 100`, `sy = -2*wy + 2300`, so the band's
    // world corners (90,1010) and (210,990) land at screen (80,280) and
    // (320,320).
    final camera = cameraAt(2.0, const Offset(-100, 2300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);

    final leftToRight = SelectTool();
    leftToRight.onPointerDown(ev(camera, const Offset(80, 280)), ctx);
    leftToRight.onPointerMove(ev(camera, const Offset(320, 320)), ctx);
    expect(leftToRight.phase, ToolPhase.dragging);
    expect(leftToRight.bandMode, BandMode.window);
    leftToRight.onPointerUp(ev(camera, const Offset(320, 320)), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(inside)), isTrue);

    selection.clear();
    final rightToLeft = SelectTool();
    rightToLeft.onPointerDown(ev(camera, const Offset(320, 320)), ctx);
    rightToLeft.onPointerMove(ev(camera, const Offset(80, 280)), ctx);
    expect(rightToLeft.phase, ToolPhase.dragging);
    expect(rightToLeft.bandMode, BandMode.crossing);
    rightToLeft.onPointerUp(ev(camera, const Offset(80, 280)), ctx);
    expect(selection.length, 2);
    expect(selection.contains(SelectionKey.root(inside)), isTrue);
    expect(selection.contains(SelectionKey.root(straddling)), isTrue);
  });

  test('a group is window-selected only when every leaf is enclosed', () {
    // M-02r / Ruling P-1. A plain translation places the group off the
    // origin; the transform's own composition is already covered at the
    // index level (band_query_test.dart) — this test is only about the
    // tool's every-leaf-in-the-group accounting.
    final doc = DraftDocument.empty();
    final group =
        addGroup(doc, doc.rootHandle, Transform2.translation(500, 300));
    addEntity(doc, group, EntityKind.line, [0, 0, 2, 0],
        []); // world (500,300)-(502,300)
    addEntity(doc, group, EntityKind.line, [20, 0, 22, 0],
        []); // world (520,300)-(522,300)
    // A root-level leaf, not a group member, so it never enters the
    // group's every/any-leaf accounting: it straddles the band's right
    // edge (world x 510) the way the group's own leaves do not, so the
    // band fixture has a genuine straddler rather than only fully-in and
    // fully-out entities.
    final straddler = addEntity(doc, doc.rootHandle, EntityKind.line,
        [505, 300, 515, 300], []); // world (505,300)-(515,300)
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    // Scale 2.0 with a non-zero translation: `sx = 2*wx - 600`,
    // `sy = -2*wy + 900`, so the band's world corners (486,280) and
    // (510,320) land at screen (372,340) and (420,260).
    final camera = cameraAt(2.0, const Offset(-600, 900));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);

    // Band world box [486, 510] x [280, 320]: encloses the first leaf
    // only; the straddler (505-515) crosses the box's right edge at 510.
    final window = SelectTool();
    window.onPointerDown(ev(camera, const Offset(372, 340)), ctx);
    window.onPointerMove(ev(camera, const Offset(420, 260)), ctx);
    expect(window.bandMode, BandMode.window);
    window.onPointerUp(ev(camera, const Offset(420, 260)), ctx);
    expect(selection.isEmpty, isTrue,
        reason: 'the group is missing a leaf and the straddler is not '
            'fully enclosed, so window takes neither');

    final crossing = SelectTool();
    crossing.onPointerDown(ev(camera, const Offset(420, 260)), ctx);
    crossing.onPointerMove(ev(camera, const Offset(372, 340)), ctx);
    expect(crossing.bandMode, BandMode.crossing);
    crossing.onPointerUp(ev(camera, const Offset(372, 340)), ctx);
    expect(selection.length, 2);
    expect(selection.contains(SelectionKey.root(group)), isTrue);
    expect(selection.contains(SelectionKey.root(straddler)), isTrue,
        reason: 'crossing takes the straddler even though it reaches '
            'outside the band');
  });

  test('shift-band toggles', () {
    final doc = DraftDocument.empty();
    final lineA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [100, 1000, 120, 1000], []);
    final lineB = addEntity(
        doc, doc.rootHandle, EntityKind.line, [300, 1000, 320, 1000], []);
    // Straddles the band's right edge (world x 330): 325 is inside the
    // box, 340 is outside it — present under crossing, absent under
    // window, checked below in both directions.
    final lineC = addEntity(
        doc, doc.rootHandle, EntityKind.line, [325, 1000, 340, 1000], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    // Scale 2.0 with a non-zero translation: `sx = 2*wx - 80`,
    // `sy = -2*wy + 2200`, so the band's world corners (290,990) and
    // (330,1010) land at screen (500,220) and (580,180).
    final camera = cameraAt(2.0, const Offset(-80, 2200));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    selection.replace([SelectionKey.root(lineA)]);
    final tool = SelectTool();

    // Crossing (right-to-left): takes B (fully inside) and C (straddling).
    tool.onPointerDown(ev(camera, const Offset(580, 180), shift: true), ctx);
    tool.onPointerMove(ev(camera, const Offset(500, 220), shift: true), ctx);
    expect(tool.bandMode, BandMode.crossing);
    tool.onPointerUp(ev(camera, const Offset(500, 220), shift: true), ctx);
    expect(selection.length, 3);
    expect(selection.contains(SelectionKey.root(lineA)), isTrue);
    expect(selection.contains(SelectionKey.root(lineB)), isTrue);
    expect(selection.contains(SelectionKey.root(lineC)), isTrue,
        reason: 'crossing takes the straddler too');

    // The same band again toggles B and C back off.
    tool.onPointerDown(ev(camera, const Offset(580, 180), shift: true), ctx);
    tool.onPointerMove(ev(camera, const Offset(500, 220), shift: true), ctx);
    tool.onPointerUp(ev(camera, const Offset(500, 220), shift: true), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineA)), isTrue);

    // Window (left-to-right), non-shift: replaces with B alone — the
    // straddler is not fully enclosed, so it is left out this time.
    tool.onPointerDown(ev(camera, const Offset(500, 220)), ctx);
    tool.onPointerMove(ev(camera, const Offset(580, 180)), ctx);
    expect(tool.bandMode, BandMode.window);
    tool.onPointerUp(ev(camera, const Offset(580, 180)), ctx);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineB)), isTrue,
        reason: 'window excludes the straddler, and non-shift replaces A');
  });

  test(
      'Escape during a band drops it, selection untouched; cancel returns '
      'to idle', () {
    // `onKey` is a no-op until Task 6 wires Escape to `cancel`; this drives
    // the cancel path directly, as the task brief for this task specifies.
    // A `KeyDownEvent` is built here only to document the shape Task 6's
    // `onKey` will receive.
    final escape = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.escape,
      logicalKey: LogicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    );
    expect(escape.logicalKey, LogicalKeyboardKey.escape);

    final doc = DraftDocument.empty();
    final lineA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(2.0, const Offset(-1600, 1300));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    selection.replace([SelectionKey.root(lineA)]);
    final tool = SelectTool();

    tool.onPointerDown(ev(camera, const Offset(50, 50)), ctx);
    tool.onPointerMove(ev(camera, const Offset(55, 50)), ctx);
    expect(tool.phase, ToolPhase.dragging);
    expect(tool.bandMode, isNotNull);

    tool.cancel(ctx);
    expect(tool.phase, ToolPhase.idle);
    expect(tool.bandMode, isNull);
    expect(tool.bandScreen, isNull);
    expect(selection.length, 1);
    expect(selection.contains(SelectionKey.root(lineA)), isTrue);
  });
}
