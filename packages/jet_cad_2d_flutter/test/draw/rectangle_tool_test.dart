import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/rectangle_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

void main() {
  for (final flipY in const [true, false]) {
    test('R1 flipY $flipY: two corners make a closed world-axis rectangle', () {
      final s = drawScene();
      final rig =
          drawRig(s.document, RectangleTool(), flipY: flipY, objectSnap: false);
      final a = screenOf(rig.camera, 7010.5, 3020.25);
      final b = screenOf(rig.camera, 7090.75, 3070.5);
      clickAt(rig, a);
      clickAt(rig, b);
      final p =
          payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
      final c1 = worldAt(rig, a), c2 = worldAt(rig, b);
      expect(p.coords.toList(),
          [c1.x, c1.y, c2.x, c1.y, c2.x, c2.y, c1.x, c2.y, c1.x, c1.y]);
      expect(isClosedPolyline(p), isTrue);
    });
  }

  test('R2 a zero-width rectangle is refused', () {
    final s = drawScene(snapToGrid: true);
    final rig = drawRig(s.document, RectangleTool(), objectSnap: false);
    // The 20 mm minor grid at this fixture's zoom (Deviation 1 in the
    // report): 7010 sits exactly on a grid line's midpoint, so the two
    // clicks' sub-µm screen round-trip noise straddles it and they snap to
    // *different* lines, 20 mm apart — not the near-duplicate x this test
    // means to exercise. 7009/7009.01 sit well inside one 20 mm cell, so
    // both snap to its same line and the rectangle collapses to zero width.
    final a = screenOf(rig.camera, 7009, 3020);
    clickAt(rig, a);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7009.01, 3090));
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });

  test(
      'R3 with Fill on, one region in the fill colour, one undo step '
      '(M-05o, M-05p)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig =
        drawRig(s.document, RectangleTool(fill: fill), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7090, 3070));
    final boundary = ofKind(s.document, EntityKind.polyline).single;
    final fillHandle = s.document.fills.fillsOf(boundary).single;
    final record =
        s.document.entities.read(s.document.entities.slotOf(fillHandle)!);
    expect(record.color, kDraftFillColor);
    expect(fillHandle.value, lessThan(boundary.value));
    expect(s.document.commands.undoDepth, 1);
    s.document.commands.undo();
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
  });

  test('R4 with Fill off, a plain polyline and no fill', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(false);
    addTearDown(fill.dispose);
    final rig =
        drawRig(s.document, RectangleTool(fill: fill), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7090, 3070));
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
    expect(ofKind(s.document, EntityKind.polyline), hasLength(1));
  });

  test(
      'R5 a filled rectangle round-trips through the codec as a closed '
      'polyline with its fill (exit criterion 5)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig =
        drawRig(s.document, RectangleTool(fill: fill), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7090, 3070));
    final text = snapshot(s.document);
    final back = DraftDocumentCodec.decodeString(text,
        measurer: MetricModelMeasurer(),
        registerComponents: PageComponent.register);
    final boundary = ofKind(back, EntityKind.polyline).single;
    expect(isClosedPolyline(payloadOf(back, boundary)), isTrue);
    expect(back.fills.fillsOf(boundary), hasLength(1));
    expect(snapshot(back), text);
  });
}
