@Tags(['golden'])
library;

// One fixture, the same dashed geometry at five zoom levels, so the collapse
// floor's effect is visible as a ladder rather than as a number.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

const Size kGoldenViewport = Size(400, 300);
const Key kCanvasKey = Key('golden-canvas');

/// Six horizontal dashed rules, and one dashed circle, spanning the width.
DraftDocument dashLadderFixture() {
  final doc = DraftDocument.empty();
  final dashed = doc.handleSeed.next();
  doc.tables.linetypes.add(LinetypeRecord(
    handle: dashed,
    name: 'DASHED',
    description: '__ __ __',
    pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
  ));
  for (var i = 0; i < 6; i++) {
    _dashedEntity(doc, dashed, EntityKind.polyline,
        [-500, -60.0 + i * 24, 500, -60.0 + i * 24], const []);
  }
  _dashedEntity(doc, dashed, EntityKind.circle, [0, 0], const [90]);
  return doc;
}

void _dashedEntity(DraftDocument doc, Handle linetype, EntityKind kind,
    List<double> coords, List<double> scalars) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: linetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars)),
  ));
}

Widget _at(DraftDocument doc, double halfSpan) {
  final index = SpatialIndex(doc);
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          key: kCanvasKey,
          width: kGoldenViewport.width,
          height: kGoldenViewport.height,
          child: DraftCanvas(
            document: doc,
            index: index,
            resolver: DocumentStyleResolver(doc),
            camera: CameraController(ViewportTransform.fit(
                Aabb2(
                    Vector2(-halfSpan, -halfSpan), Vector2(halfSpan, halfSpan)),
                kGoldenViewport)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final (name, halfSpan) in const [
    ('1', 60.0),
    ('2', 150.0),
    ('3', 400.0),
    ('4', 1200.0),
    ('5', 4000.0),
  ]) {
    testWidgets('dash ladder rung $name', (tester) async {
      await tester.pumpWidget(_at(dashLadderFixture(), halfSpan));
      await expectLater(
          find.byKey(kCanvasKey), matchesGoldenFile('dash_ladder_$name.png'));
    });
  }
}
