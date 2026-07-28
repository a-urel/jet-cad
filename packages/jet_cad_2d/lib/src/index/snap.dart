import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../core/handle.dart';

/// The snap kinds, in priority order.
///
/// Declaration order *is* priority order: at equal distance an endpoint beats
/// a midpoint, and both beat `nearest`. Reordering this enum changes snapping
/// behaviour, which is why the order is stated rather than incidental.
///
/// `endpoint` through `insertion` are the "cheap" kinds ([SnapMask.cheap]):
/// constant cost per entity, needing nothing but the entity's own stored
/// geometry. `perpendicular`, `tangent`, `intersection` and `nearest` are
/// the "moderate" kinds: each needs either a second entity (`intersection`,
/// pairwise over the candidates in the query rectangle) or a per-candidate
/// projection against the query point itself (`perpendicular`, `tangent`,
/// `nearest`). **All nine are produced by [SpatialIndex.snapInto]** — see
/// its own doc comment for what each of the moderate kinds actually
/// computes and why `tangent` uses the query point as its own reference
/// rather than a caller-supplied one. There is no unimplemented kind.
enum SnapKind {
  endpoint,
  midpoint,
  center,
  quadrant,
  insertion,
  perpendicular,
  tangent,
  intersection,
  nearest,
}

/// Which snap kinds a query should consider.
///
/// A bitmask, not a `Set<SnapKind>`: building a `Set` literal per query would
/// allocate, which [SpatialIndex.snapInto]'s zero-allocation budget forbids.
extension type const SnapMask(int bits) {
  static const SnapMask none = SnapMask(0);

  /// `endpoint` through `insertion` — constant cost per entity, no second
  /// entity or reference point required.
  ///
  /// Hard-coded rather than derived from [SnapKind] in a const expression:
  /// `SnapKind.insertion.index` is not itself a constant expression (enum
  /// `.index` cannot be read in const context), so there is no const-safe way
  /// to compute this from the enum. [SnapMask.cheap] and [SnapMask.all] are
  /// each covered by a test in `snap_test.dart` that re-derives the same
  /// value at runtime by walking `SnapKind.values`, so inserting or
  /// reordering a kind without updating this literal fails that test rather
  /// than silently going stale.
  static const SnapMask cheap = SnapMask(0x1F); // endpoint..insertion

  /// Every kind. [SpatialIndex.snapInto] produces all of them — see
  /// [SnapKind]'s own doc comment; there is no unimplemented kind for this
  /// mask to be a promise about.
  static const SnapMask all = SnapMask(0x1FF);

  bool has(SnapKind kind) => bits & (1 << kind.index) != 0;

  SnapMask with_(SnapKind kind) => SnapMask(bits | (1 << kind.index));
}

/// The single best snap candidate within a query radius.
///
/// Caller-owned, including [chain], because a snap query runs at
/// pointer-move rate and must allocate nothing — see the zero-allocation
/// doc comment on [SpatialIndex.snapInto].
///
/// **No-hit contract.** [SpatialIndex.snapInto] resets this object
/// unconditionally at the start of *every* call, the same way
/// [HitPath.reset] is used by `pickInto`: on a miss, [found] is `false` and
/// every other field is left exactly as [reset] leaves it, so a caller that
/// forgets to check [found] can never mistake a previous query's hit — on
/// this same object — for a fresh one.
class SnapResult {
  SnapResult([int chainCapacity = 16]) : chain = Uint32List(chainCapacity);

  bool found = false;
  SnapKind kind = SnapKind.nearest;

  /// `final`, and never reassigned — the same reasoning as
  /// [HitPath.worldPoint]: [SpatialIndex.snapInto] resets this object at the
  /// start of every call, so reassigning a fresh `Vector2.zero()` in [reset]
  /// would allocate once per snap, on a method the zero-allocation
  /// frame-path constraint names by name. Written in place with
  /// `setValues`/`setZero`, so a caller must not hold it across calls.
  final Vector2 point = Vector2.zero();
  Handle entity = const Handle(0);

  /// Root-level ancestor first, leaf's immediate parent last — the same
  /// convention as [HitPath.chain].
  final Uint32List chain;
  int chainLength = 0;

  /// Whether the real path to [entity] was deeper than [chain] could hold,
  /// so that entries were dropped from the **root** end.
  ///
  /// The same flag, with the same meaning, as [HitPath.truncated], and here
  /// for the same reason: a cap is a design decision only when the caller
  /// can tell it fired. Without this, a snap through five instances into a
  /// `SnapResult(2)` reported a two-long chain indistinguishable from a
  /// genuinely two-deep hit, and a caller walking that chain from the root
  /// would resolve the wrong node.
  ///
  /// Dropping from the root end, not the leaf end, is what keeps [entity]
  /// and the innermost instances correct — see
  /// `SpatialIndex._writeSnapChain`.
  bool truncated = false;

  void reset() {
    found = false;
    chainLength = 0;
    truncated = false;
    entity = const Handle(0);
    // Clear kind and point for the same reason HitPath.reset does: a stale
    // snap kind or point from the previous query is plausible-looking and
    // wrong.
    kind = SnapKind.nearest;
    point.setZero();
  }
}
