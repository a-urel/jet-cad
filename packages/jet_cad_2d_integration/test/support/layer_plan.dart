// P-6's layer fixture (jet_cad_floor_plan/test/support/layer_fixture.dart), as a plan file (3a Task 26): layers A (ACI 1), B (ACI 5, locked), C (ACI 3, hidden), the box of four walls on A in rotated groups at the corpus far origin, a door on B, optionally a room on A and a dimension on B; and the picker's extras (a layer D, a line, a region, a symbol on A).
//
// Every object is created as a tool creates it -- one compound: its group,
// its parameters and its `ObjectLayer` -- into a [planWith] document (the
// plan library's registration, system and DASHED record), so the layers
// and objects are not undo steps of the controller that opens the text.
// The kit's own copy (its layer tests' ToolContext and clicks) is
// jet_cad_2d_kit_architecture/test/support/layer_fixture.dart.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'plans.dart';

/// P-6's layers and the objects added on them so far, by handle: the
/// handles live on in the plan file a controller opens.
final class LayerPlan {
  LayerPlan(this.place, this.a, this.b, this.c);

  final Placement place;

  /// `A` (ACI 1), `B` (ACI 5, locked) and `C` (ACI 3, hidden).
  final Handle a, b, c;

  final List<Handle> walls = <Handle>[];
  final List<Handle> openings = <Handle>[];
  Handle? room;
  Handle? dimension;

  Vector2 at(double x, double y) => place.at(x, y);
}

/// [create] (a tool's creation compound for object [h]) with
/// `SetComponentCommand<ObjectLayer>(h, ObjectLayer(layer))` appended, as
/// every parametric tool now commits it (spec 12b D2).
CompoundCommand onLayer(CompoundCommand create, Handle h, Handle layer) =>
    CompoundCommand([
      ...create.children,
      SetComponentCommand<ObjectLayer>(h, ObjectLayer(layer)),
    ], label: create.label);

/// The group [h] at [at] (default the identity) and its [params], one
/// compound, on [layer].
Handle addObjectOn<T extends Component>(
    DraftDocument doc, T params, Handle layer,
    {Transform2? at}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(onLayer(
      CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: at ?? Transform2.identity(),
            children: const [])),
        SetComponentCommand<T>(h, params),
      ], label: 'Add object'),
      h,
      layer));
  return h;
}

/// P-6's layers on [doc], at [place].
LayerPlan layersOn(DraftDocument doc, {Placement place = corpusGroups}) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  Handle add(String name, int aci, {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    )));
    return handle;
  }

  final a = add('A', 1);
  final b = add('B', 5, locked: true);
  final c = add('C', 3, visible: false);
  return LayerPlan(place, a, b, c);
}

/// Adds [walls] (plan millimetres) to [l], wall `k` in its own rotated
/// group `groupFor(place, k)` when the placement says so, each on [layer].
/// Returns their handles, also appended to `l.walls`.
List<Handle> addWallsOn(
    DraftDocument doc, LayerPlan l, List<W> walls, Handle layer) {
  final out = <Handle>[];
  for (final w in walls) {
    final k = l.walls.length;
    final g = l.place.groups ? groupFor(l.place, k) : Transform2.identity();
    final inv = g.invert();
    final s = inv.transformPoint(l.at(w.sx, w.sy));
    final e = inv.transformPoint(l.at(w.ex, w.ey));
    final h = addObjectOn(doc, WallParams(s.x, s.y, e.x, e.y, w.t, w.j), layer,
        at: g);
    l.walls.add(h);
    out.add(h);
  }
  return out;
}

/// P-6's app fixture: [boxWalls] on `A`; a 900 mm door on `B`, hosted by
/// the first wall, centred 2,750 along it; with [room], a room on `A` seeded
/// inside the box; with [dimension], an aligned dimension on `B` from the
/// first wall's start to its end (right faces), 650 off.
LayerPlan layerFixture(DraftDocument doc,
    {Placement place = corpusGroups, bool room = true, bool dimension = true}) {
  final l = layersOn(doc, place: place);
  addWallsOn(doc, l, boxWalls, l.a);
  l.openings.add(addObjectOn(
      doc,
      OpeningParams(l.walls[0], 2750, 900, OpeningKind.door,
          swing: SwingSide.left),
      l.b));
  if (room) {
    final seed = l.at(5250.5, 2750.25);
    l.room = addObjectOn(doc, RoomParams(seed.x, seed.y, 'Hall'), l.a);
  }
  if (dimension) {
    l.dimension = addObjectOn(
        doc,
        DimensionParams(AttachedEnd(l.walls[0], 0, WallSide.right),
            AttachedEnd(l.walls[0], 1, WallSide.right), DimKind.aligned, 650),
        l.b);
  }
  return l;
}

/// A drafted line on [layer] from plan point ([x1], [y1]) to ([x2],
/// [y2]), as the Line tool adds it: one command. Returns its handle.
Handle addLineOn(DraftDocument doc, LayerPlan l, Handle layer, double x1,
    double y1, double x2, double y2) {
  final s = l.at(x1, y1), e = l.at(x2, y2);
  final add = addDrafted(
      doc,
      EntityKind.line,
      GeometryPayload(
          coords: Float64List.fromList([s.x, s.y, e.x, e.y]),
          scalars: Float64List(0)),
      layer: layer);
  doc.commands.execute(add);
  return add.record.handle;
}

/// A drafted region on [layer] — a circle's boundary and its fill, as the
/// Circle tool adds a filled one — centred at plan point ([x], [y]), and a
/// second fill naming the same boundary, also on [layer] (a file can hold
/// one; spec 12b S-8 moves every fill of a boundary).
({Handle fill, Handle boundary, Handle secondFill}) addRegionOn(
    DraftDocument doc,
    LayerPlan l,
    Handle layer,
    double x,
    double y,
    double r) {
  final c = l.at(x, y);
  final region = addDraftedRegion(
      doc,
      EntityKind.circle,
      GeometryPayload(
          coords: Float64List.fromList([c.x, c.y]),
          scalars: Float64List.fromList([r])),
      layer: layer)!;
  doc.commands.execute(region);
  final boundary = region.boundary.handle;
  final second = AddEntityCommand(
      record: draftRecord(
          doc.handleSeed.next(), doc.rootHandle, EntityKind.fill,
          layer: layer, color: const IndexedColor(4)),
      payload: GeometryPayload(
          coords: Float64List(0),
          scalars: Float64List.fromList([boundary.value.toDouble()])));
  doc.commands.execute(second);
  return (
    fill: region.fill.handle,
    boundary: boundary,
    secondFill: second.record.handle
  );
}

/// A symbol as the library makes one: a definition whose line is on
/// layer 0, an instance of it at the root on [layer] at plan point ([x],
/// [y]), turned a little, and an ATTRIB on layer 0 owned by the instance.
({Handle definition, Handle instance, Handle attrib}) addSymbolOn(
    DraftDocument doc, LayerPlan l, Handle layer, double x, double y) {
  Handle leaf(
      Handle owner, EntityKind kind, List<double> coords, List<double> scalars,
      {String text = ''}) {
    final add = AddEntityCommand(
        record: draftRecord(doc.handleSeed.next(), owner, kind,
            layer: ReservedHandles.layerZero, text: text),
        payload: GeometryPayload(
            coords: Float64List.fromList(coords),
            scalars: Float64List.fromList(scalars)));
    doc.commands.execute(add);
    return add.record.handle;
  }

  final definition = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'Table ${definition.toHex()}',
      basePoint: Vector2(40, 30),
      children: const []));
  leaf(definition, EntityKind.line, [10, 10, 610, 340], const []);
  final at = l.at(x, y);
  final instance = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform:
          Transform2.translation(at.x, at.y).multiply(Transform2.rotation(0.4)),
      definition: definition,
      layer: layer)));
  final attrib =
      leaf(instance, EntityKind.attrib, [90, 60], [4, 0], text: 'TAG');
  return (definition: definition, instance: instance, attrib: attrib);
}

/// Entity [h]'s stored layer.
Handle layerOf(DraftDocument doc, Handle h) =>
    doc.entities.layerAt(doc.entities.slotOf(h)!);

/// Object [h]'s `ObjectLayer` component, or null.
Handle? objectLayerOf(DraftDocument doc, Handle h) =>
    doc.components.get<ObjectLayer>(h)?.layer;

/// Moves object [h] to [layer], as the picker will: one
/// `SetComponentCommand<ObjectLayer>`, one undo step.
void moveObject(DraftDocument doc, Handle h, Handle layer) => doc.commands
    .execute(SetComponentCommand<ObjectLayer>(h, ObjectLayer(layer)));

/// The app's picker fixture (apps/floor_planner/test/layers/
/// layer_picker_test.dart:33-65, `PickerDoc`): P-6 without room and
/// dimension, a visible layer D, a line, a region with a second fill and a
/// symbol, all on A; `wall` and `door` are `l.walls[0]` and
/// `l.openings[0]`.
({String json, LayerPlan l, Handle d, Handle line, Handle wall, Handle door})
    pickerPlan() {
  late LayerPlan l;
  late Handle d, line;
  final json = planWith((doc) {
    l = layerFixture(doc, room: false, dimension: false);
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    d = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: d,
        name: 'D',
        color: const IndexedColor(2),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency)));
    line = addLineOn(doc, l, l.a, 1250.5, 3400.25, 4100.75, 3650.5);
    addRegionOn(doc, l, l.a, 7300.5, 2100.25, 350);
    addSymbolOn(doc, l, l.a, 2600.5, 1800.75);
  });
  return (
    json: json,
    l: l,
    d: d,
    line: line,
    wall: l.walls[0],
    door: l.openings[0]
  );
}
