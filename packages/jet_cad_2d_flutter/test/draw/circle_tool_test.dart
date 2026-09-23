import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/circle_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ];

void main() {
  for (final flipY in const [true, false]) {
    test('C1 flipY $flipY: centre and a point on the circle', () {
      final s = drawScene();
      final rig =
          drawRig(s.document, CircleTool(), flipY: flipY, objectSnap: false);
      final c = screenOf(rig.camera, 7050.5, 3080.25);
      final r = screenOf(rig.camera, 7091.75, 3102.5);
      clickAt(rig, c);
      clickAt(rig, r);
      final p =
          payloadOf(s.document, ofKind(s.document, EntityKind.circle).single);
      final wc = worldAt(rig, c), wr = worldAt(rig, r);
      expect(p.coords.toList(), [wc.x, wc.y]);
      expect(p.scalars.toList(), [wc.distanceTo(wr)]);
    });
  }

  test('C2 with Fill on, a circle commits as one region', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, CircleTool(fill: fill), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    clickAt(rig, screenOf(rig.camera, 7090, 3100));
    final circle = ofKind(s.document, EntityKind.circle).single;
    expect(s.document.fills.fillsOf(circle), hasLength(1));
    expect(s.document.commands.undoDepth, 1);
  });

  test('C3 a zero radius is refused', () {
    final s = drawScene();
    final rig = drawRig(s.document, CircleTool(), objectSnap: false);
    final c = screenOf(rig.camera, 7050, 3080);
    clickAt(rig, c);
    final before = snapshot(s.document);
    clickAt(rig, c);
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });
}
