import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/polyline_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) {
  final out = <Handle>[
    for (final slot in doc.entities.liveSlots)
      if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
  ];
  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

void main() {
  for (final flipY in const [true, false]) {
    test(
        'PL1 flipY $flipY: three clicks and Enter make an open polyline, '
        'one undo step', () {
      final s = drawScene();
      final rig = drawRig(s.document, PolylineTool(), flipY: flipY);
      final a = screenOf(rig.camera, 7010.5, 3020.25);
      final b = screenOf(rig.camera, 7060.75, 3090.5);
      final c = screenOf(rig.camera, 7120.25, 3030.75);
      clickAt(rig, a);
      clickAt(rig, b);
      clickAt(rig, c);
      keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
      final h = ofKind(s.document, EntityKind.polyline).single;
      final p = payloadOf(s.document, h);
      final wa = worldAt(rig, a), wb = worldAt(rig, b), wc = worldAt(rig, c);
      expect(p.coords.toList(), [wa.x, wa.y, wb.x, wb.y, wc.x, wc.y]);
      expect(isClosedPolyline(p), isFalse);
      expect(s.document.commands.undoDepth, 1);
    });

    test(
        'PL3 flipY $flipY: clicking the first vertex closes on the stored '
        'point itself (M-05i)', () {
      final s = drawScene();
      final rig = drawRig(s.document, PolylineTool(), flipY: flipY);
      final a = screenOf(rig.camera, 7010.5, 3020.25);
      clickAt(rig, a);
      clickAt(rig, screenOf(rig.camera, 7060.75, 3090.5));
      clickAt(rig, screenOf(rig.camera, 7120.25, 3030.75));
      clickAt(rig, a + const Offset(3, -2));
      final p =
          payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
      expect(p.pointCount, 4);
      expect(p.coords[6], p.coords[0]);
      expect(p.coords[7], p.coords[1]);
      expect(isClosedPolyline(p), isTrue);
    });
  }

  test('PL2 clicking the last vertex again finishes it open', () {
    final s = drawScene();
    final rig = drawRig(s.document, PolylineTool());
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    final b = screenOf(rig.camera, 7060, 3090);
    clickAt(rig, b);
    clickAt(rig, b + const Offset(1, 2));
    final p =
        payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
    expect(p.pointCount, 2);
    expect(rig.tool.isPending, isFalse);
  });

  test(
      'PL4 with Fill on, closing commits one region; one undo removes both '
      '(M-05p)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, PolylineTool(fill: fill));
    final a = screenOf(rig.camera, 7010, 3020);
    clickAt(rig, a);
    clickAt(rig, screenOf(rig.camera, 7060, 3090));
    clickAt(rig, screenOf(rig.camera, 7120, 3030));
    clickAt(rig, a);
    final boundary = ofKind(s.document, EntityKind.polyline).single;
    final fills = s.document.fills.fillsOf(boundary);
    expect(fills, hasLength(1));
    expect(fills.single.value, lessThan(boundary.value));
    expect(s.document.commands.undoDepth, 1);
    s.document.commands.undo();
    expect(ofKind(s.document, EntityKind.polyline), isEmpty);
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
  });

  test(
      'PL5 a bow tie with Fill on still commits, as a plain boundary '
      '(M-05q)', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig =
        drawRig(s.document, PolylineTool(fill: fill), objectSnap: false);
    final a = screenOf(rig.camera, 7000, 3000);
    clickAt(rig, a);
    clickAt(rig, screenOf(rig.camera, 7100, 3100));
    clickAt(rig, screenOf(rig.camera, 7100, 3000));
    clickAt(rig, screenOf(rig.camera, 7000, 3100));
    clickAt(rig, a);
    final boundary = ofKind(s.document, EntityKind.polyline).single;
    expect(isClosedPolyline(payloadOf(s.document, boundary)), isTrue);
    expect(ofKind(s.document, EntityKind.fill), isEmpty);
    expect(s.document.fills.fillsOf(boundary), isEmpty);
  });

  test('PL6 shift pins the third vertex to the second, not the first (M-05h)',
      () {
    final s = drawScene();
    final tool = PolylineTool();
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010.5, 3020.25));
    clickAt(rig, screenOf(rig.camera, 7100.25, 3090.75));
    clickAt(rig, screenOf(rig.camera, 7180.5, 3101.25), shift: true);
    expect(tool.points, hasLength(3));
    expect(tool.points[2].y, tool.points[1].y,
        reason: '|dx| > |dy| from the last vertex: y pinned to it');
    expect(tool.points[2].y, isNot(tool.points[0].y));
  });

  test(
      'PL7 a tiny triangle closes on its first vertex; two coincident '
      'clicks are ignored (Review Focus 4)', () {
    final s = drawScene();
    final tool = PolylineTool();
    final rig = drawRig(s.document, tool, objectSnap: false);
    // Screen offsets against a 10 px aperture. b is 20 px from a. c is
    // 16.6 px from b, so placing it cannot finish on b; it is 8.6 px from
    // a, but with two vertices the first is not yet a close target. The
    // close click q is 3.6 px from a and 5 px from c: inside both.
    final a = screenOf(rig.camera, 7050, 3050);
    clickAt(rig, a);
    clickAt(rig, a); // coincident with the only vertex: ignored
    expect(tool.points, hasLength(1));
    clickAt(rig, a + const Offset(20, 0));
    clickAt(rig, a + const Offset(5, 7));
    expect(tool.points, hasLength(3));
    clickAt(rig, a + const Offset(2, 3)); // q: near both first and last
    final p =
        payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
    expect(isClosedPolyline(p), isTrue, reason: 'first beats last at 3+');
  });

  test('PL8 its own first vertex beats a nearer entity endpoint (M-05w)', () {
    final s = drawScene();
    final rig = drawRig(s.document, PolylineTool());
    // The first vertex sits 6 px from the anchor's start on screen.
    final anchor = screenOf(rig.camera, kAnchorX, kAnchorY);
    final first = anchor + const Offset(6, 0);
    rig.snap.toggleObjectSnap(); // off: place the first vertex raw
    clickAt(rig, first);
    rig.snap.toggleObjectSnap(); // back on
    clickAt(rig, screenOf(rig.camera, 7060, 3090));
    clickAt(rig, screenOf(rig.camera, 7120, 3030));
    // 4 px from the first vertex and 2 px from the anchor: both inside.
    clickAt(rig, anchor + const Offset(2, 0));
    final p =
        payloadOf(s.document, ofKind(s.document, EntityKind.polyline).single);
    expect(isClosedPolyline(p), isTrue);
    expect(p.coords[6], isNot(kAnchorX));
  });

  test('PL9 Escape with three vertices placed is byte-identical (M-05l)', () {
    final s = drawScene();
    final rig = drawRig(s.document, PolylineTool());
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7010, 3020));
    clickAt(rig, screenOf(rig.camera, 7060, 3090));
    clickAt(rig, screenOf(rig.camera, 7120, 3030));
    rig.tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.escape,
            logicalKey: LogicalKeyboardKey.escape,
            timeStamp: Duration.zero),
        rig.context);
    expect(snapshot(s.document), before);
  });
}
