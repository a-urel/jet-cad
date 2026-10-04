// The symbol placer (spec 09 D6): one command that copies a library symbol
// into a document on first use and adds an instance of it.
//
// No Flutter import and no `dart:io`: this file is Dart over
// `package:jet_cad_2d` only. It writes no table record (a symbol uses only
// reserved handles, spec decision 4) and never touches `DraftDocument.purge`.

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_index.dart';
import '../tables/table_label.dart';
import '../tables/table_numbers.dart';
import 'seating_component.dart';
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

/// `translation(at) · rotation · scale(mirrored ? -1 : 1, 1) ·
/// translation(-basePoint)`: the definition's base point lands on [at]
/// (spec F-2), and a mirror flips the **local** x axis whatever the
/// rotation.
///
/// The rotation is given one of two ways, never both (an [ArgumentError],
/// in release builds too):
/// - [quarterTurns] counter-clockwise, taken modulo 4 (negative allowed),
///   with exact cosine and sine from a table (0 and ±1, never `6e-17`);
/// - [rotation], a unit vector `(cos, sin)` used exactly as given (spec 09c
///   D5: a wall face's `t`).
///
/// Neither is no turn. The quarter-turn form is the [rotation] form at its
/// table entry, so the two give the same bytes. No stored component is
/// `-0.0` in either form, so a placement stores clean numbers in a file.
Transform2 placementTransform({
  required Vector2 at,
  required Vector2 basePoint,
  int? quarterTurns,
  (double, double)? rotation,
  bool mirrored = false,
}) {
  if (quarterTurns != null && rotation != null) {
    throw ArgumentError(
        'placementTransform takes quarterTurns or rotation, not both');
  }
  final (cos, sin) = rotation ?? _quarterTurn(quarterTurns ?? 0);
  final m = Transform2.translation(at.x, at.y)
      .multiply(Transform2(cos, sin, -sin, cos, 0, 0))
      .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
      .multiply(Transform2.translation(-basePoint.x, -basePoint.y));
  double clean(double v) => v == 0 ? 0.0 : v;
  return Transform2(
      clean(m.a), clean(m.b), clean(m.c), clean(m.d), clean(m.e), clean(m.f));
}

/// The exact `(cos, sin)` of [quarterTurns] counter-clockwise quarter turns.
(double, double) _quarterTurn(int quarterTurns) => const [
      (1.0, 0.0),
      (0.0, 1.0),
      (-1.0, 0.0),
      (0.0, -1.0)
    ][((quarterTurns % 4) + 4) % 4];

/// The definition a placement of [entry] in [doc] uses, and the commands
/// that make it when it is a copy (none when one is reused): the one
/// reuse-or-copy path, shared by [placeSymbol] and a size change (spec 09c
/// D7, V-7). A definition is reused when it carries the entry's key and
/// version, still exists, agrees on seating (spec 14 S2) and is leaf-equal
/// to the entry; otherwise the definition is copied with fresh handles,
/// allocated here. The entry's leaves are ascending by handle (R5-7).
({Handle definition, List<DraftCommand> commands}) definitionForEntry(
    DraftDocument doc, SymbolEntry entry) {
  assert(_ascending(entry.leaves),
      'the entry\'s leaves must be ascending by handle (spec 09c R5-7)');
  final commands = <DraftCommand>[];
  Handle? definition;
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h);
    // A component can outlive its definition in a file saved before 09c
    // (removing a definition now takes its components, spec D11, but leaves
    // such orphans alone, and purge never clears a component), so the
    // definition must still exist. Its seating must agree with the entry's
    // too (spec 14 S2, review F-5): a hand-edited or foreign plan's copy
    // without seats would make every new placement of a table unservable,
    // so such a copy is not reused; one is made beside it.
    if (c != null &&
        c.key == entry.key &&
        c.version == entry.version &&
        doc.tree.definition(h) != null &&
        doc.components.get<SeatingComponent>(h)?.seats == entry.seats &&
        isLeafEqual(doc, h, entry)) {
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
    // A servable symbol stays servable in the plan (spec 14 S2).
    final seats = entry.seats;
    if (seats != null) {
      commands.add(SetComponentCommand<SeatingComponent>(
          copy, SeatingComponent(seats: seats)));
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
  return (definition: definition, commands: commands);
}

bool _ascending(List<({EntityRecord record, GeometryPayload payload})> leaves) {
  for (var i = 1; i < leaves.length; i++) {
    if (leaves[i - 1].record.handle.value >= leaves[i].record.handle.value) {
      return false;
    }
  }
  return true;
}

/// The command that places [entry] in [doc] at [at]. Labelled
/// `Place <name>`; it does **not** execute.
///
/// Every handle is allocated from `doc.handleSeed` here, once (spec F-8), so
/// a redo reuses them. A definition already in [doc] with the entry's key and
/// version is reused when it is leaf-equal to the entry ([isLeafEqual], spec
/// 09c D10), the first such in ascending handle; otherwise the definition is
/// copied with fresh handles for it and for every leaf, the leaves in the
/// library's ascending order so draw order is stable, under the first free
/// name of `key@version`, `key@version#2`, `#3`, ...
///
/// A servable entry becomes a numbered table (spec 14a T13): when
/// [numbered], its label, with the plan's next number, is added after the
/// instance and stamped upright for the placement. The palette's thumbnails
/// pass `numbered: false` (F-15). The number is fixed here, with the
/// handles, so a redo replays the same one.
CompoundCommand placeSymbol(
  DraftDocument doc,
  SymbolEntry entry, {
  required Vector2 at,
  int quarterTurns = 0,
  bool mirrored = false,
  Transform2? transform,
  InstanceStyle style = const InstanceStyle(),
  bool numbered = true,
}) {
  final made = definitionForEntry(doc, entry);
  final commands = <DraftCommand>[...made.commands];
  final definition = made.definition;

  final instance = doc.handleSeed.next();
  final placement = transform ??
      placementTransform(
        at: at,
        basePoint: entry.definition.basePoint,
        quarterTurns: quarterTurns,
        mirrored: mirrored,
      );
  commands.add(AddNodeCommand(InstanceNode(
    handle: instance,
    parent: doc.rootHandle,
    definition: definition,
    // Spec 12b D7: the instance takes the current layer; the definition's
    // leaves stay on layer 0 (the library's rule) and follow it.
    layer: drawingLayer(doc),
    transform: placement,
    color: style.color,
    lineweight: style.lineweight,
    transparency: style.transparency,
    linetype: style.linetype,
    linetypeScale: style.linetypeScale,
  )));

  if (numbered && entry.seats != null) {
    final first = entry.leaves.isEmpty ? null : entry.leaves.first;
    commands.add(AddEntityCommand(
      record: tableLabelRecord(
        handle: doc.handleSeed.next(),
        instance: instance,
        number: nextTableNumber(TableSurvey.of(doc).numbers),
      ),
      payload: tableLabelPayload(
        anchor: entry.definition.basePoint,
        height: first == null
            ? kTableLabelMaxHeight
            : tableLabelHeight(first.record.kind, first.payload),
        placement: placement,
      ),
    ));
  }

  return CompoundCommand(commands, label: 'Place ${entry.name}');
}

/// Whether the definition [definition] in [doc] is **leaf-equal** to [entry]
/// (spec 09c D10, W-11): what a placement checks before it reuses a
/// definition found by key and version.
///
/// Leaf-equal means: [definition] names a definition; its base point is the
/// entry's; it has no child node; it owns as many live leaves as the entry
/// has; and, pairing its leaves ascending by handle with the entry's (which
/// [SymbolEntry] holds ascending by handle), every [EntityRecord] field but
/// `handle`, `owner` and `geomIndex` (the placement rewrites the first two,
/// `AddEntityCommand` the third) and every payload coordinate and scalar
/// are equal. Every comparison is exact `==`: these are stored values, not
/// geometric decisions. `==` equates `-0.0` and `0.0`, which D10 accepts.
///
/// Pure: reads [doc], writes nothing. O(entities) per call, never on a
/// frame path (a placement is built once per click).
bool isLeafEqual(DraftDocument doc, Handle definition, SymbolEntry entry) {
  final def = doc.tree.definition(definition);
  if (def == null) return false;
  final base = entry.definition.basePoint;
  if (def.basePoint.x != base.x || def.basePoint.y != base.y) return false;
  if (doc.tree.childNodesOf(def.children).isNotEmpty) return false;

  final entities = doc.entities;
  final slots = [
    for (final slot in entities.liveSlots)
      if (entities.ownerAt(slot) == definition) slot,
  ]..sort((a, b) =>
      entities.handleAt(a).value.compareTo(entities.handleAt(b).value));
  if (slots.length != entry.leaves.length) return false;

  for (var i = 0; i < slots.length; i++) {
    final want = entry.leaves[i];
    final got = entities.read(slots[i]);
    // Every field but the three a placement rewrites, through the record's
    // own `==`, so a field added to `EntityRecord` is compared here too.
    final comparable = got.copyWith(
      handle: want.record.handle,
      owner: want.record.owner,
      geomIndex: want.record.geomIndex,
    );
    if (comparable != want.record) return false;
    if (doc.geometry.read(got.geomIndex) != want.payload) return false;
  }
  return true;
}
