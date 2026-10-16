// The symbol's local box (spec 09c D2): the axis-aligned bounds of a
// symbol's leaves in its definition's coordinates (the base point not
// subtracted). The catalog's frame (F-1) puts the front of a piece on its
// smallest y and its back on its largest, so `front = minY` and
// `back = maxY`. And the placement transform (spec 09 D6, 09c D5) and the
// orthonormal test (09c W-8, S-10) a placement and an attachment use.
//
// Moved into the contract from jet_cad_2d_plan's symbols/symbol_box.dart
// and symbol_placer.dart, unchanged (3a Task 1, spec C1.4): a kit's
// attachment provider needs the neighbours' boxes and the exact placement
// (the wall-face provider, spec 3a C5).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_library.dart' show SymbolEntry;

/// The local box of a symbol: `left = minX`, `right = maxX`,
/// `front = minY`, `back = maxY` in the definition's coordinates.
final class SymbolBox {
  final double left, right, front, back;

  const SymbolBox({
    required this.left,
    required this.right,
    required this.front,
    required this.back,
  });

  /// `W = right − left`.
  double get width => right - left;

  /// `D = back − front`.
  double get depth => back - front;

  /// The middle of the back edge, `((left + right) / 2, back)`: the point
  /// that lands on a wall's face (spec D4).
  Vector2 get backCentre => Vector2((left + right) / 2, back);

  @override
  bool operator ==(Object other) =>
      other is SymbolBox &&
      other.left == left &&
      other.right == right &&
      other.front == front &&
      other.back == back;

  @override
  int get hashCode => Object.hash(left, right, front, back);

  @override
  String toString() =>
      'SymbolBox(left: $left, right: $right, front: $front, back: $back)';
}

/// The axis directions an arc's sweep can pass, `k · π/2` for k = 0..3, and
/// the unit offset of the circle's extreme in each: exact, so an extreme is
/// `c ± r` with no rounding.
const List<double> _axisAngles = [0, 0.5 * math.pi, math.pi, 1.5 * math.pi];
const List<double> _axisX = [1, 0, -1, 0];
const List<double> _axisY = [0, 1, 0, -1];

/// The local box of [leaves] (each a kind and its payload, in the
/// definition's coordinates), or null when none of them draws.
///
/// A line's and a polyline's vertices; a circle's centre ± r; an arc's two
/// end points plus each axis extreme its sweep passes (its **true** extents,
/// spec D2), whichever way it turns. Any other kind (a point, a text, a
/// fill, an attribute: the library holds none, spec 09 D5) and a malformed
/// payload are skipped, as the ghost path skips them.
SymbolBox? boxOfLeaves(Iterable<(EntityKind, GeometryPayload)> leaves) {
  var minX = double.infinity, maxX = double.negativeInfinity;
  var minY = double.infinity, maxY = double.negativeInfinity;
  void add(double x, double y) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  for (final (kind, p) in leaves) {
    final c = p.coords;
    switch (kind) {
      case EntityKind.line:
      case EntityKind.polyline:
        for (var i = 0; i + 1 < c.length; i += 2) {
          add(c[i], c[i + 1]);
        }
      case EntityKind.circle:
        if (c.length < 2 || p.scalars.isEmpty) continue;
        final r = p.scalars[0];
        add(c[0] - r, c[1] - r);
        add(c[0] + r, c[1] + r);
      case EntityKind.arc:
        if (c.length < 2 || p.scalars.length < 3) continue;
        final r = p.scalars[0], start = p.scalars[1], sweep = p.scalars[2];
        final end = start + sweep;
        add(c[0] + r * math.cos(start), c[1] + r * math.sin(start));
        add(c[0] + r * math.cos(end), c[1] + r * math.sin(end));
        for (var k = 0; k < 4; k++) {
          if (angleInSweep(_axisAngles[k], start, sweep)) {
            add(c[0] + r * _axisX[k], c[1] + r * _axisY[k]);
          }
        }
      case EntityKind.point:
      case EntityKind.text:
      case EntityKind.attrib:
      case EntityKind.fill:
        continue;
    }
  }
  if (minX > maxX) return null;
  return SymbolBox(left: minX, right: maxX, front: minY, back: maxY);
}

final Expando<_Memo> _entryBoxes = Expando<_Memo>('symbolBox');

/// Holds a memoised box, null included (an entry with no drawn leaf).
final class _Memo {
  final SymbolBox? box;
  const _Memo(this.box);
}

/// The local box of [entry], computed on the first call and the same object
/// on every later call for the same entry (spec D2: once per entry).
SymbolBox? boxOfEntry(SymbolEntry entry) =>
    (_entryBoxes[entry] ??= _Memo(boxOfLeaves(
            [for (final l in entry.leaves) (l.record.kind, l.payload)])))
        .box;

/// The served top of [entry] in its definition's coordinates (spec 2b S2,
/// `SymbolDefinitionRef.top`): its first leaf's box when that leaf is a
/// circle or a closed polyline (today's `tableTopOf`,
/// jet_cad_floor_plan/lib/src/service/table_picker.dart:92-110), else the
/// symbol's box ([boxOfEntry]); empty when no leaf draws. The entry's
/// leaves are ascending by handle, so the first is the lowest.
Aabb2 servedTopOfEntry(SymbolEntry entry) {
  final all = boxOfEntry(entry);
  final whole = all == null ? Aabb2.empty() : footprintOf(all);
  if (entry.leaves.isEmpty) return whole;
  final first = entry.leaves.first;
  final kind = first.record.kind;
  final served = kind == EntityKind.circle ||
      (kind == EntityKind.polyline && isClosedPolyline(first.payload));
  if (!served) return whole;
  final top = boxOfLeaves([(kind, first.payload)]);
  return top == null ? whole : footprintOf(top);
}

/// The local box of the definition [definition] in [doc], from its **live**
/// leaves (the entities it owns); null when [definition] names no definition
/// or none of its leaves draws.
///
/// Not memoised: O(entities) per call. A caller that asks often keeps its
/// own memo and drops it when the document changes (its
/// `commands.stateId`).
SymbolBox? boxOfDefinition(DraftDocument doc, Handle definition) {
  if (doc.tree.definition(definition) == null) return null;
  final entities = doc.entities;
  return boxOfLeaves([
    for (final slot in entities.liveSlots)
      if (entities.ownerAt(slot) == definition)
        (
          entities.kindAt(slot),
          doc.geometry.read(entities.geomIndexAt(slot)),
        ),
  ]);
}

/// [box] as the engine's box, the shape `AttachmentQuery.footprint` takes:
/// x from left to right, y from front to back, in the definition's
/// coordinates.
Aabb2 footprintOf(SymbolBox box) =>
    Aabb2.raw(box.left, box.front, box.right, box.back);

/// Whether [g]'s linear part is orthonormal (spec 09c W-8, S-10):
/// `|a² + b² − 1|`, `|c² + d² − 1|` and `|ac + bd|` each at most
/// `Tolerance.standard.linear`. A mirror is orthonormal; a scale is not.
bool isOrthonormal(Transform2 g) {
  final tol = Tolerance.standard.linear;
  return (g.a * g.a + g.b * g.b - 1).abs() <= tol &&
      (g.c * g.c + g.d * g.d - 1).abs() <= tol &&
      (g.a * g.c + g.b * g.d).abs() <= tol;
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
