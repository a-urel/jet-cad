import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart'
    show kPickRadiusPixels;
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';

KeyDownEvent _deleteDown() => const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.delete,
    logicalKey: LogicalKeyboardKey.delete,
    timeStamp: Duration.zero);
KeyUpEvent _deleteUp() => const KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.delete,
    logicalKey: LogicalKeyboardKey.delete,
    timeStamp: Duration.zero);
KeyRepeatEvent _deleteRepeat() => const KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.delete,
    logicalKey: LogicalKeyboardKey.delete,
    timeStamp: Duration.zero);
KeyDownEvent _escapeDown() => const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.escape,
    logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero);

/// Copied from `region_command_test.dart`'s `squareLoop()`, never imported
/// from a test file.
GeometryPayload _squareLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
    scalars: Float64List(0));

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

  test('a leaf the picking filter rejects is skipped by the group every-rule',
      () {
    // A1. `_bandDescend` in the engine applies the filter before counting a
    // member; the tool's every-rule must agree, or a group with one locked
    // leaf could never be window-selected at all.
    //
    // Camera: `sx = 2*wx - 600`, `sy = -2*wy + 900`, so the band's world
    // corners (486,280) and (510,320) land at screen (372,340) and (420,260).
    // The band encloses the first leaf only.
    (DraftDocument, Handle) fixture({required bool locked}) {
      final doc = DraftDocument.empty();
      final group =
          addGroup(doc, doc.rootHandle, Transform2.translation(500, 300));
      addEntity(doc, group, EntityKind.line, [0, 0, 2, 0],
          []); // world (500,300)-(502,300), inside the band
      final layer = addLayer(doc, locked ? 'Locked' : 'Free', locked: locked);
      addEntity(doc, group, EntityKind.line, [20, 0, 22, 0], [],
          layer: layer); // world (520,300)-(522,300), outside the band
      return (doc, group);
    }

    List<SelectionKey> band(DraftDocument doc) {
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-600, 900));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      tool.onPointerDown(ev(camera, const Offset(372, 340)), ctx);
      tool.onPointerMove(ev(camera, const Offset(420, 260)), ctx);
      expect(tool.bandMode, BandMode.window);
      tool.onPointerUp(ev(camera, const Offset(420, 260)), ctx);
      return selection.keys.toList();
    }

    final (lockedDoc, lockedGroup) = fixture(locked: true);
    expect(band(lockedDoc), [SelectionKey.root(lockedGroup)],
        reason: 'the locked leaf is not a member the every-rule can fail on');

    final (freeDoc, freeGroup) = fixture(locked: false);
    expect(band(freeDoc), isEmpty,
        reason: 'the same leaf, visible and unlocked, is outside the band, '
            'so the group is missing a member and window takes nothing');
  });

  test('both band corners are converted at release, not at press', () {
    // A3 / spec D8. The camera moves between press and release (a trackpad
    // zoom during a band drag), so a world corner captured on press names a
    // different point than the screen corner the user is still holding.
    final doc = DraftDocument.empty();
    // Inside the band the *release-time* camera computes, outside the one a
    // press-time corner would build.
    final right = addEntity(
        doc, doc.rootHandle, EntityKind.line, [420, 245, 428, 255], []);
    // The exact opposite: inside the press-time band, outside the correct one.
    final wrong = addEntity(
        doc, doc.rootHandle, EntityKind.line, [440, 265, 460, 275], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    // `sx = 2*wx - 600`, `sy = -2*wy + 900`.
    final camera = cameraAt(2.0, const Offset(-600, 900));
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tool = SelectTool();

    tool.onPointerDown(ev(camera, const Offset(372, 340)), ctx);
    tool.onPointerMove(ev(camera, const Offset(420, 260)), ctx);
    expect(tool.bandMode, BandMode.window);

    // Zoom about a focus that is neither corner, so *both* screen corners
    // name different world points afterwards.
    camera.zoomAt(const Offset(100, 500), 2.0);
    expect(camera.value.scale, closeTo(4.0, 1e-12));

    // Post-zoom the two screen corners are world (418,240) and (430,260);
    // pre-zoom the press corner was world (486,280).
    final a = camera.value.screenToWorld(Vector2(372, 340));
    final b = camera.value.screenToWorld(Vector2(420, 260));
    expect(a.x, closeTo(418, 1e-9));
    expect(a.y, closeTo(240, 1e-9));
    expect(b.x, closeTo(430, 1e-9));
    expect(b.y, closeTo(260, 1e-9));

    tool.onPointerUp(ev(camera, const Offset(420, 260)), ctx);

    expect(selection.keys.toList(), [SelectionKey.root(right)],
        reason: 'the band is the world box of both screen corners under the '
            'camera at release');
    expect(selection.contains(SelectionKey.root(wrong)), isFalse,
        reason: 'a press-time world corner would build [430,486] x [260,280] '
            'and take this one instead');
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

  group('keys and delete', () {
    test('Escape when idle clears', () {
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
      selection.replace([SelectionKey.root(lineA)]);

      final result = tool.onKey(_escapeDown(), ctx);

      expect(result, KeyEventResult.handled);
      expect(selection.isEmpty, isTrue);
      expect(tool.phase, ToolPhase.idle);
    });

    test('a KeyUpEvent and a KeyRepeatEvent do nothing', () {
      // M-02x at tool level.
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
      selection.replace([SelectionKey.root(lineA), SelectionKey.root(lineB)]);

      final upResult = tool.onKey(_deleteUp(), ctx);
      final repeatResult = tool.onKey(_deleteRepeat(), ctx);

      expect(upResult, KeyEventResult.ignored);
      expect(repeatResult, KeyEventResult.ignored);
      expect(doc.entities.slotOf(lineA), isNotNull);
      expect(doc.entities.slotOf(lineB), isNotNull);
      expect(selection.length, 2);
    });

    test(
        'Delete removes a leaf and an instance through the log; undo '
        'restores geometry, not selection', () {
      final doc = DraftDocument.empty();
      final leaf = addEntity(
          doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
      final def = addDefinition(doc, 'Def');
      addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
      final instance = addInstance(doc, def, kPlacement);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      selection.replace([SelectionKey.root(leaf), SelectionKey.root(instance)]);
      final depthBefore = doc.commands.undoDepth;

      final result = tool.onKey(_deleteDown(), ctx);

      expect(result, KeyEventResult.handled);
      expect(doc.entities.slotOf(leaf), isNull);
      expect(doc.tree[instance], isNull);
      expect(selection.isEmpty, isTrue);
      expect(doc.commands.undoDepth, depthBefore + 1,
          reason: 'two objects, one Delete, one undo step');

      doc.commands.undo();

      expect(doc.entities.slotOf(leaf), isNotNull,
          reason: 'one undo brings back everything the Delete removed');
      expect(doc.tree[instance], isNotNull);
      expect(selection.isEmpty, isTrue,
          reason: 'undo replays the command log; it never restores the '
              "selection controller's own state");
    });

    test(
        'Delete cascades a group: leaves, child instance, nested group, '
        'then the group', () {
      // M-02j.
      final doc = DraftDocument.empty();
      final group =
          addGroup(doc, doc.rootHandle, Transform2.translation(500, 300));
      final leafA = addEntity(doc, group, EntityKind.line, [0, 0, 2, 0], []);
      final leafB = addEntity(doc, group, EntityKind.line, [5, 0, 7, 0], []);
      final def = addDefinition(doc, 'Def');
      addEntity(doc, def, EntityKind.line, [0, 0, 1, 0], []);
      final childInstance = addInstance(doc, def, kPlacement, parent: group);
      final nestedGroup = addGroup(doc, group, Transform2.translation(20, 0));
      final nestedLeaf =
          addEntity(doc, nestedGroup, EntityKind.line, [0, 0, 1, 0], []);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      selection.replace([SelectionKey.root(group)]);
      final depthBefore = doc.commands.undoDepth;

      final result = tool.onKey(_deleteDown(), ctx);

      expect(result, KeyEventResult.handled);
      expect(doc.entities.slotOf(leafA), isNull);
      expect(doc.entities.slotOf(leafB), isNull);
      expect(doc.entities.slotOf(nestedLeaf), isNull);
      expect(doc.tree[childInstance], isNull);
      expect(doc.tree[nestedGroup], isNull);
      expect(doc.tree[group], isNull);
      expect(doc.commands.undoDepth, depthBefore + 1,
          reason: 'the whole cascade is one undo step');

      doc.commands.undo();

      expect(doc.tree[group], isNotNull);
      expect(doc.tree[nestedGroup], isNotNull);
      expect(doc.tree[childInstance], isNotNull);
      expect(doc.entities.slotOf(leafA), isNotNull);
      expect(doc.entities.slotOf(leafB), isNotNull);
      expect(doc.entities.slotOf(nestedLeaf), isNotNull);
      expect(doc.entities.read(doc.entities.slotOf(nestedLeaf)!).owner,
          nestedGroup,
          reason: 'the leaf comes back under its owner, which is back too: '
              'the partial-undo hazard spec D10 recorded is closed');
    });

    test(
        "a region inside a group is deleted once: the boundary's command "
        'takes the fill', () {
      final doc = DraftDocument.empty();
      final group =
          addGroup(doc, doc.rootHandle, Transform2.translation(200, 100));
      final region = AddRegionCommand.allocate(
        seed: doc.handleSeed,
        owner: group,
        boundaryKind: EntityKind.polyline,
        boundaryPayload: _squareLoop(),
        layer: ReservedHandles.layerZero,
        fillColor: const TrueColor(0x3366CC),
        boundaryColor: const TrueColor(0x000000),
      );
      doc.commands.execute(region);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      selection.replace([SelectionKey.root(group)]);

      expect(() => tool.onKey(_deleteDown(), ctx), returnsNormally);
      expect(doc.entities.slotOf(region.fill.handle), isNull);
      expect(doc.entities.slotOf(region.boundary.handle), isNull);
      expect(doc.tree[group], isNull);
    });

    test(
        'a fill selected alongside the group that owns its boundary is '
        'removed once, by the boundary', () {
      // M-S3: the boundary's command takes the fill with it (D10's cascade),
      // so the fill's own key must emit nothing. A second removal would
      // throw at execute time and roll the whole Delete back. Only
      // reachable through `replace` today — 02 selects root objects — but
      // 03/05's enter-a-container work makes it a click.
      final doc = DraftDocument.empty();
      final group =
          addGroup(doc, doc.rootHandle, Transform2.translation(200, 100));
      final region = AddRegionCommand.allocate(
        seed: doc.handleSeed,
        owner: group,
        boundaryKind: EntityKind.polyline,
        boundaryPayload: _squareLoop(),
        layer: ReservedHandles.layerZero,
        fillColor: const TrueColor(0x3366CC),
        boundaryColor: const TrueColor(0x000000),
      );
      doc.commands.execute(region);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      selection.replace(
          [SelectionKey.root(group), SelectionKey.root(region.fill.handle)]);
      final depthBefore = doc.commands.undoDepth;

      expect(() => tool.onKey(_deleteDown(), ctx), returnsNormally);

      expect(doc.entities.slotOf(region.fill.handle), isNull);
      expect(doc.entities.slotOf(region.boundary.handle), isNull);
      expect(doc.tree[group], isNull);
      expect(doc.commands.undoDepth, depthBefore + 1);
      expect(selection.isEmpty, isTrue);
    });

    test('a refused group does not hide a permitted key inside it', () {
      // M-S2: the group's cascade names every handle under it. If those
      // names were recorded before the group's own permission preflight
      // refused it, the leaf's key would find itself already named, emit
      // nothing, and still be deselected — gone from the selection, still in
      // the document. Structure denied, geometry allowed, is the permission
      // set that separates the two.
      final doc = DraftDocument.empty();
      final group =
          addGroup(doc, doc.rootHandle, Transform2.translation(500, 300));
      final leaf = addEntity(doc, group, EntityKind.line, [0, 0, 2, 0], []);
      doc.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: true, structure: false);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      selection.replace([SelectionKey.root(group), SelectionKey.root(leaf)]);

      final result = tool.onKey(_deleteDown(), ctx);

      expect(result, KeyEventResult.handled);
      expect(doc.tree[group], isNotNull, reason: 'refused, so untouched');
      expect(doc.entities.slotOf(leaf), isNull, reason: 'permitted, so gone');
      expect(selection.keys, [SelectionKey.root(group)],
          reason: 'the refused key stays selected; the removed one does not');
    });

    test('a read-only document is selectable and Delete is a no-op', () {
      // M-02n.
      final doc = DraftDocument.empty(permissions: DraftPermissions.readOnly);
      // The document is read-only from construction; permissions is a
      // mutable field on the dispatcher (see `command_test.dart`'s own
      // `dispatcher.permissions = ...` idiom), flipped here only long enough
      // to seed the fixture, then restored before the Delete under test.
      doc.commands.permissions = DraftPermissions.all;
      final leaf = addEntity(
          doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
      doc.commands.permissions = DraftPermissions.readOnly;
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      selection.replace([SelectionKey.root(leaf)]);

      expect(() => tool.onKey(_deleteDown(), ctx), returnsNormally);
      expect(doc.entities.slotOf(leaf), isNotNull);
      expect(selection.contains(SelectionKey.root(leaf)), isTrue);
    });

    test('a refused object stays selected, a permitted one goes', () {
      final doc = DraftDocument.empty();
      final leaf = addEntity(
          doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);
      final def = addDefinition(doc, 'Def');
      addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
      final instance = addInstance(doc, def, kPlacement);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final tool = SelectTool();
      selection.replace([SelectionKey.root(leaf), SelectionKey.root(instance)]);
      doc.commands.permissions = const DraftPermissions(
          transform: false,
          components: false,
          geometry: true,
          structure: false);

      final result = tool.onKey(_deleteDown(), ctx);

      expect(result, KeyEventResult.handled);
      expect(doc.entities.slotOf(leaf), isNull);
      expect(doc.tree[instance], isNotNull);
      expect(selection.contains(SelectionKey.root(instance)), isTrue);
      expect(selection.contains(SelectionKey.root(leaf)), isFalse);
    });
  });
}
