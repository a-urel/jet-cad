// The fill tests' fixture (3a Task 28, R-16, ruling IA-R6): 2b's
// (jet_cad_2d_plan/test/service/paint/unit_fill_test.dart:66-245) with
// today's teal room and its table R restored
// (jet_cad_floor_plan/test/service/table_fill_test.dart:85-86, 183-252):
// one plan, every table turned and mirrored, 38 m and more off the origin.
// Most tables are the embedding fixture's hand-made top (an asymmetric
// quadrilateral, its box off the definition's origin, which is the base
// point and where the number label sits, outside the top); B and K are a
// round top whose circle is off the definition's origin too. A, B and C
// are coloured; U is coloured and unnumbered, K coloured on a locked layer,
// H coloured on a hidden layer, M carries the unknown name "magenta", N
// has no colour, and R is coloured inside a teal room. Hues teal and
// purple.
//
// Built over the public libraries: the tables placed and labelled by hand
// (`units.dart`), the walls through `plans.dart`'s `addWall`, and the
// colours written into the saved text as the plan file stores them
// (`"jetcad.unit_colour": {"<handle>": {"color": "<name>"}}`,
// jet_cad_2d_plan/lib/src/units/unit_components.dart:178-200), since
// `UnitColour` is the plan library's own.
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogCircle, CatalogSymbol;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'plans.dart' show addWall, planWith;
import 'units.dart';

/// A servable round top, its circle off the definition's origin (the base
/// point, where the number sits, 670 mm from the centre).
final CatalogSymbol roundTable = CatalogSymbol(
  key: 'fx.round.off',
  name: 'Off-centre round table',
  category: 'Tests',
  tags: const ['table', 'test'],
  unit: tableUnit(4),
  base: (0, 0),
  shapes: const [CatalogCircle((600, 300), 400)],
);

const int teal = 0x00897B, purple = 0x8E24AA;
const int whitePaper = 0xFFFFFF;

/// `round(255 * 0.35)`, `round(255 * 0.6)`, and a room tint's alpha
/// (transparency 204 of 255).
const int alphaDefault = 89, alphaThemed = 153, tintAlpha = 51;

/// One table of the fixture: its label (null: unnumbered), its top, its base
/// point, its turn (always mirrored), its layer and its stored colour name.
typedef Spec = ({
  String key,
  String? label,
  bool round,
  double x,
  double y,
  double deg,
  String? layer,
  String? color,
});

const String hiddenLayer = 'Hidden', lockedLayer = 'Locked';

const List<Spec> specs = [
  (
    key: 'A',
    label: 'A',
    round: false,
    x: 46000,
    y: -27500,
    deg: 120,
    layer: null,
    color: 'teal'
  ),
  (
    key: 'B',
    label: 'B',
    round: true,
    x: 49000,
    y: -27500,
    deg: 25,
    layer: null,
    color: 'purple'
  ),
  (
    key: 'C',
    label: 'C',
    round: false,
    x: 46000,
    y: -30500,
    deg: 30,
    layer: null,
    color: 'teal'
  ),
  (
    key: 'N',
    label: 'N',
    round: false,
    x: 49000,
    y: -30500,
    deg: -40,
    layer: null,
    color: null
  ),
  (
    key: 'U',
    label: null,
    round: false,
    x: 46000,
    y: -33500,
    deg: 15,
    layer: null,
    color: 'teal'
  ),
  (
    key: 'K',
    label: 'K',
    round: true,
    x: 49000,
    y: -33500,
    deg: 60,
    layer: lockedLayer,
    color: 'purple'
  ),
  (
    key: 'H',
    label: 'H',
    round: false,
    x: 39500,
    y: -27500,
    deg: 45,
    layer: hiddenLayer,
    color: 'teal'
  ),
  (
    key: 'M',
    label: 'M',
    round: false,
    x: 42500,
    y: -27500,
    deg: -20,
    layer: null,
    color: 'magenta'
  ),
  (
    key: 'R',
    label: 'R',
    round: false,
    x: 39000,
    y: -33300,
    deg: 10,
    layer: null,
    color: 'purple'
  ),
];

Spec spec(String key) => specs.singleWhere((s) => s.key == key);

/// The table's placement: turned [Spec.deg] and mirrored, its base point on
/// ([Spec.x], [Spec.y]).
Transform2 placementOf(Spec s) => embeddingPlacement(s.x, s.y, s.deg, sy: -1);

/// A world point inside [s]'s top, well clear of its edges and of its
/// number (at the base point, outside the top): the quadrilateral's (650,
/// 50), 250 mm and more from every edge; the circle's centre.
Vector2 insideTop(Spec s) => placementOf(s)
    .transformPoint(s.round ? Vector2(600, 300) : Vector2(650, 50));

/// The teal room's tint, clear of every table and of the room's labels.
final Vector2 tintSample = Vector2(43000, -34300);

/// The fixture as a plan file over [architectureKit] and [fxKit]: a 1:50
/// page, a teal room (four 200 mm walls, 38-44 m by -35 to -31 m), then
/// [specs] in order, their colours stored as the plan stores them.
String fillJson() {
  final colours = <String, String>{};
  final json = planWith((doc) {
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        PageComponent(
            originX: 37000,
            originY: -36200,
            background: 0xFFFFFFFF,
            gridVisible: false,
            snapToGrid: false)));
    void wall(double sx, double sy, double ex, double ey) {
      doc.commands.execute(addWall(doc, doc.handleSeed.next(), Vector2(sx, sy),
          Vector2(ex, ey), 200, Justification.centre,
          at: Transform2.identity()));
    }

    wall(38000, -35000, 44000, -35000);
    wall(44000, -35000, 44000, -31000);
    wall(44000, -31000, 38000, -31000);
    wall(38000, -31000, 38000, -35000);
    final room = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: room,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      SetComponentCommand<RoomParams>(
          room, const RoomParams(41500, -32000, 'Dining', color: 'teal')),
    ], label: 'Add room'));
    final layers = {
      hiddenLayer: addLayer(doc, hiddenLayer, visible: false),
      lockedLayer: addLayer(doc, lockedLayer, locked: true),
    };
    for (final s in specs) {
      final instance = placeUnit(doc, s.round ? roundTable : embeddingTable,
          transform: placementOf(s), layer: layers[s.layer]);
      if (s.label case final label?) labelUnit(doc, instance, label);
      if (s.color case final name?) colours['${instance.value}'] = name;
    }
  }, kits: [architectureKit, fxKit()]);
  final plan = (jsonDecode(json) as Map).cast<String, Object?>();
  final components =
      Map<String, Object?>.of((plan['components']! as Map).cast());
  components['jetcad.unit_colour'] = {
    for (final MapEntry(key: h, value: name) in colours.entries)
      h: {'color': name},
  };
  plan['components'] = {
    for (final typeId in components.keys.toList()..sort())
      typeId: components[typeId],
  };
  return jsonEncode(plan);
}

/// [rgb] at [alpha] over the opaque [paper], straight alpha, per channel
/// `round(a * s + (1 - a) * p)`.
int composite(int rgb, int alpha, int paper) {
  final a = alpha / 255;
  var out = 0;
  for (final shift in const [16, 8, 0]) {
    final s = (rgb >> shift) & 0xFF;
    final p = (paper >> shift) & 0xFF;
    out |= (a * s + (1 - a) * p).round() << shift;
  }
  return out;
}
