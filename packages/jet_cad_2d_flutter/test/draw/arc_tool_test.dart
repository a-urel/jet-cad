import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/arc_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

Handle arcOf(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.arc)
          doc.entities.handleAt(slot),
    ].single;

const double cx = 7150.5, cy = 3120.25;

/// The pointer at [angle] on a circle of [r] around the centre.
void at(DrawRig rig, double angle, double r,
        {bool click = false, bool down = false}) =>
    down
        ? downAt(
            rig,
            screenOf(
                rig.camera, cx + r * math.cos(angle), cy + r * math.sin(angle)))
        : click
            ? clickAt(
                rig,
                screenOf(rig.camera, cx + r * math.cos(angle),
                    cy + r * math.sin(angle)))
            : hoverAt(
                rig,
                screenOf(rig.camera, cx + r * math.cos(angle),
                    cy + r * math.sin(angle)));

void main() {
  for (final flipY in const [true, false]) {
    test(
        'AR1 flipY $flipY: an asymmetric CCW arc stores start then sweep '
        '(M-05e)', () {
      final s = drawScene();
      final rig =
          drawRig(s.document, ArcTool(), flipY: flipY, objectSnap: false);
      clickAt(rig, screenOf(rig.camera, cx, cy));
      at(rig, 0.3, 40, click: true);
      for (final a in const [0.8, 1.4, 2.0]) {
        at(rig, a, 40);
      }
      at(rig, 2.2, 55, click: true); // the end need not be on the circle
      final p = payloadOf(s.document, arcOf(s.document));
      final start = p.scalars[1], sweep = p.scalars[2];
      expect(start, closeTo(0.3, 1e-6));
      expect(sweep, closeTo(1.9, 1e-6));
      expect(p.scalars[0], closeTo(40, 1e-6));
      expect(rig.tool.points, isEmpty, reason: 'cleared after the commit');
    });
  }

  test('AR2 a clockwise path gives a negative sweep (M-05g)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    for (final a in const [0.0, -0.5, -1.0]) {
      at(rig, a, 40);
    }
    at(rig, -1.2, 40, click: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], closeTo(-1.5, 1e-6));
  });

  test('AR3 a path across the ±π seam keeps its direction (M-05f)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 2.9, 40, click: true);
    for (final a in const [3.05, -3.05, -2.9]) {
      at(rig, a, 40);
    }
    at(rig, -2.8, 40, click: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], greaterThan(0));
    expect(p.scalars[2], closeTo(-2.8 + 2 * math.pi - 2.9, 1e-6));
  });

  test('AR4 an end press with no hover after the start is CCW (M-05z)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    downAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, down: true);
    at(rig, -1.0, 40, down: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], greaterThan(0), reason: 'τ == 0 is CCW');
    expect(p.scalars[2], closeTo(2 * math.pi - 1.3, 1e-6));
  });

  test('AR5 Fill does not apply to an arc', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    at(rig, 1.0, 40);
    at(rig, 1.2, 40, click: true);
    expect(s.document.fills.fillsOf(arcOf(s.document)), isEmpty);
    expect(fill.value, isTrue);
  });

  test('AR6 an end on the start ray is refused and the tool waits', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    final before = snapshot(s.document);
    downAt(rig,
        screenOf(rig.camera, cx + 70 * math.cos(0.3), cy + 70 * math.sin(0.3)));
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });
}
