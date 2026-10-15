// The Symbol section's model (spec 09c D7, revision 5): which instance it
// shows, its library entry and size family, its rotation, and the commands
// its rows commit -- Rotate, Mirror and Change size. The widgets are the
// Selection panel's; everything here is Dart over the document.
// Ported to the kit model: a symbol is a jetcad.symbol definition (the kit's SymbolComponent), a servable one carries a UnitComponent, and a size family is SymbolComponent.family (the K2 field) instead of a family: tag.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show
        SymbolBox,
        SymbolComponent,
        SymbolEntry,
        UnitComponent,
        boxOfDefinition,
        boxOfEntry,
        isOrthonormal;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../symbols/plan_symbol.dart';
import '../symbols/symbol_placer.dart' show definitionForEntry;

/// [handle] is a root-level instance whose definition carries a
/// [SymbolComponent] (D7's rule, F-11's for a symbol).
bool isSymbolInstance(DraftDocument doc, Handle handle) {
  final node = doc.tree[handle];
  return node is InstanceNode &&
      node.parent == doc.rootHandle &&
      doc.tree.definition(node.definition) != null &&
      doc.components.get<SymbolComponent>(node.definition) != null;
}

/// [instance]'s definition carries a [UnitComponent]: a table (V-4, as
/// `TableSurvey` reads it).
bool isServableInstance(DraftDocument doc, Handle instance) {
  final node = doc.tree[instance];
  return node is InstanceNode &&
      doc.components.get<UnitComponent>(node.definition) != null;
}

/// [instance]'s library entry (V-5): the exact `key@version` of its
/// definition's [SymbolComponent], else the key's highest version; null
/// when the library has neither.
SymbolEntry? entryOfInstance(
    Iterable<SymbolEntry> entries, DraftDocument doc, Handle instance) {
  final node = doc.tree[instance];
  if (node is! InstanceNode) return null;
  final c = doc.components.get<SymbolComponent>(node.definition);
  if (c == null) return null;
  SymbolEntry? highest;
  for (final e in entries) {
    if (e.symbol.key != c.key) continue;
    if (e.symbol.version == c.version) return e;
    if (highest == null || e.symbol.version > highest.symbol.version) {
      highest = e;
    }
  }
  return highest;
}

final Expando<Map<String, List<SymbolEntry>>> _families =
    Expando<Map<String, List<SymbolEntry>>>('families');

/// The members of [entry]'s size family (V-4, V-5): every entry of [entries]
/// whose symbol has its `family`, one per key (its highest version), none
/// servable, sorted by width then depth. Empty when [entry] has no family.
/// Memoised per entries list and family: the panel rebuilds on every hover.
List<SymbolEntry> familyMembers(List<SymbolEntry> entries, SymbolEntry entry) {
  final family = entry.symbol.family;
  if (family == null) return const [];
  final memo = _families[entries] ??= {};
  return memo[family] ??= () {
    final byKey = <String, SymbolEntry>{};
    for (final e in entries) {
      if (e.unit != null || e.symbol.family != family) continue;
      final seen = byKey[e.symbol.key];
      if (seen == null || e.symbol.version > seen.symbol.version) {
        byKey[e.symbol.key] = e;
      }
    }
    final members = [
      for (final e in byKey.values)
        if (boxOfEntry(e) != null) e
    ]..sort((a, b) {
        final x = boxOfEntry(a)!, y = boxOfEntry(b)!;
        final w = x.width.compareTo(y.width);
        return w != 0 ? w : x.depth.compareTo(y.depth);
      });
    return List<SymbolEntry>.unmodifiable(members);
  }();
}

/// What the Symbol section's Size menu offers for [instance] (D7, V-4,
/// R5-3): its entry's size family among [entries], or nothing for an
/// instance with no entry or a servable one (a table never changes size,
/// whatever family its entry names).
List<SymbolEntry> sizeMenuMembers(
    List<SymbolEntry> entries, DraftDocument doc, Handle instance) {
  final entry = entryOfInstance(entries, doc, instance);
  return entry == null || isServableInstance(doc, instance)
      ? const <SymbolEntry>[]
      : familyMembers(entries, entry);
}

final Expando<List<SymbolEntry>> _entriesOf = Expando<List<SymbolEntry>>();

/// The entries of the controller's loaded symbols, one list per symbols
/// list, so [familyMembers]' memo holds across builds.
List<SymbolEntry> symbolEntriesOf(List<PlanSymbol> symbols) =>
    _entriesOf[symbols] ??=
        List<SymbolEntry>.unmodifiable([for (final s in symbols) s.entry]);

/// The Rotation field's display steps per degree: it shows a rotation
/// rounded to a millionth of a degree, and a typed value within one step
/// of the current rotation is the shown value committed again, not a
/// turn. A property of the field's text, not a geometric tolerance.
const double kRotationStepsPerDegree = 1e6;

/// The Rotation row's value (D7): `atan2(−c, d)` in degrees, in `[0, 360)`
/// -- the local `y` column's angle, so a mirror does not add 180°.
double rotationDegreesOf(Transform2 t) {
  var deg = math.atan2(-t.c, t.d) * 180 / math.pi;
  if (deg < 0) deg += 360;
  if (deg >= 360) deg -= 360;
  return deg == 0 ? 0.0 : deg;
}

/// The exact `(cos, sin)` of [quarterTurns] quarter turns (F-2).
(double, double) _quarter(int quarterTurns) => const [
      (1.0, 0.0),
      (0.0, 1.0),
      (-1.0, 0.0),
      (0.0, -1.0),
    ][((quarterTurns % 4) + 4) % 4];

double _clean(double v) => v == 0 ? 0.0 : v;

/// [t] turned so its Rotation reads [degrees] (any finite number, taken
/// modulo 360), about the insertion point `t · basePoint` (D7): the linear
/// part `A` becomes `R(θ' − θ)·A`, so a mirror and a file's scale are
/// kept; an orthonormal result at a multiple of 90° is `R(θ')·S` from the
/// exact table, `S` the mirror or the identity, `-0.0` normalised.
Transform2 rotatedTo(Transform2 t, Vector2 basePoint, double degrees) {
  var target = degrees % 360;
  if (target < 0) target += 360;
  final p = t.transformPoint(basePoint);
  final delta = (target - rotationDegreesOf(t)) * math.pi / 180;
  final cs = math.cos(delta), sn = math.sin(delta);
  var a = cs * t.a - sn * t.b, b = sn * t.a + cs * t.b;
  var c = cs * t.c - sn * t.d, d = sn * t.c + cs * t.d;
  if (target % 90 == 0 && isOrthonormal(Transform2(a, b, c, d, 0, 0))) {
    final (qc, qs) = _quarter(target ~/ 90);
    if (t.a * t.d - t.b * t.c < 0) {
      // R(θ')·scale(−1, 1).
      a = -qc;
      b = -qs;
    } else {
      a = qc;
      b = qs;
    }
    c = -qs;
    d = qc;
  }
  final e = p.x - (a * basePoint.x + c * basePoint.y);
  final f = p.y - (b * basePoint.x + d * basePoint.y);
  return Transform2(
      _clean(a), _clean(b), _clean(c), _clean(d), _clean(e), _clean(f));
}

/// [t] mirrored in its own frame about [box]'s centre `x` (D7): the
/// footprint does not move, a scale is kept.
Transform2 mirroredAbout(Transform2 t, SymbolBox box) {
  final cx = (box.left + box.right) / 2;
  return t
      .multiply(Transform2.translation(cx, 0))
      .multiply(Transform2.scale(-1, 1))
      .multiply(Transform2.translation(-cx, 0));
}

/// The `Rotate` step for [instance] (D7), or null when nothing changes.
CompoundCommand? rotateSymbolCommand(
    DraftDocument doc, Handle instance, double degrees) {
  final node = doc.tree[instance];
  if (node is! InstanceNode || !degrees.isFinite) return null;
  final def = doc.tree.definition(node.definition);
  if (def == null) return null;
  // Already there, within the field's display step: the shown value
  // committed again is nothing.
  var diff = (degrees - rotationDegreesOf(node.transform)) % 360;
  if (diff < 0) diff += 360;
  final steps = diff * kRotationStepsPerDegree;
  if (steps < 1 || steps > 360 * kRotationStepsPerDegree - 1) return null;
  final next = rotatedTo(node.transform, def.basePoint, degrees);
  if (_same(next, node.transform)) return null;
  return CompoundCommand([TransformNodeCommand(instance, next)],
      label: 'Rotate');
}

/// The `Mirror` step for [instance] (D7), or null when it has no box.
CompoundCommand? mirrorSymbolCommand(DraftDocument doc, Handle instance) {
  final node = doc.tree[instance];
  if (node is! InstanceNode) return null;
  final box = boxOfDefinition(doc, node.definition);
  if (box == null) return null;
  return CompoundCommand(
      [TransformNodeCommand(instance, mirroredAbout(node.transform, box))],
      label: 'Mirror');
}

/// The `Change size` step (D7, decision 9): [instance] takes [entry]'s
/// definition (reused or copied, [definitionForEntry]), its linear part
/// kept and its translation chosen so the new box's back-left corner
/// `(left', back')` lands where the old `(left, back)` was. Null when the
/// instance already draws [entry]'s key (re-picking the checked size is
/// not a size change: it would copy a fresh definition over an older
/// version or an edited one), or a box is missing.
CompoundCommand? changeSizeCommand(
    DraftDocument doc, Handle instance, SymbolEntry entry) {
  final node = doc.tree[instance];
  if (node is! InstanceNode) return null;
  if (doc.components.get<SymbolComponent>(node.definition)?.key ==
      entry.symbol.key) {
    return null;
  }
  final oldBox = boxOfDefinition(doc, node.definition);
  final newBox = boxOfEntry(entry);
  if (oldBox == null || newBox == null) return null;
  final made = definitionForEntry(doc, entry);
  if (made.definition == node.definition) return null;
  final t = node.transform;
  final corner = t.transformPoint(Vector2(oldBox.left, oldBox.back));
  final next = Transform2(
    t.a,
    t.b,
    t.c,
    t.d,
    _clean(corner.x - (t.a * newBox.left + t.c * newBox.back)),
    _clean(corner.y - (t.b * newBox.left + t.d * newBox.back)),
  );
  return CompoundCommand([
    ...made.commands,
    SetInstanceDefinitionCommand(instance, made.definition),
    TransformNodeCommand(instance, next),
  ], label: 'Change size');
}

bool _same(Transform2 x, Transform2 y) =>
    x.a == y.a &&
    x.b == y.b &&
    x.c == y.c &&
    x.d == y.d &&
    x.e == y.e &&
    x.f == y.f;

/// [instance]'s Rotation as the row shows it (09c D7): to a millionth of a
/// degree, so 30 is not 29.999999999999996; 360 shows as 0.
double shownRotation(DraftDocument doc, Handle instance) {
  final deg =
      rotationDegreesOf((doc.tree[instance]! as InstanceNode).transform);
  final shown =
      (deg * kRotationStepsPerDegree).roundToDouble() / kRotationStepsPerDegree;
  return shown >= 360 ? 0.0 : shown;
}

/// [radians] in degrees as an angle field shows them: to a millionth of a
/// degree, no `-0.0`.
double degreesShown(double radians) {
  final shown =
      (radians * 180 / math.pi * kRotationStepsPerDegree).roundToDouble() /
          kRotationStepsPerDegree;
  return shown == 0 ? 0.0 : shown;
}
