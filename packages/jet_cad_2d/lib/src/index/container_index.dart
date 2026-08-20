import 'dart:math' as math;
import 'dart:typed_data';

import '../core/handle.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/node.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'dirty_list.dart';
import 'packed_rtree.dart';

/// The spatial index of one indexed container — the document root, or a
/// definition.
///
/// Holds three trees, not one: leaves keyed by entity slot, instances keyed
/// by node handle, and the **snap centres** of arcs and circles, also keyed
/// by entity slot. Separate trees rather than one tagged tree because the
/// callers differ — culling wants leaves and instances separately, and a
/// tagged tree would make every visitor branch on the tag.
///
/// **Why centres get a tree of their own.** An arc's box bounds its drawn
/// *sweep*, which need not contain its own centre — a 10° arc's box is a
/// sliver a full radius away from it — and `snapInto` offers that centre as
/// a [SnapKind.center] candidate. So the leaf tree's boxes do not cover
/// everything the snap narrow phase measures. Widening the *query* to
/// compensate was measured at 500,000 entities to cost roughly 87% of a
/// default (`SnapMask.cheap`) snap: one large narrow-sweep arc anywhere in a
/// container widened every centre-including query in it by that arc's
/// radius. Indexing the centres themselves puts each one exactly where it
/// is, and the query stays tight. Deliberately **not** folded into
/// [_leaves]: those boxes are what `forEachInRect` and `pickInto` report
/// against, and a point entry per arc would put snap-only data on the
/// hit-test path.
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
    this._snapCentres,
    this._instanceHandles,
    this._instanceTransforms,
    this._leafTransforms,
    this._ownSlack,
    this._ownSnapCentreReach,
    this._bounds,
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
    // Parallel arrays, one entry per arc or circle leaf: the slot, and its
    // centre already composed into this container's own space.
    final centreSlots = <int>[];
    final centreCoords = <double>[];
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
        textStyle: doc.textStyleOf(record.textStyle),
        textAttrs: record.textAttrs,
        text: record.text,
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
      final centre = snapCentreOfLeaf(record.kind, payload, composed);
      if (centre != null) {
        centreSlots.add(slot);
        centreCoords
          ..add(centre.$1)
          ..add(centre.$2);
      }
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

    // Memoized per definition, not per instance: calling
    // [DraftDocument.definitionBounds] once per instance makes a build over N
    // instances of one shared definition O(N x entities) instead of
    // O(entities). A build over 500 instances of an 8000-leaf definition
    // measured ~5.7s uncached versus a few ms cached; see task-5-report.md.
    //
    // [leavesByOwner] — the map this factory was already handed, shared
    // across every container built in this pass — is threaded through to
    // [DraftDocument.definitionBounds] rather than left to its default of
    // recomputing its own. Without this, a build over many *distinct*
    // definitions is still O(definitions x entities): the cache above stops
    // a repeated definition from paying twice, but the first call for each
    // definition still cost a full entity-store scan on its own. Task 18's
    // benchmark measured this directly: 2,000 definitions over 32,000
    // entities took multiple seconds before this line was added — see
    // task-18-report.md for the before/after numbers.
    final definitionBoundsCache = <Handle, Aabb2>{};
    Aabb2 boundsOfDefinition(Handle def) =>
        definitionBoundsCache[def] ??= doc.definitionBounds(def, leavesByOwner);

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

    // Measured against the *finished* [bounds], which is why it happens here
    // and not inside `addLeaf`: what a parent container needs to know is how
    // far outside this container's own bound — the very box its instances
    // are indexed by — a snap centre inside it can lie. See
    // [ownSnapCentreReach].
    var centreReach = 0.0;
    if (!bounds.isEmpty) {
      for (var i = 0; i < centreSlots.length; i++) {
        final d = _distanceToBox(
            bounds, centreCoords[i * 2], centreCoords[i * 2 + 1]);
        if (d > centreReach) centreReach = d;
      }
    }

    return ContainerIndex._(
      container,
      _treeOf(leafSlots.length, leafBoxes, Uint32List.fromList(leafSlots)),
      _treeOf(instanceHandles.length, instanceBoxes,
          Uint32List.fromList([for (final h in instanceHandles) h.value])),
      _centreTreeOf(centreSlots, centreCoords),
      instanceHandles,
      instanceTransforms,
      leafTransforms,
      ownSlack,
      centreReach,
      bounds,
    );
  }

  static PackedRTree _treeOf(
          int count, List<double> boxes, Uint32List payloads) =>
      count == 0
          ? PackedRTree.empty()
          : PackedRTree.build(count, Float64List.fromList(boxes), payloads);

  /// The snap-centre tree: one **degenerate** (point) box per arc or circle,
  /// payload the leaf's slot.
  ///
  /// A zero-area box is exactly right here rather than a compromise: a
  /// centre is a point, `PackedRTree`'s overlap test is inclusive, and the
  /// STR packing sorts by box centre, which for a point is the point.
  static PackedRTree _centreTreeOf(List<int> slots, List<double> coords) {
    if (slots.isEmpty) return PackedRTree.empty();
    final boxes = Float64List(slots.length * 4);
    for (var i = 0; i < slots.length; i++) {
      final cx = coords[i * 2], cy = coords[i * 2 + 1];
      boxes[i * 4] = cx;
      boxes[i * 4 + 1] = cy;
      boxes[i * 4 + 2] = cx;
      boxes[i * 4 + 3] = cy;
    }
    return PackedRTree.build(slots.length, boxes, Uint32List.fromList(slots));
  }

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

  /// The centres of this container's own arcs and circles, as points, keyed
  /// by the same slot [_leaves] uses — see the class doc for why they are
  /// indexed at all and why they are not in [_leaves].
  ///
  /// Kept in lockstep with [_leaves] by [markLeafDead] and [markLeafAlive],
  /// which touch both trees in one call so no caller can revive a leaf and
  /// leave its centre buried. The dirty overlay in front of it is [dirty]
  /// itself, which records a centre alongside every box; there is
  /// deliberately no second dirty list.
  final PackedRTree _snapCentres;

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
  /// what the last build saw (a circle whose radius grew, or a circle added
  /// to a group after the index was built), and [noteLeaf] folds that in —
  /// dropping that one line leaves such a circle correctly indexed,
  /// correctly transformed and still unpickable in the gap between its exact
  /// bound and its approximated radius. It only ever grows between rebuilds,
  /// which is the conservative direction — a stale-but-larger slack costs
  /// broad-phase candidates, where a stale-but-smaller one would drop hits.
  NarrowPhaseSlack _ownSlack;

  /// How far outside this container's own [bounds] a snap centre of one of
  /// its own leaves lies — zero for the overwhelming majority of documents,
  /// since a circle's centre is always inside its box and most arcs sit
  /// among other geometry that covers theirs.
  ///
  /// **Who reads this, and why it is not a query margin here.** This
  /// container's own centres are indexed exactly, in [_snapCentres], so a
  /// query into *this* container never needs widening. What still does is
  /// the step *into* an instance one level up: a parent indexes this
  /// container by its [bounds] transformed, and `forEachInstanceInRect`
  /// reports against that same box, so it may not be grown to swallow a
  /// stray centre. [SpatialIndex] lifts this number up through each
  /// instance transform instead and widens only the instance search by it —
  /// the compensation that remains is therefore proportional to how far a
  /// centre escapes its *definition*, not to the largest arc radius in the
  /// document.
  ///
  /// Not final, and only ever grows, for the same reason as [_ownSlack]:
  /// see [noteLeaf].
  double _ownSnapCentreReach;

  /// The union of everything this container holds, in its own space.
  ///
  /// **Maintained across reconciliation, not merely set at build time.** A
  /// leaf that moves outward through [noteLeaf], and an instance whose
  /// definition grew through [growInstanceBox], both widen it.
  ///
  /// **Whether it ever narrows again depends on whether anything places this
  /// container.** Narrowing costs an O(leaves + instances) scan
  /// ([recomputeBounds]), so it is done only where it buys something: a
  /// *definition*'s bound is what every instance box that places it is
  /// derived from, so leaving it wide leaves those boxes wide, and a query
  /// over empty space keeps descending into all of them for the life of the
  /// index. `SpatialIndex` therefore lets a placed container's bound recede,
  /// gated on [boundsMayHaveReceded] so the scan is skipped for any edit that
  /// was not holding a side of it.
  ///
  /// For the **root**, and for a definition nothing places, no query path
  /// reads this at all, and the scan would be over the whole document — so
  /// it stays an upper bound: exact immediately after a rebuild, never
  /// smaller than the truth in between, and narrowed again only by a rebuild.
  /// Unlike [_ownSlack] and [_ownSnapCentreReach], which are broad-phase
  /// margins with a narrow phase behind them to reject the excess, a bound
  /// this one feeds has no second chance — an over-wide instance box is a
  /// reported result, not a spent candidate — which is exactly why the
  /// placed case is not allowed the same latitude.
  ///
  /// It used to be `final`, which made it a *lower* bound instead: an entity
  /// added at (500, 500) to a document that correctly found it left this
  /// still reading the box the last build saw, with no caveat here saying
  /// so. That is the unsafe direction — [SpatialIndex] reads it to decide
  /// whether a leaf has escaped its definition and the placing containers'
  /// instance boxes need widening, and a bound that is too small says "still
  /// inside" about geometry that is not.
  Aabb2 get bounds => _bounds;
  Aabb2 _bounds;

  /// Whether an edit since the last [recomputeBounds] could have let [bounds]
  /// back in — a leaf that was holding a side of it moved inwards, or left.
  ///
  /// A *necessary* condition, cheap and one-sided: it is set when the old box
  /// of a reconciled leaf touched the bound, which is the only way that leaf
  /// could have been what was holding it out. When it is false the bound
  /// provably cannot have receded, so [recomputeBounds] — the only O(items)
  /// operation on this path — is skipped outright, which is the answer for
  /// almost every edit, since almost every edit is to geometry in the middle
  /// of a drawing rather than on its edge.
  bool get boundsMayHaveReceded => _boundsMayHaveReceded;
  bool _boundsMayHaveReceded = false;

  /// Records that [was] — a leaf or instance box this container had indexed —
  /// is no longer in force, so [bounds] may no longer be tight.
  ///
  /// Exact comparison against each side, not a tolerance: this is asking
  /// "was this box holding the bound out", a stored-value question, and a
  /// tolerance would make it fire on boxes that were never touching.
  void noteBoxWithdrawn(Aabb2 was) {
    if (_boundsMayHaveReceded || was.isEmpty || _bounds.isEmpty) return;
    if (was.minX == _bounds.minX ||
        was.minY == _bounds.minY ||
        was.maxX == _bounds.maxX ||
        was.maxY == _bounds.maxY) {
      _boundsMayHaveReceded = true;
    }
  }

  /// Re-derives [bounds] from what this container currently holds, letting it
  /// **shrink**, and clears [boundsMayHaveReceded]. Returns whether it
  /// actually changed.
  ///
  /// O(leaves + instances) *of this container*, with no walk of the document
  /// and no rebuild: the live item boxes of both trees, unioned with the
  /// dirty overlay in front of them. A leaf that has moved is dead in the
  /// tree and live only on the overlay, so both halves are needed to get the
  /// same answer a rebuild would.
  ///
  /// **Why growth does not need this and shrinkage does.** `noteLeaf` widens
  /// the bound exactly when a leaf escapes it, and `SpatialIndex`
  /// re-derives every instance box that places this container in the same
  /// breath, so the outward direction is exact at every step. Nothing does
  /// the mirror image, because nothing can tell in O(1) that the last leaf
  /// holding a side has moved in. Left alone, that asymmetry is not a small
  /// inaccuracy: it accumulates for the life of the session, and it lands on
  /// the query side, where every instance box that ever covered a region goes
  /// on being descended into for as long as the index lives.
  bool recomputeBounds() {
    _boundsMayHaveReceded = false;
    final tight = _leaves
        .liveItemBounds()
        .union(_instances.liveItemBounds())
        .union(dirty.entryBounds());
    if (_sameBox(tight, _bounds)) return false;

    // [_ownSnapCentreReach] is measured *against* [bounds], so pulling the
    // bound in leaves every reach already recorded understated by however far
    // the sides moved — and an understated reach is the one direction that
    // drops hits, since it is what widens a parent's instance search enough
    // to reach a snap centre lying outside the definition it belongs to.
    //
    // Raised by the diagonal retreat rather than recomputed: any point's
    // distance to the narrowed box is at most its distance to the old box
    // plus how far the nearest part of that box moved away from it, which
    // `hypot` of the two axes' retreats bounds rigorously. Recomputing the
    // exact figure would mean a third scan, over the centre tree and the
    // overlay's centres, to sharpen a number that is zero for almost every
    // document and only ever costs broad-phase candidates when it is not.
    if (!tight.isEmpty && !_bounds.isEmpty && _ownSnapCentreReach > 0) {
      final dx = math.max(tight.minX - _bounds.minX, _bounds.maxX - tight.maxX);
      final dy = math.max(tight.minY - _bounds.minY, _bounds.maxY - tight.maxY);
      if (dx > 0 || dy > 0) {
        final ex = dx > 0 ? dx : 0.0, ey = dy > 0 ? dy : 0.0;
        _ownSnapCentreReach += math.sqrt(ex * ex + ey * ey);
      }
    }

    _bounds = tight;
    return true;
  }

  final DirtyList dirty;

  int get leafCount => _leaves.itemCount;
  int get instanceCount => _instances.itemCount;

  /// How many arc/circle centres the built tree holds. Test-visible for the
  /// same reason as [leafCount]: it is what distinguishes "the centre tree
  /// was populated" from "the query happened to find it another way".
  int get snapCentreCount => _snapCentres.itemCount;

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
    searchLeavesRaw(local.minX, local.minY, local.maxX, local.maxY, visit);
  }

  /// [searchLeaves] over a rectangle held as four loose doubles.
  ///
  /// Exists for one reason: [Aabb2] is immutable, so a caller on the
  /// zero-allocation frame path that builds its query rectangle from scratch
  /// on every call — `SpatialIndex._considerIntersections` does, once per
  /// `snapInto` — allocates one box per call just to hand four numbers over.
  /// Callers that already hold an [Aabb2] should keep using [searchLeaves];
  /// this is not the preferred spelling, it is the escape hatch for the
  /// frame path.
  void searchLeavesRaw(double minX, double minY, double maxX, double maxY,
      void Function(int slot) visit) {
    if (minX > maxX || minY > maxY) return;
    _leaves.search(minX, minY, maxX, maxY, visit);
    dirty.search(minX, minY, maxX, maxY, visit);
  }

  /// Visits the slot of every arc or circle whose **centre** lies inside
  /// [local], expressed in this container's own space.
  ///
  /// The sibling of [searchLeaves], and deliberately a separate call rather
  /// than an extra flag on it: `forEachInRect` and `pickInto` must not see
  /// these entries at all, and only a snap whose mask includes
  /// [SnapKind.center] pays for this walk.
  ///
  /// Dirty entries are visited too, from the same [dirty] list that backs
  /// [searchLeaves] — see [DirtyList.searchCentres].
  void searchSnapCentres(Aabb2 local, void Function(int slot) visit) {
    if (local.isEmpty) return;
    _snapCentres.search(local.minX, local.minY, local.maxX, local.maxY, visit);
    dirty.searchCentres(local.minX, local.minY, local.maxX, local.maxY, visit);
  }

  /// [searchLeaves] and [searchSnapCentres] over one query, sharing a single
  /// pass over [dirty].
  ///
  /// The two trees are still walked separately — they are separate trees —
  /// but the dirty overlay in front of them is one linear array, and a snap
  /// that wants both answers would otherwise scan it end to end twice. See
  /// [DirtyList.searchBoxesAndCentres].
  void searchLeavesAndSnapCentres(
    Aabb2 local,
    void Function(int slot) visitLeaf,
    void Function(int slot) visitCentre,
  ) {
    if (local.isEmpty) return;
    _leaves.search(local.minX, local.minY, local.maxX, local.maxY, visitLeaf);
    _snapCentres.search(
        local.minX, local.minY, local.maxX, local.maxY, visitCentre);
    dirty.searchBoxesAndCentres(
        local.minX, local.minY, local.maxX, local.maxY, visitLeaf, visitCentre);
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

  /// See [_ownSnapCentreReach].
  double get ownSnapCentreReach => _ownSnapCentreReach;

  /// Records the container-space transform and narrow-phase slack of a leaf
  /// that has just been re-derived by reconciliation, folds its box into
  /// [bounds], and reports **whether [bounds] had to grow to hold it**.
  ///
  /// Called for every live leaf reconciliation, not only the ones that dirty
  /// something: [transformOfLeaf] must answer for a leaf whose owning group
  /// changed even when its box happens to be unchanged, and the slack only
  /// grows, so folding an unchanged leaf in again is a no-op.
  ///
  /// The return value is what makes propagating growth affordable. A leaf
  /// that stays inside this container's existing bound cannot have invalidated
  /// any instance box above it, so `false` — the overwhelmingly common answer,
  /// since most edits happen well inside a drawing — lets [SpatialIndex] skip
  /// the walk over everything that places this container entirely.
  bool noteLeaf(
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

    // Before the centre reach below, not after: that reach is measured
    // against [bounds], and what a parent indexes this container by is a box
    // that covers the *new* bound (see [growInstanceBox]). Measuring against
    // the pre-edit bound would charge for a distance the parent's box has
    // already swallowed.
    final grownBounds = boxInContainerSpace.isEmpty
        ? _bounds
        : _bounds.union(boxInContainerSpace);
    final grew = !_sameBox(grownBounds, _bounds);
    _bounds = grownBounds;
    // The centre half of the same "only ever grows between rebuilds" rule.
    // The dirty overlay can introduce a centre further outside [bounds] than
    // anything the last build saw — an arc dragged away from the rest of a
    // definition's geometry — and a parent that never hears about it stops
    // descending into the instance that holds it. Dropping this line leaves
    // that arc correctly indexed, correctly transformed, and its centre
    // unsnappable through every instance of its definition.
    final centre = snapCentreOfLeaf(kind, payload, composed);
    if (centre != null && !bounds.isEmpty) {
      final reach = _distanceToBox(bounds, centre.$1, centre.$2);
      if (reach > _ownSnapCentreReach) _ownSnapCentreReach = reach;
    }
    return grew;
  }

  /// Enlarges the indexed box of the instance node [node] so that it also
  /// contains [box], expressed in this container's own space, and folds the
  /// same growth into [bounds]. Returns whether anything actually changed.
  ///
  /// **Why an instance box ever needs this.** A parent indexes an instance by
  /// its definition's bound, derived once, at the parent's build time. Adding
  /// an entity to that definition afterwards dirties a leaf inside the
  /// *definition's* index and nothing else — one entry, far below the rebuild
  /// floor of 64 — so without this the box the parent holds still describes
  /// the definition as it was, and every query that has to step through it to
  /// reach the new entity stops at the door.
  ///
  /// Growing rather than re-deriving is deliberate, and matches how every
  /// other cross-rebuild value in this class behaves: re-deriving would mean
  /// recomputing the whole definition's bound on every edit inside it, while
  /// growing is O(tree depth) and errs towards a box that is too large, which
  /// costs broad-phase candidates instead of dropping hits.
  bool growInstanceBox(Handle node, Aabb2 box) {
    if (box.isEmpty) return false;
    final grew =
        _instances.growBox(node.value, box.minX, box.minY, box.maxX, box.maxY);
    if (grew) _bounds = _bounds.union(box);
    return grew;
  }

  /// Replaces the indexed box of the instance node [node] outright, narrowing
  /// it if [box] is smaller than what is stored.
  ///
  /// The counterpart of [growInstanceBox], and the only way an instance box
  /// ever gets smaller without a rebuild of *this* container. Called when the
  /// placed definition's own index has just been rebuilt, so its bound is
  /// exact again and the widened box here is known to be pure slack — see
  /// `SpatialIndex._retightenPlacementsOf` for why leaving that slack in place
  /// is what turned one ordinary drag into a query cliff.
  ///
  /// [bounds] is deliberately *not* narrowed alongside it: it is a maximum
  /// over everything this container holds, and lowering it would mean
  /// rescanning every leaf and every other instance. Leaving it high costs a
  /// too-large public bound, which its own doc comment already discloses, and
  /// nothing on a query path reads it.
  void setInstanceBox(Handle node, Aabb2 box) {
    if (box.isEmpty) return;
    if (_instances.setBox(node.value, box.minX, box.minY, box.maxX, box.maxY)) {
      // A side of this instance's box moved in, so this container's own bound
      // may have been resting on it. Set directly rather than through
      // [noteBoxWithdrawn], which would need the old box and therefore an
      // allocation per placement; the flag is a one-sided hint either way, so
      // the only cost of setting it slightly more often is one skipped scan.
      _boundsMayHaveReceded = true;
    }
  }

  /// Deliberately exact `==`, not a tolerance: this asks "did the stored
  /// bound change at all", a stored-value question, exactly like
  /// `SpatialIndex._sameBox`. A tolerance here would let a real escape past
  /// the containment test that gates propagating growth upwards.
  static bool _sameBox(Aabb2 a, Aabb2 b) =>
      a.minX == b.minX &&
      a.minY == b.minY &&
      a.maxX == b.maxX &&
      a.maxY == b.maxY;

  /// Forgets [slot]'s composed transform, for an entity that has been
  /// removed from this container.
  ///
  /// The slack is deliberately *not* lowered: it is a maximum over leaves,
  /// recomputing it would mean rescanning every leaf on every removal, and
  /// leaving it high only costs broad-phase candidates until the next
  /// rebuild. [bounds] is not lowered either, for the same reason and with
  /// the same consequence.
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
  ///
  /// Revives the centre entry in the same call. Splitting the two would let
  /// an undone arc come back visible to `pickInto` and still have no
  /// snappable centre, with nothing anywhere reporting a disagreement.
  void markLeafAlive(int slot) {
    _leaves.markAlive(slot);
    _snapCentres.markAlive(slot);
  }

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
  ///
  /// Kills the centre entry in the same call, the counterpart of
  /// [markLeafAlive]. Without it a moved or deleted arc keeps offering its
  /// *old* centre as a snap candidate for as long as the tree stands, on top
  /// of the new one the dirty overlay supplies — a stale hit, not a missed
  /// one, which is the harder kind to notice.
  ///
  /// A slot with no centre entry — every kind but arc and circle — costs a
  /// failed map lookup and nothing else; [PackedRTree.markDead] ignores a
  /// payload it does not hold.
  void markLeafDead(int slot) {
    _leaves.markDead(slot);
    _snapCentres.markDead(slot);
  }

  /// Whether the centre this container has stored for [slot] is exactly
  /// ([centreX], [centreY]) — or, when those are [DirtyList.noCentre], that
  /// it has no stored centre for [slot] at all.
  ///
  /// Reads the stored value **including a dead entry**, because the one
  /// caller is `SpatialIndex._reconcileEntity`, which asks this question on
  /// both its live-and-unchanged path and its revive-a-dead-entry path and
  /// wants the same answer from each.
  ///
  /// This exists because an arc's centre is a fact about it that its indexed
  /// box does not imply: an arc can be edited so that its box comes out
  /// bit-identical while its centre moves (centre `(0,0)`, r 1, sweeping the
  /// first quadrant, and centre `(1,1)`, r 1, sweeping the third, both bound
  /// exactly `(0,0)..(1,1)`). Comparing boxes alone would call that edit
  /// unchanged and leave the old centre indexed.
  bool storedSnapCentreMatches(int slot, double centreX, double centreY) {
    final stored = _snapCentres.boxIgnoringDead(slot);
    if (centreX.isNaN || centreY.isNaN) return stored == null;
    return stored != null && stored.minX == centreX && stored.minY == centreY;
  }
}

/// The centre a leaf offers as a `SnapKind.center` snap candidate, in the
/// space [composed] maps its stored coordinates into — or null for a kind
/// that offers none.
///
/// Arcs and circles only. Every other kind's snap candidates are corners,
/// midpoints and projections of geometry its own box already contains, so
/// there is nothing to index separately for them.
///
/// Null, not a NaN pair, for a payload whose centre does not come out
/// finite: `PackedRTree.build` sorts by box centre, and a NaN would make
/// that comparison meaningless for every other item in the same tree.
(double, double)? snapCentreOfLeaf(
  EntityKind kind,
  GeometryPayload payload,
  Transform2 composed,
) {
  if (kind != EntityKind.circle && kind != EntityKind.arc) return null;
  if (payload.coords.length < 2) return null;
  final lx = payload.coords[0], ly = payload.coords[1];
  final cx = composed.a * lx + composed.c * ly + composed.e;
  final cy = composed.b * lx + composed.d * ly + composed.f;
  if (!cx.isFinite || !cy.isFinite) return null;
  return (cx, cy);
}

/// How far outside a leaf's own indexed box the pick/snap **narrow** phase
/// can still accept a point, as a distance in one container's own space.
///
/// **The invariant this exists to restore:** a broad phase must never be
/// tighter than the region the narrow phase it feeds will test — the rule
/// [Aabb2.transformedBy]'s own doc comment states. For every entity kind but
/// one, the narrow phase measures the entity's exact geometry, which its
/// indexed box contains by construction, and this is zero. The exception is
/// round:
///
/// * A **circle or arc** under a non-conformal transform becomes an ellipse,
///   and `SpatialIndex._considerLeaf` deliberately approximates it by the
///   circle of radius `r * scaleMagnitude` (the geometric mean of the axis
///   scales) rather than doing ellipse math. That circle pokes out of the
///   exact ellipse's box along the ellipse's short axis.
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
/// **What this deliberately no longer covers: the arc centre.** An arc's box
/// bounds the drawn sweep and need not contain its own centre — a 10° arc's
/// box is a sliver a full radius away from it — and `snapInto` offers that
/// centre as a `SnapKind.center` candidate. This class used to carry a third
/// channel for that, adding roughly the arc's radius to every
/// centre-including snap query in the container. Measured at 500,000
/// entities that term was about 87% of the cost of a default
/// (`SnapMask.cheap`) snap, because it is a *per-container union*: one large
/// narrow-sweep arc widened every such query, not only the queries near it.
/// The centre is now indexed where it actually is, in
/// [ContainerIndex.searchSnapCentres], and no query is widened for it. What
/// is left of the compensation is
/// [ContainerIndex.ownSnapCentreReach] — applied only to the *instance*
/// search, and proportional to how far a centre escapes its own definition's
/// bound rather than to the largest radius in the drawing.
///
/// Two channels rather than one, because the sharp bound and the
/// survives-anything bound have different audiences:
///
/// * [pick] — the margin every pick and every snap widens its broad phase
///   by. Zero unless a round leaf sits under a non-conformal transform,
///   which is the rare case.
/// * [crude] — the bound that stays valid under **any** further transform,
///   `approximating radius + distance from centre to box`. Used when lifting
///   a definition's slack through a non-conformal instance, where the
///   sharper channel's assumptions no longer hold; see [through].
class NarrowPhaseSlack {
  const NarrowPhaseSlack(this.pick, this.crude);

  static const NarrowPhaseSlack none = NarrowPhaseSlack(0, 0);

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
  /// separate closed forms.
  ///
  /// **The headroom that buys, measured rather than asserted:** the bound
  /// stays at least **2x** the two effects' sum over the entire range where
  /// it is active — `2.005x` as `k` approaches 1, where both terms go as
  /// `eps/2` and the ratio is therefore tightest, rising to `2.34x` at
  /// `k = 1.5625`, where `4 * (sqrt(k) - 1)` reaches 1 and the clamp hands
  /// over to the crude bound, which is rigorous for any `k`. (A worked
  /// example, since "at least 2x" is easy to misread as the margin rather
  /// than the ratio: at `k = 1.2` the sum is `0.181` against this bound's
  /// `0.382`.) A search over `k` from `1 + 1e-7` to 1000, including sweeps
  /// placed at and just inside quadrant boundaries and a hill-climb
  /// maximising the ratio per `k`, found no configuration where the bound is
  /// exceeded.
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
      return NarrowPhaseSlack(tight, crude);
    }

    // The rim term only. The arc *centre* used to be bounded here too, by
    // `centreGap + rho * fraction`; it is indexed as its own point now (see
    // this class's doc comment and [ContainerIndex.searchSnapCentres]), so
    // there is nothing left for a query margin to reach.
    final rim = crude * deviationFraction(k);
    return NarrowPhaseSlack(rim, crude);
  }

  /// The larger of each channel — the slack of a set of leaves is the worst
  /// of them, since the query is widened once for all of them.
  NarrowPhaseSlack union(NarrowPhaseSlack other) => NarrowPhaseSlack(
        pick > other.pick ? pick : other.pick,
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
      sigmaMax * crude,
    );
  }

  /// The margin a pick or a snap must widen its broad phase by.
  final double pick;

  /// The margin that stays valid however the leaves below are transformed
  /// afterwards. Never used as a query margin directly — only by [through].
  final double crude;

  @override
  String toString() => 'NarrowPhaseSlack($pick, $crude)';
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
