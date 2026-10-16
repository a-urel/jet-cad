// How the sample plans place a restaurant symbol from a `PlanBuild`: a build
// gets no symbol services (the plan library's placer is not exported, and
// the library is read asynchronously), so the symbol is placed by engine
// commands from `restaurantSymbolEntries()`, in the shape the plan library's
// own placer writes: the definition copied on first use (reused by key
// afterwards), one root-level instance on the drawing layer under the
// contract's `placementTransform`, and, for a numbered unit, its `UNIT`
// label (`unitLabelAttrib`) reading the next number in build order.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The sheet's lower-left corner in world millimetres: the plan library's
/// default page (A4 landscape, 1:50), centred on the origin. The samples'
/// positions are measured from it, as the old plans' were.
final Vector2 kSheetMin = Vector2(-7425, -5250);

/// Places restaurant symbols into one document, numbering the units in the
/// order they are placed.
final class TablePlacer {
  TablePlacer(this._doc);

  final DraftDocument _doc;
  final Map<String, Handle> _definitions = {};
  int _next = 1;

  /// Places `[key]@1` so its base point lands [x] mm right and [y] mm up of
  /// the sheet's lower-left corner, turned [quarterTurns] counter-clockwise.
  /// A numbered unit gets the next number. Returns the instance's handle.
  Handle place(String key, double x, double y, {int quarterTurns = 0}) {
    final entry = restaurantSymbolEntries()['$key@1'];
    if (entry == null) throw ArgumentError.value(key, 'key', 'not in the kit');
    final commands = <DraftCommand>[];
    var definition = _definitions[entry.id];
    if (definition == null) {
      final copy = definition = _doc.handleSeed.next();
      _definitions[entry.id] = copy;
      commands
        ..add(AddDefinitionCommand(Definition(
            handle: copy,
            name: entry.id,
            basePoint: entry.definition.basePoint,
            children: const [])))
        ..add(SetComponentCommand<SymbolComponent>(copy, entry.symbol));
      final unit = entry.unit;
      if (unit != null) {
        commands.add(SetComponentCommand<UnitComponent>(copy, unit));
      }
      for (final leaf in entry.leaves) {
        commands.add(AddEntityCommand(
            record: leaf.record
                .copyWith(handle: _doc.handleSeed.next(), owner: copy),
            payload: leaf.payload));
      }
    }
    final transform = placementTransform(
        at: Vector2(kSheetMin.x + x, kSheetMin.y + y),
        basePoint: entry.definition.basePoint,
        quarterTurns: quarterTurns);
    final instance = _doc.handleSeed.next();
    commands.add(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: _doc.rootHandle,
        definition: definition,
        layer: drawingLayer(_doc),
        transform: transform)));
    if (entry.unit?.labelling == UnitLabelling.numbered) {
      final label = unitLabelAttrib('${_next++}',
          instanceToWorld: transform,
          anchor: entry.definition.basePoint,
          top: _labelTop(entry));
      commands.add(AddEntityCommand(
          record: EntityRecord(
              handle: _doc.handleSeed.next(),
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
              text: label.text,
              tag: label.tag,
              textAttrs: label.textAttrs),
          payload: label.payload));
    }
    _doc.commands.execute(
        CompoundCommand(commands, label: 'Place ${entry.symbol.name}'));
    return instance;
  }
}

/// The box the label's height reads: the first leaf's, when it is a circle
/// or a polyline; empty (the full height) otherwise.
Aabb2 _labelTop(SymbolEntry entry) {
  if (entry.leaves.isEmpty) return Aabb2.empty();
  final first = entry.leaves.first;
  if (first.record.kind != EntityKind.circle &&
      first.record.kind != EntityKind.polyline) {
    return Aabb2.empty();
  }
  final b = boxOfLeaves([(first.record.kind, first.payload)]);
  return b == null
      ? Aabb2.empty()
      : Aabb2.raw(b.left, b.front, b.right, b.back);
}
