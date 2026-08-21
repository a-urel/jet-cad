// Brute-force answers, computed independently of the index.
//
// Deliberately slow and obvious: it walks every entity, composes transforms
// by hand, and sorts at the end. **It must never import anything from
// `lib/src/index/` except `query_filter.dart`'s `FilterEvaluator`** — a pure
// accept/reject predicate over visibility and lock state, not a traversal or
// ordering decision, and the task brief's own model code uses it directly.
// Nothing here calls `SpatialIndex`, `ContainerIndex` or `PackedRTree`;
// sharing traversal, ordering or transform-composition code with the
// implementation under test would make agreement meaningless.
//
// It *does* use `entityBounds` (geometry/primitives.dart's bounds
// definition) and most of `distance.dart`'s narrow-phase formulas
// (`distanceToSegment`, `distanceToCircle`, `distanceToArc`,
// `projectOntoSegment`), because those are the geometry definitions rather
// than the index under test, and the task brief explicitly sanctions reusing
// them — re-deriving point-to-arc distance independently would test the
// arithmetic twice rather than testing the index.
//
// **One deliberate exception: segment intersection does *not* share code.**
// `distance.dart`'s zero-allocation `segmentIntersection` is the function
// `SpatialIndex._considerIntersections` actually calls, so this file uses
// `primitives.dart`'s independently-written, allocating twin
// `segmentIntersectionTol` instead — a genuinely different implementation
// (denominator-vs-zero clamp, not angular-tolerance) of the same
// mathematical operation, which exists in this package for an unrelated
// naming-collision reason (see its own doc comment) and happens to be
// exactly the "second implementation" independence requires here. Sharing
// `segmentIntersection` would have made "return the infinite-line
// intersection" (dropping the segment clamp) an undetectable mutation.

import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// One leaf entity reachable from the document root, together with the
/// transform that carries its local coordinates into world space and the
/// handle of its root-level ancestor (see [allLeavesInWorld]).
typedef LeafCandidate = ({int slot, Transform2 toWorld, Handle root});

/// A depth/step cap for every recursive walk in this file. A well-formed
/// document cannot reach it — cycles are rejected on write — but a malformed
/// corpus fixture should fail a test with a clear error rather than hang the
/// suite.
const int _kMaxWalkDepth = 256;

/// The transform from [owner]'s own space up to the document root, or
/// `null` when the walk reaches a *definition* instead of the root.
///
/// This null case is the whole point of writing this by hand rather than
/// calling `DocumentTree.accumulatedTransform`: that method stops climbing
/// the `parent` chain wherever it runs out of nodes, which is exactly what
/// happens both at the true root *and* at a definition's own children (a
/// definition is not a [Node] and carries no `parent`), so it cannot tell
/// "reached the root" apart from "walked into a definition body". Getting
/// that distinction wrong would make root-level and definition-only content
/// indistinguishable, silently agreeing with a broken index for the wrong
/// reason.
Transform2? toRootSpace(DraftDocument doc, Handle owner) {
  if (owner == doc.rootHandle) return Transform2.identity();

  final chain = <Transform2>[];
  var current = owner;
  final seen = <Handle>{};
  var depth = 0;
  while (current != doc.rootHandle) {
    if (doc.tree.definition(current) != null) {
      return null; // inside a definition body, not root-level
    }
    final node = doc.tree[current];
    if (node == null) return null; // dangling owner; not reachable from root
    if (!seen.add(current)) {
      throw StateError('reference walk found a cycle at ${current.toHex()}');
    }
    chain.add(node.transform);
    current = node.parent;
    if (++depth > _kMaxWalkDepth) {
      throw StateError('reference walk exceeded depth cap (possible cycle)');
    }
  }

  // chain is owner-first, root-ward; each subsequent (more outer) transform
  // is composed on the *left* of the accumulator, since Transform2.multiply
  // applies its argument first (parent.multiply(child) maps child space into
  // parent space).
  var acc = Transform2.identity();
  for (final t in chain) {
    acc = t.multiply(acc);
  }
  return acc;
}

/// Child **node** handles of [container] — a group, a definition, or the
/// root — never leaf entities. Written locally rather than via
/// `DocumentTree.childNodesOf` so this file owns its own reading of
/// `GroupNode.children`/`Definition.children`, matching the independence
/// this file is for; the corpus never produces a `children` entry naming a
/// handle that is not a node, so the "tolerate a dangling entry" filter that
/// utility applies is not needed here.
List<Handle> _childrenOf(DraftDocument doc, Handle container) {
  final node = doc.tree[container];
  if (node is GroupNode) return node.children;
  final def = doc.tree.definition(container);
  if (def != null) return def.children;
  return const [];
}

/// Every leaf entity reachable from the document root, descending through
/// every instance with its transform composed in — the same set
/// `pickInto`/`snapInto` search, computed by walking the raw tree rather
/// than any indexed structure.
///
/// [LeafCandidate.root] is the handle of the root-level ancestor: the
/// top-most instance on the path from the root to this leaf, or the leaf's
/// own handle when it sits directly at the root (with, at most, flattened
/// groups between it and the root) — the same "a root-level leaf stands in
/// for its own root-level ancestor" rule `SpatialIndex._considerLeaf`'s doc
/// comment states.
///
/// Computed once and reused across every trial of one test: the document
/// does not change between queries in this harness, so recomputing this walk
/// per trial would be wasted work, not extra correctness.
List<LeafCandidate> allLeavesInWorld(DraftDocument doc) {
  final byOwner = <Handle, List<int>>{};
  for (final slot in doc.entities.liveSlots) {
    (byOwner[doc.entities.ownerAt(slot)] ??= <int>[]).add(slot);
  }

  final out = <LeafCandidate>[];
  final visiting = <Handle>{};

  void walk(
    Handle container,
    Transform2 toWorld,
    Handle rootAncestor,
    int depth,
  ) {
    if (depth > _kMaxWalkDepth) {
      throw StateError('reference leaf walk exceeded depth cap (possible '
          'cycle)');
    }
    if (!visiting.add(container)) {
      throw StateError(
          'reference leaf walk found a cycle at ${container.toHex()}');
    }

    for (final slot in byOwner[container] ?? const <int>[]) {
      final root =
          rootAncestor.isNone ? doc.entities.handleAt(slot) : rootAncestor;
      out.add((slot: slot, toWorld: toWorld, root: root));
    }

    for (final childHandle in _childrenOf(doc, container)) {
      final node = doc.tree[childHandle];
      if (node == null) continue; // tolerate a dangling children entry
      switch (node) {
        case GroupNode():
          walk(childHandle, toWorld.multiply(node.transform), rootAncestor,
              depth + 1);
        case InstanceNode(:final definition):
          final composed = toWorld.multiply(node.transform);
          // Leaves whose owner is the *instance node itself* — an ATTRIB
          // belongs to the INSERT, not to the definition (see
          // `EntityRecord.owner`), so `byOwner` files it under the node
          // handle and the `byOwner[container]` loop above, which only ever
          // sees containers, never reaches it. Its coordinates are
          // instance-local, exactly like any other leaf this node owns, so
          // it takes `composed` — the same transform the definition's own
          // leaves take, and the same one `toRootSpace` gives it in
          // [referenceEntitiesInRect]. It stays at *this* level's
          // `rootAncestor`, not `newRoot`: it is not inside the definition,
          // so a root-level INSERT's attribute is root-level content and
          // stands in for its own root-level ancestor.
          for (final slot in byOwner[childHandle] ?? const <int>[]) {
            final root = rootAncestor.isNone
                ? doc.entities.handleAt(slot)
                : rootAncestor;
            out.add((slot: slot, toWorld: composed, root: root));
          }
          final newRoot = rootAncestor.isNone ? childHandle : rootAncestor;
          walk(definition, composed, newRoot, depth + 1);
      }
    }

    visiting.remove(container);
  }

  walk(doc.rootHandle, Transform2.identity(), Handle.none, 0);
  return out;
}

/// Every root-level leaf whose world box overlaps [world], ascending.
///
/// Mirrors `forEachInRect`: root-level only, no descent into instances,
/// groups flattened.
List<Handle> referenceEntitiesInRect(
    DraftDocument doc, Aabb2 world, QueryFilter filter) {
  if (world.isEmpty) return const [];
  final evaluator = FilterEvaluator(doc);
  final out = <Handle>[];

  for (final slot in doc.entities.liveSlots) {
    final owner = doc.entities.ownerAt(slot);
    final composed = toRootSpace(doc, owner);
    if (composed == null) continue; // inside a definition, not root-level
    if (!evaluator.acceptsEntity(slot, filter)) continue;

    final record = doc.entities.read(slot);
    final payload = doc.geometry.peek(record.geomIndex);
    // `peek`, not `read`: this reference walk mirrors the index's own
    // per-candidate style, and nothing here keeps the boundary payload past
    // the call.
    EntityKind? boundaryKind;
    GeometryPayload? boundaryPayload;
    if (record.kind == EntityKind.fill) {
      final b = doc.entities.slotOf(boundaryHandleOf(payload));
      if (b != null) {
        boundaryKind = doc.entities.kindAt(b);
        boundaryPayload = doc.geometry.peek(doc.entities.geomIndexAt(b));
      }
    }
    final box = entityBounds(
      kind: record.kind,
      payload: payload,
      measurer: doc.textMeasurer,
      textStyle: doc.textStyleOf(record.textStyle),
      textAttrs: record.textAttrs,
      text: record.text,
      boundaryKind: boundaryKind,
      boundaryPayload: boundaryPayload,
    ).transformedBy(composed);

    if (!box.isEmpty && box.intersects(world)) {
      out.add(doc.entities.handleAt(slot));
    }
  }

  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

/// Every root-level instance whose world box overlaps [world], ascending.
List<Handle> referenceInstancesInRect(
    DraftDocument doc, Aabb2 world, QueryFilter filter) {
  if (world.isEmpty) return const [];
  final evaluator = FilterEvaluator(doc);
  final out = <Handle>[];

  for (final node in doc.tree.nodes) {
    if (node is! InstanceNode) continue;
    final parentTransform = toRootSpace(doc, node.parent);
    if (parentTransform == null) continue;
    if (!evaluator.acceptsNode(node.handle, filter)) continue;

    final box = doc
        .definitionBounds(node.definition)
        .transformedBy(parentTransform.multiply(node.transform));
    if (!box.isEmpty && box.intersects(world)) out.add(node.handle);
  }

  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

/// The winning pick, or null. Descends into instances, unlike the rect
/// query. [leaves] is the result of [allLeavesInWorld] for the same
/// document — passed in rather than recomputed here so a caller running many
/// trials against an unchanged document pays for the walk once.
///
/// The tie-break mirrors the doc comment on
/// `SpatialIndex._considerLeaf`: kind first (vertex beats edge beats fill,
/// unconditionally), and only on a kind tie does the root-level ancestor's
/// handle decide, and only on *that* tie does the leaf's own handle decide.
/// There is deliberately no distance term — a click's "which vertex/edge/
/// fill wins within one entity" is already resolved by [_hitAtOf]; across
/// entities, later-drawn (greater handle) wins a tie, not nearer.
///
/// **The [point] is part of the answer, not decoration.** It used to be
/// absent, so `differential_test.dart` could only compare entity and kind
/// while its `snapInto` sibling compared coordinates — and an arc whose
/// reported `HitPath.worldPoint` was a radial projection with no sweep
/// check went unnoticed through the whole corpus. What the two sides must
/// agree on is the point [HitPath.worldPoint] carries: the feature that was
/// hit, not the query point.
({Handle entity, HitKind kind, Vector2 point})? referencePick(
  DraftDocument doc,
  Vector2 world,
  double radius,
  QueryFilter filter,
  List<LeafCandidate> leaves,
) {
  final evaluator = FilterEvaluator(doc);
  ({Handle entity, HitKind kind, Vector2 point, Handle root})? best;

  for (final candidate in leaves) {
    if (!evaluator.acceptsEntity(candidate.slot, filter)) continue;

    final hit = _hitAtOf(doc, candidate, world, radius);
    if (hit == null) continue;

    final handle = doc.entities.handleAt(candidate.slot);
    if (best == null ||
        hit.kind.index < best.kind.index ||
        (hit.kind == best.kind &&
            (candidate.root.value > best.root.value ||
                (candidate.root == best.root &&
                    handle.value > best.entity.value)))) {
      best = (
        entity: handle,
        kind: hit.kind,
        point: hit.point,
        root: candidate.root
      );
    }
  }

  return best == null
      ? null
      : (entity: best.entity, kind: best.kind, point: best.point);
}

/// The winning snap candidate, or null. [leaves] is [allLeavesInWorld] for
/// the same document, reused across trials the same way [referencePick]
/// reuses it.
///
/// **The tie-break here is the full four-term contract stated on
/// `SpatialIndex._considerSnapCandidate`'s doc comment — kind, then
/// distance, then root-level ancestor handle, then leaf handle — not the
/// two-term (kind, distance) shortcut in the task brief's own illustrative
/// snippet.** The brief's snippet omits the root/leaf terms; the doc comment
/// on the method it is modelling states them explicitly ("on a full tie
/// [...] the candidate whose root-level ancestor has the greater handle
/// wins, and only when *that* also ties does the leaf's own handle decide"),
/// so this implements the documented contract rather than the abbreviated
/// example.
({SnapKind kind, Vector2 point, Handle entity})? referenceSnap(
  DraftDocument doc,
  Vector2 world,
  double radius,
  SnapMask mask,
  List<LeafCandidate> leaves,
) {
  SnapKind? bestKind;
  var bestDist = double.infinity;
  var bestEntity = Handle.none;
  var bestRoot = Handle.none;
  Vector2? bestPoint;

  void consider(SnapKind kind, Vector2 point, Handle entity, Handle root) {
    final distance = world.distanceTo(point);
    if (distance > radius) return;
    final better = bestKind == null ||
        kind.index < bestKind!.index ||
        (kind == bestKind &&
            (distance < bestDist ||
                (distance == bestDist &&
                    (root.value > bestRoot.value ||
                        (root == bestRoot &&
                            entity.value > bestEntity.value)))));
    if (!better) return;
    bestKind = kind;
    bestDist = distance;
    bestEntity = entity;
    bestRoot = root;
    bestPoint = point;
  }

  for (final candidate in leaves) {
    final entity = doc.entities.handleAt(candidate.slot);
    for (final (kind, point) in _snapCandidates(doc, candidate, mask, world)) {
      consider(kind, point, entity, candidate.root);
    }
  }

  if (mask.has(SnapKind.intersection)) {
    _considerIntersections(doc, world, radius, consider);
  }

  return bestKind == null
      ? null
      : (kind: bestKind!, point: bestPoint!, entity: bestEntity);
}

/// Measures one candidate leaf in world space and returns the highest-
/// priority [HitKind] within [radius] **and the point that hit reports**, or
/// null. Checked in the fixed order vertex, then edge, then fill — mirroring
/// `SpatialIndex._considerLeaf`'s doc comment, written out again
/// independently rather than shared.
///
/// The point is computed here the obvious way — nearest vertex, clamped foot
/// on the nearest segment, radial projection onto a rim, the query point
/// itself for a fill — with no help from `lib/src/index/`. Within one leaf
/// the *first* of several equally near features wins, matching
/// `_considerLeaf`'s strict `<` comparisons; a `<=` there would silently
/// prefer the last, which is a real difference on a polyline whose vertices
/// coincide.
({HitKind kind, Vector2 point})? _hitAtOf(
  DraftDocument doc,
  LeafCandidate candidate,
  Vector2 world,
  double radius,
) {
  final record = doc.entities.read(candidate.slot);
  final payload = doc.geometry.peek(record.geomIndex);
  final toWorld = candidate.toWorld;
  final count = payload.pointCount;
  if (count == 0) return null;

  switch (record.kind) {
    case EntityKind.point:
      final p = toWorld.transformPoint(payload.pointAt(0));
      return world.distanceTo(p) <= radius
          ? (kind: HitKind.vertex, point: p)
          : null;

    case EntityKind.text:
    case EntityKind.attrib:
      // Text is picked by the box its glyphs occupy, not by its insertion
      // point -- which stays a `SnapKind.insertion` candidate, and only
      // that. The radius plays no part, exactly as it plays none in the
      // closed-polyline fill case above.
      //
      // **Written from the laid-out box, deliberately not the way the index
      // computes it.** `SpatialIndex._considerLeaf` composes the text's
      // local transform with the leaf's world transform into six raw
      // doubles, inverts that by solving a 2x2 system, and tests the
      // resulting glyph-space point against the axis-aligned box. This maps
      // the box's four corners *forwards* into world space and asks whether
      // the query point is inside the resulting parallelogram, by the sign
      // of four edge cross products. The two agree only if the composition,
      // the inversion and the interval test are all right; a shared helper,
      // or copying that expression here, would have made the differential
      // test compare an implementation with itself.
      //
      // `resolveTextAttributes`/`textLocalBounds`/`textLocalTransform` *are*
      // shared, on the same footing as `entityBounds` and `distance.dart`'s
      // formulas (see this file's own header): they are the definition of
      // where a text entity's glyphs sit, not the index under test, and
      // re-deriving DXF's justification and oblique rules here would test
      // that arithmetic twice rather than testing the index.
      final style = doc.textStyleOf(record.textStyle);
      final metrics = doc.textMeasurer.measure(text: record.text, style: style);
      final attrs = resolveTextAttributes(payload, record.textAttrs, style);
      final box = textLocalBounds(attrs, metrics);
      // A box with no area has nothing to fill -- an empty string, or the
      // zero metrics `InsertionPointMeasurer` answers with. The index
      // states the same rule; both sides need it, or they disagree on
      // whether a collapsed box swallows the single point it collapsed to.
      if (box.maxX <= box.minX || box.maxY <= box.minY) return null;

      final toGlyphWorld = toWorld
          .multiply(textLocalTransform(attrs, metrics, payload.pointAt(0)));
      final corners = [
        toGlyphWorld.transformPoint(Vector2(box.minX, box.minY)),
        toGlyphWorld.transformPoint(Vector2(box.maxX, box.minY)),
        toGlyphWorld.transformPoint(Vector2(box.maxX, box.maxY)),
        toGlyphWorld.transformPoint(Vector2(box.minX, box.maxY)),
      ];
      return _insideParallelogram(world, corners)
          ? (kind: HitKind.fill, point: world)
          : null;

    case EntityKind.line:
    case EntityKind.polyline:
      final worldPts = [
        for (var i = 0; i < count; i++)
          toWorld.transformPoint(payload.pointAt(i)),
      ];
      var bestVertex = double.infinity;
      var bestVertexPoint = worldPts[0];
      for (final p in worldPts) {
        final d = world.distanceTo(p);
        if (d < bestVertex) {
          bestVertex = d;
          bestVertexPoint = p;
        }
      }
      if (bestVertex <= radius) {
        return (kind: HitKind.vertex, point: bestVertexPoint);
      }
      if (count < 2) return null;

      var bestEdge = double.infinity;
      var bestEdgePoint = worldPts[0];
      for (var i = 0; i + 1 < count; i++) {
        final d = distanceToSegment(world, worldPts[i], worldPts[i + 1]);
        if (d < bestEdge) {
          bestEdge = d;
          bestEdgePoint =
              _clampedFootOnSegment(world, worldPts[i], worldPts[i + 1]);
        }
      }
      if (bestEdge <= radius) return (kind: HitKind.edge, point: bestEdgePoint);

      if (record.kind == EntityKind.polyline &&
          count >= 3 &&
          // Closed on the *local* data, exactly the check
          // `SpatialIndex._considerLeaf` makes -- an affine transform
          // preserves coincidence, so this could equally be checked in
          // world space, but checking the stored values is the more
          // direct statement of "does the data say closed".
          payload.coords[0] == payload.coords[(count - 1) * 2] &&
          payload.coords[1] == payload.coords[(count - 1) * 2 + 1] &&
          _insideWorldPolygon(worldPts, world)) {
        // A fill hit has no feature of its own to report, so the query point
        // stands in for it -- the same convention `_considerLeaf` uses.
        return (kind: HitKind.fill, point: world);
      }
      return null;

    case EntityKind.circle:
      final centre = toWorld.transformPoint(payload.pointAt(0));
      final worldRadius = payload.scalars[0] * toWorld.scaleMagnitude;
      final rim = distanceToCircle(world, centre, worldRadius);
      final centreDist = world.distanceTo(centre);
      if (rim <= radius) {
        // Dead centre has no single nearest rim point; both sides answer
        // "the one at angle zero" by convention, the same way they agree on
        // any other tie-break here.
        final point = centreDist == 0.0
            ? Vector2(centre.x + worldRadius, centre.y)
            : Vector2(
                centre.x + (world.x - centre.x) / centreDist * worldRadius,
                centre.y + (world.y - centre.y) / centreDist * worldRadius,
              );
        return (kind: HitKind.edge, point: point);
      }
      if (centreDist < worldRadius) return (kind: HitKind.fill, point: world);
      return null;

    case EntityKind.arc:
      final local = payload.pointAt(0);
      final localRadius = payload.scalars[0];
      final startAngle = payload.scalars[1];
      final sweep = payload.scalars[2];
      final centre = toWorld.transformPoint(local);
      final worldRadius = localRadius * toWorld.scaleMagnitude;
      final startLocal = Vector2(
        local.x + localRadius * math.cos(startAngle),
        local.y + localRadius * math.sin(startAngle),
      );
      final worldStart = toWorld.transformPoint(startLocal);
      final worldStartAngle =
          math.atan2(worldStart.y - centre.y, worldStart.x - centre.x);
      final worldSweep = toWorld.determinant < 0 ? -sweep : sweep;
      final d = distanceToArc(
          world, centre, worldRadius, worldStartAngle, worldSweep);
      if (d > radius) return null;
      return (
        kind: HitKind.edge,
        point: _footOnWorldArc(
            world, centre, worldRadius, worldStartAngle, worldSweep),
      );

    case EntityKind.fill:
      // A fill produces no hit and no snap candidate.
      return null;
  }
}

/// The point of `[a], [b]` nearest [world], clamped to the segment.
///
/// Written out rather than calling `projectOntoSegment`: that function is
/// what the implementation itself uses for its `nearest`/`perpendicular`
/// snap candidates, and a pick's edge point has to be derived here from the
/// definition of "closest point on a segment", not from the same code.
Vector2 _clampedFootOnSegment(Vector2 world, Vector2 a, Vector2 b) {
  final abx = b.x - a.x, aby = b.y - a.y;
  final lenSq = abx * abx + aby * aby;
  if (lenSq == 0.0) return a;
  var t = ((world.x - a.x) * abx + (world.y - a.y) * aby) / lenSq;
  if (t < 0.0) {
    t = 0.0;
  } else if (t > 1.0) {
    t = 1.0;
  }
  return Vector2(a.x + t * abx, a.y + t * aby);
}

/// The point of a *drawn* arc nearest [world]: the radial projection when
/// [world]'s direction from the centre falls inside the sweep, otherwise the
/// nearer endpoint.
///
/// An arc is not a circle. Projecting radially with no sweep check returns a
/// point the curve never passes through, which is exactly the disagreement
/// between `pickInto` and `snapInto` this oracle was extended to catch.
Vector2 _footOnWorldArc(Vector2 world, Vector2 centre, double worldRadius,
    double worldStartAngle, double worldSweep) {
  final dx = world.x - centre.x, dy = world.y - centre.y;
  final centreDist = math.sqrt(dx * dx + dy * dy);
  if (centreDist != 0.0 &&
      angleInSweep(math.atan2(dy, dx), worldStartAngle, worldSweep)) {
    return Vector2(centre.x + dx / centreDist * worldRadius,
        centre.y + dy / centreDist * worldRadius);
  }
  final endAngle = worldStartAngle + worldSweep;
  final start = Vector2(centre.x + worldRadius * math.cos(worldStartAngle),
      centre.y + worldRadius * math.sin(worldStartAngle));
  final end = Vector2(centre.x + worldRadius * math.cos(endAngle),
      centre.y + worldRadius * math.sin(endAngle));
  return world.distanceToSquared(start) <= world.distanceToSquared(end)
      ? start
      : end;
}

/// Whether [world] lies in the closed convex quadrilateral [corners], given
/// in order around its perimeter.
///
/// The half-plane test, not the even-odd ray cast [_insideWorldPolygon] runs
/// for a closed polyline: an affine image of a rectangle is convex, so "on
/// the same side of all four edges" is exact for it, and -- unlike the ray
/// cast -- it treats the boundary as *inside*, which is what makes it agree
/// with the index's closed-interval box test on a point sitting exactly on
/// an edge.
///
/// A collapsed quadrilateral (zero area, from a singular transform: a zero
/// text height, or an instance that flattens its definition) would make
/// every cross product zero and swallow every point on the segment it
/// collapsed to, so it answers false outright. The index states the same
/// rule as its own singular-determinant guard.
bool _insideParallelogram(Vector2 world, List<Vector2> corners) {
  var positive = false;
  var negative = false;
  var area = 0.0;
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % corners.length];
    area += a.x * b.y - b.x * a.y;
    final cross = (b.x - a.x) * (world.y - a.y) - (b.y - a.y) * (world.x - a.x);
    if (cross > 0) positive = true;
    if (cross < 0) negative = true;
  }
  if (area == 0.0) return false;
  return !(positive && negative);
}

/// Even-odd ray cast over already-world-space points. The same standard
/// algorithm `SpatialIndex._insideWorldPolygon` uses, but written fresh
/// against a plain `List<Vector2>` rather than imported -- that private
/// function is not even visible outside `spatial_index.dart`.
bool _insideWorldPolygon(List<Vector2> pts, Vector2 world) {
  var inside = false;
  var j = pts.length - 1;
  for (var i = 0; i < pts.length; i++) {
    final xi = pts[i].x, yi = pts[i].y;
    final xj = pts[j].x, yj = pts[j].y;
    if ((yi > world.y) != (yj > world.y) &&
        world.x < (xj - xi) * (world.y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
    j = i;
  }
  return inside;
}

/// Every cheap- and moderate-kind snap candidate of one leaf, in world
/// space, filtered to [mask]. The same per-kind table
/// `SpatialIndex._considerSnapLeaf` computes, written out again here rather
/// than shared -- a shared table would let one mistake pass both sides.
List<(SnapKind, Vector2)> _snapCandidates(
  DraftDocument doc,
  LeafCandidate candidate,
  SnapMask mask,
  Vector2 world,
) {
  final record = doc.entities.read(candidate.slot);
  final payload = doc.geometry.peek(record.geomIndex);
  final toWorld = candidate.toWorld;
  final count = payload.pointCount;
  final out = <(SnapKind, Vector2)>[];
  if (count == 0) return out;

  void add(SnapKind kind, Vector2 p) {
    if (mask.has(kind)) out.add((kind, p));
  }

  switch (record.kind) {
    case EntityKind.point:
      add(SnapKind.endpoint, toWorld.transformPoint(payload.pointAt(0)));

    case EntityKind.line:
    case EntityKind.polyline:
      final worldPts = [
        for (var i = 0; i < count; i++)
          toWorld.transformPoint(payload.pointAt(i)),
      ];
      for (final p in worldPts) {
        add(SnapKind.endpoint, p);
      }
      for (var i = 0; i + 1 < count; i++) {
        add(
          SnapKind.midpoint,
          Vector2((worldPts[i].x + worldPts[i + 1].x) / 2,
              (worldPts[i].y + worldPts[i + 1].y) / 2),
        );
      }
      if (mask.has(SnapKind.nearest) || mask.has(SnapKind.perpendicular)) {
        for (var i = 0; i + 1 < count; i++) {
          final foot = Vector2.zero();
          final result =
              projectOntoSegment(world, worldPts[i], worldPts[i + 1], foot);
          if (result == null) continue;
          add(SnapKind.perpendicular, foot.clone());
          add(SnapKind.nearest, foot.clone());
        }
      }

    case EntityKind.circle:
      final localCentre = payload.pointAt(0);
      final r = payload.scalars[0];
      final centre = toWorld.transformPoint(localCentre);
      final worldRadius = r * toWorld.scaleMagnitude;

      add(SnapKind.center, centre);
      for (var q = 0; q < 4; q++) {
        final angle = q * (math.pi / 2);
        final lp = Vector2(localCentre.x + r * math.cos(angle),
            localCentre.y + r * math.sin(angle));
        add(SnapKind.quadrant, toWorld.transformPoint(lp));
      }
      if (mask.has(SnapKind.nearest) || mask.has(SnapKind.perpendicular)) {
        final foot = _footOnRim(world, centre, worldRadius);
        if (foot != null) {
          add(SnapKind.perpendicular, foot);
          add(SnapKind.nearest, foot);
        }
      }
      if (mask.has(SnapKind.tangent)) {
        final tangents =
            _tangentPoints(world.x, world.y, centre.x, centre.y, worldRadius);
        if (tangents != null) {
          add(SnapKind.tangent, tangents.$1);
          add(SnapKind.tangent, tangents.$2);
        }
      }

    case EntityKind.arc:
      final localCentre = payload.pointAt(0);
      final r = payload.scalars[0];
      final startAngle = payload.scalars[1];
      final sweep = payload.scalars[2];
      final centre = toWorld.transformPoint(localCentre);
      final worldRadius = r * toWorld.scaleMagnitude;

      final s = Vector2(localCentre.x + r * math.cos(startAngle),
          localCentre.y + r * math.sin(startAngle));
      final e = Vector2(localCentre.x + r * math.cos(startAngle + sweep),
          localCentre.y + r * math.sin(startAngle + sweep));
      add(SnapKind.endpoint, toWorld.transformPoint(s));
      add(SnapKind.endpoint, toWorld.transformPoint(e));

      final mid = startAngle + sweep / 2;
      final mp = Vector2(
          localCentre.x + r * math.cos(mid), localCentre.y + r * math.sin(mid));
      add(SnapKind.midpoint, toWorld.transformPoint(mp));

      add(SnapKind.center, centre);

      for (var q = 0; q < 4; q++) {
        final angle = q * (math.pi / 2);
        if (!angleInSweep(angle, startAngle, sweep)) continue;
        final lp = Vector2(localCentre.x + r * math.cos(angle),
            localCentre.y + r * math.sin(angle));
        add(SnapKind.quadrant, toWorld.transformPoint(lp));
      }

      final startLocal = Vector2(localCentre.x + r * math.cos(startAngle),
          localCentre.y + r * math.sin(startAngle));
      final worldStart = toWorld.transformPoint(startLocal);
      final worldStartAngle =
          math.atan2(worldStart.y - centre.y, worldStart.x - centre.x);
      final worldSweep = toWorld.determinant < 0 ? -sweep : sweep;

      if (mask.has(SnapKind.nearest) || mask.has(SnapKind.perpendicular)) {
        final foot =
            _footOnArc(world, centre, worldRadius, worldStartAngle, worldSweep);
        if (foot != null) {
          add(SnapKind.perpendicular, foot);
          add(SnapKind.nearest, foot);
        }
      }
      if (mask.has(SnapKind.tangent)) {
        final tangents =
            _tangentPoints(world.x, world.y, centre.x, centre.y, worldRadius);
        if (tangents != null) {
          final (ta, tb) = tangents;
          if (angleInSweep(math.atan2(ta.y - centre.y, ta.x - centre.x),
              worldStartAngle, worldSweep)) {
            add(SnapKind.tangent, ta);
          }
          if (angleInSweep(math.atan2(tb.y - centre.y, tb.x - centre.x),
              worldStartAngle, worldSweep)) {
            add(SnapKind.tangent, tb);
          }
        }
      }

    case EntityKind.text:
    case EntityKind.attrib:
      add(SnapKind.insertion, toWorld.transformPoint(payload.pointAt(0)));

    case EntityKind.fill:
      // A fill produces no hit and no snap candidate.
      break;
  }

  return out;
}

/// The point on a world-space circle's rim nearest [world]. Null when
/// [world] sits exactly on [centre], the sibling of
/// `SpatialIndex._footOnRim`'s own null case.
Vector2? _footOnRim(Vector2 world, Vector2 centre, double worldRadius) {
  final dx = world.x - centre.x, dy = world.y - centre.y;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d == 0.0) return null;
  return Vector2(
      centre.x + dx / d * worldRadius, centre.y + dy / d * worldRadius);
}

/// The sibling of `SpatialIndex._footOnArc`: the radial foot when [world]'s
/// direction from [centre] falls inside the sweep, otherwise the nearer of
/// the two arc endpoints -- an arc does not draw its full rim.
Vector2? _footOnArc(
  Vector2 world,
  Vector2 centre,
  double worldRadius,
  double startAngle,
  double sweep,
) {
  final dx = world.x - centre.x, dy = world.y - centre.y;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d != 0.0 && angleInSweep(math.atan2(dy, dx), startAngle, sweep)) {
    return Vector2(
        centre.x + dx / d * worldRadius, centre.y + dy / d * worldRadius);
  }

  final endAngle = startAngle + sweep;
  final ea = Vector2(centre.x + worldRadius * math.cos(startAngle),
      centre.y + worldRadius * math.sin(startAngle));
  final eb = Vector2(centre.x + worldRadius * math.cos(endAngle),
      centre.y + worldRadius * math.sin(endAngle));
  final da =
      (world.x - ea.x) * (world.x - ea.x) + (world.y - ea.y) * (world.y - ea.y);
  final db =
      (world.x - eb.x) * (world.x - eb.x) + (world.y - eb.y) * (world.y - eb.y);
  return da <= db ? ea : eb;
}

/// The classical two-tangent-lines-from-an-external-point construction,
/// using [px],[py] as that external point -- the same formula
/// `SpatialIndex._tangentPoints` implements, re-derived independently rather
/// than shared. Null when there is no real tangent (the point is inside the
/// circle, beyond a small tolerance for "numerically right on the rim").
(Vector2, Vector2)? _tangentPoints(
    double px, double py, double cx, double cy, double r) {
  final dx = px - cx, dy = py - cy;
  final d2 = dx * dx + dy * dy;
  final linearTol = Tolerance.standard.linear;
  final discriminant = d2 - r * r;
  if (discriminant < -(linearTol * linearTol)) return null;
  final clamped = discriminant < 0.0 ? 0.0 : discriminant;
  final d = math.sqrt(d2);
  if (d == 0.0) return null;
  final ux = dx / d, uy = dy / d;
  final a = r * r / d;
  final h = r * math.sqrt(clamped) / d;
  final fx = cx + a * ux, fy = cy + a * uy;
  final perpX = -uy, perpY = ux;
  return (
    Vector2(fx + h * perpX, fy + h * perpY),
    Vector2(fx - h * perpX, fy - h * perpY),
  );
}

/// Every pairwise crossing among root-level line/polyline entities within
/// [radius] of [world], among the [kIntersectionCandidateCap] entities with
/// the *greatest handle values* touching the query square -- the same
/// deterministic cap `SpatialIndex._considerIntersections` documents,
/// re-implemented here (sort by handle, then take the tail) rather than
/// trusted by agreement. Greatest, not lowest: ascending handle value is
/// draw order, and the cap keeps the most recently drawn entities, matching
/// every other later-drawn-wins rule in the snap engine.
void _considerIntersections(
  DraftDocument doc,
  Vector2 world,
  double radius,
  void Function(SnapKind kind, Vector2 point, Handle entity, Handle root)
      consider,
) {
  final queryBox = Aabb2(
    Vector2(world.x - radius, world.y - radius),
    Vector2(world.x + radius, world.y + radius),
  );

  final candidates = <(Handle handle, int slot, Transform2 toRoot)>[];
  for (final slot in doc.entities.liveSlots) {
    final kind = doc.entities.kindAt(slot);
    if (kind != EntityKind.line && kind != EntityKind.polyline) continue;
    final owner = doc.entities.ownerAt(slot);
    final composed = toRootSpace(doc, owner);
    if (composed == null) continue;

    final record = doc.entities.read(slot);
    final box = entityBounds(
      kind: kind,
      payload: doc.geometry.peek(record.geomIndex),
      measurer: doc.textMeasurer,
      textStyle: doc.textStyleOf(record.textStyle),
      textAttrs: record.textAttrs,
      text: record.text,
    ).transformedBy(composed);
    if (box.isEmpty || !box.intersects(queryBox)) continue;

    candidates.add((doc.entities.handleAt(slot), slot, composed));
  }
  candidates.sort((a, b) => a.$1.value.compareTo(b.$1.value));

  final n = candidates.length < kIntersectionCandidateCap
      ? candidates.length
      : kIntersectionCandidateCap;
  final first = candidates.length - n;
  final end = candidates.length;

  for (var i = first; i < end; i++) {
    final (handleA, slotA, toRootA) = candidates[i];
    final payloadA = doc.geometry.peek(doc.entities.geomIndexAt(slotA));
    final countA = payloadA.pointCount;
    if (countA < 2) continue;

    for (var j = i + 1; j < end; j++) {
      final (handleB, slotB, toRootB) = candidates[j];
      final payloadB = doc.geometry.peek(doc.entities.geomIndexAt(slotB));
      final countB = payloadB.pointCount;
      if (countB < 2) continue;

      final winner = handleA.value > handleB.value ? handleA : handleB;

      for (var sa = 0; sa + 1 < countA; sa++) {
        final a1 = toRootA.transformPoint(payloadA.pointAt(sa));
        final a2 = toRootA.transformPoint(payloadA.pointAt(sa + 1));
        for (var sb = 0; sb + 1 < countB; sb++) {
          final b1 = toRootB.transformPoint(payloadB.pointAt(sb));
          final b2 = toRootB.transformPoint(payloadB.pointAt(sb + 1));
          // segmentIntersectionTol, not distance.dart's segmentIntersection
          // -- see this file's own doc comment for why the two must not be
          // the same function.
          final hit =
              segmentIntersectionTol(a1, a2, b1, b2, Tolerance.standard);
          if (hit == null) continue;
          if (world.distanceTo(hit) > radius) continue;
          consider(SnapKind.intersection, hit, winner, winner);
        }
      }
    }
  }
}
