// The symbol placer (spec 09 D6): one command that copies a library symbol
// into a document on first use and adds an instance of it.
//
// No Flutter import and no `dart:io`: this file is Dart over
// `package:jet_cad_2d` only. It writes no table record (a symbol uses only
// reserved handles, spec decision 4) and never touches `DraftDocument.purge`.

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_component.dart';
import 'symbol_library.dart';

/// The instance fields a placement imposes on the symbol's BYBLOCK contents.
/// The defaults are [InstanceNode]'s own.
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

/// `translation(at) · rotation(quarterTurns · 90°) · scale(mirrored ? -1 : 1,
/// 1) · translation(-basePoint)`: the definition's base point lands on [at]
/// (spec F-2), and a mirror flips the **local** x axis whatever the turns.
///
/// Quarter turns use exact cosine and sine (0 and ±1, never `6e-17`), taken
/// modulo 4 (negative allowed), and no stored component is `-0.0`, so a
/// placement stores clean numbers in a file's bytes.
Transform2 placementTransform({
  required Vector2 at,
  required Vector2 basePoint,
  int quarterTurns = 0,
  bool mirrored = false,
}) {
  final q = ((quarterTurns % 4) + 4) % 4;
  const cos = [1.0, 0.0, -1.0, 0.0];
  const sin = [0.0, 1.0, 0.0, -1.0];
  final m = Transform2.translation(at.x, at.y)
      .multiply(Transform2(cos[q], sin[q], -sin[q], cos[q], 0, 0))
      .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
      .multiply(Transform2.translation(-basePoint.x, -basePoint.y));
  double clean(double v) => v == 0 ? 0.0 : v;
  return Transform2(
      clean(m.a), clean(m.b), clean(m.c), clean(m.d), clean(m.e), clean(m.f));
}

/// The command that places [entry] in [doc] at [at]. Labelled
/// `Place <name>`; it does **not** execute.
///
/// Every handle is allocated from `doc.handleSeed` here, once (spec F-8), so
/// a redo reuses them. A definition already in [doc] with the entry's key and
/// version is reused; otherwise the definition is copied with fresh handles
/// for it and for every leaf, the leaves in the library's ascending order so
/// draw order is stable.
CompoundCommand placeSymbol(
  DraftDocument doc,
  SymbolEntry entry, {
  required Vector2 at,
  int quarterTurns = 0,
  bool mirrored = false,
  InstanceStyle style = const InstanceStyle(),
}) {
  final commands = <DraftCommand>[];

  Handle? definition;
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h);
    // A component can outlive its definition in a file saved before 09c
    // (removing a definition now takes its components, spec D11, but leaves
    // such orphans alone, and purge never clears a component), so the
    // definition must still exist.
    if (c != null &&
        c.key == entry.key &&
        c.version == entry.version &&
        doc.tree.definition(h) != null) {
      definition = h;
      break;
    }
  }

  if (definition == null) {
    final copy = doc.handleSeed.next();
    final taken = {for (final d in doc.tree.definitions) d.name};
    final base = '${entry.key}@${entry.version}';
    var name = base;
    for (var n = 2; taken.contains(name); n++) {
      name = '$base#$n';
    }
    commands
      ..add(AddDefinitionCommand(Definition(
        handle: copy,
        name: name,
        basePoint: entry.definition.basePoint,
        children: const [],
      )))
      ..add(SetComponentCommand<SymbolComponent>(
        copy,
        SymbolComponent(
          key: entry.key,
          name: entry.name,
          category: entry.category,
          tags: entry.tags,
          version: entry.version,
        ),
      ));
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
    // Spec 12b D7: the instance takes the current layer; the definition's
    // leaves stay on layer 0 (the library's rule) and follow it.
    layer: drawingLayer(doc),
    transform: placementTransform(
      at: at,
      basePoint: entry.definition.basePoint,
      quarterTurns: quarterTurns,
      mirrored: mirrored,
    ),
    color: style.color,
    lineweight: style.lineweight,
    transparency: style.transparency,
    linetype: style.linetype,
    linetypeScale: style.linetypeScale,
  )));

  return CompoundCommand(commands, label: 'Place ${entry.name}');
}
