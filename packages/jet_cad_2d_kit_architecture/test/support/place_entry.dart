// A library entry placed by the engine's commands (3a Task 23). The plan
// library's placer (jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart:
// 52-102 `definitionForEntry`, 126-177 `placeSymbol`) is not exported, and a
// kit's tests may not import the plan library (tool/ci/check_kit_deps.dart),
// so the kit's tests place through this copy of its path for a placement
// without a unit label: the definition copied on first use (reused by key and
// version afterwards), then a root-level instance on the drawing layer under
// the contract's `placementTransform`, or under [transform] when given (an
// attachment's). Not copied: the leaf-equality and unit checks of the plan's
// reuse and its `#n` definition-name suffix (a test document holds only
// copies this helper made) and the unit label (no `units` index here). The
// instance style is the placer's (`InstanceStyle`, copied below; 3a Task 28
// for symbol_end_to_end_test's coloured instance).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The instance fields a placement imposes on the symbol's BYBLOCK
/// contents (jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart:27-44,
/// copied). The defaults are [InstanceNode]'s own.
final class InstanceStyle {
  final DraftColor color;
  final int lineweight;
  final int transparency;
  final Handle linetype;
  final double linetypeScale;

  const InstanceStyle({
    this.color = const ByBlockColor(),
    this.lineweight = kByBlock,
    this.transparency = kByBlock,
    this.linetype = ReservedHandles.byBlockLinetype,
    this.linetypeScale = 1.0,
  });
}

/// The definition of [doc] that copies [entry] (same key and version), or
/// null.
Handle? copyOfEntry(DraftDocument doc, SymbolEntry entry) {
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h);
    if (c != null &&
        c.key == entry.symbol.key &&
        c.version == entry.symbol.version &&
        doc.tree.definition(h) != null) {
      return h;
    }
  }
  return null;
}

/// The command that places [entry] in [doc] at [at] ([quarterTurns]
/// counter-clockwise, [mirrored]), or under [transform] when given, with
/// [style]'s instance fields; one
/// compound labelled `Place <name>`, every handle allocated here, in the
/// placer's order (the definition, its leaves, the instance). [doc] must
/// have the contract's components registered.
CompoundCommand placeEntry(
  DraftDocument doc,
  SymbolEntry entry, {
  required Vector2 at,
  int quarterTurns = 0,
  bool mirrored = false,
  Transform2? transform,
  InstanceStyle style = const InstanceStyle(),
}) {
  final commands = <DraftCommand>[];
  var definition = copyOfEntry(doc, entry);
  if (definition == null) {
    final copy = doc.handleSeed.next();
    commands
      ..add(AddDefinitionCommand(Definition(
        handle: copy,
        name: entry.id,
        basePoint: entry.definition.basePoint,
        children: const [],
      )))
      ..add(SetComponentCommand<SymbolComponent>(copy, entry.symbol));
    final unit = entry.unit;
    if (unit != null) {
      commands.add(SetComponentCommand<UnitComponent>(copy, unit));
    }
    for (final leaf in entry.leaves) {
      commands.add(AddEntityCommand(
        record:
            leaf.record.copyWith(handle: doc.handleSeed.next(), owner: copy),
        payload: leaf.payload,
      ));
    }
    definition = copy;
  }
  commands.add(AddNodeCommand(InstanceNode(
    handle: doc.handleSeed.next(),
    parent: doc.rootHandle,
    definition: definition,
    layer: drawingLayer(doc),
    color: style.color,
    lineweight: style.lineweight,
    transparency: style.transparency,
    linetype: style.linetype,
    linetypeScale: style.linetypeScale,
    transform: transform ??
        placementTransform(
          at: at,
          basePoint: entry.definition.basePoint,
          quarterTurns: quarterTurns,
          mirrored: mirrored,
        ),
  )));
  return CompoundCommand(commands, label: 'Place ${entry.symbol.name}');
}
