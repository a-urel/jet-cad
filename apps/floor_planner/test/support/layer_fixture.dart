// Plan 12b P-6, the app half: a floor plan on layers. Layers `A` (ACI 1),
// `B` (ACI 5, locked) and `C` (ACI 3, hidden) beside a visible layer 0, each
// added by `AddLayerCommand`; a box of four walls on `A`, a door on `B`
// hosted by the first, a room on `A` and a dimension on `B` attached to the
// first wall's two ends. Every object is created as a tool creates it — one
// compound: its group, its parameters and its `ObjectLayer` — and every wall
// sits in its own rotated group at the corpus far origin (`corpusGroups`):
// nothing at the origin, no identity transform where one matters, no ACI 7
// colour, and the hidden layer is not layer 0.
import 'dart:typed_data';

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/separator.dart'
    show ensureDashedLinetype;
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_fixture.dart';

export 'dimension_fixture.dart';

/// A document with P-6's layers and the floor planner's components and
/// parametric system, and the objects added to it so far.
final class LayerDoc {
  LayerDoc._(this.doc, this.place, this.a, this.b, this.c, this.system);

  final DraftDocument doc;
  final Placement place;

  /// `A` (ACI 1), `B` (ACI 5, locked) and `C` (ACI 3, hidden).
  final Handle a, b, c;
  final ParametricSystem system;

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

/// An empty document with P-6's layers, the app's components and the
/// parametric system, at [place]. The layer additions are not undo steps.
LayerDoc layerDoc(
    {Placement place = corpusGroups,
    TextMeasurer measurer = const InsertionPointMeasurer()}) {
  final doc = DraftDocument.empty(measurer: measurer);
  registerAppComponents(doc.components);
  final system = installParametric(doc);
  ensureDashedLinetype(doc);
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
  doc.commands.clearHistory();
  return LayerDoc._(doc, place, a, b, c, system);
}

/// Adds [walls] (plan millimetres) to [l], wall `k` in its own rotated
/// group `groupFor(place, k)` when the placement says so, each on [layer].
/// Returns their handles, also appended to `l.walls`.
List<Handle> addWallsOn(LayerDoc l, List<W> walls, Handle layer) {
  final out = <Handle>[];
  for (final w in walls) {
    final k = l.walls.length;
    final g = l.place.groups ? groupFor(l.place, k) : Transform2.identity();
    final inv = g.invert();
    final s = inv.transformPoint(l.at(w.sx, w.sy));
    final e = inv.transformPoint(l.at(w.ex, w.ey));
    final h = addObjectOn(
        l.doc, WallParams(s.x, s.y, e.x, e.y, w.t, w.j), layer,
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
LayerDoc layerFixture(
    {Placement place = corpusGroups,
    bool room = true,
    bool dimension = true,
    TextMeasurer measurer = const InsertionPointMeasurer()}) {
  final l = layerDoc(place: place, measurer: measurer);
  final doc = l.doc;
  addWallsOn(l, boxWalls, l.a);
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
  doc.commands.clearHistory();
  return l;
}

/// A drafted line on [layer] from plan point ([x1], [y1]) to ([x2],
/// [y2]), as the Line tool adds it: one command. Returns its handle.
Handle addLineOn(
    LayerDoc l, Handle layer, double x1, double y1, double x2, double y2) {
  final s = l.at(x1, y1), e = l.at(x2, y2);
  final add = addDrafted(
      l.doc,
      EntityKind.line,
      GeometryPayload(
          coords: Float64List.fromList([s.x, s.y, e.x, e.y]),
          scalars: Float64List(0)),
      layer: layer);
  l.doc.commands.execute(add);
  return add.record.handle;
}

/// A drafted region on [layer] — a circle's boundary and its fill, as the
/// Circle tool adds a filled one — centred at plan point ([x], [y]), and a
/// second fill naming the same boundary, also on [layer] (a file can hold
/// one; spec 12b S-8 moves every fill of a boundary).
({Handle fill, Handle boundary, Handle secondFill}) addRegionOn(
    LayerDoc l, Handle layer, double x, double y, double r) {
  final doc = l.doc;
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
    LayerDoc l, Handle layer, double x, double y) {
  final doc = l.doc;
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

/// A real [ToolContext] over [doc]: its own index, a camera at 1 pixel per
/// mm (a 10 mm aperture), a selection and snap settings with object snap
/// on, no page (no grid). Everything is disposed at tear-down.
ToolContext toolContextOf(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  final snap = SnapSettings(objectSnap: true);
  addTearDown(() {
    snap.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return ToolContext(
      document: doc,
      index: index,
      camera: camera,
      selection: selection,
      snap: snap);
}

ToolPointerEvent _pointerAt(Vector2 world, {int buttons = 0}) =>
    ToolPointerEvent(
        screen: Offset.zero,
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 1);

/// A hover to world point [world], then a primary press there, with [tool].
void clickWith(Tool tool, ToolContext ctx, Vector2 world) {
  tool.onPointerMove(_pointerAt(world), ctx);
  tool.onPointerDown(_pointerAt(world, buttons: kPrimaryButton), ctx);
}
