import 'dart:math' as math;
import 'dart:typed_data';

import '../core/handle.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/node.dart';
import '../document/style.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'dirty_list.dart';
import 'packed_rtree.dart';

/// The spatial index of one indexed container — the document root, or a
/// definition.
///
/// Holds two trees, not one: leaves keyed by entity slot, and instances keyed
/// by node handle. Two trees rather than one tagged tree because the callers
/// differ — culling wants leaves and instances separately, and a tagged tree
/// would make every visitor branch on the tag.
///
/// **Groups are flattened.** A group is a one-off: it is not shared, so a
/// per-group index buys no reuse while costing a recursion level on every
/// query. Its leaves are folded into the nearest indexed ancestor with the
/// group transform composed in. An instance is *not* flattened — it is the
/// sharing boundary, and folding it in would defeat the entire design.
class ContainerIndex {
  ContainerIndex._(
    this.container,
    this._leaves,
    this._instances,
    this._instanceHandles,
    this._instanceTransforms,
    this._leafTransforms,
    this._ownSlack,
    this.bounds,
  ) : dirty = DirtyList();

  /// Builds the index for [container].
  ///
  /// [leavesByOwner] is shared across every container built in one pass; see
  /// [ContainerIndex.leavesByOwner]. Passing it in rather than recomputing it
  /// per container is what keeps a whole-document build linear in entities
  /// rather than O(containers x entities).
  factory ContainerIndex.build(
    DraftDocument doc,
    Handle container,
    Map<Handle, List<int>> leavesByOwner,
  ) {
    final leafSlots = <int>[];
    final leafBoxes = <double>[];
    final instanceHandles = <Handle>[];
    final instanceBoxes = <double>[];
    final instanceTransforms = <Transform2>[];
    final leafTransforms = <int, Transform2>{};
    var ownSlack = NarrowPhaseSlack.none;
    var bounds = Aabb2.empty();

    void addBox(List<double> into, Aabb2 b) {
      into
        ..add(b.minX)
        ..add(b.minY)
        ..add(b.maxX)
        ..add(b.maxY);
    }

    void addLeaf(int slot, Transform2 composed) {
      final record = doc.entities.read(slot);
      final payload = doc.geometry.read(record.geomIndex);
      final leafBox = entityBounds(
        kind: record.kind,
        payload: payload,
        measurer: doc.textMeasurer,
        textStyle: ReservedHandles.standardTextStyle,
      ).transformedBy(composed);
      leafSlots.add(slot);
      addBox(leafBoxes, leafBox);
      bounds = bounds.union(leafBox);
      // Identity is not stored: see [_leafTransforms]. `isIdentity` is
      // bit-exact, so a composed transform that is identity only to within
      // rounding is kept and multiplied through — one redundant multiply per
      // candidate, never a wrong answer.
      if (!composed.isIdentity) leafTransforms[slot] = composed;
      ownSlack = ownSlack.union(
          NarrowPhaseSlack.ofLeaf(record.kind, payload, composed, leafBox));
    }

    List<Handle> childNodesOf(Handle c) {
      final node = doc.tree[c];
      if (node is GroupNode) return doc.tree.childNodesOf(node.children);
      final definition = doc.tree.definition(c);
      if (definition != null) {
        return doc.tree.childNodesOf(definition.children);
      }
      return const [];
    }

    // Memoized per definition, not per instance: [DraftDocument.definitionBounds]
    // recomputes `leavesByOwner()` — a full entity-store scan — on every
    // call, so calling it once per instance makes a build over N instances of
    // one shared definition O(N x entities) instead of O(entities). A build
    // over 500 instances of an 8000-leaf definition measured ~5.7s uncached
    // versus a few ms cached; see task-5-report.md.
    final definitionBoundsCache = <Handle, Aabb2>{};
    Aabb2 boundsOfDefinition(Handle def) =>
        definitionBoundsCache[def] ??= doc.definitionBounds(def);

    // Explicit stack rather than recursion: a malformed tree must not blow
    // the Dart stack, and `validate()` reports tree.cycle for exactly that.
    //
    // No depth cap. `seen` below already bounds the walk to at most one push
    // per node — that is what actually prevents a cyclic graph from hanging
    // the build, since the stack is heap-allocated, not the Dart call stack,
    // so there is nothing a numeric depth limit would protect against that
    // `seen` does not already cover. A cap here would only ever silently
    // truncate a legitimately deep — or legitimately wide, since many
    // siblings are pending on the stack at once before any of them pops —
    // and otherwise acyclic tree, which is strictly worse than the hang it
    // would claim to prevent.
    final stack = <(Handle, Transform2)>[(container, Transform2.identity())];
    final seen = <Handle>{container};

    while (stack.isNotEmpty) {
      final (current, acc) = stack.removeLast();

      for (final slot in leavesByOwner[current] ?? const <int>[]) {
        addLeaf(slot, acc);
      }

      for (final child in childNodesOf(current)) {
        // `seen` also deduplicates a `children` list that names the same
        // child twice — tolerated on import (see
        // `DocumentTree._withoutAll`'s doc comment) but fatal to
        // `PackedRTree.build`, which requires unique payloads, if left
        // unguarded here.
        if (!seen.add(child)) continue;
        final node = doc.tree[child];
        switch (node) {
          case GroupNode(:final transform):
            // Flattened: recurse with the composed transform. `acc` is
            // applied second, so acc.multiply(transform) maps child space to
            // container space.
            stack.add((child, acc.multiply(transform)));
          case InstanceNode(:final definition, :final transform):
            final composed = acc.multiply(transform);
            final instanceBox =
                boundsOfDefinition(definition).transformedBy(composed);
            instanceHandles.add(child);
            instanceTransforms.add(composed);
            addBox(instanceBoxes, instanceBox);
            bounds = bounds.union(instanceBox);

            // Attributes belong to the INSERT, not to the definition: an
            // ATTRIB entity's owner is the instance node, and per
            // `EntityRecord.owner`'s governing rule ("leaf coordinates are
            // expressed in the owner's space") its coordinates are
            // instance-*local*, exactly like any other leaf owned by this
            // node — not already placed. They must therefore be transformed
            // by `composed`, the same as every other leaf this container
            // owns, which is what makes them differ per placement; sharing
            // one untransformed box across every instance, or dropping them
            // because `leavesByOwner[current]` alone never reaches a slot
            // owned by the instance, are the two ways to get this wrong. A
            // DXF importer must convert ATTRIB coordinates into
            // instance-local space on import — DXF stores them already
            // placed in world space, and re-using that value verbatim here
            // would double-apply the INSERT transform.
            for (final slot in leavesByOwner[child] ?? const <int>[]) {
              addLeaf(slot, composed);
            }
          case null:
            break;
        }
      }
    }

    return ContainerIndex._(
      container,
      _treeOf(leafSlots.length, leafBoxes, Uint32List.fromList(leafSlots)),
      _treeOf(instanceHandles.length, instanceBoxes,
          Uint32List.fromList([for (final h in instanceHandles) h.value])),
      instanceHandles,
      instanceTransforms,
      leafTransforms,
      ownSlack,
      bounds,
    );
  }

  static PackedRTree _treeOf(
          int count, List<double> boxes, Uint32List payloads) =>
      count == 0
          ? PackedRTree.empty()
          : PackedRTree.build(count, Float64List.fromList(boxes), payloads);

  /// Every live entity slot bucketed by its owner, ascending within a bucket.
  ///
  /// Delegates to [DraftDocument.leavesByOwner] rather than keeping an
  /// independent copy of the bucketing loop: leaf containment is stated
  /// exactly once, by `EntityRecord.owner`, and that statement's one
  /// implementation lives on the document, which is also what
  /// `definitionBounds` and `extents` use. This static wrapper exists only
  /// so every call site in this file and its tests can write
  /// `ContainerIndex.leavesByOwner(doc)` uniformly, matching the shape the
  /// rest of this class's API uses. Never read leaves out of a `children`
  /// list — `children` holds child nodes only.
  static Map<Handle, List<int>> leavesByOwner(DraftDocument doc) =>
      doc.leavesByOwner();

  final Handle container;
  final PackedRTree _leaves;
  final PackedRTree _instances;
  final List<Handle> _instanceHandles;
  final List<Transform2> _instanceTransforms;

  /// The composed transform of every leaf whose stored coordinates are
  /// **not** already in this container's own space — a leaf folded in from a
  /// flattened [GroupNode], or an ATTRIB whose owner is an instance node.
  ///
  /// Sparse and keyed by slot, holding only non-identity transforms: the
  /// overwhelmingly common leaf is owned directly by the indexed container,
  /// where the transform is the identity and an entry would be pure
  /// overhead. A dense `List<Transform2>` parallel to the leaf array would
  /// cost a pointer per leaf on *every* document, including the many that
  /// contain no groups at all, to say "identity" over and over.
  ///
  /// The values are shared, never copied: [ContainerIndex.build] composes
  /// one `Transform2` per group as it descends and hands the same instance
  /// to every leaf of that group, so a 10 000-leaf group costs 10 000 map
  /// entries and exactly one matrix — the "small table of distinct
  /// transforms" a parallel index array would have to build explicitly,
  /// obtained here for free from how the walk already works.
  final Map<int, Transform2> _leafTransforms;

  /// This container's own leaves' [NarrowPhaseSlack], excluding anything
  /// reachable through its instances.
  ///
  /// Not final: the dirty overlay can introduce a leaf whose slack exceeds
  /// what the last build saw (a circle whose radius grew), and
  /// [noteDirtyLeaf] folds that in. It only ever grows between rebuilds,
  /// which is the conservative direction — a stale-but-larger slack costs
  /// broad-phase candidates, where a stale-but-smaller one would drop hits.
  NarrowPhaseSlack _ownSlack;

  /// The union of everything this container holds, in its own space.
  final Aabb2 bounds;

  final DirtyList dirty;

  int get leafCount => _leaves.itemCount;
  int get instanceCount => _instances.itemCount;

  /// Above this many dirty entries the tree is rebuilt.
  ///
  /// The floor of 64 keeps a small document from rebuilding on every second
  /// edit; the 5% term keeps a large one from linearly scanning a meaningful
  /// fraction of itself on every query.
  int get rebuildThreshold => math.max(64, (leafCount * 0.05).floor());

  bool get needsRebuild => dirty.length > rebuildThreshold;

  /// Visits the slot of every leaf whose box overlaps [local], which is
  /// expressed in this container's own space.
  ///
  /// Dirty entries are visited too, so a caller sees recent edits. A slot may
  /// be visited twice if it is both in the tree and dirty; the tree marks
  /// superseded entries dead to prevent that, and the invalidation path is
  /// responsible for doing so.
  void searchLeaves(Aabb2 local, void Function(int slot) visit) {
    if (local.isEmpty) return;
    _leaves.search(local.minX, local.minY, local.maxX, local.maxY, visit);
    dirty.search(local.minX, local.minY, local.maxX, local.maxY, visit);
  }

  void searchInstances(Aabb2 local, void Function(Handle node) visit) {
    if (local.isEmpty) return;
    _instances.search(local.minX, local.minY, local.maxX, local.maxY,
        (payload) => visit(Handle(payload)));
  }

  /// The composed container-space transform of [node], including every group
  /// transform between it and this container.
  Transform2 transformOfInstance(Handle node) {
    final at = _instanceHandles.indexOf(node);
    if (at < 0) return Transform2.identity();
    return _instanceTransforms[at];
  }

  /// The instance node at [i], for a caller walking every instance this
  /// container holds — see [SpatialIndex]'s broad-phase margin, which needs
  /// each edge's transform to lift a definition's slack into this
  /// container's space.
  Handle instanceHandleAt(int i) => _instanceHandles[i];

  /// The composed container-space transform of the instance at [i], the
  /// positional sibling of [instanceHandleAt].
  Transform2 instanceTransformAt(int i) => _instanceTransforms[i];

  /// The transform carrying [slot]'s stored coordinates into this
  /// container's own space, or null when they are already in it.
  ///
  /// Null rather than [Transform2.identity]: the caller composes this onto
  /// its own world transform once per candidate leaf, and null lets it skip
  /// the multiply entirely. Returning a freshly built identity would
  /// allocate one matrix per candidate, which `SpatialIndex.pickInto`'s and
  /// `snapInto`'s zero-allocation guarantee forbids — the returned object is
  /// always one this index already owns, never a new one.
  Transform2? transformOfLeaf(int slot) => _leafTransforms[slot];

  /// How far outside its own indexed box the pick/snap narrow phase can
  /// accept a point, over this container's own leaves only.
  ///
  /// Its instances' contents are deliberately not included: composing those
  /// needs every edge transform on the path, which is [SpatialIndex]'s job —
  /// see [NarrowPhaseSlack.through].
  NarrowPhaseSlack get ownNarrowPhaseSlack => _ownSlack;

  /// Records the container-space transform and narrow-phase slack of a leaf
  /// that has just been re-derived by reconciliation.
  ///
  /// Called for every live leaf reconciliation, not only the ones that dirty
  /// something: [transformOfLeaf] must answer for a leaf whose owning group
  /// changed even when its box happens to be unchanged, and the slack only
  /// grows, so folding an unchanged leaf in again is a no-op.
  void noteLeaf(
    int slot,
    Transform2 composed,
    EntityKind kind,
    GeometryPayload payload,
    Aabb2 boxInContainerSpace,
  ) {
    if (composed.isIdentity) {
      _leafTransforms.remove(slot);
    } else {
      _leafTransforms[slot] = composed;
    }
    _ownSlack = _ownSlack.union(
        NarrowPhaseSlack.ofLeaf(kind, payload, composed, boxInContainerSpace));
  }

  /// Forgets [slot]'s composed transform, for an entity that has been
  /// removed from this container.
  ///
  /// The slack is deliberately *not* lowered: it is a maximum over leaves,
  /// recomputing it would mean rescanning every leaf on every removal, and
  /// leaving it high only costs broad-phase candidates until the next
  /// rebuild.
  void forgetLeaf(int slot) => _leafTransforms.remove(slot);

  /// The indexed box of [slot], or null if this container does not hold it —
  /// **including when it holds a dead entry for it.**
  ///
  /// Reads the tree's stored box rather than recomputing from geometry: the
  /// point of the comparison is "does what is indexed still match the
  /// document", so recomputing both sides would compare a value to itself.
  ///
  /// Returning null for a dead item is load-bearing, not tidiness. Remove
  /// marks the tree entry dead; undo then restores the entity to the same slot
  /// with the same box. If this returned the still-stored box, reconciliation
  /// would compare equal, return early without dirtying, and leave the dead
  /// bit set — and the entity would be permanently invisible to every query,
  /// with no error anywhere.
  Aabb2? boxOfLeaf(int slot) => _leaves.boxOfPayload(slot);

  /// Un-marks a leaf, for the restore half of remove-then-undo.
  void markLeafAlive(int slot) => _leaves.markAlive(slot);

  /// Whether the tree holds an entry for [slot] at all, alive or dead.
  ///
  /// Distinct from asking "is there a usable box" — [boxOfLeaf] non-null
  /// answers that, and is false for a dead entry. Reconciliation needs both
  /// questions: this one to tell a dead entry apart from no entry at all.
  bool containsLeafSlot(int slot) => _leaves.holdsPayload(slot);

  /// The stored box of a dead entry, so reconciliation can decide whether a
  /// restored entity is going back exactly where it was.
  Aabb2? boxOfDeadLeaf(int slot) => _leaves.boxIgnoringDead(slot);

  /// Marks a leaf slot as superseded by a dirty entry, or removed.
  void markLeafDead(int slot) => _leaves.markDead(slot);
}

/// How far outside a leaf's own indexed box the pick/snap **narrow** phase
/// can still accept a point, as a distance in one container's own space.
///
/// **The invariant this exists to restore:** a broad phase must never be
/// tighter than the region the narrow phase it feeds will test — the rule
/// [Aabb2.transformedBy]'s own doc comment states. For every entity kind but
/// two, the narrow phase measures the entity's exact geometry, which its
/// indexed box contains by construction, and this is zero. The two
/// exceptions are both round:
///
/// * A **circle** under a non-conformal transform becomes an ellipse, and
///   `SpatialIndex._considerLeaf` deliberately approximates it by the circle
///   of radius `r * scaleMagnitude` (the geometric mean of the axis scales)
///   rather than doing ellipse math. That circle pokes out of the exact
///   ellipse's box along the ellipse's short axis.
/// * An **arc**'s centre is a `SnapKind.center` candidate, and an arc's box
///   bounds the drawn sweep, which need not contain its own centre at all —
///   a 10° arc's box is a sliver a full radius away from it.
///
/// The fix is deliberately **not** to widen the stored boxes. Those boxes
/// are what `forEachInRect` and `forEachInstanceInRect` report against, and
/// their meaning — "the bound of the entity, or of the definition, under its
/// composed transform" — is the document's own, shared with `doc.extents`
/// and re-derived independently by the differential test's reference. Making
/// a stored box mean something else to satisfy pick and snap would change
/// what a rect query answers. Instead pick and snap widen their *query*
/// region by this much, which restores the invariant without touching what a
/// box means, and costs nothing at all for a document whose leaves are all
/// straight or whose transforms are all conformal.
///
/// Three channels rather than one, because the two exceptions have different
/// audiences and very different costs:
///
/// * [pick] — needed by [SpatialIndex.pickInto] and by every snap kind
///   except `center`. Zero unless a round leaf sits under a non-conformal
///   transform, which is the rare case.
/// * [snap] — [pick] plus the arc-centre term, needed only when a snap
///   query's mask includes [SnapKind.center]. Kept apart so a *pick* never
///   pays for a snap-only candidate: a drawing with one 5000-unit arc would
///   otherwise widen every pick to the whole drawing.
/// * [crude] — the bound that stays valid under **any** further transform,
///   `approximating radius + distance from centre to box`. Used when lifting
///   a definition's slack through a non-conformal instance, where the
///   sharper channels' assumptions no longer hold; see [through].
class NarrowPhaseSlack {
  const NarrowPhaseSlack(this.pick, this.snap, this.crude);

  static const NarrowPhaseSlack none = NarrowPhaseSlack(0, 0, 0);

  /// How much of [crude] an anisotropy of [k] is charged for.
  ///
  /// Zero at `k == 1` — a conformal transform maps a circle to a circle and
  /// an arc to an arc, so the approximation is *exact* and there is nothing
  /// to widen — rising to the whole crude bound as the transform stretches.
  /// Continuous, so a rotation that computes to `k == 1 + 2e-16` is charged
  /// essentially nothing rather than falling off a threshold into the full
  /// crude bound.
  ///
  /// The factor 4 is a cushion, not a derivation. Under an anisotropy `k` a
  /// circle's approximated radius is wrong by at most `rho * (1 - 1/sqrt(k))`
  /// — that one *is* exact, and [ofLeaf] uses it directly for circles. An
  /// arc additionally has its angles distorted, by at most
  /// `atan(sqrt(k)) - atan(1/sqrt(k))` radians, and the two effects are
  /// bounded together here by `4 * (sqrt(k) - 1)` rather than by adding two
  /// separate closed forms — which stays above their sum by a comfortable
  /// margin over the whole range where it is below `1` (at the tightest,
  /// `k = 1.2`, the sum is `0.19` against this bound's `0.24`), and is
  /// clamped at `1` where the crude bound takes over and is exact regardless.
  static double deviationFraction(double k) {
    if (!k.isFinite) return 1.0;
    final f = 4.0 * (math.sqrt(k) - 1.0);
    if (f <= 0.0) return 0.0;
    return f < 1.0 ? f : 1.0;
  }

  /// The slack of one leaf, in the space its [box] is expressed in.
  ///
  /// [composed] is the transform that carried the leaf's stored coordinates
  /// into that space — the flattened group chain, identity for a leaf owned
  /// directly by the container — and [box] is the box actually indexed for
  /// it, so the two agree by construction rather than by re-derivation.
  factory NarrowPhaseSlack.ofLeaf(
    EntityKind kind,
    GeometryPayload payload,
    Transform2 composed,
    Aabb2 box,
  ) {
    if (kind != EntityKind.circle && kind != EntityKind.arc) {
      // Every other kind's narrow phase measures points, segments or the
      // interior of a closed polyline, all of which the box contains.
      return none;
    }
    if (box.isEmpty || payload.scalars.isEmpty) return none;

    // The radius the narrow phase will actually use, expressed in the box's
    // own space: `scaleMagnitude` is exactly what `_considerLeaf` multiplies
    // the stored radius by.
    final rho = payload.scalars[0] * composed.scaleMagnitude;
    if (!rho.isFinite) return none;

    final cx = composed.a * payload.coords[0] +
        composed.c * payload.coords[1] +
        composed.e;
    final cy = composed.b * payload.coords[0] +
        composed.d * payload.coords[1] +
        composed.f;
    final centreGap = _distanceToBox(box, cx, cy);

    // Rigorous under any transform: everything the narrow phase accepts for
    // a circle or an arc lies inside the disc of radius `rho` about the
    // centre, so nothing it accepts is further from the box than the centre
    // is, plus that radius.
    final crude = rho + centreGap;

    final k = composed.anisotropyRatio;
    if (kind == EntityKind.circle) {
      // Exact, not a cushion: the indexed box is the box of the transformed
      // local square, so it contains the whole ellipse, which in turn
      // contains the disc of radius `r * sigmaMin = rho / sqrt(k)` about the
      // centre. The approximating disc of radius `rho` can therefore stick
      // out by no more than the difference. The centre of a circle is always
      // inside its own box, so there is no centre term.
      final tight = k.isFinite ? rho * (1.0 - 1.0 / math.sqrt(k)) : crude;
      return NarrowPhaseSlack(tight, tight, crude);
    }

    final fraction = deviationFraction(k);
    final rim = crude * fraction;
    final centre = centreGap + rho * fraction;
    return NarrowPhaseSlack(rim, rim > centre ? rim : centre, crude);
  }

  /// The larger of each channel — the slack of a set of leaves is the worst
  /// of them, since the query is widened once for all of them.
  NarrowPhaseSlack union(NarrowPhaseSlack other) => NarrowPhaseSlack(
        pick > other.pick ? pick : other.pick,
        snap > other.snap ? snap : other.snap,
        crude > other.crude ? crude : other.crude,
      );

  /// This slack, as measured inside a definition, lifted into the space of a
  /// container that places that definition through an instance whose
  /// composed transform is [edge].
  ///
  /// Two things happen at an instance edge. Distances scale, by at most the
  /// larger singular value of [edge] — `scaleMagnitude * sqrt(k)`, since the
  /// two singular values multiply to `|det|` and their ratio is the
  /// anisotropy. And the edge's own anisotropy compounds with whatever the
  /// leaves below already had, which the sharper [pick]/[snap] channels were
  /// computed without knowing; [crude] is exactly the bound that survives
  /// that, so the edge's [deviationFraction] of it is added back.
  ///
  /// A singular edge returns [none]: `SpatialIndex._descend` cannot invert
  /// it, so it never descends through one and there is nothing below it to
  /// keep reachable.
  NarrowPhaseSlack through(Transform2 edge) {
    final k = edge.anisotropyRatio;
    if (!k.isFinite) return none;
    final sigmaMax = edge.scaleMagnitude * math.sqrt(k);
    if (!sigmaMax.isFinite || sigmaMax == 0.0) return none;
    final compounded = crude * deviationFraction(k);
    return NarrowPhaseSlack(
      sigmaMax * (pick + compounded),
      sigmaMax * (snap + compounded),
      sigmaMax * crude,
    );
  }

  /// The margin a pick, or a snap that cannot produce a `center` candidate,
  /// must widen its broad phase by.
  final double pick;

  /// The margin a snap whose mask includes `center` must widen its broad
  /// phase by.
  final double snap;

  /// The margin that stays valid however the leaves below are transformed
  /// afterwards. Never used as a query margin directly — only by [through].
  final double crude;

  @override
  String toString() => 'NarrowPhaseSlack($pick, $snap, $crude)';
}

/// Euclidean distance from ([x], [y]) to the nearest point of [box], zero
/// when the point is inside it.
double _distanceToBox(Aabb2 box, double x, double y) {
  final dx = x < box.minX
      ? box.minX - x
      : x > box.maxX
          ? x - box.maxX
          : 0.0;
  final dy = y < box.minY
      ? box.minY - y
      : y > box.maxY
          ? y - box.maxY
          : 0.0;
  if (dx == 0.0) return dy;
  if (dy == 0.0) return dx;
  return math.sqrt(dx * dx + dy * dy);
}
