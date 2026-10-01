import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// The render package's layer fixture (plan 12b P-6). It mirrors the
/// engine's `test/support/layer_fixture.dart`, which a render test cannot
/// import, and adds what the render half needs: root-level lines and a
/// group that carries an `ObjectLayer`, as a parametric object's group does.
///
/// Layers `A` (ACI 1), `B` (ACI 5, locked) and `C` (ACI 3, hidden) beside a
/// visible layer 0. No colour is ACI 7, and the hidden layer is not layer 0.
///
/// - A root group under a turned, moved transform holds one line on each of
///   layer 0, `A`, `B` and `C`, all away from the origin.
/// - Two root lines, on layer 0 and on `A`, away from the origin.
/// - An object: a root group under a turned, moved transform, carrying
///   `ObjectLayer(A)`, whose one child (a polyline) is on `A` — what the
///   regeneration's stamp leaves (spec 12b D2).
/// - A symbol: definition `Table` (base point off the origin) holds a line
///   and a circle on layer 0 and a nested instance, on layer 0, of
///   definition `Leg`, whose one line is on layer 0 too — the library's
///   rule, every symbol leaf on layer 0. One instance of `Table` sits at the
///   root on `A`, turned a quarter and moved; it owns an ATTRIB on layer 0.
/// - A drafted region (a circle's fill and boundary) on `A`.
///
/// Every geometry is built by direct command execution; the history is
/// cleared at the end, so a test's first undo is its own. Text is laid out
/// by [MetricModelMeasurer], so the ATTRIB has a real glyph box.
class LayerFixture {
  LayerFixture() : doc = DraftDocument.empty(measurer: MetricModelMeasurer()) {
    a = _addLayer('A', 1);
    b = _addLayer('B', 5, locked: true);
    c = _addLayer('C', 3, visible: false);

    group = _group(groupTransform);
    lineZero = _line(group, ReservedHandles.layerZero, 100, 0, 180, 10);
    lineA = _line(group, a, 100, 40, 180, 50);
    lineB = _line(group, b, 100, 80, 180, 90);
    lineC = _line(group, c, 100, 120, 180, 130);

    rootZero = _line(
        doc.rootHandle, ReservedHandles.layerZero, -420, -260, -330, -210);
    rootA = _line(doc.rootHandle, a, -420, -160, -330, -110);

    object = _group(objectTransform);
    doc.commands
        .execute(SetComponentCommand<ObjectLayer>(object, ObjectLayer(a)));
    objectChild = _entity(object, a, EntityKind.polyline,
        [0, 0, 120, 0, 120, 70, 0, 70, 0, 0], const []);

    leg = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: leg,
      name: 'Leg',
      basePoint: Vector2(3, -2),
      children: const [],
    ));
    legLine = _line(leg, ReservedHandles.layerZero, 5, 5, 25, 15);

    table = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: table,
      name: 'Table',
      basePoint: Vector2(40, 30),
      children: const [],
    ));
    tableLine = _line(table, ReservedHandles.layerZero, 10, 10, 70, 40);
    tableCircle = _entity(
        table, ReservedHandles.layerZero, EntityKind.circle, [-30, 20], [6]);
    nested = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: nested,
      parent: table,
      transform: nestedTransform,
      definition: leg,
      layer: ReservedHandles.layerZero,
    )));

    instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: instanceTransform,
      definition: table,
      layer: a,
    )));
    attrib = _entity(instance, ReservedHandles.layerZero, EntityKind.attrib,
        [90, 60], [4, 0],
        text: 'TAG');

    final region = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.circle,
      boundaryPayload: GeometryPayload(
        coords: Float64List.fromList([-600, 420]),
        scalars: Float64List.fromList([30]),
      ),
      layer: a,
      fillColor: const IndexedColor(4),
      boundaryColor: const ByLayerColor(),
    );
    doc.commands.execute(region);
    regionFill = region.fill.handle;
    regionBoundary = region.boundary.handle;

    doc.commands.clearHistory();
  }

  final DraftDocument doc;
  late final Handle a;
  late final Handle b;
  late final Handle c;

  late final Handle group;
  late final Handle lineZero;
  late final Handle lineA;
  late final Handle lineB;
  late final Handle lineC;

  late final Handle rootZero;
  late final Handle rootA;

  late final Handle object;
  late final Handle objectChild;

  late final Handle leg;
  late final Handle legLine;
  late final Handle table;
  late final Handle tableLine;
  late final Handle tableCircle;
  late final Handle nested;
  late final Handle instance;
  late final Handle attrib;

  late final Handle regionFill;
  late final Handle regionBoundary;

  static final Transform2 groupTransform = Transform2.translation(500, -300)
      .multiply(Transform2.rotation(math.pi / 6));
  static final Transform2 objectTransform =
      Transform2.translation(-150, 640).multiply(Transform2.rotation(-0.35));
  static final Transform2 instanceTransform = Transform2.translation(1200, 800)
      .multiply(Transform2.rotation(math.pi / 2));
  static final Transform2 nestedTransform =
      Transform2.translation(60, -25).multiply(Transform2.rotation(0.4));

  LayerRecord layer(Handle handle) => doc.tables.layers[handle]!;

  /// [handle]'s record with [visible] and [locked] replaced.
  LayerRecord withState(Handle handle, {bool? visible, bool? locked}) =>
      layer(handle).copyWith(visible: visible, locked: locked);

  /// Replaces [record] in the table directly: no command, no history, no
  /// `DocChange` — only the tables' revision moves.
  void writeLayer(LayerRecord record) {
    doc.tables.layers
      ..remove(record.handle)
      ..add(record);
  }

  Handle _addLayer(String name, int aci,
      {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers.add(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    ));
    return handle;
  }

  Handle _group(Transform2 transform) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: handle,
      parent: doc.rootHandle,
      transform: transform,
      children: const [],
    )));
    return handle;
  }

  Handle _line(Handle owner, Handle layer, double x1, double y1, double x2,
          double y2) =>
      _entity(owner, layer, EntityKind.line, [x1, y1, x2, y2], const []);

  Handle _entity(Handle owner, Handle layer, EntityKind kind,
      List<double> coords, List<double> scalars,
      {String text = ''}) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: owner,
        kind: kind,
        layer: layer,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
        text: text,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars),
      ),
    ));
    return handle;
  }
}
