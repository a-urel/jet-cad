// Spec 14a T9, T11: an entity owned by an instance (an ATTRIB: a table's
// number) is picked as its instance, a drag that starts on it moves the
// instance, and deleting the instance deletes it in the same undo step.
//
// The fixture is not degenerate: the instance sits off the origin, turned
// 37 degrees and mirrored, and its ATTRIB lies in the middle of a 1000-wide
// square, 500 from every line, so a pick there can only find the ATTRIB.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart'
    show kPickRadiusPixels;
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';

const KeyDownEvent _deleteDown = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.delete,
    logicalKey: LogicalKeyboardKey.delete,
    timeStamp: Duration.zero);

/// `translate(4000, -2500) · rotate(37°) · mirror x · translate(-500, -500)`.
final Transform2 kTablePlacement = Transform2.translation(4000, -2500)
    .multiply(Transform2.rotation(37 * math.pi / 180))
    .multiply(Transform2.scale(-1, 1))
    .multiply(Transform2.translation(-500, -500));

/// A synthetic pointer sample through [camera] (`select_tool_test.dart`'s
/// `ev`, copied).
ToolPointerEvent ev(CameraController camera, Offset screen,
        {int buttons = kPrimaryButton}) =>
    ToolPointerEvent(
      screen: screen,
      world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
      pointer: 1,
      buttons: buttons,
      shift: false,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
    );

/// A square table definition, one instance of it at [kTablePlacement] on a
/// layer of its own (not layer 0), [parent] or the root holding it, and an
/// ATTRIB `"12"` the instance owns at the square's centre, on layer 0, as
/// the app makes one (spec 14a T8).
final class _Table {
  _Table(this.doc, {Handle? parent}) {
    tables = addLayer(doc, 'Tables');
    definition = addDefinition(doc, 'Table');
    addEntity(doc, definition, EntityKind.polyline,
        [0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0], []);
    instance = addInstance(doc, definition, kTablePlacement,
        parent: parent, layer: tables);
    label = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: label,
        owner: instance,
        kind: EntityKind.attrib,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byBlockLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByBlockColor(),
        lineweight: kByBlock,
        transparency: kByBlock,
        flags: 0,
        text: '12',
        tag: 'TABLE',
        textStyle: ReservedHandles.standardTextStyle,
        textAttrs:
            packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.middle),
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([500, 500]),
        scalars: Float64List.fromList([200, 0]),
      ),
    ));
  }

  final DraftDocument doc;
  late final Handle tables;
  late final Handle definition;
  late final Handle instance;
  late final Handle label;

  /// The label's anchor in world space (under the root; a [parent] group
  /// adds its own transform).
  Vector2 get labelWorld => kTablePlacement.transformPoint(Vector2(500, 500));
}

/// Records every command [doc]'s dispatcher executes, in order, without
/// changing it (the slot is free in these tests).
List<DraftCommand> _record(DraftDocument doc) {
  final out = <DraftCommand>[];
  doc.commands.expander = (c) {
    out.add(c);
    return c;
  };
  addTearDown(() => doc.commands.expander = null);
  return out;
}

/// The handles [c]'s leaf commands remove, in order: `E` for an entity,
/// `N` for a node.
List<String> _removals(DraftCommand c) => switch (c) {
      CompoundCommand(:final children) => [
          for (final child in children) ..._removals(child)
        ],
      RemoveEntityCommand(:final handle) => ['E${handle.value}'],
      RemoveNodeCommand(:final handle) => ['N${handle.value}'],
      _ => const [],
    };

DraftDocument _doc() => DraftDocument.empty(measurer: MetricModelMeasurer());

/// World (4000, -2500) lands on screen (400, 250) at a scale of 0.1.
CameraController _camera() => cameraAt(0.1, Offset.zero);

Offset _screenOf(CameraController camera, Vector2 world) {
  final s = camera.value.worldToScreen(world);
  return Offset(s.x, s.y);
}

void main() {
  test('IA1 a pick on the number resolves to its instance (M-14a-6)', () {
    final doc = _doc();
    final t = _Table(doc);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(t.labelWorld, 5, const QueryFilter.picking(), hit),
        isTrue);
    expect(hit.entity, t.label, reason: 'premise: only the number is there');
    expect(resolveHit(hit, doc), SelectionKey.root(t.instance));
  });

  test('IA2 a number inside a group resolves to the group, as before', () {
    final doc = _doc();
    final shift = Transform2.translation(-700, 300);
    final group = addGroup(doc, doc.rootHandle, shift);
    final t = _Table(doc, parent: group);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    final world = shift.transformPoint(t.labelWorld);
    expect(index.pickInto(world, 5, const QueryFilter.picking(), hit), isTrue);
    expect(hit.entity, t.label, reason: 'premise: only the number is there');
    expect(resolveHit(hit, doc), SelectionKey.root(group));
  });

  test('IA3 a drag that starts on the number moves the table (F-14)', () {
    final doc = _doc();
    final t = _Table(doc);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = _camera();
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tool = SelectTool();
    final start = _screenOf(camera, t.labelWorld);

    tool.onPointerDown(ev(camera, start), ctx);
    tool.onPointerMove(ev(camera, start + const Offset(10, 0)), ctx);
    expect(tool.dragKind, DragKind.move);
    tool.onPointerMove(ev(camera, start + const Offset(50, 0)), ctx);
    tool.onPointerUp(ev(camera, start + const Offset(50, 0)), ctx);

    expect(selection.keys, {SelectionKey.root(t.instance)});
    final moved = (doc.tree[t.instance]! as InstanceNode).transform;
    expect(moved.e, closeTo(kTablePlacement.e + 500, 1e-9));
    expect(moved.f, closeTo(kTablePlacement.f, 1e-9));
    final slot = doc.entities.slotOf(t.label)!;
    expect(doc.entities.ownerAt(slot), t.instance);
    expect(doc.geometry.read(doc.entities.geomIndexAt(slot)).coords, [500, 500],
        reason: 'the number moves with its table, not by itself');
  });

  group('delete (M-14a-5)', () {
    late DraftDocument doc;
    late _Table t;
    late SpatialIndex index;
    late SelectionController selection;
    late ToolContext ctx;

    setUp(() {
      doc = _doc();
      t = _Table(doc);
      index = SpatialIndex(doc);
      selection = SelectionController(doc);
      ctx = ToolContext(
          document: doc, index: index, camera: _camera(), selection: selection);
    });
    tearDown(() {
      selection.dispose();
      index.dispose();
    });

    test('IA4 the instance and its number go in one step; undo returns both',
        () {
      selection.replace([SelectionKey.root(t.instance)]);
      final depth = doc.commands.undoDepth;
      final executed = _record(doc);

      SelectTool().onKey(_deleteDown, ctx);

      expect(_removals(executed.single),
          ['E${t.label.value}', 'N${t.instance.value}'],
          reason: 'the number before its table (T9)');

      expect(doc.tree[t.instance], isNull);
      expect(doc.entities.slotOf(t.label), isNull);
      expect(doc.validate(), isEmpty);
      expect(doc.commands.undoDepth, depth + 1);

      doc.commands.undo();
      final slot = doc.entities.slotOf(t.label)!;
      expect(doc.entities.ownerAt(slot), t.instance);
      expect(doc.entities.textAt(slot), '12');
      expect(doc.validate(), isEmpty);

      doc.commands.redo();
      expect(doc.entities.slotOf(t.label), isNull);
      expect(doc.validate(), isEmpty);
    });

    test('IA5 an instance inside a deleted group takes its number too', () {
      final group =
          addGroup(doc, doc.rootHandle, Transform2.translation(-900, 1200));
      final def = addDefinition(doc, 'Stool');
      addEntity(doc, def, EntityKind.circle, [190, 190], [190]);
      final inner = addInstance(doc, def, kTablePlacement, parent: group);
      final innerLabel = addEntity(
          doc, inner, EntityKind.line, [100, 100, 300, 100], [],
          layer: ReservedHandles.layerZero);
      selection.replace([SelectionKey.root(group)]);
      final executed = _record(doc);

      SelectTool().onKey(_deleteDown, ctx);

      final order = _removals(executed.single);
      expect(order.indexOf('E${innerLabel.value}'),
          lessThan(order.indexOf('N${inner.value}')),
          reason: 'the number before its table (T9)');
      expect(doc.tree[group], isNull);
      expect(doc.tree[inner], isNull);
      expect(doc.entities.slotOf(innerLabel), isNull);
      expect(doc.validate(), isEmpty);
      doc.commands.undo();
      expect(doc.entities.ownerAt(doc.entities.slotOf(innerLabel)!), inner);
    });

    test(
        'IA6 a selection holding the number and its table deletes once '
        '(M-14a-19)', () {
      // Only a file or a host can make the number's own key now; the
      // delete must not remove it twice and roll back.
      selection
          .replace([SelectionKey.root(t.label), SelectionKey.root(t.instance)]);

      SelectTool().onKey(_deleteDown, ctx);

      expect(doc.tree[t.instance], isNull);
      expect(doc.entities.slotOf(t.label), isNull);
      expect(selection.isEmpty, isTrue);
      expect(doc.validate(), isEmpty);
    });

    test(
        'IA7 the same when the number\'s handle is below its table\'s (its '
        'key is deleted first)', () {
      final early = doc.handleSeed.next();
      final def = addDefinition(doc, 'Bench');
      addEntity(doc, def, EntityKind.line, [0, 0, 1500, 0], []);
      final bench = addInstance(doc, def, kTablePlacement);
      addEntity(doc, bench, EntityKind.line, [700, 100, 800, 100], [],
          handle: early);
      expect(early.value < bench.value, isTrue, reason: 'premise');
      selection.replace([SelectionKey.root(early), SelectionKey.root(bench)]);
      final depth = doc.commands.undoDepth;

      SelectTool().onKey(_deleteDown, ctx);

      expect(doc.tree[bench], isNull);
      expect(doc.entities.slotOf(early), isNull);
      expect(doc.commands.undoDepth, depth + 1);
      expect(doc.validate(), isEmpty);
    });

    test(
        'IA8 a table whose number needs a capability the permissions lack '
        'stays whole and selected; another key still goes', () {
      final def = addDefinition(doc, 'Planter');
      addEntity(doc, def, EntityKind.circle, [250, 250], [250]);
      final planter = addInstance(doc, def, Transform2.translation(-3000, 1800),
          layer: t.tables);
      doc.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: false, structure: true);
      selection
          .replace([SelectionKey.root(t.instance), SelectionKey.root(planter)]);

      SelectTool().onKey(_deleteDown, ctx);

      expect(doc.tree[planter], isNull);
      expect(doc.tree[t.instance], isNotNull);
      expect(doc.entities.slotOf(t.label), isNotNull);
      expect(selection.keys, {SelectionKey.root(t.instance)});
      expect(doc.validate(), isEmpty);
    });

    test(
        'IA9 a group and an instance inside it, the instance\'s handle the '
        'lower, delete in one step', () {
      final early = doc.handleSeed.next();
      final group =
          addGroup(doc, doc.rootHandle, Transform2.translation(2500, -700));
      final inner = addInstance(doc, t.definition, kTablePlacement,
          parent: group, handle: early);
      final innerLabel = addEntity(
          doc, inner, EntityKind.line, [200, 200, 400, 200], [],
          layer: ReservedHandles.layerZero);
      selection.replace([SelectionKey.root(group), SelectionKey.root(inner)]);
      final depth = doc.commands.undoDepth;

      SelectTool().onKey(_deleteDown, ctx);

      expect(doc.commands.undoDepth, depth + 1);
      expect(doc.tree[group], isNull);
      expect(doc.tree[inner], isNull);
      expect(doc.entities.slotOf(innerLabel), isNull);
      expect(doc.validate(), isEmpty);
    });
  });
}
