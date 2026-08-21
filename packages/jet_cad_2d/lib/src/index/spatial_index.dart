import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../core/handle.dart';
import '../core/tolerance.dart';
import '../document/doc_change.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/node.dart';
import '../document/text_geometry.dart';
import '../geometry/aabb2.dart';
import '../geometry/distance.dart';
import '../geometry/primitives.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'container_index.dart';
import 'dirty_list.dart';
import 'hit.dart';
import 'query_filter.dart';
import 'query_scratch.dart';
import 'snap.dart';

/// Thrown when a query runs inside another query's visitor, or when the
/// document is mutated inside one.
///
/// Both corrupt the walk. The index owns a single reusable scratch stack —
/// that is what makes a query allocation-free — so a nested query overwrites
/// the outer one's state, and a mutation changes the structure being walked
/// underneath it.
class QueryReentrancyError implements Exception {
  const QueryReentrancyError(this.what);
  final String what;
  @override
  String toString() =>
      'QueryReentrancyError: $what is not permitted inside a query visitor. '
      'Collect the results first, then act on them.';
}

/// The most candidates an intersection snap will consider.
///
/// Pairwise testing is quadratic, so an uncapped version degrades without
/// bound on a dense drawing: 64 candidates is already `64 * 63 / 2 = 2016`
/// pair tests, once per pointer move. The number is declared here, as a
/// named constant, rather than invented inline, so it is testable and
/// tunable rather than buried in [SpatialIndex._considerIntersections].
///
/// **The cap is disclosed, not silent.** [SnapResult] carries no "some
/// candidates were dropped" flag, and that is a deliberate choice, not an
/// oversight: [SpatialIndex._considerIntersections] always takes exactly
/// the entities with the [kIntersectionCandidateCap] **greatest** handle
/// values among those the query rectangle touches — a fixed, documented,
/// deterministic rule, not "whatever the R-tree happened to visit first".
/// A caller that needs to know a rectangle holds more line-like entities
/// than that already has [SpatialIndex.forEachInRect] to count them
/// directly, so a second reporting mechanism here would just be a second,
/// redundant way to ask the same question.
///
/// **Greatest, not lowest.** Ascending handle value is draw order
/// throughout this package, and every other decision the snap engine makes
/// on a tie — [SpatialIndex._considerSnapCandidate]'s root and leaf terms,
/// [SpatialIndex._considerLeaf]'s, and the `winningSlot` naming rule inside
/// `_considerIntersections` itself — resolves in favour of the *later*
/// drawn entity. Capping from the low end contradicted all of them, and did
/// so where it is least acceptable: in a dense area the entity dropped from
/// intersection snapping was the one the user had just drawn.
const int kIntersectionCandidateCap = 64;

/// The bits of the snap kinds [SpatialIndex._considerSnapLeaf] actually
/// produces — every kind except `center`, which comes from
/// [ContainerIndex.searchSnapCentres], and `intersection`, which
/// [SpatialIndex._considerIntersections] handles on its own root-level walk.
///
/// A snap whose mask has none of these bits can skip the leaf walk entirely.
/// `final`, not `const`: an enum's `.index` is not a constant expression, and
/// hard-coding the two literals here is exactly the staleness
/// [SnapMask.cheap]'s doc comment describes guarding against.
final int _kLeafProducedSnapKinds = SnapMask.all.bits &
    ~((1 << SnapKind.center.index) | (1 << SnapKind.intersection.index));

/// One placement of a definition: the container that places it, the instance
/// node that does the placing, and that node's composed transform into the
/// container's own space.
///
/// A class rather than a record because [SpatialIndex._placedBy] holds these
/// in long-lived lists rebuilt only when a [ContainerIndex] is replaced —
/// there is nothing per-query or per-edit about them — and a named type is
/// what lets [SpatialIndex._growPlacements] read as prose. The [transform] is
/// the one [ContainerIndex] already owns, shared rather than copied.
class _Placement {
  const _Placement(this.container, this.node, this.transform);

  final ContainerIndex container;
  final Handle node;
  final Transform2 transform;
}

/// Every [ContainerIndex] in a document, kept current against its changes.
///
/// One index per indexed container: the tree root, plus every definition —
/// including definitions with no instances, since one may be placed at any
/// moment and building on demand would put an unbounded build inside a query.
///
/// **Definitions must be in place before construction, or followed by an
/// explicit [rebuildAll].** [DocumentTree.addDefinition] and
/// [DocumentTree.removeDefinition] are not commands — nothing calling either
/// one emits a [DocChange], so this class has no way to hear about it. A
/// definition added afterwards never gets a [ContainerIndex]; one removed
/// leaves a stale entry that [rebuildContainer] would reject and only
/// [rebuildAll] clears. A future plan that turns definition mutation into
/// commands removes this caveat along with the gap it names.
///
/// **Editing a definition's *contents*, on the other hand, is fully
/// incremental.** An instance is indexed in its placing container by the
/// definition's bound, so an entity added to a definition has to widen every
/// box that places it or no query ever steps in far enough to find it — see
/// [_placedBy] and [_growPlacements] for how that is done without a rebuild
/// and without walking every container.
///
/// **Both directions, and that is not decoration.** Growth alone is monotone,
/// and monotone here is not a small conservatism of the kind
/// [ContainerIndex.ownNarrowPhaseSlack] gets away with: a slack is a
/// broad-phase margin of bounded size with a narrow phase behind it to reject
/// what it lets through, whereas an instance box is what
/// [forEachInstanceInRect] *reports* and what [pickInto] descends into, with
/// nothing behind it. Left to grow only, one out-and-back drag inside a
/// definition placed 3000 times left every one of those boxes at the furthest
/// reach of the gesture and took a pick over the empty space it had crossed
/// from 0.4 us to 3.75 ms — a quarter of a frame, over geometry that is not
/// there, for the rest of the index's life. [_letBoundRecede] is the way
/// back.
class SpatialIndex {
  SpatialIndex(this.document) {
    rebuildAll();
    // Synchronous, not `document.changes.listen`: that stream is an async
    // broadcast controller, so the index would be stale for the rest of the
    // current turn and a query issued right after an edit would quietly
    // return the old answer.
    document.commands.onAfterMutate = _onChange;
    // Same reasoning as the reentrancy guard below: mutating the document
    // from inside a query visitor changes the structure being walked
    // underneath it, and is the likelier and less expected of the two
    // mistakes a caller can make — nothing about a `void Function(int
    // slot)` visitor suggests that mutating is forbidden.
    document.commands.onBeforeMutate = _guardMutation;
  }

  final DraftDocument document;
  final Map<Handle, ContainerIndex> _byContainer = <Handle, ContainerIndex>{};

  /// Every place a definition is placed, keyed by definition handle — the
  /// reverse of the `instance -> definition` edge the tree already carries.
  ///
  /// Rebuilt wholesale by [_rebuildPlacements] whenever any [ContainerIndex]
  /// is replaced, so an entry can never name a container object that is no
  /// longer in [_byContainer].
  ///
  /// **Why it exists.** An instance is indexed by its definition's bound, and
  /// that bound is derived once, in the placing container's build. Adding an
  /// entity to a definition dirties one leaf inside the *definition's* index
  /// and touches nothing above it, so every box that places that definition
  /// silently keeps describing it as it was. Reconciliation already knows
  /// which definition it is editing; what it did not have, and this supplies,
  /// is a way to get from there to the containers that place it without
  /// walking every container in the document on every edit. See
  /// [_growPlacements].
  final Map<Handle, List<_Placement>> _placedBy = <Handle, List<_Placement>>{};

  bool _disposed = false;

  /// Set for the duration of a query walk; see [_beginQuery] and [_endQuery].
  bool _inQuery = false;

  /// Installed as [CommandDispatcher.onBeforeMutate]. A tear-off, not an
  /// inline closure literal: [dispose] must be able to tell *this* index's
  /// hook apart from another index's over the same document, and two
  /// tear-offs of the same instance method on the same receiver compare
  /// `==` — see the identical reasoning on [_onChange] and [dispose] below.
  /// A closure allocated fresh at construction time would not have that
  /// property.
  void _guardMutation() {
    if (_inQuery) throw const QueryReentrancyError('mutating the document');
  }

  /// Raises the reentrancy flag for the duration of a query walk, throwing
  /// if one is already raised.
  ///
  /// **Not a closure-taking `_guarded(body)` helper**, deliberately: an
  /// earlier version of this guard wrapped each query's body in a closure
  /// literal passed to a shared helper. That reads well, but a closure
  /// literal captures its enclosing scope — here, `this` plus whichever of
  /// `world`, `filter` and `visit` the body touches — into a freshly
  /// allocated context and Closure object on *every call*. `forEachInRect`
  /// and `forEachInstanceInRect` are both named in this package's
  /// zero-allocation-on-the-frame-path constraint, so that per-call
  /// allocation is exactly what it forbids — the same class of cost the
  /// constraint already rejects `List.sublist` for elsewhere in this index.
  ///
  /// [_beginQuery] and [_endQuery] are plain instance methods with no
  /// parameters and nothing to capture, so calling them allocates nothing;
  /// the `try`/`finally` itself lives directly in each query method's body
  /// (see [forEachInRect] and [forEachInstanceInRect]) rather than inside a
  /// helper that would need a closure to reach it. If a future query
  /// method (`pickInto`, `snapInto`) wants to share this shape, copy the
  /// `_beginQuery(); try { ... } finally { _endQuery(); }` pattern rather
  /// than reintroducing a closure-taking wrapper — do not "clean this up"
  /// back into one.
  void _beginQuery() {
    if (_inQuery) throw const QueryReentrancyError('a nested query');
    _inQuery = true;
  }

  /// Lowers the reentrancy flag. Always called from a `finally`, never a
  /// trailing statement: a visitor that throws — or an exception the walk
  /// itself raises, independent of the visitor — must not leave the index
  /// permanently unqueryable.
  void _endQuery() {
    _inQuery = false;
  }

  ContainerIndex? indexFor(Handle container) => _byContainer[container];

  ContainerIndex get rootIndex {
    if (_disposed) {
      throw StateError('SpatialIndex used after dispose()');
    }
    return _byContainer[document.rootHandle]!;
  }

  int get containerCount => _byContainer.length;

  final QueryScratch _scratch = QueryScratch();

  /// A [QueryScratch], not a `List<Handle>`: `List.clear()` is not a cheap
  /// length reset in the Dart VM — it shrinks the backing array to empty
  /// once it has held anything, so every subsequent query regrows it from
  /// scratch. That is precisely the allocation [QueryScratch.reset] exists to
  /// avoid, so this buffer gets the same treatment even though its entries
  /// are instance [Handle.value]s rather than entity slots — see
  /// [QueryScratch.sortByValue], the sibling of [QueryScratch.sortByHandle]
  /// for a buffer that is already keyed by its own stored value.
  final QueryScratch _instanceScratch = QueryScratch();

  late final FilterEvaluator _filters = FilterEvaluator(document);

  /// The live capacity of the entity-query scratch buffer. Test-visible for
  /// the same reason as [rebuildCount]: the load-bearing guarantee is that a
  /// warmed query never regrows it.
  int get entityScratchCapacity => _scratch.capacity;

  /// The live capacity of the instance-query scratch buffer. Same reasoning
  /// as [entityScratchCapacity].
  int get instanceScratchCapacity => _instanceScratch.capacity;

  /// Visits the slot of every root-level leaf whose box overlaps [world],
  /// in ascending handle order.
  ///
  /// **Does not descend into instances.** A shared definition's entities would
  /// otherwise be reported once per instance, with no way to tell the
  /// instances apart — and the renderer does not want that, since it replays
  /// one cached picture per instance. Use [forEachInstanceInRect] for those,
  /// and `pickInto` when you need to descend.
  ///
  /// **Not reentrant.** Both rect queries share this index's scratch
  /// buffers; calling either one again from inside [visit] — or mutating the
  /// document from inside it — throws [QueryReentrancyError] rather than
  /// corrupting the outer call's in-progress buffer or silently truncating
  /// its results.
  void forEachInRect(
      Aabb2 world, QueryFilter filter, void Function(int slot) visit) {
    final root = rootIndex; // throws if disposed, even for an empty rect
    if (world.isEmpty) return;
    _beginQuery();
    // Guard body inlined rather than passed as a closure to a shared
    // helper — see the doc comment on [_beginQuery] for why: a closure
    // literal here would capture `this`, `root`, `filter` and `visit` into
    // a fresh allocation on every call, which this method's zero-allocation
    // frame-path guarantee forbids.
    try {
      _scratch.reset();
      root.searchLeaves(world, (slot) {
        if (_filters.acceptsEntity(slot, filter)) _scratch.add(slot);
      });
      _scratch.sortByHandle(document.entities);
      for (var i = 0; i < _scratch.length; i++) {
        visit(_scratch[i]);
      }
    } finally {
      _endQuery();
    }
  }

  /// Visits every root-level instance whose box overlaps [world], ascending.
  ///
  /// See [forEachInRect]'s doc comment: the same not-reentrant caveat
  /// applies here too, since both methods share this index's scratch state.
  void forEachInstanceInRect(
      Aabb2 world, QueryFilter filter, void Function(Handle instance) visit) {
    final root = rootIndex; // throws if disposed, even for an empty rect
    if (world.isEmpty) return;
    _beginQuery();
    // Same reasoning as [forEachInRect]: the guard is inlined, not passed
    // as a closure to a shared helper, so this method allocates nothing per
    // call beyond what the walk itself already needs.
    try {
      _instanceScratch.reset();
      root.searchInstances(world, (node) {
        if (_filters.acceptsNode(node, filter)) {
          _instanceScratch.add(node.value);
        }
      });
      _instanceScratch.sortByValue();
      for (var i = 0; i < _instanceScratch.length; i++) {
        visit(Handle(_instanceScratch[i]));
      }
    } finally {
      _endQuery();
    }
  }

  // --- pickInto ------------------------------------------------------

  /// Best-so-far for the pick in progress, held as fields rather than
  /// threaded through the recursion or returned as a record: a record
  /// carrying a `Vector2` field would allocate one per candidate, exactly
  /// what this method's zero-allocation guarantee forbids. `_bestEntity` and
  /// `_bestRoot` are raw handle values, not [Handle]s, purely so the
  /// tie-break comparisons below read as plain integer comparisons.
  HitKind? _bestKind;
  int _bestEntity = 0;
  int _bestRoot = 0;

  /// Scratch endpoints for [distanceToSegment] and centres for
  /// [distanceToCircle]/[distanceToArc], reused across every candidate of
  /// every pick. Mutated with [Vector2.setValues], never replaced: replacing
  /// either with a fresh `Vector2` would be exactly the per-candidate
  /// allocation the zero-allocation guarantee on [pickInto] forbids.
  final Vector2 _scratchA = Vector2.zero();
  final Vector2 _scratchB = Vector2.zero();

  /// One text candidate's resolved attributes, composed local transform and
  /// glyph box, refilled in place for every text or attrib leaf a pick
  /// considers. Same reasoning as [_scratchA]/[_scratchB]: calling
  /// `resolveTextAttributes`, `textLocalTransform` and `textLocalBounds`
  /// instead would build three fresh objects per candidate — four with the
  /// inverse the box test needs — including a [Transform2] and an [Aabb2],
  /// two of the three classes
  /// `test/invariants/query_allocation_test.dart` watches — which is exactly
  /// the per-candidate allocation [pickInto]'s guarantee forbids. See
  /// [TextLayout]'s own doc comment for why the layout math itself is not
  /// inlined here instead.
  final TextLayout _textLayout = TextLayout();

  /// The instance handle taken to reach each depth of the current descent,
  /// root first. Copied into [HitPath.chain] by [_writeChain] when a new
  /// best candidate is found. Grows, never shrinks, like every other scratch
  /// in this class.
  Uint32List _instancePath = Uint32List(16);

  /// The container (root or definition) being searched at each depth of the
  /// current descent. Exists only to make [_pickIn]'s cycle guard an O(depth)
  /// scratch scan instead of a `Set<Handle>` allocated per pick.
  Uint32List _containerPath = Uint32List(16);

  void _ensurePathCapacity(int depth) {
    if (depth < _instancePath.length) return;
    var capacity = _instancePath.length;
    while (capacity <= depth) {
      capacity *= 2;
    }
    final growIn = Uint32List(capacity)..setAll(0, _instancePath);
    final growContainer = Uint32List(capacity)..setAll(0, _containerPath);
    _instancePath = growIn;
    _containerPath = growContainer;
  }

  /// One reusable instance-collection buffer per recursion depth, so a pick
  /// through nested instances allocates nothing once the deepest level any
  /// pick has reached is warmed.
  ///
  /// A [QueryScratch] per level, not a `List<Handle>`: the same
  /// `List.clear()`-regrows-every-time hazard [_instanceScratch]'s doc
  /// comment describes applies here too, once per nesting level instead of
  /// once per query. The outer `List<QueryScratch>` itself only grows the
  /// first time a pick reaches a new maximum depth, which is the same
  /// grows-once shape as every other scratch buffer in this class.
  final List<QueryScratch> _levelScratch = <QueryScratch>[];

  QueryScratch _scratchForDepth(int depth) {
    while (_levelScratch.length <= depth) {
      _levelScratch.add(QueryScratch());
    }
    return _levelScratch[depth];
  }

  // --- snapInto --------------------------------------------------------

  /// Best-so-far for the snap in progress, held as fields for the same
  /// zero-allocation reason as [_bestKind] et al. above -- see
  /// [_considerSnapCandidate]'s doc comment for the comparison these back.
  SnapKind? _bestSnapKind;
  double _bestSnapDist = double.infinity;
  int _bestSnapEntity = 0;
  int _bestSnapRoot = 0;

  /// Segment endpoints and the projected-point `out` for
  /// [projectOntoSegment], reused across every `nearest`/`perpendicular`
  /// candidate of every snap. Same zero-allocation reasoning as
  /// [_scratchA]/[_scratchB] above, and deliberately not those two fields:
  /// this class's not-reentrant contract means pick and snap never run at
  /// the same time, so sharing would not be *unsafe*, but [_scratchA]'s own
  /// doc comment says "every pick" — reusing it here for snapping would
  /// make that comment inaccurate rather than save anything real.
  final Vector2 _snapSegA = Vector2.zero();
  final Vector2 _snapSegB = Vector2.zero();
  final Vector2 _snapProjection = Vector2.zero();

  /// The two tangent points [_tangentPoints] computes, reused across every
  /// `tangent` candidate of every snap. Same reasoning as [_snapSegA] et al.
  final Vector2 _snapTangentA = Vector2.zero();
  final Vector2 _snapTangentB = Vector2.zero();

  /// Segment endpoints and the crossing-point `out` for [segmentIntersection]
  /// in [_considerIntersections], reused across every pair of every
  /// intersection snap.
  final Vector2 _isectA1 = Vector2.zero();
  final Vector2 _isectA2 = Vector2.zero();
  final Vector2 _isectB1 = Vector2.zero();
  final Vector2 _isectB2 = Vector2.zero();
  final Vector2 _isectOut = Vector2.zero();

  /// Finds the topmost entity within [radius] of [world], descending into
  /// every instance the query touches and reporting the full path down to
  /// the leaf.
  ///
  /// **No-hit contract:** returns `false` on a miss, and [out] is left
  /// exactly as [HitPath.reset] leaves it — `chainLength` zero, `entity`
  /// [Handle.none], `worldPoint` the origin, `kind` [HitKind.edge],
  /// `truncated` false. [out] is reset unconditionally at the start of
  /// *every* call, not only on a miss, so a caller that forgets to check the
  /// boolean result can never mistake a previous pick's hit for this one's.
  ///
  /// Descends into instances, unlike [forEachInRect] — a pick wants the
  /// leaf, and [HitPath.chain] records which instance it was reached
  /// through, which is exactly what [forEachInRect] deliberately does not
  /// report.
  ///
  /// **Not reentrant.** Shares this index's scratch state with every other
  /// query; see [forEachInRect]'s doc comment for why.
  bool pickInto(Vector2 world, double radius, QueryFilter filter, HitPath out) {
    final root = rootIndex; // throws if disposed
    _beginQuery();
    // Guard body inlined, not passed to a closure-taking helper -- see the
    // doc comment on [_beginQuery].
    try {
      out.reset();
      _bestKind = null;
      _bestEntity = 0;
      _bestRoot = 0;
      final broad = radius + _broadPhaseMargin().pick;
      _descend(root, Transform2.identity(), world, radius, broad, broad, filter,
          0, out, SnapMask.none, null);
      return _bestKind != null;
    } finally {
      _endQuery();
    }
  }

  /// Searches one container, then recurses into whichever of its instances
  /// the query touches. Shared by [pickInto] and [snapInto]: exactly one of
  /// [pickOut] / [snapOut] is non-null, and that is what selects which of
  /// [_considerLeaf] / [_considerSnapLeaf] runs for each candidate leaf --
  /// a plain branch on an already-in-hand field, not a closure, so sharing
  /// this walk adds no allocation of its own. [snapMask] is only meaningful
  /// when [snapOut] is non-null.
  ///
  /// **Collects instances into [_scratchForDepth], then recurses after the
  /// visitor has closed — never inside it.** [ContainerIndex.searchInstances]
  /// walks its `PackedRTree`'s own traversal stack; that stack is a field on
  /// the tree object, reused across calls for the same reason every other
  /// scratch in this class is, and `PackedRTree.search`'s own doc comment
  /// says plainly that calling it again from inside its visitor corrupts the
  /// walk. Recursing straight into the visitor reads more naturally, passes
  /// every shallow test, and risks exactly that corruption the moment two
  /// instances at the same depth are found before either is recursed into.
  ///
  /// **Inherited, not fixed, cost:** the leaf, snap-centre and instance
  /// visitors below are each a closure over this call's locals, and a fresh
  /// set is allocated on *every* recursive call — one per level of nesting a
  /// query descends through. (Three now rather than two: `visitSnapCentre`
  /// is declared unconditionally so the fused and unfused search calls can
  /// share it, and a closure costs far less than the second full scan of the
  /// dirty overlay that fusing avoids.) That was true of
  /// `pickInto`'s descent before this method existed and stays true now that
  /// `snapInto` shares it too; sharing the walk means `snapInto` does not
  /// add a *second*, independent occurrence of the same cost elsewhere in
  /// this file. Measured, not eliminated, by Task 17's allocation harness
  /// (`test/invariants/query_allocation_test.dart`), per that task's own
  /// scope.
  ///
  /// **A second, smaller cost of the same shape:** `toWorld.multiply(...)`
  /// below allocates one [Transform2] per *instance actually recursed into*
  /// — [Transform2] is immutable, same as [Aabb2], so composing a transform
  /// can only ever hand back a fresh one. This is bounded by nesting depth
  /// times branching, not by candidate or leaf count, the same shape as the
  /// closure-pair cost above and unlike the per-candidate cost the harness's
  /// tight zero-allocation assertion actually targets — see that harness's
  /// own file comment for why a root-only fixture cannot see either of these
  /// two costs and why a nested one is required to catch them. Eliminating
  /// it would mean threading `toWorld` through this recursion as six raw
  /// doubles instead of a [Transform2], the same shape [_considerLeaf]
  /// already uses for its own per-candidate transform math; left for a
  /// future task rather than done here, since it touches this method's
  /// signature and every call site of it.
  void _descend(
    ContainerIndex index,
    Transform2 toWorld,
    Vector2 world,
    double radius,
    double broadRadius,
    double instanceRadius,
    QueryFilter filter,
    int depth,
    HitPath? pickOut,
    SnapMask snapMask,
    SnapResult? snapOut,
  ) {
    _ensurePathCapacity(depth);
    _containerPath[depth] = index.container.value;

    final Transform2 toLocal;
    try {
      toLocal = toWorld.invert();
    } on SingularTransformError {
      // A singular transform collapses this container's geometry to
      // nothing in world space: there is nothing to hit and nothing to
      // report.
      return;
    }
    // [broadRadius], not [radius]: the broad phase must cover every point
    // the narrow phase would accept, and for a circle or an arc that region
    // is not the entity's own indexed box -- see [_broadPhaseMargin] and
    // [NarrowPhaseSlack]. Widening the world square before inverting is what
    // makes one margin correct at every depth: an ancestor's instance box
    // always contains the mapped-up box of the leaf inside it, so a query
    // that reaches the leaf's own box necessarily reaches every instance box
    // on the way down to it.
    //
    final localQuery = _localQueryBox(toLocal, world, broadRadius);
    // A second, wider box for the instance search *only*, and only when the
    // two radii actually differ -- see [_centreDescentMargin] for the one
    // thing that widens it. Reusing `localQuery` when they agree, which is
    // the overwhelmingly common case, is what keeps this method's
    // one-`Aabb2`-per-recursion-level allocation profile intact; the
    // allocation harness budgets that per level.
    final instanceQuery = instanceRadius == broadRadius
        ? localQuery
        : _localQueryBox(toLocal, world, instanceRadius);

    void visitLeaf(int slot) {
      if (!_filters.acceptsEntity(slot, filter)) return;
      _composeLeafTransform(toWorld, index.transformOfLeaf(slot));
      if (pickOut != null) {
        _considerLeaf(slot, _lta, _ltb, _ltc, _ltd, _lte, _ltf, world, radius,
            depth, pickOut);
      } else {
        _considerSnapLeaf(slot, _lta, _ltb, _ltc, _ltd, _lte, _ltf, world,
            radius, snapMask, depth, snapOut!);
      }
    }

    // The `center` candidates, from their own tree and under the *same*
    // tight box -- never a widened one. This walk is why the box above no
    // longer has to reach an arc's centre from the arc's own sliver of a
    // bound.
    void visitSnapCentre(int slot) {
      if (!_filters.acceptsEntity(slot, filter)) return;
      _composeLeafTransform(toWorld, index.transformOfLeaf(slot));
      _considerSnapCentre(slot, _lta, _ltb, _ltc, _ltd, _lte, _ltf, world,
          radius, depth, snapOut!);
    }

    // A snap for `center` alone has nothing to ask of the leaf walk: every
    // other kind's candidates come from [_considerSnapLeaf], and `center`'s
    // now come from the centre tree. Skipping it is what makes a centre-only
    // mask cheap rather than merely correct.
    final leafWalkWanted =
        pickOut != null || (snapMask.bits & _kLeafProducedSnapKinds) != 0;
    final centreWalkWanted = snapOut != null && snapMask.has(SnapKind.center);

    // Fused when both are wanted -- which is every default snap, since
    // `SnapMask.cheap` includes `center` -- so the dirty overlay in front of
    // the two trees is scanned once rather than twice. See
    // [ContainerIndex.searchLeavesAndSnapCentres].
    if (leafWalkWanted && centreWalkWanted) {
      index.searchLeavesAndSnapCentres(localQuery, visitLeaf, visitSnapCentre);
    } else if (leafWalkWanted) {
      index.searchLeaves(localQuery, visitLeaf);
    } else if (centreWalkWanted) {
      index.searchSnapCentres(localQuery, visitSnapCentre);
    }

    final level = _scratchForDepth(depth)..reset();
    index.searchInstances(instanceQuery, (node) {
      if (_filters.acceptsNode(node, filter)) level.add(node.value);
    });

    for (var i = 0; i < level.length; i++) {
      final node = Handle(level[i]);
      final resolved = document.tree[node];
      if (resolved is! InstanceNode) continue;
      final child = _byContainer[resolved.definition];
      if (child == null) continue;

      // Cycle guard: never re-enter a container already open on this path.
      // A well-formed document cannot reach this -- AddNodeCommand's own
      // cycle check refuses to create a definition cycle in the first
      // place -- but a `seen`-style check costs little and turns a
      // hypothetical malformed graph into "this branch reports nothing
      // further" rather than a hang, the same trade [ContainerIndex.build]
      // makes with its own `seen` set. A scratch array rather than a
      // `Set<Handle>`: a fresh `Set` would allocate on every recursive
      // step, which this method's zero-allocation guarantee forbids.
      var cyclic = false;
      for (var d = 0; d <= depth; d++) {
        if (_containerPath[d] == child.container.value) {
          cyclic = true;
          break;
        }
      }
      if (cyclic) continue;

      _instancePath[depth] = node.value;
      // The instance's transform is already composed to this container's
      // space by ContainerIndex.build, since any groups between them were
      // flattened; toWorld then lifts it the rest of the way. The argument
      // to multiply is applied first (see Transform2.multiply), so this is
      // toWorld-after-instance, never the reverse -- reversing it would
      // silently misplace every entity behind a rotated or scaled instance.
      final composed = toWorld.multiply(index.transformOfInstance(node));
      _descend(child, composed, world, radius, broadRadius, instanceRadius,
          filter, depth + 1, pickOut, snapMask, snapOut);
    }
  }

  /// The AABB, in the local space [toLocal] maps world space into, of the
  /// world square centred on [world] with half-size [halfSize].
  ///
  /// Built from raw doubles, not `Aabb2(Vector2, Vector2).transformedBy(...)`:
  /// that reads better but was measured (Task 17's allocation harness) to
  /// allocate roughly ten `Vector2`/`Aabb2` objects per call -- the four
  /// corners as `Vector2`s, `Aabb2.fromPoints`' intermediate `List`, and one
  /// `Aabb2.raw` per fold step of `expandedToPoint`. Since this runs once (or,
  /// when the instance search needs a wider box, twice) per *recursion level*,
  /// not once per candidate, every one of those was a real steady-state
  /// allocation scaling with how deep a pick or snap descends through nested
  /// instances. All four corners of the square are still transformed and
  /// bounded -- same conservative-under-rotation contract as
  /// [Aabb2.transformedBy] -- just with the min/max fold done over plain
  /// doubles instead of immutable objects, the same style [_considerLeaf]
  /// already uses for its own per-candidate transform math.
  ///
  /// A plain method with no captures, so calling it allocates nothing beyond
  /// the one `Aabb2` it returns -- see [_beginQuery]'s doc comment on why a
  /// closure would not do.
  Aabb2 _localQueryBox(Transform2 toLocal, Vector2 world, double halfSize) {
    final wMinX = world.x - halfSize, wMinY = world.y - halfSize;
    final wMaxX = world.x + halfSize, wMaxY = world.y + halfSize;
    final la = toLocal.a, lb = toLocal.b, lc = toLocal.c;
    final ld = toLocal.d, le = toLocal.e, lf = toLocal.f;
    var qMinX = la * wMinX + lc * wMinY + le;
    var qMinY = lb * wMinX + ld * wMinY + lf;
    var qMaxX = qMinX, qMaxY = qMinY;
    for (var i = 1; i < 4; i++) {
      final cx = (i & 1) == 0 ? wMinX : wMaxX;
      final cy = (i & 2) == 0 ? wMinY : wMaxY;
      final lx = la * cx + lc * cy + le;
      final ly = lb * cx + ld * cy + lf;
      if (lx < qMinX) qMinX = lx;
      if (lx > qMaxX) qMaxX = lx;
      if (ly < qMinY) qMinY = ly;
      if (ly > qMaxY) qMaxY = ly;
    }
    return Aabb2.raw(qMinX, qMinY, qMaxX, qMaxY);
  }

  /// The six coefficients of the last transform [_composeLeafTransform]
  /// built, read straight back by [_descend]'s two visitors.
  ///
  /// Fields rather than a returned record or `Transform2`: this is computed
  /// once per *candidate*, and either of those would allocate one object per
  /// candidate -- exactly what `pickInto`'s and `snapInto`'s zero-allocation
  /// guarantee forbids. They are read immediately and passed **by value**
  /// into the `_consider*` methods, so nothing downstream depends on them
  /// surviving another candidate.
  double _lta = 0, _ltb = 0, _ltc = 0, _ltd = 0, _lte = 0, _ltf = 0;

  /// Composes [toWorld] after [group] into [_lta]..[_ltf].
  ///
  /// A leaf reached through a flattened GroupNode carries that group's
  /// composed transform ([group] is null when there is none, which is the
  /// common case); the narrow phase needs toWorld-after-group, since the
  /// leaf's stored coordinates are in the group's space, not the container's.
  /// The argument order matches [Transform2.multiply] -- the group is applied
  /// first, then toWorld -- so this is `toWorld.multiply(group)` written out.
  void _composeLeafTransform(Transform2 toWorld, Transform2? group) {
    if (group == null) {
      _lta = toWorld.a;
      _ltb = toWorld.b;
      _ltc = toWorld.c;
      _ltd = toWorld.d;
      _lte = toWorld.e;
      _ltf = toWorld.f;
      return;
    }
    _lta = toWorld.a * group.a + toWorld.c * group.b;
    _ltb = toWorld.b * group.a + toWorld.d * group.b;
    _ltc = toWorld.a * group.c + toWorld.c * group.d;
    _ltd = toWorld.b * group.c + toWorld.d * group.d;
    _lte = toWorld.a * group.e + toWorld.c * group.f + toWorld.e;
    _ltf = toWorld.b * group.e + toWorld.d * group.f + toWorld.f;
  }

  /// Measures one candidate leaf in world space and, if it is the best hit
  /// found so far this pick, writes it into [out].
  ///
  /// The world transform arrives as its six raw coefficients rather than as
  /// a [Transform2], because [_descend] must compose the container's own
  /// transform with the leaf's flattened-group transform for every candidate
  /// (see [ContainerIndex.transformOfLeaf]) and building a `Transform2` to
  /// hold the product would allocate one matrix per candidate — exactly what
  /// this method's zero-allocation guarantee forbids. The coefficients are
  /// passed by value, so nothing here depends on a shared scratch matrix
  /// staying untouched for the duration of the call.
  ///
  /// Every point and segment is transformed into world space with them
  /// **before** measuring -- never the other way round, which is what lets
  /// this stay exact under a mirrored or non-uniformly scaled instance
  /// without any ellipse math. Priority within one entity is checked in the
  /// fixed order vertex, then edge, then fill: a click near a line's
  /// endpoint means the endpoint, even though it is also on the line.
  ///
  /// Deliberately not delegated to [distanceToPolyline], [insideClosedPolyline]
  /// or [nearestVertexDistance]: each takes a [GeometryPayload] in the query's
  /// own space, and building a world-space payload per candidate would
  /// allocate a `Float64List` (or a `GeometryPayload` wrapping one) on every
  /// call -- exactly what this method's zero-allocation guarantee forbids.
  /// The transform is fused into each loop below instead, using raw doubles
  /// so nothing but the two hoisted scratch vectors above is ever touched.
  /// [distanceToSegment], [distanceToCircle] and [distanceToArc] take
  /// individual `Vector2` arguments rather than a payload, so those three
  /// are reused directly against the hoisted scratch vectors.
  void _considerLeaf(
    int slot,
    double ta,
    double tb,
    double tc,
    double td,
    double te,
    double tf,
    Vector2 world,
    double radius,
    int depth,
    HitPath out,
  ) {
    final kind = document.entities.kindAt(slot);
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final coords = payload.coords;
    final count = payload.pointCount;
    if (count == 0) return;

    HitKind? foundKind;
    var foundX = 0.0, foundY = 0.0;

    switch (kind) {
      case EntityKind.point:
        // The only geometric feature is the point itself, treated as a
        // vertex, since that is the one feature there is to grab.
        final lx = coords[0], ly = coords[1];
        final wx = ta * lx + tc * ly + te, wy = tb * lx + td * ly + tf;
        final dx = world.x - wx, dy = world.y - wy;
        if (math.sqrt(dx * dx + dy * dy) <= radius) {
          foundKind = HitKind.vertex;
          foundX = wx;
          foundY = wy;
        }

      case EntityKind.text:
      case EntityKind.attrib:
        // The laid-out box is the hit geometry ([HitKind.fill]); the
        // insertion point stays a *snap* candidate (see
        // [_considerSnapLeaf]'s own text case) and is no longer a pick
        // candidate. Picking and snapping are different questions: a label
        // is grabbed by the words the eye sees, and the insertion point is
        // a construction reference, not a handle.
        //
        // Everything below writes into [_textLayout] and plain locals. The
        // obvious spelling -- `resolveTextAttributes` +
        // `textLocalTransform` + `textLocalBounds`, then
        // `Transform2.invert()` -- builds four objects per candidate, which
        // is what this method's zero-allocation guarantee forbids.
        final style = document.textStyleOf(document.entities.textStyleAt(slot));
        final metrics = document.textMeasurer
            .measure(text: document.entities.textAt(slot), style: style);
        final layout = _textLayout
          ..resolve(payload, document.entities.textAttrsAt(slot), style)
          ..layOutBox(metrics)
          ..composeTransform(metrics, coords[0], coords[1]);

        // A box with no area has nothing to fill: an empty string, or the
        // zero metrics [InsertionPointMeasurer] answers with for every
        // string. Stated as its own rule rather than left to fall out of
        // the containment test, because the brute-force oracle in
        // `test/invariants/reference_query.dart` states the same one and
        // the two must agree on the degenerate case, not merely on the
        // ordinary one.
        if (layout.maxX <= layout.minX || layout.maxY <= layout.minY) return;

        // Glyph space -> this leaf's own space (the layout) -> world
        // (ta..tf), composed into six locals: `Transform2.multiply` and
        // `Transform2.invert` each hand back a fresh matrix, being
        // immutable, so neither can appear on this path.
        final ma = ta * layout.a + tc * layout.b;
        final mb = tb * layout.a + td * layout.b;
        final mc = ta * layout.c + tc * layout.d;
        final md = tb * layout.c + td * layout.d;
        final me = ta * layout.e + tc * layout.f + te;
        final mf = tb * layout.e + td * layout.f + tf;
        final det = ma * md - mb * mc;
        // Singular: a zero height, or an instance transform that collapses
        // this text to a line or a point. Nothing is drawn, so nothing is
        // hit -- the same answer [_descend] gives for a singular container
        // transform, rather than a [SingularTransformError] thrown out of a
        // pointer move.
        if (det == 0.0 || !det.isFinite) return;

        // The query point in glyph space, by solving the 2x2 system rather
        // than forming the inverse: same answer, no matrix.
        final px = world.x - me, py = world.y - mf;
        final gx = (md * px - mc * py) / det;
        final gy = (ma * py - mb * px) / det;
        if (gx >= layout.minX &&
            gx <= layout.maxX &&
            gy >= layout.minY &&
            gy <= layout.maxY) {
          // A fill hit has no feature of its own to report, so the query
          // point stands in for it -- the same convention the closed
          // polyline case below uses.
          foundKind = HitKind.fill;
          foundX = world.x;
          foundY = world.y;
        }

      case EntityKind.line:
      case EntityKind.polyline:
        var bestVertexDist = double.infinity;
        var bestVertexX = 0.0, bestVertexY = 0.0;
        for (var i = 0; i < count; i++) {
          final lx = coords[i * 2], ly = coords[i * 2 + 1];
          final wx = ta * lx + tc * ly + te, wy = tb * lx + td * ly + tf;
          final dx = world.x - wx, dy = world.y - wy;
          final dist = math.sqrt(dx * dx + dy * dy);
          if (dist < bestVertexDist) {
            bestVertexDist = dist;
            bestVertexX = wx;
            bestVertexY = wy;
          }
        }
        if (bestVertexDist <= radius) {
          foundKind = HitKind.vertex;
          foundX = bestVertexX;
          foundY = bestVertexY;
        } else if (count >= 2) {
          var bestEdgeDist = double.infinity;
          var bestEdgeX = 0.0, bestEdgeY = 0.0;
          for (var i = 0; i + 1 < count; i++) {
            final wax = ta * coords[i * 2] + tc * coords[i * 2 + 1] + te;
            final way = tb * coords[i * 2] + td * coords[i * 2 + 1] + tf;
            final wbx = ta * coords[i * 2 + 2] + tc * coords[i * 2 + 3] + te;
            final wby = tb * coords[i * 2 + 2] + td * coords[i * 2 + 3] + tf;
            _scratchA.setValues(wax, way);
            _scratchB.setValues(wbx, wby);
            final dist = distanceToSegment(world, _scratchA, _scratchB);
            if (dist < bestEdgeDist) {
              bestEdgeDist = dist;
              final abx = wbx - wax, aby = wby - way;
              final lenSq = abx * abx + aby * aby;
              if (lenSq == 0.0) {
                bestEdgeX = wax;
                bestEdgeY = way;
              } else {
                var tt =
                    ((world.x - wax) * abx + (world.y - way) * aby) / lenSq;
                if (tt < 0.0) {
                  tt = 0.0;
                } else if (tt > 1.0) {
                  tt = 1.0;
                }
                bestEdgeX = wax + tt * abx;
                bestEdgeY = way + tt * aby;
              }
            }
          }
          if (bestEdgeDist <= radius) {
            foundKind = HitKind.edge;
            foundX = bestEdgeX;
            foundY = bestEdgeY;
          } else if (kind == EntityKind.polyline &&
              count >= 3 &&
              // Closed, not merely convex: fill only applies when the
              // stored points already close the loop. Exact comparison,
              // not a tolerance -- this is "does the data say closed", the
              // same kind of stored-value question `_sameBox` answers
              // exactly elsewhere in this file.
              coords[0] == coords[(count - 1) * 2] &&
              coords[1] == coords[(count - 1) * 2 + 1] &&
              _insideWorldPolygon(
                  coords, count, ta, tb, tc, td, te, tf, world)) {
            foundKind = HitKind.fill;
            foundX = world.x;
            foundY = world.y;
          }
        }

      case EntityKind.circle:
        final lx = coords[0], ly = coords[1];
        final wx = ta * lx + tc * ly + te, wy = tb * lx + td * ly + tf;
        // scaleMagnitude, not the raw local radius: under a non-uniform
        // instance scale a circle becomes an ellipse in world space, and
        // this package deliberately avoids ellipse math (see distance.dart's
        // file doc). The geometric-mean radius is exact under any uniform
        // scale, rotation, translation or mirror, and an honest
        // approximation otherwise. Where that approximation reaches outside
        // this leaf's own indexed box, the broad phase that fed this
        // candidate has already been widened to compensate -- see
        // [NarrowPhaseSlack], which is derived from this very formula.
        final worldRadius =
            payload.scalars[0] * _scaleMagnitudeOf(ta, tb, tc, td);
        _scratchA.setValues(wx, wy);
        final rim = distanceToCircle(world, _scratchA, worldRadius);
        final dx = world.x - wx, dy = world.y - wy;
        final centreDist = math.sqrt(dx * dx + dy * dy);
        if (rim <= radius) {
          foundKind = HitKind.edge;
          if (centreDist == 0.0) {
            foundX = wx + worldRadius;
            foundY = wy;
          } else {
            foundX = wx + dx / centreDist * worldRadius;
            foundY = wy + dy / centreDist * worldRadius;
          }
        } else if (centreDist < worldRadius) {
          foundKind = HitKind.fill;
          foundX = world.x;
          foundY = world.y;
        }

      case EntityKind.arc:
        final lx = coords[0], ly = coords[1];
        final wx = ta * lx + tc * ly + te, wy = tb * lx + td * ly + tf;
        final localRadius = payload.scalars[0];
        final worldRadius = localRadius * _scaleMagnitudeOf(ta, tb, tc, td);
        final startAngle = payload.scalars[1];
        final sweep = payload.scalars[2];
        // The start point, transformed, gives the world-space start angle
        // directly -- exact under rotation and mirroring alike, without
        // assuming which axis a mirror flips. A negative determinant
        // reverses the sweep's turning sense, the same test
        // [Transform2.anisotropyRatio]'s doc comment uses for "how far from
        // conformal".
        final slx = lx + localRadius * math.cos(startAngle);
        final sly = ly + localRadius * math.sin(startAngle);
        final wslx = ta * slx + tc * sly + te, wsly = tb * slx + td * sly + tf;
        final worldStartAngle = math.atan2(wsly - wy, wslx - wx);
        final worldSweep = ta * td - tb * tc < 0 ? -sweep : sweep;
        _scratchA.setValues(wx, wy);
        final dist = distanceToArc(
            world, _scratchA, worldRadius, worldStartAngle, worldSweep);
        if (dist <= radius) {
          foundKind = HitKind.edge;
          // [_footOnArc], not a bare radial projection: an arc draws only
          // its sweep, so when the nearest point of the drawn curve is an
          // endpoint the radial foot is not on the arc at all. The hit
          // *test* above has always known that -- [distanceToArc] measures
          // to the endpoints outside the sweep -- but the reported point did
          // not, so a pick just past an arc's end answered `true` with a
          // `worldPoint` off the curve. Sharing [_footOnArc] with
          // [_considerSnapLeaf] is what keeps pick and snap agreeing on what
          // "the point on an arc" means.
          final foot = _footOnArc(world, wx, wy, worldRadius, worldStartAngle,
              worldSweep, _scratchB);
          foundX = foot.x;
          foundY = foot.y;
        }

      case EntityKind.fill:
        // Unreachable: this method returns above when `count == 0`, and a
        // fill's payload carries no coordinates. This case exists only so the
        // switch stays exhaustive, so a future EntityKind still fails to
        // compile here instead of falling through silently.
        break;
    }

    if (foundKind == null) return;

    final handle = document.entities.handleAt(slot);
    // A root-level leaf's own handle stands in for its "root-level
    // ancestor": it has no enclosing instance, and draw order among
    // root-level things is exactly their own ascending handle order, so
    // treating it as its own ancestor is what keeps this comparison
    // consistent with a leaf reached through an instance. Defaulting a
    // root-level leaf to handle 0 instead would make it lose every tie
    // against *any* instanced content, regardless of which was actually
    // drawn later.
    final effectiveRoot = depth == 0 ? handle.value : _instancePath[0];

    // Kind first: any vertex hit outranks any edge hit outranks any fill
    // hit, full stop -- see this method's doc comment on priority. Only
    // once kind ties does the tie-break in the class doc apply: greater
    // root-level ancestor handle wins, and only when *that* also ties does
    // the leaf's own handle decide.
    final better = _bestKind == null ||
        foundKind.index < _bestKind!.index ||
        (foundKind == _bestKind &&
            (effectiveRoot > _bestRoot ||
                (effectiveRoot == _bestRoot && handle.value > _bestEntity)));
    if (!better) return;

    _bestKind = foundKind;
    _bestEntity = handle.value;
    _bestRoot = effectiveRoot;

    out.entity = handle;
    out.kind = foundKind;
    out.worldPoint.setValues(foundX, foundY);
    _writeChain(out, depth);
  }

  /// Copies the current descent path into [out.chain], root first.
  ///
  /// When the path is deeper than [out]'s capacity, keeps the **deepest**
  /// entries -- the ones nearest the leaf -- and drops from the root end,
  /// setting [HitPath.truncated]. Truncating from the root is what keeps
  /// [HitPath.entity] correct no matter how deep the chain above it goes.
  void _writeChain(HitPath out, int depth) {
    final capacity = out.chain.length;
    if (depth <= capacity) {
      for (var i = 0; i < depth; i++) {
        out.chain[i] = _instancePath[i];
      }
      out.chainLength = depth;
      out.truncated = false;
    } else {
      final drop = depth - capacity;
      for (var i = 0; i < capacity; i++) {
        out.chain[i] = _instancePath[drop + i];
      }
      out.chainLength = capacity;
      out.truncated = true;
    }
  }

  /// Finds the single best snap candidate within [radius] of [world], among
  /// the kinds in [mask].
  ///
  /// One candidate wins, ordered by `(kind priority, distance)`. **Kind
  /// dominates unconditionally**: the comparison in
  /// [_considerSnapCandidate] checks kind before it ever looks at distance,
  /// so a far endpoint inside the radius beats a near midpoint even though
  /// the midpoint is closer -- declaration order in [SnapKind] is priority,
  /// full stop, not merely a tie-break between otherwise-equal distances.
  /// Distance only decides between two candidates that already tied on
  /// kind, and on a full tie (same kind, bit-exact same distance) the
  /// candidate whose root-level ancestor has the greater handle wins, and
  /// only when *that* also ties does the leaf's own handle decide -- the
  /// same "ascending handle value is draw order, so the later one drawn
  /// wins" convention [_considerLeaf] uses for [pickInto].
  ///
  /// Every [SnapKind] is produced now. `nearest` and `perpendicular` are the
  /// same foot-of-the-projection point on a straight segment (or the same
  /// radial foot on a circle or arc), offered under both kinds so that
  /// [_considerSnapCandidate]'s priority comparison decides which survives
  /// when both are requested. `tangent` uses [world] itself as the external
  /// point for the classical two-tangent-lines construction -- see
  /// [_tangentPoints]'s doc comment for why, since this method has no
  /// separate "point I am drawing from" parameter. `intersection` is
  /// handled separately by [_considerIntersections], root-level entities
  /// only -- see its doc comment for the scope and the ordering guarantee
  /// on [kIntersectionCandidateCap].
  ///
  /// **No-hit contract:** [out] is reset unconditionally at the start of
  /// *every* call, the same way [pickInto] resets [HitPath] -- see
  /// [SnapResult]'s doc comment. Unlike [pickInto], this returns `void`;
  /// callers read [SnapResult.found] rather than a return value.
  ///
  /// **A snap query allocates nothing per candidate** in steady state, once
  /// every scratch buffer it touches has grown to the deepest nesting and
  /// largest candidate set any query has reached -- it runs at pointer-move
  /// rate. **Per *descent level* is a different claim, and a weaker one:**
  /// this shares [_descend], which allocates a closure pair on every
  /// recursive call, so a snap that descends N levels of instance nesting
  /// still allocates on the order of 2N closures however warm the buffers
  /// are. That cost is inherited, not introduced here, and is carried
  /// against the allocation harness that measures it; do not read the
  /// sentence above as a stronger guarantee than [_descend] actually
  /// provides.
  /// **[filter] defaults to [QueryFilter.rendering], not
  /// [QueryFilter.all].** Snapping to geometry on a hidden layer is a bug,
  /// not a feature: the user cannot see the thing the cursor jumped to.
  /// This method previously accepted no filter at all and hard-coded
  /// `QueryFilter.all()`, which made it the one frame-path query that
  /// ignored visibility while its sibling [pickInto] honoured it.
  ///
  /// Not [QueryFilter.picking], which also excludes *locked* geometry: a
  /// locked layer still draws, and snapping to something you can see but
  /// not select is ordinary CAD behaviour — it is how you draw *relative*
  /// to a locked reference. Visibility and selectability are different
  /// questions and this is the one where they part company; pass
  /// [QueryFilter.picking] explicitly if a caller wants both.
  ///
  /// Descends into instances and shares [pickInto]'s descent (see
  /// [_descend]'s doc comment for what "shares" means here and what it does
  /// and does not inherit).
  ///
  /// **Not reentrant.** Shares this index's scratch state with every other
  /// query; see [forEachInRect]'s doc comment.
  void snapInto(Vector2 world, double radius, SnapMask mask, SnapResult out,
      {QueryFilter filter = const QueryFilter.rendering()}) {
    final root = rootIndex; // throws if disposed
    _beginQuery();
    // Guard body inlined, not passed to a closure-taking helper -- see the
    // doc comment on [_beginQuery].
    try {
      out.reset();
      _bestSnapKind = null;
      _bestSnapDist = double.infinity;
      _bestSnapEntity = 0;
      _bestSnapRoot = 0;
      // The leaf and centre searches use the *tight* margin -- the same one
      // a pick uses. An arc's centre no longer needs reaching from the arc's
      // own box; it is indexed where it is. See [NarrowPhaseSlack] for what
      // is left in this channel and why.
      final broad = radius + _broadPhaseMargin().pick;
      // Only the instance search is widened, and only for a mask that can
      // actually produce a centre candidate -- see [_centreDescentMargin].
      final instanceRadius =
          mask.has(SnapKind.center) ? broad + _centreDescentMargin() : broad;
      _descend(root, Transform2.identity(), world, radius, broad,
          instanceRadius, filter, 0, null, mask, out);
      if (mask.has(SnapKind.intersection)) {
        _considerIntersections(world, radius, filter, out);
      }
      out.found = _bestSnapKind != null;
    } finally {
      _endQuery();
    }
  }

  /// Considers every pairwise crossing among the root-level line and
  /// polyline entities within [radius] of [world], among the
  /// [kIntersectionCandidateCap] with the greatest handle values, feeding each
  /// crossing found through [_considerSnapCandidate] exactly as any other
  /// snap candidate.
  ///
  /// **Root-level only, deliberately** -- the same restriction
  /// [forEachInRect]'s doc comment states and for the same reason: this
  /// reuses [forEachInRect]'s exact broad-phase shape (root container,
  /// world-space query rectangle, [_scratch] as the result buffer, sorted
  /// by handle) rather than [_descend]'s instance-aware walk, so a leaf
  /// inside an instance is never a candidate here. Only
  /// [EntityKind.line] and [EntityKind.polyline] segments are tested; a
  /// circle or arc is never an intersection candidate for this task.
  ///
  /// **The [kIntersectionCandidateCap] greatest handles, not the first
  /// [kIntersectionCandidateCap] visited.** [ContainerIndex.searchLeaves]
  /// visits in R-tree packing order, which has no defined relationship to
  /// handle order -- capping in visit order would make a truncated result
  /// depend on how the tree happens to be packed today, and change the next
  /// time it is rebuilt even though nothing the user drew changed. Sorting
  /// first, exactly as [forEachInRect] already does for its own ascending-
  /// handle-order guarantee, is what keeps the cap deterministic; the *tail*
  /// of that ascending sort is what makes it keep the newest work rather
  /// than the oldest. See [kIntersectionCandidateCap]'s own doc comment.
  ///
  /// Quadratic in the candidate count -- up to `kIntersectionCandidateCap *
  /// (kIntersectionCandidateCap - 1) / 2` pairs -- times each pair's own
  /// count of segments *near the query point*, which [_collectNearSegments]
  /// establishes in one linear pass beforehand. The cap bounds entities, not
  /// segments, so without that pass a cap-ful of six-point polylines cost
  /// twenty-five times a cap-ful of two-point lines for the same rectangle.
  void _considerIntersections(
      Vector2 world, double radius, QueryFilter filter, SnapResult out) {
    final root = rootIndex;
    // Four loose doubles, not an `Aabb2`: this method runs once per
    // `snapInto` on the frame path, and [Aabb2] is immutable, so building
    // one here was one guaranteed allocation per call -- flat, not
    // depth-bound. It is the same construction [_descend] documents having
    // removed from its own hot path for the same reason; the lesson was
    // applied there and, until now, not to its sibling here.
    final qMinX = world.x - radius, qMinY = world.y - radius;
    final qMaxX = world.x + radius, qMaxY = world.y + radius;
    _scratch.reset();
    root.searchLeavesRaw(qMinX, qMinY, qMaxX, qMaxY, (slot) {
      final kind = document.entities.kindAt(slot);
      if (kind != EntityKind.line && kind != EntityKind.polyline) return;
      // The same filter the rest of the snap honours -- an intersection
      // between two lines on a hidden layer is no more snappable than
      // either line is on its own.
      if (!_filters.acceptsEntity(slot, filter)) return;
      _scratch.add(slot);
    });
    _scratch.sortByHandle(document.entities);

    final n = _scratch.length < kIntersectionCandidateCap
        ? _scratch.length
        : kIntersectionCandidateCap;
    // The *tail* of an ascending sort: the entities with the
    // [kIntersectionCandidateCap] **greatest** handle values. See this
    // method's doc comment -- keeping the lowest handles would drop exactly
    // the line the user drew most recently, and it contradicted the
    // later-drawn-wins rule the tie-break twenty lines below applies to the
    // very same pair.
    final first = _scratch.length - n;
    final end = _scratch.length;
    _collectNearSegments(world, radius, first, end);

    for (var i = first; i < end; i++) {
      final aFrom = _nearSegmentStart[i - first];
      final aTo = _nearSegmentStart[i - first + 1];
      if (aFrom == aTo) continue;
      final slotA = _scratch[i];
      final payloadA =
          document.geometry.peek(document.entities.geomIndexAt(slotA));
      final coordsA = payloadA.coords;

      for (var j = i + 1; j < end; j++) {
        final bFrom = _nearSegmentStart[j - first];
        final bTo = _nearSegmentStart[j - first + 1];
        if (bFrom == bTo) continue;
        final slotB = _scratch[j];
        final payloadB =
            document.geometry.peek(document.entities.geomIndexAt(slotB));
        final coordsB = payloadB.coords;

        // SnapResult.entity names whichever of the pair was drawn later
        // (the greater handle) -- an intersection point genuinely belongs
        // to both entities equally, so this is a naming convention, not a
        // correctness question, and it is the same "ascending handle is
        // draw order, later one wins" convention [_considerSnapCandidate]
        // already uses to break a tie elsewhere in this class.
        final handleA = document.entities.handleAt(slotA);
        final handleB = document.entities.handleAt(slotB);
        final winningSlot = handleA.value > handleB.value ? slotA : slotB;

        for (var p = aFrom; p < aTo; p++) {
          final sa = _nearSegment[p];
          _isectA1.setValues(coordsA[sa * 2], coordsA[sa * 2 + 1]);
          _isectA2.setValues(coordsA[sa * 2 + 2], coordsA[sa * 2 + 3]);
          for (var q = bFrom; q < bTo; q++) {
            final sb = _nearSegment[q];
            _isectB1.setValues(coordsB[sb * 2], coordsB[sb * 2 + 1]);
            _isectB2.setValues(coordsB[sb * 2 + 2], coordsB[sb * 2 + 3]);
            final hit = segmentIntersection(
                _isectA1, _isectA2, _isectB1, _isectB2, _isectOut);
            if (hit == null) continue;
            final dx = world.x - hit.x, dy = world.y - hit.y;
            if (math.sqrt(dx * dx + dy * dy) > radius) continue;
            _considerSnapCandidate(SnapKind.intersection, hit.x, hit.y, world,
                radius, winningSlot, 0, out);
          }
        }
      }
    }
  }

  /// Segment indices, per intersection candidate, of the segments that come
  /// within the query radius. [_nearSegmentStart] holds one offset per
  /// candidate plus a final end marker, so candidate `k`'s segments are
  /// `_nearSegment[_nearSegmentStart[k] .. _nearSegmentStart[k + 1])`.
  ///
  /// Grow-once scratch, never `clear()`ed, for the same reason as every
  /// other buffer in this class.
  Int32List _nearSegmentStart = Int32List(kIntersectionCandidateCap + 1);
  Int32List _nearSegment = Int32List(64);

  /// Records, for each intersection candidate in `_scratch[from..to)`, which
  /// of its segments come within [radius] of [world].
  ///
  /// **This changes no result, only the work.** An accepted crossing lies on
  /// both segments and within [radius] of [world], so each of those segments
  /// is itself within [radius] of [world]; a segment further away than that
  /// cannot contribute one. Skipping those turns the pairwise loop from
  /// "every segment of A against every segment of B" into "every *near*
  /// segment against every near segment", and the pairs are still visited in
  /// the same ascending order, so even a degenerate tie between two crossings
  /// of the same pair resolves the way it did before.
  ///
  /// It is worth doing because the cap selects *entities*, not segments. A
  /// polyline is admitted because its own bound overlaps the query square,
  /// which says nothing about its individual segments: on a floor plan whose
  /// polyline segments run hundreds of units, one segment of a six-point
  /// polyline may be near the cursor and the other four nowhere near it,
  /// while the quadratic loop tested all of them against all of the other
  /// candidate's.
  void _collectNearSegments(Vector2 world, double radius, int from, int to) {
    final count = to - from;
    if (_nearSegmentStart.length < count + 1) {
      _nearSegmentStart = Int32List(count + 1);
    }
    var written = 0;
    for (var k = 0; k < count; k++) {
      _nearSegmentStart[k] = written;
      final payload = document.geometry
          .peek(document.entities.geomIndexAt(_scratch[from + k]));
      final coords = payload.coords;
      final points = payload.pointCount;
      for (var s = 0; s + 1 < points; s++) {
        _isectA1.setValues(coords[s * 2], coords[s * 2 + 1]);
        _isectA2.setValues(coords[s * 2 + 2], coords[s * 2 + 3]);
        if (distanceToSegment(world, _isectA1, _isectA2) > radius) continue;
        if (written == _nearSegment.length) {
          _nearSegment = Int32List(_nearSegment.length * 2)
            ..setRange(0, written, _nearSegment);
        }
        _nearSegment[written++] = s;
      }
    }
    _nearSegmentStart[count] = written;
  }

  /// Generates every cheap-kind candidate point of one leaf, in world space,
  /// and measures each against the snap in progress.
  ///
  /// Every candidate here is a single point, computed in **local** space and
  /// transformed to world with the raw `a..f` coefficients **before** being
  /// measured -- never the other way round. Transforming a point is nothing
  /// more than the affine map itself, so (unlike [_considerLeaf]'s
  /// circle/arc cases) no radius-scaling trick is needed to stay exact under
  /// a non-uniform or mirrored instance scale: there is no curve here to
  /// distort, only points, and an affine map carries a point to the right
  /// place regardless of scale or mirroring.
  ///
  /// A candidate whose kind bit is unset in [mask] is never generated, not
  /// generated-then-discarded: cheaper, and it means [_considerSnapCandidate]
  /// never has to re-check the mask itself.
  void _considerSnapLeaf(
    int slot,
    double ta,
    double tb,
    double tc,
    double td,
    double te,
    double tf,
    Vector2 world,
    double radius,
    SnapMask mask,
    int depth,
    SnapResult out,
  ) {
    final kind = document.entities.kindAt(slot);
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final coords = payload.coords;
    final count = payload.pointCount;
    if (count == 0) return;

    switch (kind) {
      case EntityKind.point:
        if (!mask.has(SnapKind.endpoint)) return;
        final lx = coords[0], ly = coords[1];
        _considerSnapCandidate(SnapKind.endpoint, ta * lx + tc * ly + te,
            tb * lx + td * ly + tf, world, radius, slot, depth, out);

      case EntityKind.line:
      case EntityKind.polyline:
        if (mask.has(SnapKind.endpoint)) {
          for (var i = 0; i < count; i++) {
            final lx = coords[i * 2], ly = coords[i * 2 + 1];
            _considerSnapCandidate(SnapKind.endpoint, ta * lx + tc * ly + te,
                tb * lx + td * ly + tf, world, radius, slot, depth, out);
          }
        }
        if (mask.has(SnapKind.midpoint)) {
          for (var i = 0; i + 1 < count; i++) {
            final mx = (coords[i * 2] + coords[i * 2 + 2]) / 2;
            final my = (coords[i * 2 + 1] + coords[i * 2 + 3]) / 2;
            _considerSnapCandidate(SnapKind.midpoint, ta * mx + tc * my + te,
                tb * mx + td * my + tf, world, radius, slot, depth, out);
          }
        }
        if (mask.has(SnapKind.nearest) || mask.has(SnapKind.perpendicular)) {
          // Transformed to world space *before* projecting -- the same
          // never-the-other-way-round rule [_considerLeaf]'s doc comment
          // states, and for the same reason: projecting in local space and
          // then transforming the result would not be the closest point
          // under a non-uniform or mirrored instance scale.
          for (var i = 0; i + 1 < count; i++) {
            final wax = ta * coords[i * 2] + tc * coords[i * 2 + 1] + te;
            final way = tb * coords[i * 2] + td * coords[i * 2 + 1] + tf;
            final wbx = ta * coords[i * 2 + 2] + tc * coords[i * 2 + 3] + te;
            final wby = tb * coords[i * 2 + 2] + td * coords[i * 2 + 3] + tf;
            _snapSegA.setValues(wax, way);
            _snapSegB.setValues(wbx, wby);
            final foot = projectOntoSegment(
                world, _snapSegA, _snapSegB, _snapProjection);
            if (foot == null) continue; // degenerate zero-length segment
            // nearest and perpendicular are the same foot on a straight
            // segment -- see [projectOntoSegment]'s doc comment -- so both
            // candidates are offered here and [_considerSnapCandidate]'s
            // kind-first comparison decides which (if either) survives.
            if (mask.has(SnapKind.perpendicular)) {
              _considerSnapCandidate(SnapKind.perpendicular, foot.x, foot.y,
                  world, radius, slot, depth, out);
            }
            if (mask.has(SnapKind.nearest)) {
              _considerSnapCandidate(SnapKind.nearest, foot.x, foot.y, world,
                  radius, slot, depth, out);
            }
          }
        }

      case EntityKind.circle:
        final cx = coords[0], cy = coords[1];
        final r = payload.scalars[0];
        final wcx = ta * cx + tc * cy + te, wcy = tb * cx + td * cy + tf;
        // scaleMagnitude, not the raw local radius -- same reasoning as
        // [_considerLeaf]'s circle case: this package avoids ellipse math,
        // so a non-uniform instance scale is approximated by the
        // geometric-mean radius, exact under any uniform scale, rotation,
        // translation or mirror.
        final worldRadius = r * _scaleMagnitudeOf(ta, tb, tc, td);
        // No `center` candidate here, deliberately: it comes from
        // [_considerSnapCentre], fed by the container's own centre tree. A
        // circle's centre *is* inside its box, so this one could safely have
        // stayed -- it is here for the arc's sake that both go through one
        // path, so "where does a centre candidate come from" has a single
        // answer rather than two that must be kept in step.
        if (mask.has(SnapKind.quadrant)) {
          for (var q = 0; q < 4; q++) {
            final angle = q * (math.pi / 2);
            final lx = cx + r * math.cos(angle);
            final ly = cy + r * math.sin(angle);
            _considerSnapCandidate(SnapKind.quadrant, ta * lx + tc * ly + te,
                tb * lx + td * ly + tf, world, radius, slot, depth, out);
          }
        }
        if (mask.has(SnapKind.nearest) || mask.has(SnapKind.perpendicular)) {
          final rim = _footOnRim(world, wcx, wcy, worldRadius);
          if (rim != null) {
            if (mask.has(SnapKind.perpendicular)) {
              _considerSnapCandidate(SnapKind.perpendicular, rim.x, rim.y,
                  world, radius, slot, depth, out);
            }
            if (mask.has(SnapKind.nearest)) {
              _considerSnapCandidate(SnapKind.nearest, rim.x, rim.y, world,
                  radius, slot, depth, out);
            }
          }
        }
        if (mask.has(SnapKind.tangent) &&
            _tangentPoints(world.x, world.y, wcx, wcy, worldRadius)) {
          _considerSnapCandidate(SnapKind.tangent, _snapTangentA.x,
              _snapTangentA.y, world, radius, slot, depth, out);
          _considerSnapCandidate(SnapKind.tangent, _snapTangentB.x,
              _snapTangentB.y, world, radius, slot, depth, out);
        }

      case EntityKind.arc:
        final cx = coords[0], cy = coords[1];
        final r = payload.scalars[0];
        final startAngle = payload.scalars[1];
        final sweep = payload.scalars[2];
        if (mask.has(SnapKind.endpoint)) {
          final slx = cx + r * math.cos(startAngle);
          final sly = cy + r * math.sin(startAngle);
          _considerSnapCandidate(SnapKind.endpoint, ta * slx + tc * sly + te,
              tb * slx + td * sly + tf, world, radius, slot, depth, out);
          final endAngle = startAngle + sweep;
          final elx = cx + r * math.cos(endAngle);
          final ely = cy + r * math.sin(endAngle);
          _considerSnapCandidate(SnapKind.endpoint, ta * elx + tc * ely + te,
              tb * elx + td * ely + tf, world, radius, slot, depth, out);
        }
        if (mask.has(SnapKind.midpoint)) {
          final midAngle = startAngle + sweep / 2;
          final lx = cx + r * math.cos(midAngle);
          final ly = cy + r * math.sin(midAngle);
          _considerSnapCandidate(SnapKind.midpoint, ta * lx + tc * ly + te,
              tb * lx + td * ly + tf, world, radius, slot, depth, out);
        }
        // No `center` candidate here -- see the circle case above. For an
        // arc it is not merely tidiness: the arc's box need not contain its
        // centre at all, so reaching it from this walk is what used to force
        // every centre-including snap query to be widened by an arc radius.
        if (mask.has(SnapKind.quadrant)) {
          // "Quadrants inside the sweep only": a quadrant point that the
          // arc's own curve never passes through is not a snap candidate --
          // unlike the circle case above, an arc does not draw its full
          // rim. [angleInSweep] is evaluated on the *local* start angle and
          // sweep, since sweep containment is a fact about the arc's own
          // data and does not depend on how it is later transformed.
          for (var q = 0; q < 4; q++) {
            final angle = q * (math.pi / 2);
            if (!angleInSweep(angle, startAngle, sweep)) continue;
            final lx = cx + r * math.cos(angle);
            final ly = cy + r * math.sin(angle);
            _considerSnapCandidate(SnapKind.quadrant, ta * lx + tc * ly + te,
                tb * lx + td * ly + tf, world, radius, slot, depth, out);
          }
        }
        if (mask.has(SnapKind.nearest) ||
            mask.has(SnapKind.perpendicular) ||
            mask.has(SnapKind.tangent)) {
          final wcx = ta * cx + tc * cy + te, wcy = tb * cx + td * cy + tf;
          final worldRadius = r * _scaleMagnitudeOf(ta, tb, tc, td);
          // World start angle and sweep, exactly [_considerLeaf]'s arc
          // derivation: the start point transformed gives the world-space
          // start angle directly -- exact under rotation and mirroring,
          // without assuming which axis a mirror flips -- and a negative
          // determinant reverses the sweep's turning sense.
          final slx = cx + r * math.cos(startAngle);
          final sly = cy + r * math.sin(startAngle);
          final wslx = ta * slx + tc * sly + te,
              wsly = tb * slx + td * sly + tf;
          final worldStartAngle = math.atan2(wsly - wcy, wslx - wcx);
          final worldSweep = ta * td - tb * tc < 0 ? -sweep : sweep;

          if (mask.has(SnapKind.nearest) || mask.has(SnapKind.perpendicular)) {
            final foot = _footOnArc(world, wcx, wcy, worldRadius,
                worldStartAngle, worldSweep, _snapProjection);
            if (mask.has(SnapKind.perpendicular)) {
              _considerSnapCandidate(SnapKind.perpendicular, foot.x, foot.y,
                  world, radius, slot, depth, out);
            }
            if (mask.has(SnapKind.nearest)) {
              _considerSnapCandidate(SnapKind.nearest, foot.x, foot.y, world,
                  radius, slot, depth, out);
            }
          }
          if (mask.has(SnapKind.tangent) &&
              _tangentPoints(world.x, world.y, wcx, wcy, worldRadius)) {
            // Unlike the circle case, a tangent candidate on an arc must
            // also fall inside the sweep -- the same "does the drawn curve
            // actually pass through here" rule [quadrant] enforces above,
            // checked against the *world* angle since [_snapTangentA]/
            // [_snapTangentB] are already world-space points here.
            if (angleInSweep(
                math.atan2(_snapTangentA.y - wcy, _snapTangentA.x - wcx),
                worldStartAngle,
                worldSweep)) {
              _considerSnapCandidate(SnapKind.tangent, _snapTangentA.x,
                  _snapTangentA.y, world, radius, slot, depth, out);
            }
            if (angleInSweep(
                math.atan2(_snapTangentB.y - wcy, _snapTangentB.x - wcx),
                worldStartAngle,
                worldSweep)) {
              _considerSnapCandidate(SnapKind.tangent, _snapTangentB.x,
                  _snapTangentB.y, world, radius, slot, depth, out);
            }
          }
        }

      case EntityKind.text:
      case EntityKind.attrib:
        if (!mask.has(SnapKind.insertion)) return;
        final lx = coords[0], ly = coords[1];
        _considerSnapCandidate(SnapKind.insertion, ta * lx + tc * ly + te,
            tb * lx + td * ly + tf, world, radius, slot, depth, out);

      case EntityKind.fill:
        // Unreachable: this method returns above when `count == 0`, and a
        // fill's payload carries no coordinates. This case exists only so the
        // switch stays exhaustive, so a future EntityKind still fails to
        // compile here instead of falling through silently.
        break;
    }
  }

  /// Offers one arc's or circle's centre as a [SnapKind.center] candidate.
  ///
  /// The counterpart of [_considerSnapLeaf] for the one snap kind that comes
  /// from [ContainerIndex.searchSnapCentres] instead of from the leaf tree.
  /// The world transform arrives as its six raw coefficients for the same
  /// zero-allocation reason [_considerLeaf]'s doc comment gives, and the
  /// centre is transformed to world space before being measured -- an affine
  /// map carries a point to the right place under any scale or mirroring, so
  /// unlike a radius there is nothing here to approximate.
  ///
  /// The kind check is not redundant with what the tree holds: a slot whose
  /// entity has since changed kind keeps its tree entry until the next
  /// rebuild (marked dead, so ordinarily unreachable), and this is one line
  /// against a candidate computed from the wrong two scalars.
  void _considerSnapCentre(
    int slot,
    double ta,
    double tb,
    double tc,
    double td,
    double te,
    double tf,
    Vector2 world,
    double radius,
    int depth,
    SnapResult out,
  ) {
    final kind = document.entities.kindAt(slot);
    if (kind != EntityKind.circle && kind != EntityKind.arc) return;
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    if (payload.pointCount == 0) return;
    final cx = payload.coords[0], cy = payload.coords[1];
    _considerSnapCandidate(SnapKind.center, ta * cx + tc * cy + te,
        tb * cx + td * cy + tf, world, radius, slot, depth, out);
  }

  /// The point on a circle's rim nearest [world], via [_snapProjection] --
  /// the radial projection of [world] through the world-space centre
  /// ([cx],[cy]), at [worldRadius]. Never null in practice for a circle
  /// with a positive radius, but returns null rather than dividing by zero
  /// when [world] sits exactly on the centre, where "the nearest point on
  /// the rim" has no single answer -- every point on the rim is equally
  /// near.
  Vector2? _footOnRim(Vector2 world, double cx, double cy, double worldRadius) {
    final dx = world.x - cx, dy = world.y - cy;
    final centreDist = math.sqrt(dx * dx + dy * dy);
    if (centreDist == 0.0) return null;
    _snapProjection
      ..x = cx + dx / centreDist * worldRadius
      ..y = cy + dy / centreDist * worldRadius;
    return _snapProjection;
  }

  /// [_footOnRim]'s sibling for an arc: the radial foot when [world]'s
  /// direction from the centre falls inside the sweep, otherwise the
  /// *nearer* of the two arc endpoints -- an arc does not draw its full
  /// rim, so a foot outside the sweep is not a point the drawn curve
  /// contains, exactly the distinction [distanceToArc] draws for `pickInto`
  /// and [angleInSweep]'s quadrant check draws above. All angles here are
  /// world-space, matching [worldStartAngle]/[worldSweep] as computed by
  /// the caller.
  ///
  /// The answer is written into [into] and returned, never allocated: the
  /// two callers own different scratch points -- [_considerSnapLeaf] passes
  /// [_snapProjection], [_considerLeaf] passes [_scratchB] -- because
  /// nothing should have to reason about whether the pick path and the snap
  /// path may share one buffer. Returning a fresh `Vector2` instead would be
  /// one allocation per candidate arc, which both paths' zero-allocation
  /// guarantee forbids.
  ///
  /// **Both [pickInto] and [snapInto] go through here**, so "the point on an
  /// arc" means the same thing to each. It did not always: `_considerLeaf`
  /// used to project radially with no sweep check at all, so a pick near an
  /// arc's endpoint reported a `worldPoint` off the drawn curve while
  /// `snapInto`, on the very same arc, reported the endpoint.
  Vector2 _footOnArc(Vector2 world, double cx, double cy, double worldRadius,
      double worldStartAngle, double worldSweep, Vector2 into) {
    final dx = world.x - cx, dy = world.y - cy;
    final centreDist = math.sqrt(dx * dx + dy * dy);
    if (centreDist != 0.0 &&
        angleInSweep(math.atan2(dy, dx), worldStartAngle, worldSweep)) {
      into
        ..x = cx + dx / centreDist * worldRadius
        ..y = cy + dy / centreDist * worldRadius;
      return into;
    }

    final endAngle = worldStartAngle + worldSweep;
    final eax = cx + worldRadius * math.cos(worldStartAngle);
    final eay = cy + worldRadius * math.sin(worldStartAngle);
    final ebx = cx + worldRadius * math.cos(endAngle);
    final eby = cy + worldRadius * math.sin(endAngle);
    final da =
        (world.x - eax) * (world.x - eax) + (world.y - eay) * (world.y - eay);
    final db =
        (world.x - ebx) * (world.x - ebx) + (world.y - eby) * (world.y - eby);
    if (da <= db) {
      into
        ..x = eax
        ..y = eay;
    } else {
      into
        ..x = ebx
        ..y = eby;
    }
    return into;
  }

  /// Writes the two points where a line from [px],[py] would be tangent to
  /// a circle centred at [cx],[cy] with radius [r], into [_snapTangentA]
  /// and [_snapTangentB]. Returns false, leaving both scratch points
  /// untouched, when there is no real tangent to find.
  ///
  /// This is the classical two-tangent-lines-from-an-external-point
  /// construction, using [world] itself as that external point: `snapInto`
  /// has no separate "line I am drawing from" parameter (see [SnapKind]'s
  /// own doc comment on why `tangent` is one of the kinds that would
  /// normally want a second entity or reference point this call does not
  /// have), so the query point plays that role directly. The distance from
  /// [world] to either result is the tangent length
  /// `sqrt(d^2 - r^2)`, not zero, so this kind only actually reports a hit
  /// once the query point is already close to the circle -- it converges to
  /// [_footOnRim]'s answer as [world] approaches the rim, which is the
  /// honest behaviour for a from-point this method does not otherwise have.
  ///
  /// `a` (distance from the centre to the foot of the chord, along the
  /// centre-to-[world] direction) and `h` (the chord's half-length) are
  /// each `r`-dependent in a way that does not cancel out -- `a = r*r/d`,
  /// `h = r*sqrt(d*d - r*r)/d` -- so a circle's radius genuinely changes
  /// where the tangent points land, not merely how far out they sit.
  ///
  /// **Inside-vs-on-the-rim is a `Tolerance` decision.** A discriminant
  /// (`d*d - r*r`) that is genuinely negative means [world] is inside the
  /// circle, where no real tangent line exists, and this returns false. A
  /// discriminant that is negative only by a sliver no larger than
  /// [Tolerance.standard.linear] squared is treated as exactly zero instead
  /// of rejected outright: that is the "query point is numerically right on
  /// the rim" case, and rejecting it outright would make the tangent kind
  /// flicker in and out as floating-point noise pushes the same on-rim
  /// point a hair to either side of the boundary.
  bool _tangentPoints(double px, double py, double cx, double cy, double r) {
    final dx = px - cx, dy = py - cy;
    final d2 = dx * dx + dy * dy;
    final linearTol = Tolerance.standard.linear;
    final discriminant = d2 - r * r;
    if (discriminant < -(linearTol * linearTol)) return false;
    final clampedDiscriminant = discriminant < 0.0 ? 0.0 : discriminant;
    final d = math.sqrt(d2);
    if (d == 0.0) return false; // world sits on the centre: no direction
    final ux = dx / d, uy = dy / d;
    final a = r * r / d;
    final h = r * math.sqrt(clampedDiscriminant) / d;
    final fx = cx + a * ux, fy = cy + a * uy;
    final perpX = -uy, perpY = ux;
    _snapTangentA.setValues(fx + h * perpX, fy + h * perpY);
    _snapTangentB.setValues(fx - h * perpX, fy - h * perpY);
    return true;
  }

  /// Measures one world-space candidate point and, if it both lies within
  /// [radius] and beats the snap in progress, updates the running best and
  /// writes it into [out].
  ///
  /// The comparison is `(kind.index, distance)` lexicographic, with a
  /// deterministic tie-break -- see [snapInto]'s doc comment for the full
  /// ordering this implements and why. The kind term is compared on its own
  /// first (`kindIndex < _bestSnapKind!.index`), independent of distance, so
  /// nothing about the distance terms further down can ever let a
  /// lower-priority kind beat a higher-priority one.
  void _considerSnapCandidate(
    SnapKind kind,
    double wx,
    double wy,
    Vector2 world,
    double radius,
    int slot,
    int depth,
    SnapResult out,
  ) {
    final dx = world.x - wx, dy = world.y - wy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist > radius) return;

    final handle = document.entities.handleAt(slot);
    // Same reasoning as [_considerLeaf]'s effectiveRoot: a root-level leaf
    // stands in for its own root-level ancestor.
    final effectiveRoot = depth == 0 ? handle.value : _instancePath[0];

    final kindIndex = kind.index;
    final better = _bestSnapKind == null ||
        kindIndex < _bestSnapKind!.index ||
        (kindIndex == _bestSnapKind!.index &&
            (dist < _bestSnapDist ||
                (dist == _bestSnapDist &&
                    (effectiveRoot > _bestSnapRoot ||
                        (effectiveRoot == _bestSnapRoot &&
                            handle.value > _bestSnapEntity)))));
    if (!better) return;

    _bestSnapKind = kind;
    _bestSnapDist = dist;
    _bestSnapEntity = handle.value;
    _bestSnapRoot = effectiveRoot;

    out.entity = handle;
    out.kind = kind;
    out.point.setValues(wx, wy);
    _writeSnapChain(out, depth);
  }

  /// Copies the current descent path into [out.chain], root first -- the
  /// [SnapResult] sibling of [_writeChain].
  ///
  /// When the path is deeper than [out]'s capacity, keeps the **deepest**
  /// entries -- the ones nearest the leaf -- and drops from the root end,
  /// exactly as [_writeChain] does, for the same reason: that is what keeps
  /// [SnapResult.entity] and the innermost instances correct no matter how
  /// deep the chain above them goes. Dropping from the *leaf* end instead
  /// would report an outer instance where the caller expects the one the
  /// hit is actually inside, and would do so silently.
  ///
  /// [SnapResult.truncated] is set when that happens, the same way
  /// [_writeChain] sets [HitPath.truncated]. It used to have no flag at
  /// all, which made "the chain is short because the path is short" and
  /// "the chain is short because it was cut" the same observation.
  void _writeSnapChain(SnapResult out, int depth) {
    final capacity = out.chain.length;
    if (depth <= capacity) {
      for (var i = 0; i < depth; i++) {
        out.chain[i] = _instancePath[i];
      }
      out.chainLength = depth;
      out.truncated = false;
    } else {
      final drop = depth - capacity;
      for (var i = 0; i < capacity; i++) {
        out.chain[i] = _instancePath[drop + i];
      }
      out.chainLength = capacity;
      out.truncated = true;
    }
  }

  /// The cached whole-document broad-phase margin, or null when it must be
  /// recomputed. See [_broadPhaseMargin].
  NarrowPhaseSlack? _margin;

  /// How much wider than its own radius a pick or a snap must search, so
  /// that its broad phase is never tighter than the region its narrow phase
  /// would accept.
  ///
  /// **Why one number for the whole document, applied to the world square,
  /// rather than a per-container one applied per level:** an instance's box
  /// always contains the box of every leaf underneath it, mapped up into the
  /// same space. So a query region that reaches a leaf's own box necessarily
  /// also reaches the instance box of every container between it and the
  /// root — the deepest test is the binding one, and widening the world
  /// square once, before [_descend] inverts it per level, covers all of them.
  /// A per-level margin would have to re-derive the same thing at every
  /// level and get the compounding right; this cannot get it wrong.
  ///
  /// Zero for the documents that overwhelmingly matter: it is non-zero only
  /// when a circle or an arc sits under a non-conformal transform, or (for
  /// the `center` channel) when the document contains an arc at all. See
  /// [NarrowPhaseSlack] for what each channel bounds and why.
  ///
  /// Cached because it walks every container and every instance node, and
  /// recomputing it per pointer move would put that walk on the frame path.
  /// It allocates on a cold call (the memo and cycle-guard sets); queries
  /// are allocation-free in steady state, which is after the first query
  /// following a rebuild — the same "grows once, then free" shape as every
  /// scratch buffer in this class.
  NarrowPhaseSlack _broadPhaseMargin() => _margin ??= _reachableSlack(
      document.rootHandle, <Handle, NarrowPhaseSlack>{}, <Handle>{});

  /// [container]'s own slack, unioned with every definition reachable
  /// through its instances, lifted through each instance transform on the
  /// way up.
  ///
  /// `open` is a cycle guard, not an optimisation: a definition cycle is
  /// refused on write by `AddNodeCommand`, and this only has to stop a
  /// malformed graph from recursing forever rather than produce a meaningful
  /// answer for one — the same trade [ContainerIndex.build]'s own `seen` set
  /// makes.
  NarrowPhaseSlack _reachableSlack(
    Handle container,
    Map<Handle, NarrowPhaseSlack> memo,
    Set<Handle> open,
  ) {
    final done = memo[container];
    if (done != null) return done;
    final index = _byContainer[container];
    if (index == null) return NarrowPhaseSlack.none;
    if (!open.add(container)) return NarrowPhaseSlack.none;

    var slack = index.ownNarrowPhaseSlack;
    for (var i = 0; i < index.instanceCount; i++) {
      final node = document.tree[index.instanceHandleAt(i)];
      if (node is! InstanceNode) continue;
      final below = _reachableSlack(node.definition, memo, open);
      if (below.crude == 0.0) continue; // nothing round down there
      slack = slack.union(below.through(index.instanceTransformAt(i)));
    }

    open.remove(container);
    memo[container] = slack;
    return slack;
  }

  /// The cached instance-search widening, or null when it must be
  /// recomputed. See [_centreDescentMargin].
  double? _centreMargin;

  /// How much wider than its own radius a `center`-including snap must
  /// search **for instances**, so that it descends into every instance whose
  /// contents hold a snap centre the query could reach.
  ///
  /// **Why anything is still widened at all.** A container's own arc and
  /// circle centres are indexed exactly, by
  /// [ContainerIndex.searchSnapCentres], so no leaf is missed by a tight
  /// query. What a tight query *can* miss is the step into an instance: a
  /// parent indexes a definition by that definition's own bound, and an
  /// arc's centre can lie outside it — a definition holding nothing but one
  /// narrow-sweep arc has a bound a full radius away from the centre that
  /// arc offers. Growing the instance box to swallow it is not available:
  /// that box is what [forEachInstanceInRect] reports against, and its
  /// meaning is the document's, not this index's.
  ///
  /// **How much smaller this is than what it replaced.** The margin removed
  /// from [NarrowPhaseSlack] was a union over every arc in the document, so
  /// one big arc anywhere widened every centre-including query. This is a
  /// union over how far a centre escapes *its own definition's bound*, lifted
  /// through the instance transforms above it — zero for a definition whose
  /// arcs sit among its other geometry, which is the ordinary case, and zero
  /// for a document with no instances at all however many arcs it has.
  ///
  /// One number for the whole document applied to the world square, for
  /// exactly the reason [_broadPhaseMargin]'s doc comment gives: the
  /// recursion below already lifts every deeper definition's reach up
  /// through the transforms above it, so the root's value bounds what any
  /// level needs.
  double _centreDescentMargin() {
    final cached = _centreMargin;
    if (cached != null) return cached;
    final memo = <Handle, double>{};
    final open = <Handle>{};
    final root = _byContainer[document.rootHandle];
    var margin = 0.0;
    if (root != null) {
      // The root's *own* reach is deliberately excluded: root-level centres
      // are in the root's own centre tree, reached by the tight query. Only
      // what is below an instance needs compensating for.
      for (var i = 0; i < root.instanceCount; i++) {
        final node = document.tree[root.instanceHandleAt(i)];
        if (node is! InstanceNode) continue;
        final below = _centreReach(node.definition, memo, open);
        if (below == 0.0) continue;
        final lifted = _sigmaMaxOf(root.instanceTransformAt(i)) * below;
        if (lifted > margin) margin = lifted;
      }
    }
    return _centreMargin = margin;
  }

  /// The largest distance, in [container]'s own space, by which a snap centre
  /// reachable from it lies outside [ContainerIndex.bounds] — its own leaves'
  /// centres, and every definition below it lifted through the instance
  /// transform on the way up.
  ///
  /// `open` is a cycle guard, not an optimisation, exactly as in
  /// [_reachableSlack].
  double _centreReach(
      Handle container, Map<Handle, double> memo, Set<Handle> open) {
    final done = memo[container];
    if (done != null) return done;
    final index = _byContainer[container];
    if (index == null) return 0.0;
    if (!open.add(container)) return 0.0;

    var reach = index.ownSnapCentreReach;
    for (var i = 0; i < index.instanceCount; i++) {
      final node = document.tree[index.instanceHandleAt(i)];
      if (node is! InstanceNode) continue;
      final below = _centreReach(node.definition, memo, open);
      if (below == 0.0) continue;
      // An instance's box is contained in this container's own bound, so a
      // centre `below` outside the definition's bound is at most
      // `sigmaMax * below` outside *this* container's bound too.
      final lifted = _sigmaMaxOf(index.instanceTransformAt(i)) * below;
      if (lifted > reach) reach = lifted;
    }

    open.remove(container);
    memo[container] = reach;
    return reach;
  }

  /// The larger singular value of [edge] — the most a distance can grow
  /// across it. Zero for a singular or non-finite edge, which [_descend]
  /// cannot invert and therefore never descends through, so there is nothing
  /// below it to keep reachable. The same derivation
  /// [NarrowPhaseSlack.through] uses.
  static double _sigmaMaxOf(Transform2 edge) {
    final k = edge.anisotropyRatio;
    if (!k.isFinite) return 0.0;
    final sigmaMax = edge.scaleMagnitude * math.sqrt(k);
    return sigmaMax.isFinite ? sigmaMax : 0.0;
  }

  int _rebuildCount = 0;
  int _dirtyCount = 0;

  /// How many full container rebuilds have happened. Test-visible because the
  /// load-bearing guarantee is that certain edits cause *none*.
  int get rebuildCount => _rebuildCount;

  /// How many entries have been written to a dirty list. Same reasoning.
  int get dirtyCount => _dirtyCount;

  /// The slot each live entity occupied as of the last time this index saw
  /// it — either a rebuild or a reconciled edit.
  ///
  /// Removal notifies with only the handle: by the time [_reconcileEntity]
  /// runs, [DraftDocument.entities] has already forgotten the slot, so
  /// without this map there would be nothing to mark dead. Populated for
  /// every live entity in [rebuildAll] and kept current for every entity
  /// [_reconcileEntity] sees; a purge or load invalidates it exactly when it
  /// invalidates everything else slot-keyed, which is why [rebuildAll]
  /// rebuilds it from scratch rather than patching it.
  final Map<Handle, int> _lastKnownSlot = <Handle, int>{};

  /// Discards every index and rebuilds from scratch.
  ///
  /// One [ContainerIndex.leavesByOwner] pass is shared across every container,
  /// which is what keeps a whole-document build linear in entities rather than
  /// O(containers x entities).
  void rebuildAll() {
    _rebuildCount++;
    _margin = null;
    _centreMargin = null;
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer
      ..clear()
      ..[document.rootHandle] =
          ContainerIndex.build(document, document.rootHandle, byOwner);
    for (final definition in document.tree.definitions) {
      _byContainer[definition.handle] =
          ContainerIndex.build(document, definition.handle, byOwner);
    }
    // Rebuilt from scratch, not patched: a rebuild also follows a purge or a
    // load, either of which may have renumbered or entirely replaced every
    // slot, so a stale entry here would mark the wrong slot dead on the next
    // removal.
    _lastKnownSlot.clear();
    for (final slot in document.entities.liveSlots) {
      _lastKnownSlot[document.entities.handleAt(slot)] = slot;
    }
    // A rebuild also follows a layer edit or a load, either of which may
    // change what a cached visibility answer means for a handle that is
    // reused. No shipped command can flip a layer's or node's visibility
    // today — see [FilterEvaluator]'s own doc comment — so this has no
    // observable effect yet; it is the conservative default for when one
    // does.
    _filters.invalidate();
    _rebuildPlacements();
    // Every container here was just derived from the document, so this is a
    // no-op unless `DraftDocument.definitionBounds` and the union
    // `ContainerIndex.build` accumulates ever disagree. Running it anyway
    // turns "those two agree" from an assumption the escape check silently
    // rests on into something this class enforces.
    for (final container in _byContainer.keys) {
      _restoreInstanceBoxesOf(container);
    }
  }

  /// Re-derives [_placedBy] from the containers currently indexed.
  ///
  /// Wholesale, not patched, and called from both [rebuildAll] and
  /// [rebuildContainer]: the entries hold [ContainerIndex] *objects*, and a
  /// rebuild replaces one outright, so a patched map would keep handing out
  /// the discarded instance. It costs one pass over the instance nodes of
  /// every container — instances, not entities, so it is a small fraction of
  /// the build it follows in [rebuildAll], and in [rebuildContainer] it is
  /// bounded by how many placements the whole document has rather than by
  /// how big the rebuilt container is.
  void _rebuildPlacements() {
    _placedBy.clear();
    for (final index in _byContainer.values) {
      for (var i = 0; i < index.instanceCount; i++) {
        final node = index.instanceHandleAt(i);
        final tree = document.tree[node];
        if (tree is! InstanceNode) continue;
        (_placedBy[tree.definition] ??= <_Placement>[])
            .add(_Placement(index, node, index.instanceTransformAt(i)));
      }
    }
  }

  /// Restores, for one container, the rule every escape check depends on:
  /// **an instance box always covers the placed definition's stored bound.**
  ///
  /// Called after that container is rebuilt. The rebuild derives each
  /// instance box from `DraftDocument.definitionBounds`, which is the
  /// definition's *true* bound — but the definition's own [ContainerIndex]
  /// may still be carrying a widened one, and [_reconcileEntity] decides
  /// whether to propagate growth by asking whether a leaf escaped that
  /// widened bound. A freshly tightened instance box under a still-widened
  /// definition bound is exactly the state in which a leaf can escape the
  /// truth, stay inside the stored bound, propagate nothing, and vanish
  /// again.
  void _restoreInstanceBoxesOf(Handle container) {
    final index = _byContainer[container];
    if (index == null) return;
    for (var i = 0; i < index.instanceCount; i++) {
      final node = index.instanceHandleAt(i);
      final tree = document.tree[node];
      if (tree is! InstanceNode) continue;
      final placed = _byContainer[tree.definition];
      if (placed == null) continue;
      index.growInstanceBox(
          node, placed.bounds.transformedBy(index.instanceTransformAt(i)));
    }
  }

  /// Narrows every instance box that places [container] back onto its
  /// freshly rebuilt bound.
  ///
  /// The other half of a rebuild, and the one that gives widening a way back.
  /// [_growPlacements] is monotone, so without this a definition dragged
  /// outwards and back leaves all of its placements permanently enlarged, and
  /// a query over the empty space it briefly covered descends into every one
  /// of them. Measured at 3000 placements, one out-and-back drag took
  /// `pickInto` over empty space from 0.4 us to 3.75 ms — a quarter of a
  /// frame, for geometry that is not there.
  ///
  /// Uses [ContainerIndex.setInstanceBox], which narrows, rather than
  /// [ContainerIndex.growInstanceBox]: this runs immediately after
  /// [container]'s own bound was re-derived from the document, so the stored
  /// box is known to be exact and the difference is known to be pure slack.
  /// Together with [_restoreInstanceBoxesOf] it makes a rebuild leave the
  /// same state whichever order containers are rebuilt in, which matters
  /// because [_reconcile]'s sweep rebuilds a definition and the container
  /// placing it in map order, not dependency order.
  void _retightenPlacementsOf(Handle container) {
    final index = _byContainer[container];
    if (index == null) return;
    final places = _placedBy[container];
    if (places == null) return;
    for (final place in places) {
      place.container.setInstanceBox(
          place.node, index.bounds.transformedBy(place.transform));
    }
  }

  /// Re-derives the indexed box of every instance of [definition] from
  /// [definitionBounds] — the definition's own, freshly grown bound — and
  /// repeats upwards for any container whose own bound that widening grew.
  ///
  /// This is what makes "add an entity to a block definition" visible. The
  /// entity itself lands on the definition's own dirty overlay, correctly —
  /// but a query only ever reaches that overlay by first stepping through an
  /// instance box in the container above, and that box was derived from the
  /// definition's bound at the placing container's build time. One entry on
  /// a dirty list is far below the rebuild floor of 64, so nothing rebuilt,
  /// and `forEachInstanceInRect`, `pickInto` and `snapInto` all reported
  /// nothing over geometry `DraftDocument.extents` could see perfectly well.
  ///
  /// **The whole bound, not the one leaf that escaped it.** An instance box
  /// means "this definition's bound, transformed" — that is what
  /// `ContainerIndex.build` stores, what [forEachInstanceInRect] reports
  /// against, and what the centre-descent margin measures a stray snap centre
  /// against. Growing it by the escaping leaf's own box instead would leave
  /// it merely *large enough*, and no longer that box, since the axis-aligned
  /// bound of a rotated union is not the union of the rotated bounds.
  ///
  /// **What it costs.** One iteration per placement of [definition], and only
  /// on an edit that actually escapes the definition's current bound —
  /// [ContainerIndex.noteLeaf] reports that in O(1), and the overwhelmingly
  /// common edit, which stays inside, never gets here at all. Each iteration
  /// is one box transform and an O(tree depth) walk up the instance tree (see
  /// [PackedRTree.growBox]), and stops early when the stored box already
  /// covers the new one. A definition placed 300 times therefore costs 300
  /// cheap iterations on the frames of a drag that is pushing the definition
  /// outwards, and nothing on any other frame.
  ///
  /// **[budget], not a step cap.** A definition can appear at most once on
  /// any acyclic chain of containers, so the number of indexed containers
  /// bounds the legitimate depth exactly; this can only fire on a cyclic
  /// definition graph, which is refused on write and which this merely has to
  /// terminate on rather than answer well. It is a counter instead of a
  /// `Set<Handle>` because the alternative would allocate on an edit path
  /// that a drag walks every frame.
  void _growPlacements(Handle definition, Aabb2 definitionBounds, int budget) {
    if (budget <= 0 || definitionBounds.isEmpty) return;
    final places = _placedBy[definition];
    if (places == null) return;
    for (final place in places) {
      // The same `transformedBy` that derived the box in the first place, in
      // `ContainerIndex.build`'s INSERT case — a second way of mapping a box
      // through a transform would be a second chance to disagree with it.
      final lifted = definitionBounds.transformedBy(place.transform);
      if (place.container.growInstanceBox(place.node, lifted)) {
        // Growing an instance box grows its container's own bound too, so a
        // definition nested inside another definition carries on upwards.
        // Gated on the growth actually happening, which is what makes the
        // ordinary case one level deep rather than a walk to the root.
        _growPlacements(
            place.container.container, place.container.bounds, budget - 1);
      }
    }
  }

  /// Rebuilds one container, leaving the rest alone.
  ///
  /// [container] must already be an indexed container — the root or a live
  /// definition — never an arbitrary handle: this class indexes exactly the
  /// set [rebuildAll] builds, and letting an unrelated handle in here would
  /// silently grow that set with a phantom entry [rebuildAll] never produces
  /// and [indexFor] can never explain.
  void rebuildContainer(Handle container) {
    if (container != document.rootHandle &&
        document.tree.definition(container) == null) {
      throw ArgumentError.value(
        container,
        'container',
        'not an indexed container (must be the document root or a live '
            'definition)',
      );
    }
    _rebuildCount++;
    _margin = null;
    _centreMargin = null;
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer[container] =
        ContainerIndex.build(document, container, byOwner);
    // The rebuilt container is a different object, and [_placedBy] holds
    // objects: without this, every placement recorded for a definition this
    // container places would still point at the discarded one, and growing
    // an instance box would grow a tree nothing queries.
    _rebuildPlacements();
    // The two halves of "an instance box covers the definition's stored
    // bound", restored in both directions so that this is correct whether it
    // was called on a definition, on the container placing one, or — as
    // [_reconcile]'s sweep may do — on both in either order.
    _restoreInstanceBoxesOf(container);
    _retightenPlacementsOf(container);
  }

  /// **Re-derive and compare**, not a typed change kind.
  ///
  /// [DocChange] carries `(label, Set<Handle> touched)` with no change kind —
  /// [SetComponentCommand] touches the entity handle exactly as a geometry
  /// edit would. So this cannot be *told* what changed; it re-derives each
  /// touched handle's box from the document and compares it against what is
  /// indexed. An appearance edit finds the box unchanged and dirties nothing,
  /// which is what preserves the appearance-edits-do-not-touch-the-index
  /// guarantee by measurement rather than by a kind the stream cannot carry.
  void _onChange(DocChange change) {
    switch (change) {
      case DocumentLoaded():
      case DocumentPurged():
        // Slots were renumbered or the document replaced. Every slot-keyed
        // structure — the trees, the dirty lists, the dead bitmasks, and
        // [_lastKnownSlot] — is invalid, and there is no incremental path
        // back.
        rebuildAll();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        _reconcile(touched);
    }
  }

  /// Re-derives the box of every touched handle and dirties what moved.
  void _reconcile(Set<Handle> touched) {
    // Any edit at all can change either margin — a circle's radius, a
    // group's transform, a new arc, an arc inside a definition dragged clear
    // of everything else in it. Dropping both cached values here rather than
    // trying to work out whether this particular edit moved either keeps the
    // one rule "recompute after any change", and each recompute is a walk
    // over containers and instance nodes, not over entities.
    _margin = null;
    _centreMargin = null;
    if (touched.isEmpty) {
      // Defensive, not currently reachable: every `DraftCommand.apply` in
      // this package returns a non-empty `touched` (see `commands.dart`),
      // so `CommandDispatcher` never emits an empty set here today. Kept in
      // case a future command legitimately has nothing to name — falling
      // back to a full rebuild is the same conservative answer this class
      // already gives to every other "cannot pin down what changed" case.
      rebuildAll();
      return;
    }

    // A touched handle may be an entity, a node, or a definition. Ascending
    // order keeps the work deterministic, which matters because a rebuild
    // decision depends on how many entries land in a dirty list.
    final ordered = touched.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Not currently distinguishable from a simpler "let `_reconcileEntity`
    // find out" by any test: every shipped `DraftCommand.apply` returns a
    // singleton `touched`, so for the one handle in it, a node or
    // definition that still resolves reaches `rebuildAll()` here, and a
    // handle that resolves to *neither* an entity nor a node — a removal —
    // reaches the equally conservative fallback inside `_reconcileEntity`
    // (see its `last == null` branch). Either path ends this call with
    // exactly one `rebuildAll()`, so a single-handle touch cannot tell them
    // apart by outcome. The distinction only matters for a *batch* naming
    // more than one structural handle at once: this loop calls
    // `rebuildAll()` once after scanning the whole set, where routing every
    // structural handle through `_reconcileEntity` individually would call
    // it once per handle. No command in this package produces such a batch
    // today, so that saving is unexercised — kept for the shape of a
    // future command that touches several nodes in one edit, not because a
    // test proves it pays for itself yet.
    var structural = false;
    for (final handle in ordered) {
      if (document.tree.definition(handle) != null) {
        structural = true;
        continue;
      }
      if (document.tree[handle] != null) {
        structural = true;
        continue;
      }
      _reconcileEntity(handle);
    }

    if (structural) {
      // A node or definition changed: which container holds what, and where,
      // may have moved wholesale. Re-deriving one box is not enough, and
      // working out the minimal set is a Plan 3 optimisation if the
      // benchmark asks for it.
      rebuildAll();
      return;
    }

    // Snapshot the keys before iterating: `rebuildContainer` writes into
    // `_byContainer`, and iterating a map's values while a later call adds a
    // key throws ConcurrentModificationError. Nothing in this loop can add a
    // key that is not already in the snapshot — `rebuildContainer` only ever
    // overwrites a container that must already be indexed (its own guard
    // requires the root or a live definition), and the one path that *could*
    // grow `_byContainer` with a genuinely new entry, the `structural`
    // branch above, has already returned by this point.
    for (final container in _byContainer.keys.toList()) {
      final index = _byContainer[container];
      if (index == null) continue;
      if (index.needsRebuild) {
        rebuildContainer(container);
        continue;
      }
      _letBoundRecede(container, index);
    }
  }

  /// Gives a container's bound a way back in, and carries the tightening into
  /// every box that places it.
  ///
  /// **The mirror image of [_growPlacements], and the half that was missing.**
  /// Growth is exact at every step: a leaf that escapes its container's bound
  /// widens it and re-derives every instance box in the same breath.
  /// Shrinkage had no path at all, so the two directions were not symmetric —
  /// they were monotone. A definition dragged outwards and back left every
  /// box that places it stuck at the furthest reach of the gesture, for the
  /// rest of the index's life, and a query over the empty space it briefly
  /// covered descended into all of them. At 3000 placements one out-and-back
  /// drag took `pickInto` over empty space from 0.4 us to 3.75 ms.
  ///
  /// **Only for a container something actually places.** A bound reaches a
  /// query exactly when a *parent* indexes this container by it. The root has
  /// no parent and nothing on any query path reads its bound, so recomputing
  /// it would be an O(leaves) scan of the whole document — half a million
  /// boxes — bought nothing. Its public [ContainerIndex.bounds] therefore
  /// stays the upper bound its own doc comment already describes. A
  /// definition nothing places is skipped for the same reason, and cannot
  /// stay skipped by accident: placing one is a structural change, and every
  /// structural change goes through [rebuildAll].
  ///
  /// **No threshold, and deliberately so.** The obvious shape here is "rebuild
  /// once the bound has drifted by more than some factor", which needs a
  /// number chosen to trade query slack against rebuild frequency. This needs
  /// none: [ContainerIndex.boundsMayHaveReceded] is a one-sided *necessary*
  /// condition, false for any edit that was not holding a side of the bound,
  /// so the scan is skipped outright for almost every edit; and when it does
  /// run the answer is exact rather than within a factor. The cost profile is
  /// the exact mirror of the growth path already measured — O(placements) to
  /// push the new bound out, on the frames where the bound actually moves.
  void _letBoundRecede(Handle container, ContainerIndex index) {
    if (!index.boundsMayHaveReceded) return;
    final places = _placedBy[container];
    if (places == null || places.isEmpty) return;
    if (index.recomputeBounds()) _retightenPlacementsOf(container);
  }

  void _reconcileEntity(Handle handle) {
    final slot = document.entities.slotOf(handle);
    if (slot == null) {
      final last = _lastKnownSlot[handle];
      if (last == null) {
        // Never a live entity, and by the time `_reconcile` routed here it
        // no longer resolves to a node or definition either — so it *was*
        // one, and has just been removed (`RemoveNodeCommand`, most
        // directly, but anything with the same shape). `_reconcile`'s
        // structural rule only catches a handle that *still* resolves to a
        // node or definition when it is inspected; a removal is the one
        // case where the handle can no longer tell us that about itself,
        // which is why it falls through to here instead of setting
        // `structural`.
        //
        // Falling back to a full rebuild is the conservative version of the
        // fix: a precise one would mirror `_lastKnownSlot` for node and
        // definition handles too, but this class already accepts
        // `rebuildAll()` for every other structural change, so this is
        // consistent with the shipped design rather than a special case.
        // Without it, a removed node's leaves and instances — and a removed
        // definition's own `ContainerIndex` — stay indexed and keep being
        // found by every query until the next unrelated rebuild, a purge,
        // or a load.
        rebuildAll();
        return;
      }
      // A previously-seen entity that is now gone. Mark it dead everywhere
      // it might be indexed, and drop any dirty entry for it.
      for (final index in _byContainer.values) {
        // Before it stops counting: a removed leaf that was holding a side of
        // this container's bound is the plainest way for that bound to become
        // loose, and nothing else on this path would notice.
        //
        // The overlay is consulted when the tree has no live box, and that is
        // the common case rather than the exotic one: an entity edited since
        // the last rebuild is dead in the tree and live only on the overlay,
        // so reading `boxOfLeaf` alone would see null for exactly the
        // entities a session has been working on.
        final was = index.boxOfLeaf(last) ?? index.dirty.boxOf(last);
        if (was != null) index.noteBoxWithdrawn(was);
        index.markLeafDead(last);
        index.dirty.remove(last);
        // And its composed group transform, so a later entity that reuses
        // this slot cannot inherit it. Every path that puts a live entity in
        // a slot goes through `noteLeaf` below, which sets or clears the
        // entry outright, so this is belt-and-braces rather than the only
        // guard — but a stale matrix here would misplace an unrelated
        // entity, which is worth two lines to make impossible.
        index.forgetLeaf(last);
      }
      _lastKnownSlot.remove(handle);
      return;
    }

    _lastKnownSlot[handle] = slot;
    final owner = document.entities.ownerAt(slot);
    final index = _containerHolding(owner);
    if (index == null) {
      // Defensive, not currently reachable in a valid document: every
      // entity's owner chain terminates at the root, which is always
      // indexed, so this only fires if the tree is malformed (a broken
      // `parent` chain, or an owner naming neither a node nor an indexed
      // container). A full rebuild is the same conservative answer given
      // above rather than propagating a lookup failure into a query.
      rebuildAll();
      return;
    }

    final record = document.entities.read(slot);
    final payload = document.geometry.read(record.geomIndex);
    // `peek`, not `read`: this runs per candidate on the reconcile path and
    // `read` copies three objects. Nothing here keeps the payload past the
    // call.
    EntityKind? boundaryKind;
    GeometryPayload? boundaryPayload;
    if (record.kind == EntityKind.fill) {
      final b = document.entities
          .slotOf(boundaryHandleOf(document.geometry.peek(record.geomIndex)));
      if (b != null) {
        boundaryKind = document.entities.kindAt(b);
        boundaryPayload =
            document.geometry.peek(document.entities.geomIndexAt(b));
      }
    }
    final current = entityBounds(
      kind: record.kind,
      payload: payload,
      measurer: document.textMeasurer,
      textStyle: document.textStyleOf(record.textStyle),
      textAttrs: record.textAttrs,
      text: record.text,
      boundaryKind: boundaryKind,
      boundaryPayload: boundaryPayload,
    );
    // The indexed box is in container space; if this entity sits under a
    // flattened group — or is an ATTRIB owned directly by an instance node —
    // the two differ by that chain's composed transform. Comparing against
    // the composed box is what makes an unchanged entity register as
    // unchanged.
    final composed = _groupTransformOf(owner, index.container);
    final expected = current.transformedBy(composed);

    // Before any of the unchanged/revive shortcuts below: the narrow phase
    // reads this per leaf, and an entity whose box happens to be unchanged
    // can still need it — a fresh index has it from `ContainerIndex.build`,
    // but a leaf that arrives through the dirty overlay would have no entry
    // at all and be measured in the wrong space. `noteLeaf` clears the entry
    // when the composed transform is the identity, so this is a set, not
    // just a fill.
    //
    // The return value says whether this leaf pushed the container's own
    // bound outwards. When it did, and the container is a definition, every
    // instance box that places it was derived from the smaller bound and no
    // longer covers the definition's contents — see [_growPlacements] for
    // what that used to hide. Checked before the unchanged/revive shortcuts
    // below for the same reason `noteLeaf` itself is: a leaf whose box is
    // unchanged still has to be accounted for the first time this index sees
    // it through the overlay.
    if (index.noteLeaf(slot, composed, record.kind, payload, expected) &&
        index.container != document.rootHandle) {
      _growPlacements(index.container, index.bounds, _byContainer.length);
    }

    // The snap centre this entity now offers, in the same container space as
    // `expected`, or `DirtyList.noCentre` for a kind that offers none. It is
    // carried through every branch below because it is a second fact about
    // the entity that its box does not imply — see
    // [ContainerIndex.storedSnapCentreMatches] for the arc edit that keeps a
    // box bit-identical while moving its centre.
    final centre = snapCentreOfLeaf(record.kind, payload, composed);
    final centreX = centre == null ? DirtyList.noCentre : centre.$1;
    final centreY = centre == null ? DirtyList.noCentre : centre.$2;

    final indexed = index.boxOfLeaf(slot);
    if (indexed != null &&
        _sameBox(indexed, expected) &&
        index.storedSnapCentreMatches(slot, centreX, centreY)) {
      // Live, indexed, and unchanged.
      //
      // `index.dirty.remove(slot)` here is defensive, not currently
      // reachable: the only place this class ever calls `dirty.put` is right
      // below, paired unconditionally with `markLeafDead` in the same
      // breath, so a slot that still has a usable box (`indexed != null`,
      // i.e. not dead) can never also carry a dirty entry today. Kept
      // anyway — and cheap — in case a future change adds a second path
      // onto the dirty list without also going through `markLeafDead`; if
      // that ever happens this stops a stale entry from surviving an edit
      // that reverted to its original box.
      index.dirty.remove(slot);
      return;
    }

    // `boxOfLeaf` returns null for a dead item, so a restored entity lands
    // here rather than in the early return above. Bringing the tree entry
    // back to life is what makes remove-then-undo work; without it the dead
    // bit set by the remove would never clear.
    if (indexed == null && index.containsLeafSlot(slot)) {
      final revived = index.boxOfDeadLeaf(slot);
      if (revived != null &&
          _sameBox(revived, expected) &&
          index.storedSnapCentreMatches(slot, centreX, centreY)) {
        index.markLeafAlive(slot);
        index.dirty.remove(slot);
        return;
      }
    }

    // The box this leaf used to occupy stops holding the container's bound
    // out the moment the line below supersedes it. `indexed` is null for a
    // leaf that is already dead, in which case the overlay entry about to be
    // replaced is what was in force — a drag replaces its own dirty entry
    // once per pointer move, and that is precisely the gesture whose
    // *return* leg would otherwise leave the bound stuck at its furthest
    // reach for the rest of the session.
    index.noteBoxWithdrawn(
        indexed ?? (index.dirty.boxOf(slot) ?? Aabb2.empty()));

    index.markLeafDead(slot);
    index.dirty.put(slot, expected, centreX, centreY);
    _dirtyCount++;
  }

  /// The transform from [owner]'s space up to [container]'s space, composing
  /// every node's own transform in between.
  ///
  /// Ordinarily every node on this walk is a flattened [GroupNode] — see the
  /// class doc on [ContainerIndex] — but [owner] itself may instead be an
  /// *instance* node: an ATTRIB entity's owner is the INSERT that carries it,
  /// per [EntityRecord.owner], and [ContainerIndex.build] composes that
  /// instance's own transform into such a leaf's box exactly as it does a
  /// group's. Restricting this walk to [GroupNode] would stop at that first
  /// step and silently return an under-composed transform for every
  /// ATTRIB — not a failure to find [container], which
  /// [_containerHolding] has already resolved, but a wrong answer that
  /// [_sameBox] cannot tell from a real move. Every [Node] subtype carries a
  /// `transform`, so nothing but the loop's own termination needs to care
  /// which subtype is at each step.
  ///
  /// `seen`, not a numeric step cap: a numeric cap would silently truncate a
  /// legitimately deep chain of groups before it reaches [container],
  /// returning a partial — and therefore wrong — composed transform with no
  /// signal that anything was cut short. `seen` costs nothing a correct walk
  /// would not already pay, terminates a malformed, cyclic tree exactly as a
  /// cap would, and never truncates an acyclic one no matter how deep.
  Transform2 _groupTransformOf(Handle owner, Handle container) {
    var acc = Transform2.identity();
    var current = owner;
    final seen = <Handle>{};
    while (current != container) {
      if (!seen.add(current)) break; // cyclic tree; stop rather than hang
      final node = document.tree[current];
      if (node == null) break;
      acc = node.transform.multiply(acc);
      current = node.parent;
    }
    return acc;
  }

  /// The index of the container that holds [owner] — itself if it is
  /// indexed, otherwise the nearest indexed ancestor, since groups are
  /// flattened.
  ///
  /// `seen`, not a numeric step cap, for the same reason as
  /// [_groupTransformOf]: the failure mode here is milder — a cap firing on
  /// a legitimately deep tree only makes this return null, and every caller
  /// treats null as "fall back to [rebuildAll]", so a truncated walk cannot
  /// produce a *wrong* container, only an unnecessarily expensive correct
  /// one — but there is no reason to pay that cost when `seen` avoids it for
  /// free and still terminates a cyclic tree.
  ContainerIndex? _containerHolding(Handle owner) {
    var current = owner;
    final seen = <Handle>{};
    while (true) {
      if (!seen.add(current)) return null; // cyclic tree; stop rather than hang
      final direct = _byContainer[current];
      if (direct != null) return direct;
      final node = document.tree[current];
      if (node == null) return null;
      current = node.parent;
    }
  }

  /// Deliberately exact `==`, not a tolerance. This is a stored-value
  /// comparison — "is the indexed box byte-identical to the freshly derived
  /// one" — not a geometric decision. A tolerance here would let a real move
  /// slip through as unchanged.
  static bool _sameBox(Aabb2 a, Aabb2 b) =>
      a.minX == b.minX &&
      a.minY == b.minY &&
      a.maxX == b.maxX &&
      a.maxY == b.maxY;

  void dispose() {
    // Only detach the hook if it is still ours: a second index over the same
    // document would otherwise be silently unhooked by the first one's
    // disposal.
    //
    // `==`, not `identical`: two tear-offs of the same instance method on the
    // same receiver are `==` but never `identical` — each tear-off is a fresh
    // closure object. `identical` here would be false in every case,
    // including the single-index case this plan actually supports, so the
    // hook would never detach and a "disposed" index would keep rebuilding
    // itself on every future load and purge for the document's lifetime.
    if (document.commands.onAfterMutate == _onChange) {
      document.commands.onAfterMutate = null;
    }
    // Same reasoning, same `==` comparison, for the mutation guard: without
    // this a disposed index would keep refusing every mutation on the
    // document for the rest of its lifetime, since [_guardMutation] would
    // stay installed even though nothing can query this index to be
    // corrupted by one anymore.
    if (document.commands.onBeforeMutate == _guardMutation) {
      document.commands.onBeforeMutate = null;
    }
    _byContainer.clear();
    // Cleared alongside it, not left behind: every entry holds a
    // [ContainerIndex], which owns three `PackedRTree`s and a `DirtyList`, so
    // a `_placedBy` that outlived `_byContainer` would keep the whole index
    // alive one placement at a time after this object was meant to be done
    // with it.
    _placedBy.clear();
    _disposed = true;
  }
}

/// [Transform2.scaleMagnitude] for a transform held as loose coefficients.
///
/// The narrow phase composes the container transform with a leaf's
/// flattened-group transform into six doubles rather than a [Transform2]
/// object (see [SpatialIndex._considerLeaf]), so the two places that need the
/// representative scale of that product compute it here instead of reaching
/// for the getter. Same formula, `sqrt(|det|)`, deliberately: a second,
/// differently-rounded definition of "the scale of a transform" would make a
/// circle's picked radius disagree with the broad-phase margin derived from
/// it in [NarrowPhaseSlack].
///
/// A top-level function, not a method: it captures nothing but its
/// arguments, exactly like [_insideWorldPolygon] below.
double _scaleMagnitudeOf(double a, double b, double c, double d) =>
    math.sqrt((a * d - b * c).abs());

/// Even-odd ray cast, fused with the world transform.
///
/// The same algorithm as [insideClosedPolyline], transforming each vertex
/// into world space with the raw `a..f` coefficients as it goes rather than
/// through a materialised world-space [GeometryPayload] -- see
/// [SpatialIndex._considerLeaf]'s doc comment for why. A top-level function,
/// not a method: it captures nothing but its arguments, so it allocates no
/// closure and needs no `this`.
bool _insideWorldPolygon(
  Float64List coords,
  int count,
  double a,
  double b,
  double c,
  double d,
  double e,
  double f,
  Vector2 world,
) {
  var inside = false;
  var jx = a * coords[(count - 1) * 2] + c * coords[(count - 1) * 2 + 1] + e;
  var jy = b * coords[(count - 1) * 2] + d * coords[(count - 1) * 2 + 1] + f;
  for (var i = 0; i < count; i++) {
    final xi = a * coords[i * 2] + c * coords[i * 2 + 1] + e;
    final yi = b * coords[i * 2] + d * coords[i * 2 + 1] + f;
    if ((yi > world.y) != (jy > world.y) &&
        world.x < (jx - xi) * (world.y - yi) / (jy - yi) + xi) {
      inside = !inside;
    }
    jx = xi;
    jy = yi;
  }
  return inside;
}
