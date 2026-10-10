// The editor fixture (Slice 4 plan, Global constraints; built in Task 4,
// read by Tasks 4 to 6): the startup flat -- walls, openings, a separator,
// rooms with their labels, dimensions, a page -- with, inside its living
// room, the embedding fixture's hand-made table (its box off its base
// point) placed as `1` (turned 30 degrees) and `2` (mirrored at exactly 90
// degrees) beside the north wall, `7` and ` 7 ` sharing a number, an
// unnumbered table, `5` on a hidden and `L` on a locked layer; a root-level
// group of two lines, turned and off the origin; a free line; a TEXT; and a
// chair, a non-table furniture symbol. [editorCamera] is 0.37 px/mm, y up,
// panned: never the identity. Tests compute screen points by its forward
// transform ([canvasOf]), never from the code under test.
//
// At 0.37 px/mm the flat (14 x 9 m) is wider than any test window, so the
// camera frames its living room's north-east part in an [kEditorSurface]
// window: the north wall and its inner face (a room edge), the east wall
// with a window opening, the column (a free-standing wall), the separator,
// the overall depth's dimension beyond the east wall, and everything this
// fixture adds. The parquet's hairlines lie under all of it.
import 'package:flutter/painting.dart' show Size;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer, ViewportTransform;
import 'package:jet_cad_floor_plan/src/startup_plan.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart' show entryOf;
import 'embedding_fixture.dart';
import 'zone_fixture.dart' show addZoneLayer;

export 'embedding_fixture.dart'
    show
        EmbeddingTable,
        canvasOf,
        embeddingBox,
        embeddingPlacement,
        embeddingTable,
        kEmbeddingHidden,
        kEmbeddingLocked;

/// The window every editor test runs in: the view fills it.
const Size kEditorSurface = Size(2400, 1500);

/// A chair: not servable (no seats), its base point (0, 0) off its seat.
const FurnitureSymbol editorChair = FurnitureSymbol(
  key: 'test.chair',
  name: 'Test chair',
  category: 'Tests',
  tags: ['chair', 'test'],
  baseX: 0,
  baseY: 0,
  shapes: [
    PolylineShape([(50, 50), (500, 50), (500, 430), (50, 430)], closed: true),
    PolylineShape([(50, 430), (500, 430), (500, 500), (50, 500)], closed: true),
  ],
);

/// The fixture's tables, in placement order (ascending by handle), each
/// [embeddingTable] placed by its transform; world boxes (the transform of
/// [embeddingBox]) as the comments give them:
/// - `1`: turned 30 degrees, x 21,710..22,703, y 15,777..16,696, 54 mm
///   below the north wall's inner face (16,750);
/// - `2`: mirrored (det < 0) at exactly 90 degrees, x 22,900..23,500,
///   y 15,900..16,700, beside the same wall;
/// - `7`: turned 60 degrees, x 22,704..23,623, y 14,710..15,703;
/// - ` 7 `: mirrored at -150 degrees, x 23,847..24,840, y 14,527..15,446;
/// - an unnumbered table at 15 degrees, x 21,736..22,664, y 14,684..15,471;
/// - `5`: at 45 degrees, on the hidden layer;
/// - `L`: mirrored at 120 degrees, on the locked layer, x 24,477..25,396,
///   y 15,660..16,653.
final List<EmbeddingTable> editorTables = [
  EmbeddingTable('1', embeddingPlacement(21650, 15800, 30), degrees: 30),
  const EmbeddingTable('2', Transform2(0, 1, 1, 0, 23100, 15600),
      degrees: 90, sy: -1),
  EmbeddingTable('7', embeddingPlacement(22900, 14550, 60), degrees: 60),
  EmbeddingTable(' 7 ', embeddingPlacement(25000, 15250, -150, sy: -1),
      degrees: -150, sy: -1),
  EmbeddingTable(null, embeddingPlacement(21550, 14800, 15), degrees: 15),
  EmbeddingTable('5', embeddingPlacement(24600, 13350, 45),
      degrees: 45, layer: kEmbeddingHidden),
  EmbeddingTable('L', embeddingPlacement(25200, 15500, 120, sy: -1),
      degrees: 120, sy: -1, layer: kEmbeddingLocked),
];

/// The chair's placement: turned 10 degrees at (23,800, 16,100).
final Transform2 editorChairPlacement = embeddingPlacement(23800, 16100, 10);

/// The group's transform: turned 20 degrees at (21,600, 13,450); its two
/// lines, in its own space, cross: (100, 100)-(900, 400) and
/// (100, 400)-(900, 100).
final Transform2 editorGroupPlacement = embeddingPlacement(21600, 13450, 20);

/// The free line, in the world.
final (Vector2, Vector2) editorFreeLine =
    (Vector2(22700, 13400), Vector2(23300, 14300));

/// The TEXT's insertion point, its cap height and its words.
final Vector2 editorTextAt = Vector2(21700, 14250);
const double editorTextHeight = 200;
const String editorTextWords = 'Bar';

/// The column (spec 10 D23's tenth wall, from the startup plan): a 400 x
/// 400 square, its south-west corner a wall's end corner with nothing else
/// within 70 mm.
final Vector2 editorColumnCorner = Vector2(23500, 13800);

/// The editor fixture's plan, as a file. Built over a measurer of its own,
/// which is cleared after the encoding.
String editorPlanJson() {
  final measurer = FlutterTextMeasurer();
  final doc = startupPlan(measurer);
  final zero = ReservedHandles.layerZero;
  final hidden = addZoneLayer(doc, kEmbeddingHidden, visible: false);
  final locked = addZoneLayer(doc, kEmbeddingLocked, locked: true);
  final entry = entryOf(embeddingTable);
  for (final t in editorTables) {
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
  // The group of two lines.
  final group = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: editorGroupPlacement,
      children: const [])));
  for (final (a, b) in [
    (Vector2(100, 100), Vector2(900, 400)),
    (Vector2(100, 400), Vector2(900, 100)),
  ]) {
    doc.commands.execute(AddEntityCommand(
        record: draftRecord(doc.handleSeed.next(), group, EntityKind.line,
            layer: zero),
        payload: linePayload(a, b)));
  }
  // The free line and the TEXT.
  doc.commands.execute(addDrafted(
      doc, EntityKind.line, linePayload(editorFreeLine.$1, editorFreeLine.$2),
      layer: zero));
  doc.commands.execute(addDrafted(
      doc, EntityKind.text, textPayload(editorTextAt, editorTextHeight),
      layer: zero, text: editorTextWords));
  // The chair.
  doc.commands.execute(placeSymbol(doc, entryOf(editorChair),
      at: Vector2(editorChairPlacement.e, editorChairPlacement.f),
      transform: editorChairPlacement,
      numbered: false));
  doc.commands.clearHistory();
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  measurer.clear();
  return json;
}

/// The camera every editor test runs under: 0.37 px/mm, y flipped, panned
/// so world (21,400, 17,070) is the canvas's top left. In [kEditorSurface]
/// the canvas shows x 21,400..26,416 and y 13,200..17,070.
ViewportTransform editorCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -7918, 6315.9));
