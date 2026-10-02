// The symbol's local box (spec 09c D2): the axis-aligned bounds of a
// symbol's leaves in its definition's coordinates (the base point not
// subtracted). The catalog's frame (F-1) puts the front of a piece on its
// smallest y and its back on its largest, so `front = minY` and
// `back = maxY`.
//
// No Flutter import and no `dart:ui`: this file is Dart over
// `package:jet_cad_2d` only (spec D1, T-4).
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_library.dart';

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

/// The local box of the definition [definition] in [doc], from its **live**
/// leaves (the entities it owns); null when [definition] names no definition
/// or none of its leaves draws.
///
/// Not memoised: O(entities) per call. The per-document memo cleared on a
/// document change belongs to the caller (`WallFaces`, spec D3, D4).
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
