// The host embedding API's fixture (jet_cad_floor_plan/test/host/
// embedding_fixture.dart), ported for the unit API (2b Task 9): the
// hand-made unit whose box is off its base point, with an asymmetric top;
// copies of it turned 30 degrees, mirrored at 90 degrees, scaled
// non-uniformly (1.5, 0.8) and turned 180 degrees unmirrored, all 40 m off
// the origin; a unit on a hidden and one on a locked layer; two units
// sharing a label, an unlabelled unit and a unit whose corners are not
// finite; and a camera that is not the identity (panned, 0.37 px/mm).
// Tests compute their expectations from [embeddingBox] and each unit's
// [EmbeddingTable.transform] by the forward transform, never from the code
// under test.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'harness.dart' show planText;
import 'unit_editor_fixture.dart'
    show embeddingPlacement, embeddingTable, kEmbeddingHidden, kEmbeddingLocked;
import 'unit_fixtures.dart';

export 'unit_editor_fixture.dart'
    show
        embeddingBox,
        embeddingPlacement,
        embeddingTable,
        kEmbeddingHidden,
        kEmbeddingLocked;

/// One unit of the fixture, as the test knows it.
final class EmbeddingTable {
  const EmbeddingTable(this.label, this.transform,
      {this.degrees = 0,
      this.sx = 1,
      this.sy = 1,
      this.layer = '0',
      this.finite = true});

  /// The label written, or null for an unlabelled unit.
  final String? label;

  /// Definition space to world.
  final Transform2 transform;
  final double degrees, sx, sy;

  /// `0`, [kEmbeddingHidden] or [kEmbeddingLocked].
  final String layer;

  /// Whether its box's corners are finite in the world.
  final bool finite;

  /// The label the plan reads: trimmed, null for none.
  String? get number => label?.trim();
}

/// The fixture's units in placement order (embedding_fixture.dart:82-120).
final List<EmbeddingTable> embeddingTables = [
  EmbeddingTable('1', embeddingPlacement(40000, -27000, 30), degrees: 30),
  const EmbeddingTable('2', Transform2(0, 1, 1, 0, 43000, -27000),
      degrees: 90, sy: -1),
  EmbeddingTable('3', embeddingPlacement(46000, -27000, -20, sx: 1.5, sy: 0.8),
      degrees: -20, sx: 1.5, sy: 0.8),
  EmbeddingTable('4', embeddingPlacement(49000, -27000, 180), degrees: 180),
  EmbeddingTable('5', embeddingPlacement(40000, -31000, 45),
      degrees: 45, layer: kEmbeddingHidden),
  EmbeddingTable('L', embeddingPlacement(43000, -31000, 120, sy: -1),
      degrees: 120, sy: -1, layer: kEmbeddingLocked),
  EmbeddingTable('7', embeddingPlacement(46000, -31000, 60), degrees: 60),
  EmbeddingTable(' 7 ', embeddingPlacement(49000, -31000, -150, sy: -1),
      degrees: -150, sy: -1),
  EmbeddingTable(null, embeddingPlacement(40000, -35000, 15), degrees: 15),
  const EmbeddingTable('9', Transform2(1e306, 0, 0, 1e-306, 43000, -35000),
      sx: 1e306, sy: 1e-306, finite: false),
];

/// The fixture plan, as a plan file over [fxKit]: [tables]
/// ([embeddingTables] by default) on an A4 page at 1:50 from (37,000,
/// -36,200) around them.
String embeddingPlanJson({Iterable<EmbeddingTable>? tables}) =>
    planText([fxKit()], (doc) {
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, PageComponent(originX: 37000, originY: -36200)));
      final hidden = addLayer(doc, kEmbeddingHidden, visible: false);
      final locked = addLayer(doc, kEmbeddingLocked, locked: true);
      for (final t in tables ?? embeddingTables) {
        final h = placeUnit(doc, embeddingTable,
            transform: t.transform,
            layer: switch (t.layer) {
              kEmbeddingHidden => hidden,
              kEmbeddingLocked => locked,
              _ => ReservedHandles.layerZero,
            });
        if (t.label case final label?) addUnitLabel(doc, h, label);
      }
      doc.commands.clearHistory();
    });

/// The camera every call runs under: 0.37 px/mm, y flipped, panned so the
/// units sit near the canvas's top left.
ViewportTransform embeddingCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.5));

/// World ([x], [y]) in the canvas of [camera], by the forward transform.
({double x, double y}) canvasOf(ViewportTransform camera, double x, double y) {
  final m = camera.worldToScreenMatrix;
  return (x: m.a * x + m.c * y + m.e, y: m.b * x + m.d * y + m.f);
}

/// A controller over [embeddingPlanJson] (or [json]) under
/// [embeddingCamera], disposed at tear-down.
PlanController embeddingController({String? json}) {
  final c = PlanController(kits: [fxKit()], json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  c.camera.value = embeddingCamera();
  return c;
}

/// Within a relative 1e-12 of [want], an absolute 1e-12 near 0.
Matcher near(double want) => closeTo(want, 1e-12 * math.max(want.abs(), 1.0));
