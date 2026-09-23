import 'dart:ui' show Size;

import 'package:flutter/widgets.dart' show Listenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/polyline_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf;
import '../support/selection_fixture.dart' show addEntity;
import '../support/spy_canvas.dart';

List<RecordedCall> frame(int extraEntities) {
  final s = drawScene();
  for (var i = 0; i < extraEntities; i++) {
    addEntity(s.document, s.document.rootHandle, EntityKind.line,
        [7000.0 + i * 0.3, 3200, 7000.0 + i * 0.3, 3260], []);
  }
  final rig = drawRig(s.document, PolylineTool(), objectSnap: false);
  for (final (x, y) in const [
    (7010.0, 3020.0),
    (7040.0, 3080.0),
    (7090.0, 3030.0),
    (7130.0, 3090.0),
    (7170.0, 3040.0),
  ]) {
    clickAt(rig, screenOf(rig.camera, x, y));
  }
  hoverAt(rig, screenOf(rig.camera, 7200, 3100));
  final painter = SelectionOverlayPainter(
    selection: rig.selection,
    tools: rig.tools,
    camera: rig.camera,
    outlines: rig.outlines,
    repaint: Listenable.merge([rig.selection, rig.tools, rig.camera]),
  );
  final spy = SpyCanvas();
  painter.paint(spy, const Size(800, 600));
  return spy.calls;
}

void main() {
  test(
      'OV1 a five-vertex pending polyline is one drawPath in the preview '
      'colour (D12, M-05s)', () {
    final calls = frame(0);
    final preview = [
      for (final c in calls)
        if (c.color?.toARGB32() == kPreviewColor.toARGB32()) c,
    ];
    expect(preview.where((c) => c.name == 'drawPath'), hasLength(1));
    expect(preview.where((c) => c.name == 'drawLine'), isEmpty);
  });

  test('OV2 the overlay draws the same calls at 10 and at 1,000 entities', () {
    List<String> names(List<RecordedCall> calls) =>
        [for (final c in calls) c.name];
    expect(names(frame(1000)), names(frame(10)));
  });
}
