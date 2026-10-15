// A unit's label (spec 2b S2 "The label"): the text rule (today's table
// number rule, jet_cad_floor_plan/lib/src/tables/table_numbers.dart:5-46,
// renamed), the label record and command of a placed unit
// (table_label.dart:106-179), and how a unit's label and top are read. The
// stamp, the height and the payload are the kit's (Task 3).
//
// No Flutter import: Dart over package:jet_cad_2d and the kit's model.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show
        boxOfLeaves,
        kUnitLabelTag,
        kUnitLabelTextAttrs,
        unitLabelHeight,
        unitLabelPayload;
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A label's longest length, in UTF-16 code units.
const int kUnitLabelMaxLength = 8;

/// Why a text is not a unit label, as a value a UI words.
enum UnitLabelProblem {
  /// Empty, or longer than [kUnitLabelMaxLength] code units, trimmed.
  length,

  /// A control character, a line break among them.
  control,
}

/// Whether the UTF-16 code unit [u] is a control character: below U+0020
/// (C0, a line break among them) or U+007F to U+009F (DEL and C1). The one
/// rule [unitLabelProblem] and the unit data limits share.
bool isControlCodeUnit(int u) => u < 0x20 || (u >= 0x7F && u <= 0x9F);

/// Why [raw], trimmed, is not a unit label, or null when it is one:
/// non-empty, at most [kUnitLabelMaxLength] code units, no control
/// character.
UnitLabelProblem? unitLabelProblem(String raw) {
  final n = raw.trim();
  if (n.isEmpty || n.length > kUnitLabelMaxLength) {
    return UnitLabelProblem.length;
  }
  if (n.codeUnits.any(isControlCodeUnit)) return UnitLabelProblem.control;
  return null;
}

/// [unitLabelProblem] in English, or null (diagnostic messages; the UI's
/// words are `PlanStrings.labelProblem`).
String? unitLabelError(String raw) => switch (unitLabelProblem(raw)) {
      null => null,
      UnitLabelProblem.length => '1 to $kUnitLabelMaxLength characters',
      UnitLabelProblem.control => 'No line breaks or control characters',
    };

/// The label record of a placed unit: owned by [instance], on layer 0 (so
/// it follows the instance's layer, spec 12b S-2), BYBLOCK style, the
/// standard text style, tag `UNIT`, text [text].
EntityRecord unitLabelRecord(
        {required Handle handle,
        required Handle instance,
        required String text}) =>
    EntityRecord(
      handle: handle,
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
      text: text,
      tag: kUnitLabelTag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: kUnitLabelTextAttrs,
    );

/// The lowest-handle leaf [owner] owns, or null. O(entities): at command
/// or document-change rate, never per frame. With [leavesByOwner]
/// ([DraftDocument.leavesByOwner], shared by a caller asking for many
/// owners in one pass), only [owner]'s own leaves are visited.
/// (`tables/table_label.dart:155-181`, `CommandTarget` for `DraftDocument`.)
({EntityKind kind, GeometryPayload payload})? firstLeafOf(
    CommandTarget target, Handle owner,
    [Map<Handle, List<int>>? leavesByOwner]) {
  final entities = target.entities;
  int? best;
  final slots = leavesByOwner == null
      ? entities.liveSlots
      : leavesByOwner[owner] ?? const <int>[];
  for (final slot in slots) {
    if (entities.ownerAt(slot) != owner) continue;
    if (best == null ||
        entities.handleAt(slot).value < entities.handleAt(best).value) {
      best = slot;
    }
  }
  if (best == null) return null;
  return (
    kind: entities.kindAt(best),
    payload: target.geometry.read(entities.geomIndexAt(best)),
  );
}

/// The top of a definition whose [leaves] are given ascending by handle
/// (spec S2, `SymbolDefinitionRef.top`): the first leaf's box when it is a
/// closed polyline or a circle, else the leaves' box (`boxOfLeaves`);
/// empty for none.
Aabb2 unitTopOfLeaves(List<(EntityKind, GeometryPayload)> leaves) {
  if (leaves.isNotEmpty) {
    final (kind, p) = leaves.first;
    if (kind == EntityKind.circle) {
      final r = p.scalars[0];
      return Aabb2.raw(
          p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
    }
    if (kind == EntityKind.polyline && isClosedPolyline(p)) {
      final b = boxOfLeaves([leaves.first]);
      if (b != null) return Aabb2.raw(b.left, b.front, b.right, b.back);
    }
  }
  final b = boxOfLeaves(leaves);
  return b == null
      ? Aabb2.empty()
      : Aabb2.raw(b.left, b.front, b.right, b.back);
}

/// The box a placed unit's label height reads (spec S2: today's stamp,
/// `tables/table_label.dart:22-44`): the first leaf's box when it is a
/// circle or a polyline, open or closed; else empty, which gives the full
/// height. Not the unit's top ([unitTopOfLeaves], spec S2's rule for
/// `SymbolDefinitionRef.top` and `UnitInfo.top`): today's label reads an
/// open polyline's box and never the other leaves (controller ruling
/// R-21; the placer, the unit API's new label and the fixtures read this).
Aabb2 placedLabelTop(List<(EntityKind, GeometryPayload)> leaves) {
  if (leaves.isEmpty) return Aabb2.empty();
  final (kind, p) = leaves.first;
  switch (kind) {
    case EntityKind.circle:
      final r = p.scalars[0];
      return Aabb2.raw(
          p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
    case EntityKind.polyline:
      final c = p.coords;
      var minX = c[0], maxX = c[0], minY = c[1], maxY = c[1];
      for (var i = 2; i + 1 < c.length; i += 2) {
        if (c[i] < minX) minX = c[i];
        if (c[i] > maxX) maxX = c[i];
        if (c[i + 1] < minY) minY = c[i + 1];
        if (c[i + 1] > maxY) maxY = c[i + 1];
      }
      return Aabb2.raw(minX, minY, maxX, maxY);
    default:
      return Aabb2.empty();
  }
}

/// [placedLabelTop] of [definition]'s first leaf in [target].
/// O(entities), at command rate.
Aabb2 placedLabelTopOf(CommandTarget target, Handle definition) {
  final leaf = firstLeafOf(target, definition);
  return leaf == null
      ? Aabb2.empty()
      : placedLabelTop([(leaf.kind, leaf.payload)]);
}

/// The command that adds [text] as the label of [instance], an instance of
/// [definition] placed by [placement]: anchored at the definition's base
/// point, the height of its top, stamped upright. Allocates one handle.
AddEntityCommand addUnitLabelCommand(
  DraftDocument doc, {
  required Handle instance,
  required Handle definition,
  required Transform2 placement,
  required String text,
}) {
  final def = doc.tree.definition(definition);
  return AddEntityCommand(
    record: unitLabelRecord(
        handle: doc.handleSeed.next(), instance: instance, text: text),
    payload: unitLabelPayload(
      anchor: def?.basePoint ?? Vector2.zero(),
      height: unitLabelHeight(placedLabelTopOf(doc, definition)),
      instanceToWorld: placement,
    ),
  );
}

/// The lowest-handle `UNIT` ATTRIB [instance] owns, or null. O(entities),
/// at command rate.
Handle? unitLabelOf(CommandTarget target, Handle instance) {
  final e = target.entities;
  Handle? best;
  for (final slot in e.liveSlots) {
    if (e.ownerAt(slot) != instance ||
        e.kindAt(slot) != EntityKind.attrib ||
        e.tagAt(slot) != kUnitLabelTag) {
      continue;
    }
    final h = e.handleAt(slot);
    if (best == null || h.value < best.value) best = h;
  }
  return best;
}
