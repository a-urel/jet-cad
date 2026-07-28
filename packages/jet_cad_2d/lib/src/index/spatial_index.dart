import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../core/handle.dart';
import '../document/doc_change.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/node.dart';
import '../document/style.dart';
import '../geometry/aabb2.dart';
import '../geometry/distance.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import 'container_index.dart';
import 'hit.dart';
import 'query_filter.dart';
import 'query_scratch.dart';

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
      _pickIn(root, Transform2.identity(), world, radius, filter, 0, out);
      return _bestKind != null;
    } finally {
      _endQuery();
    }
  }

  /// Searches one container, then recurses into whichever of its instances
  /// the query touches.
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
  void _pickIn(
    ContainerIndex index,
    Transform2 toWorld,
    Vector2 world,
    double radius,
    QueryFilter filter,
    int depth,
    HitPath out,
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
    final localQuery = Aabb2(
      Vector2(world.x - radius, world.y - radius),
      Vector2(world.x + radius, world.y + radius),
    ).transformedBy(toLocal);

    index.searchLeaves(localQuery, (slot) {
      if (_filters.acceptsEntity(slot, filter)) {
        _considerLeaf(slot, toWorld, world, radius, depth, out);
      }
    });

    final level = _scratchForDepth(depth)..reset();
    index.searchInstances(localQuery, (node) {
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
      _pickIn(child, composed, world, radius, filter, depth + 1, out);
    }
  }

  /// Measures one candidate leaf in world space and, if it is the best hit
  /// found so far this pick, writes it into [out].
  ///
  /// Every point and segment is transformed into world space with [toWorld]
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
    Transform2 toWorld,
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

    final ta = toWorld.a, tb = toWorld.b, tc = toWorld.c, td = toWorld.d;
    final te = toWorld.e, tf = toWorld.f;

    HitKind? foundKind;
    var foundX = 0.0, foundY = 0.0;

    switch (kind) {
      case EntityKind.point:
      case EntityKind.text:
      case EntityKind.attrib:
        // The only geometric feature is the anchor point -- the insertion
        // point for text/attrib, the point itself for a point entity --
        // treated as a vertex, since that is the one feature there is to
        // grab.
        final lx = coords[0], ly = coords[1];
        final wx = ta * lx + tc * ly + te, wy = tb * lx + td * ly + tf;
        final dx = world.x - wx, dy = world.y - wy;
        if (math.sqrt(dx * dx + dy * dy) <= radius) {
          foundKind = HitKind.vertex;
          foundX = wx;
          foundY = wy;
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
        // approximation otherwise.
        final worldRadius = payload.scalars[0] * toWorld.scaleMagnitude;
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
        final worldRadius = localRadius * toWorld.scaleMagnitude;
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
        final worldSweep = toWorld.determinant < 0 ? -sweep : sweep;
        _scratchA.setValues(wx, wy);
        final dist = distanceToArc(
            world, _scratchA, worldRadius, worldStartAngle, worldSweep);
        if (dist <= radius) {
          foundKind = HitKind.edge;
          final dx = world.x - wx, dy = world.y - wy;
          final centreDist = math.sqrt(dx * dx + dy * dy);
          if (centreDist == 0.0) {
            foundX = wx + worldRadius;
            foundY = wy;
          } else {
            foundX = wx + dx / centreDist * worldRadius;
            foundY = wy + dy / centreDist * worldRadius;
          }
        }
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
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer[container] =
        ContainerIndex.build(document, container, byOwner);
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
      if (_byContainer[container]?.needsRebuild ?? false) {
        rebuildContainer(container);
      }
    }
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
        index.markLeafDead(last);
        index.dirty.remove(last);
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
    final current = entityBounds(
      kind: record.kind,
      payload: document.geometry.read(record.geomIndex),
      measurer: document.textMeasurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    // The indexed box is in container space; if this entity sits under a
    // flattened group — or is an ATTRIB owned directly by an instance node —
    // the two differ by that chain's composed transform. Comparing against
    // the composed box is what makes an unchanged entity register as
    // unchanged.
    final composed = _groupTransformOf(owner, index.container);
    final expected = current.transformedBy(composed);

    final indexed = index.boxOfLeaf(slot);
    if (indexed != null && _sameBox(indexed, expected)) {
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
      if (revived != null && _sameBox(revived, expected)) {
        index.markLeafAlive(slot);
        index.dirty.remove(slot);
        return;
      }
    }

    index.markLeafDead(slot);
    index.dirty.put(slot, expected);
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
    _disposed = true;
  }
}

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
