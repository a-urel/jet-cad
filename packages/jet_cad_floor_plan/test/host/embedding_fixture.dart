// The host embedding API's fixture (spec 2026-10-09, Testing; Slice 1
// plan, Global constraints), extending the zone fixture's idea: a
// hand-made servable symbol whose box is off its base point, with an
// asymmetric top; copies of it turned 30 degrees, mirrored at 90 degrees,
// scaled non-uniformly (1.5, 0.8) and turned 180 degrees unmirrored, all
// 40 m off the origin; a table on a hidden and one on a locked layer; two
// tables sharing a number, an unnumbered table and a table whose corners
// are not finite; and a camera that is not the identity (panned,
// 0.37 px/mm), set before every call. Tests compute their expectations from
// [embeddingBox] and each table's [EmbeddingTable.transform] by the forward
// transform, never from the code under test.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';
import 'zone_fixture.dart' show addZoneLayer;

/// A hand-made servable symbol (four seats): its top an asymmetric
/// quadrilateral, so a mirror or a turn read wrong moves it; its base point
/// the definition's origin, (0, 0), well outside its box, [embeddingBox].
const FurnitureSymbol embeddingTable = FurnitureSymbol(
  key: 'test.embedding',
  name: 'Test embedding table',
  category: 'Tests',
  tags: ['table', 'test'],
  seats: 4,
  baseX: 0,
  baseY: 0,
  shapes: [
    PolylineShape([(300, -200), (1100, -200), (900, 400), (300, 250)],
        closed: true),
  ],
);

/// [embeddingTable]'s box in definition space, as the test knows it: its
/// centre (700, 100) is not its base point (0, 0).
const Aabb2 embeddingBox = Aabb2.raw(300, -200, 1100, 400);

/// `translate(x, y) · R(theta) · diag(sx, sy)`, written out: the base point
/// (the definition's origin) lands on (x, y).
Transform2 embeddingPlacement(double x, double y, double degrees,
    {double sx = 1, double sy = 1}) {
  final t = degrees * math.pi / 180;
  final cos = math.cos(t), sin = math.sin(t);
  return Transform2(sx * cos, sx * sin, -sy * sin, sy * cos, x, y);
}

/// One table of the fixture, as the test knows it.
final class EmbeddingTable {
  const EmbeddingTable(this.label, this.transform,
      {this.degrees = 0,
      this.sx = 1,
      this.sy = 1,
      this.layer = '0',
      this.finite = true});

  /// The label written, or null for an unnumbered table.
  final String? label;

  /// Definition space to world.
  final Transform2 transform;

  /// The turn, the axis scales and the mirror ([sy] < 0) the transform was
  /// built from.
  final double degrees, sx, sy;

  /// The instance's layer: `0`, [kEmbeddingHidden] or [kEmbeddingLocked].
  final String layer;

  /// Whether its box's corners are finite in the world.
  final bool finite;

  /// The number the plan reads: the label trimmed, null for none.
  String? get number => label?.trim();
}

const String kEmbeddingHidden = 'Hidden';
const String kEmbeddingLocked = 'Locked';

/// The fixture's tables, in placement order (ascending by handle):
/// - `1`: turned 30 degrees;
/// - `2`: mirrored (det < 0) at 90 degrees;
/// - `3`: scaled (1.5, 0.8), turned -20 degrees;
/// - `4`: turned 180 degrees, unmirrored;
/// - `5`: on the hidden layer;
/// - `L`: mirrored at 120 degrees, on the locked layer;
/// - `7`, twice: at 60 degrees, and mirrored at -150 degrees;
/// - an unnumbered table at 15 degrees;
/// - `9`: x scaled by 1e306, y by 1e-306 (det 1): no corner is finite.
/// Every one stands 40 m and more off the origin, 3 to 4 m from the next.
final List<EmbeddingTable> embeddingTables = [
  EmbeddingTable('1', embeddingPlacement(40000, -27000, 30), degrees: 30),
  EmbeddingTable('2', embeddingPlacement(43000, -27000, 90, sy: -1),
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

/// The fixture plan, as a file: [embeddingTables] on a page around them.
String embeddingPlanJson() {
  final doc = plan();
  // A page around the tables (A4 landscape at 1:50, 14,850 x 10,500 mm, from
  // its lower left): (37,000..51,850, -36,200..-25,700) holds every finite
  // table's box, (39,929..48,841, -35,116..-25,900); a view's first fit
  // frames it, not the extents table 9 makes infinite.
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, PageComponent(originX: 37000, originY: -36200)));
  final hidden = addZoneLayer(doc, kEmbeddingHidden, visible: false);
  final locked = addZoneLayer(doc, kEmbeddingLocked, locked: true);
  final entry = entryOf(embeddingTable);
  for (final t in embeddingTables) {
    doc.commands.execute(placeSymbol(doc, entry,
        at: Vector2(t.transform.e, t.transform.f),
        transform: t.transform,
        numbered: t.label != null));
    final info = TableSurvey.of(doc).tables.last;
    if (t.label case final label?) {
      doc.commands
          .execute(SetEntityTextCommand(info.label!, label, kTableLabelTag));
    }
    switch (t.layer) {
      case kEmbeddingHidden:
        doc.commands.execute(SetInstanceLayerCommand(info.instance, hidden));
      case kEmbeddingLocked:
        doc.commands.execute(SetInstanceLayerCommand(info.instance, locked));
    }
  }
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  return json;
}

/// The camera every call runs under: 0.37 px/mm, y flipped, panned so the
/// tables sit near the canvas's top left.
ViewportTransform embeddingCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.5));

/// World [p] in the canvas of [camera], by the forward transform.
({double x, double y}) canvasOf(ViewportTransform camera, double x, double y) {
  final m = camera.worldToScreenMatrix;
  return (x: m.a * x + m.c * y + m.e, y: m.b * x + m.d * y + m.f);
}
