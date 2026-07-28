import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../core/handle.dart';

/// What part of an entity a pick landed on.
///
/// Checked in this order: a click near a line's endpoint means the endpoint,
/// even though it is also on the line.
enum HitKind { vertex, edge, fill }

/// The result of a pick: what was hit, and the chain of nodes above it.
///
/// Caller-owned so a pick allocates nothing at pointer-move rate. The engine
/// reports the path; policy lives in the widget layer — a viewer selects
/// `chain[0]`, the root-level ancestor, so tapping a chair selects its table,
/// while a designer descends.
///
/// **No-hit contract.** [SpatialIndex.pickInto] returns `false` on a miss and
/// leaves this object in the same state [reset] does: [chainLength] zero,
/// [entity] `Handle.none`, [worldPoint] the origin, [kind] [HitKind.edge],
/// [truncated] `false`. A caller that checks the boolean result first never
/// reads any of that — but one that does not must not be able to mistake a
/// stale field for a fresh answer, which is why [pickInto] resets [out]
/// unconditionally at the start of every call rather than only on a miss.
class HitPath {
  HitPath([int chainCapacity = 16]) : chain = Uint32List(chainCapacity);

  /// Root-level ancestor first, leaf's immediate parent last.
  final Uint32List chain;

  int chainLength = 0;
  Handle entity = const Handle(0);
  Vector2 worldPoint = Vector2.zero();
  HitKind kind = HitKind.edge;

  /// The chain was deeper than [chain] and was cut from the root end.
  ///
  /// Truncating from the root rather than the leaf keeps the leaf hit — the
  /// part that identifies what was clicked — always correct. Only deeply
  /// nested instances are affected.
  bool truncated = false;

  void reset() {
    chainLength = 0;
    entity = const Handle(0);
    kind = HitKind.edge;
    truncated = false;
    // Clear the point too. A caller that checks the return value first will
    // never read it on a miss — but one that does not gets the *previous*
    // pick's location, which looks entirely plausible and is the worst kind
    // of stale value.
    worldPoint = Vector2.zero();
  }
}
