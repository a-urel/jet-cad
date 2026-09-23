import 'dart:ui' show Path, Rect;

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, PhysicalKeyboardKey;
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
      clickAt(
          rig, screenOf(rig.camera, kAnchorX, kAnchorY) + const Offset(2, -3));
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

  test(
      'L3 before the first segment, a second click on the start is refused '
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

  test(
      'L4 Enter ends the chain, the segments stay, and each undo removes '
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
