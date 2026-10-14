part of 'parametric_system.dart';

int _byValue(Handle a, Handle b) => a.value.compareTo(b.value);

/// Group-local to world for a parametric object. Mutant M-06g returns the
/// identity here.
Transform2 _worldOf(CommandTarget t, Handle h) =>
    t.tree.accumulatedTransform(h);

/// The registration that names [h]'s object in [t], or null: the engine's
/// one object rule (spec D5, as amended by fix/live-object-rule). Null
/// unless [h] is a `GroupNode` whose parent is the root; null when [frozen]
/// answers true for [h] (spec 2a E2: a frozen object is a plain group to the
/// system that froze it); otherwise the **last** registration, in [types]'
/// (catalog) order, whose component [h] carries, or null when it carries
/// none. A root-level group carrying two registered types is the later one's
/// object; the earlier component is a stray ([_Survey.stray]). [_isObject],
/// [_survey] and `ParametricCatalog.names` all read this; the catalog passes
/// no [frozen]. O(types).
_Registration<Component>? _naming(
    CommandTarget t, List<_Registration<Component>> types, Handle h,
    [bool Function(Handle)? frozen]) {
  final node = t.tree[h];
  if (node is! GroupNode || node.parent != t.tree.root) return null;
  if (frozen != null && frozen(h)) return null;
  for (var i = types.length - 1; i >= 0; i--) {
    if (types[i].has(t, h)) return types[i];
  }
  return null;
}

/// A root-level group carrying a registered parametric component (spec D5),
/// not frozen ([_naming]).
bool _isObject(CommandTarget t, List<_Registration<Component>> types, Handle h,
        [bool Function(Handle)? frozen]) =>
    _naming(t, types, h, frozen) != null;

/// Pairwise reach-overlap tests performed by the neighbour search (spec 07
/// D10), for tests that pin its cost. Never reset by the library.
@visibleForTesting
int debugOverlapTests = 0;

/// `ParametricType.references` calls made by the surveys (spec 08 D2,
/// Ruling 08-3), for tests that pin their cost: exactly one per live object
/// per survey. Never reset by the library.
@visibleForTesting
int debugReferenceCalls = 0;

/// Calls into a type's `ParametricType.placeBox` (spec 10 D16.6, Ruling
/// 10-6), for tests that pin the trigger's cost: counted in
/// `_Registration.placeBoxOf`, the only caller, so a view's memo hit is not
/// a call (T-4). Never reset by the library.
@visibleForTesting
int debugPlaceBoxCalls = 0;

/// Calls into a type's `ParametricType.readBox` (spec 10 D16.6), counted in
/// `_Registration.readBoxOf`, the only caller. Never reset by the library.
@visibleForTesting
int debugReadBoxCalls = 0;

/// Everything the planner reads about the parametric objects at one moment.
///
/// Neighbours are not surveyed (spec 07 D10): [neighboursOf] computes one
/// object's list on demand, against this survey's own [reach] snapshot, and
/// memoises it. An edit asks only for its seeds and its closure, O(k·n);
/// an edit with no seeds asks for none. A view's first
/// `ParametricView.placedIn`, which needs every contributor's place box and
/// so every contributor's neighbours, fills the memo for every object at
/// once with [sweepNeighbours] (spec 10 D16.5).
final class _Survey {
  _Survey(
      this.objects,
      this.params,
      this.toWorld,
      this.reach,
      this.children,
      this.owned,
      this.declared,
      this.references,
      this.referrers,
      this.page,
      this.readers,
      this.stray,
      this.instances,
      this.generated,
      this.leaves,
      this.nested);

  /// Live objects, ascending, with their registration.
  final Map<Handle, _Registration<Component>> objects;

  /// Each object's registered component at this moment (spec 10 D16.1): the
  /// snapshot every view built over this survey reads. A component is
  /// immutable, so the reference is the snapshot.
  final Map<Handle, Component> params;

  /// Each object's accumulated transform at this moment (spec 10 D16.1),
  /// the one its [reach] was computed with.
  final Map<Handle, Transform2> toWorld;

  /// Each object's reach at this moment, one call per object.
  final Map<Handle, Aabb2> reach;

  /// Each object's children, ascending: its entities only. Its generated
  /// instances are in [instances] (spec 2b S1).
  final Map<Handle, List<Handle>> children;

  /// Every child of a live object, and every ATTRIB of one of its generated
  /// instances (spec 2b S1), to its object: the set G of spec D4. So 06 D6's
  /// entity branch covers a generated ATTRIB, and an edit of one seeds its
  /// object.
  final Map<Handle, Handle> owned;

  /// Each object's `references` as declared, from this survey's one call
  /// per object (Ruling 08-3), dead and self handles included; absent when
  /// empty. Whoever needs the declared list reads it here and never calls
  /// `references` again. Unmodifiable.
  final Map<Handle, List<Handle>> declared;

  /// Each object's live referents (spec 08 D2): the live objects among its
  /// [declared] handles, itself excluded, deduplicated, ascending; absent
  /// when empty. Unmodifiable.
  final Map<Handle, List<Handle>> references;

  /// Each live referent's live referrers, ascending (spec 08 D2); absent
  /// when none. Unmodifiable: `ParametricView.referrers` hands them out.
  final Map<Handle, List<Handle>> referrers;

  /// The root's `PageComponent` at this moment (spec 10 D14), or null when
  /// none is attached or `PageComponent` is not registered. A component is
  /// immutable, so the reference is the snapshot; `_run` compares the two
  /// surveys' pages by value.
  final PageComponent? page;

  /// How many live objects of this survey read places (spec 10 D16.2,
  /// S-4), counted as the survey registers them: the trigger runs only when
  /// the after-survey holds one, an O(1) check.
  final int readers;

  /// Every registered component this survey found that [params] does not
  /// snapshot, keyed by holder and registration: a misplaced one (spec D5:
  /// its holder is not a root-level group) and, on a holder carrying two
  /// registered types, the one whose registration does not name the
  /// object. Empty in a document that has neither; filled by the walk the
  /// survey makes anyway, so it costs one insertion per such component.
  /// Read by [_written] through [_heldBefore], on the before-survey only.
  /// A frozen object's component (spec 2a E2) is one too.
  final Map<(Handle, _Registration<Component>), Component> stray;

  /// Spec 2b S1: each live object's generated instances, the
  /// `InstanceNode` children of its group, ascending by handle, each its
  /// node value at this moment (nodes are immutable: a reference, not a
  /// copy). Absent when it has none. A nested group's instances are not
  /// generated.
  final Map<Handle, List<InstanceNode>> instances;

  /// Each generated instance of [instances], by handle, to its node value;
  /// its object is the node's `parent`.
  final Map<Handle, InstanceNode> generated;

  /// Each generated instance's own entities (its ATTRIBs, and whatever a
  /// loaded file put on it), ascending; absent when none.
  final Map<Handle, List<Handle>> leaves;

  /// Each nested group of a live object (a `GroupNode` child of its group,
  /// which a file brought in), to the object. The guard leaves it what it
  /// is today (spec 2b S1): not generated, and not an add when edited.
  final Map<Handle, Handle> nested;

  final Map<Handle, List<Handle>> _neighbours = {};

  /// [h]'s neighbours, ascending (spec 06 D3): the objects whose reach
  /// overlaps [h]'s by more than `Tolerance.standard.linear` on both axes.
  /// Empty for a handle that is not an object of this survey. The list is
  /// unmodifiable: it is the memo itself.
  List<Handle> neighboursOf(Handle h) {
    final cached = _neighbours[h];
    if (cached != null) return cached;
    final a = reach[h];
    if (a == null) return const [];
    const tol = Tolerance.standard;
    final out = <Handle>[];
    for (final e in reach.entries) {
      if (e.key == h) continue;
      debugOverlapTests++;
      final b = e.value;
      if (a.minX < b.maxX - tol.linear &&
          b.minX < a.maxX - tol.linear &&
          a.minY < b.maxY - tol.linear &&
          b.minY < a.maxY - tol.linear) {
        out.add(e.key);
      }
    }
    // Unmodifiable: the memo is shared by every caller of this survey.
    return _neighbours[h] = List.unmodifiable(out);
  }

  bool _swept = false;

  /// Fills the neighbour memo for **every** object of this survey (spec 10
  /// D16.5), once: one sort-and-sweep over the [reach] boxes instead of one
  /// O(n) [neighboursOf] search per object, so O(n log n + pairs whose x
  /// ranges overlap) rather than O(n²). The pairs whose x ranges overlap can
  /// exceed the true neighbour pairs: long horizontal walls stacked one above
  /// another all overlap along x.
  ///
  /// The boxes are sorted by `minX`. A box `a` is tested against each later
  /// box `b` only while `b.minX < a.maxX - Tolerance.standard.linear`: that
  /// is the predicate's own bound on `b.minX`, and every box after the first
  /// that fails it starts no earlier, so fails it too. The window is one
  /// conjunct of the predicate, so each pair inside it is tested for the
  /// other three, the same strict comparisons as [neighboursOf]. Every
  /// evaluation of the window, the one that closes it included, is a pair
  /// test and counted once in [debugOverlapTests]. An empty reach (`Aabb2.empty()`, `minX`
  /// infinite) sorts last and has no neighbours, as in [neighboursOf].
  ///
  /// The lists are the ones [neighboursOf] gives: ascending and
  /// unmodifiable. An object whose list is memoised already keeps it.
  void sweepNeighbours() {
    if (_swept) return;
    _swept = true;
    const tol = Tolerance.standard;
    final boxes = reach.entries.toList()
      ..sort((p, q) => p.value.minX.compareTo(q.value.minX));
    final found = <Handle, List<Handle>>{};
    for (var i = 0; i < boxes.length; i++) {
      final MapEntry(key: ha, value: a) = boxes[i];
      final bound = a.maxX - tol.linear;
      for (var j = i + 1; j < boxes.length; j++) {
        final MapEntry(key: hb, value: b) = boxes[j];
        // Counted before the window check: the check is the predicate's
        // first conjunct, so every evaluation of it is a pair test.
        debugOverlapTests++;
        if (!(b.minX < bound)) break;
        if (a.minX < b.maxX - tol.linear &&
            a.minY < b.maxY - tol.linear &&
            b.minY < a.maxY - tol.linear) {
          (found[ha] ??= []).add(hb);
          (found[hb] ??= []).add(ha);
        }
      }
    }
    for (final h in reach.keys) {
      _neighbours[h] ??= List.unmodifiable(
          (found[h] ?? const <Handle>[]).toList()..sort(_byValue));
    }
  }
}

/// A survey of [t]'s live objects. An object [frozen] answers true for
/// (spec 2a E2) is named by no registration here, so its component is a
/// [_Survey.stray], none of its hooks is called, and no view built over the
/// survey holds it.
_Survey _survey(CommandTarget t, List<_Registration<Component>> types,
    [bool Function(Handle)? frozen]) {
  final found = <Handle, _Registration<Component>>{};
  final stray = <(Handle, _Registration<Component>), Component>{};
  for (final r in types) {
    for (final h in r.handles(t)) {
      // [_naming] decides: the later registration names the object; any
      // other component, a shadowed one included, is kept here, so every
      // registered component has a snapshot.
      if (identical(_naming(t, types, h, frozen), r)) {
        found[h] = r;
      } else {
        stray[(h, r)] = r.componentOf(t, h);
      }
    }
  }
  final order = found.keys.toList()..sort(_byValue);
  final objects = {for (final h in order) h: found[h]!};
  var readers = 0;
  for (final r in objects.values) {
    if (r.type.readsPlaces) readers++;
  }
  // Spec 10 D16.1: the snapshots are the component and the transform
  // `reach` already reads, one read each, and no new client call.
  final params = {for (final h in order) h: objects[h]!.componentOf(t, h)};
  final toWorld = {for (final h in order) h: _worldOf(t, h)};
  // Ascending, like [objects]: `neighboursOf` walks it in handle order.
  final reach = {
    for (final h in order) h: objects[h]!.reachOf(params[h]!, toWorld[h]!),
  };
  // Spec 2b S1: each object's generated instances, from its group's own
  // list, ascending by handle whatever order the list is in.
  final instances = <Handle, List<InstanceNode>>{};
  final generated = <Handle, InstanceNode>{};
  final nested = <Handle, Handle>{};
  for (final h in order) {
    for (final c in (t.tree[h]! as GroupNode).children) {
      final node = t.tree[c];
      if (node == null || node.parent != h) continue;
      if (node is InstanceNode) {
        if (generated.containsKey(c)) continue;
        (instances[h] ??= []).add(node);
        generated[c] = node;
      } else {
        nested[c] = h;
      }
    }
  }
  for (final list in instances.values) {
    list.sort((a, b) => _byValue(a.handle, b.handle));
  }
  final children = <Handle, List<Handle>>{};
  final owned = <Handle, Handle>{};
  final leaves = <Handle, List<Handle>>{};
  for (final slot in t.entities.liveSlots) {
    final owner = t.entities.ownerAt(slot);
    if (objects.containsKey(owner)) {
      final h = t.entities.handleAt(slot);
      (children[owner] ??= []).add(h);
      owned[h] = owner;
      continue;
    }
    final node = generated[owner];
    if (node == null) continue;
    final h = t.entities.handleAt(slot);
    (leaves[owner] ??= []).add(h);
    if (t.entities.kindAt(slot) == EntityKind.attrib) owned[h] = node.parent;
  }
  for (final list in children.values) {
    list.sort(_byValue);
  }
  for (final list in leaves.values) {
    list.sort(_byValue);
  }
  // Spec 08 D2: one pass, one `references` call per object. The pass walks
  // [order], so each referrer list is appended to in ascending order.
  final declared = <Handle, List<Handle>>{};
  final references = <Handle, List<Handle>>{};
  final referrers = <Handle, List<Handle>>{};
  for (final h in order) {
    final declaredBy = objects[h]!.referencesOf(t, h);
    if (declaredBy.isEmpty) continue;
    final named = List<Handle>.unmodifiable(declaredBy);
    declared[h] = named;
    final live = {
      for (final x in named)
        if (x != h && objects.containsKey(x)) x,
    }.toList()
      ..sort(_byValue);
    if (live.isEmpty) continue;
    references[h] = List.unmodifiable(live);
    for (final x in live) {
      (referrers[x] ??= []).add(h);
    }
  }
  return _Survey(
      objects,
      params,
      toWorld,
      reach,
      children,
      owned,
      declared,
      references,
      {
        for (final e in referrers.entries) e.key: List.unmodifiable(e.value),
      },
      t.components.get<PageComponent>(t.tree.root),
      readers,
      stray,
      instances,
      generated,
      leaves,
      nested);
}

/// The objects a page change seeds (spec 10 D14): every live object in
/// [after] of each registered type whose [ParametricType.pageKey] of the
/// two pages differs. `_run` calls it only when the page differs between
/// [before] and [after] (value equality, a stored value), so an edit that
/// leaves the page alone pays one `==` and never calls a `pageKey`.
Iterable<Handle> _pageSeeds(CommandTarget t,
    List<_Registration<Component>> types, _Survey before, _Survey after) sync* {
  for (final r in types) {
    if (r.type.pageKey(before.page) == r.type.pageKey(after.page)) continue;
    for (final h in r.handles(t)) {
      if (after.objects.containsKey(h)) yield h;
    }
  }
}

/// The world box of the defining points of [r]'s stored children in [s]
/// (spec 10 D16.2, S-14): every `(x, y)` pair of each child payload's
/// `coords` (a fill's payload has none), mapped by [r]'s snapshot transform.
/// Empty when [r] has no child with a point.
Aabb2 _storedBox(CommandTarget t, _Survey s, Handle r) {
  final m = s.toWorld[r]!;
  var box = Aabb2.empty();
  for (final c in s.children[r] ?? const <Handle>[]) {
    final coords =
        t.geometry.peek(t.entities.geomIndexAt(t.entities.slotOf(c)!)).coords;
    for (var i = 0; i + 1 < coords.length; i += 2) {
      box = box
          .expandedToPoint(m.transformPoint(Vector2(coords[i], coords[i + 1])));
    }
  }
  return box;
}

/// The live readers an edit regenerates by place (spec 10 D16.2): every
/// live reader in [after], not itself a seed, whose
/// [ParametricType.readBox] touches (closed) a box of `L`.
///
/// Nothing at all when [seeds] is empty or [after] holds no live reader
/// (S-4: [_Survey.readers], O(1)); no view is built and no type is asked.
///
/// `K` is the spatial part of the core, the seeds and their neighbours
/// before and after. For each contributor of `K`, in ascending order, its
/// before place is its place box in the **before-view** if it was live
/// before (the snapshot: where it was, although the edit has applied), and
/// its after place its box in [afterView] if it is live after. It is
/// **changed** when exactly one of the two exists, or both exist and its
/// [ParametricType.placeInput] of the two views differs (exact `==`, S-4,
/// T-2). Only a changed contributor adds its boxes, both, to `L`: an
/// unchanged neighbour of a seed contributes what it contributed before,
/// so it can change no reader. `placeInput` is asked only when both boxes
/// exist, once per view. The before-view is built here, the only place
/// that reads it; [afterView] is the one [_plan] receives (Ruling 10-5).
///
/// A reader's `stored` box is [_storedBox] over the after-survey. When `L`
/// is empty no read box is asked.
List<Handle> _triggered(CommandTarget t, Set<Handle> seeds, _Survey before,
    _Survey after, ParametricView afterView) {
  if (seeds.isEmpty || after.readers == 0) return const [];
  final k = {
    ...seeds,
    for (final s in seeds) ...before.neighboursOf(s),
    for (final s in seeds) ...after.neighboursOf(s),
  }.toList()
    ..sort(_byValue);
  final beforeView = ParametricView._(t, before);
  final boxes = <Aabb2>[];
  for (final h in k) {
    final was = beforeView.placeBoxOf(h);
    final now = afterView.placeBoxOf(h);
    if (was == null && now == null) continue;
    if (was != null &&
        now != null &&
        before.objects[h]!.type.placeInput(beforeView, h) ==
            after.objects[h]!.type.placeInput(afterView, h)) {
      continue;
    }
    if (was != null) boxes.add(was);
    if (now != null) boxes.add(now);
  }
  if (boxes.isEmpty) return const [];
  final out = <Handle>[];
  for (final MapEntry(key: h, value: r) in after.objects.entries) {
    if (!r.type.readsPlaces || seeds.contains(h)) continue;
    final read = r.readBoxOf(
        after.params[h]!, after.toWorld[h]!, _storedBox(t, after, h));
    for (final b in boxes) {
      if (read.intersects(b)) {
        out.add(h);
        break;
      }
    }
  }
  return out;
}

/// The objects an edit regenerates, as a sorted list of live objects (spec
/// 06 D4 step 6, as amended by spec 08 D3 and spec 10 D16.2):
///
/// ```
/// core    = seeds ∪ neighbours before and after (seeds)
///                 ∪ references before and after (seeds)
///                 ∪ triggered
/// closure = core ∪ referrers before and after (core)
/// ```
///
/// [triggered] is [_triggered]'s: the live readers whose read box touches a
/// place box of a changed contributor of the spatial core, joined to the
/// core before the referrer step, so a reader's referrers follow it.
///
/// Neighbours are asked for the seeds only (spec 07 D10); references and
/// referrers are map lookups. The referent direction brings in what a
/// seed's geometry depends on (a door's wall draws the door's gap); the
/// referrer direction brings in what depends on a seed (a moved wall's
/// doors, whose empty reach no spatial relation finds).
///
/// Referrers are taken of the whole **core**, not of the seeds only,
/// because a referrer reads more than its referent's parameters: it reads
/// the referent's joints, which read the referent's spatial neighbours. A
/// neighbour B of a door's wall A changes A's straight span, so where the
/// door is drawn, though the door is neither B's referrer nor B's referent:
/// it is two hops from B (seed B → neighbour A → referrer). One extra hop
/// closes it for a type that reads no further than its referents'
/// neighbours (spec 08 D3).
List<Handle> _closure(
    Set<Handle> seeds, _Survey before, _Survey after, List<Handle> triggered) {
  final core = {
    ...seeds,
    for (final s in seeds) ...before.neighboursOf(s),
    for (final s in seeds) ...after.neighboursOf(s),
    for (final s in seeds) ...?before.references[s],
    for (final s in seeds) ...?after.references[s],
    ...triggered,
  };
  return {
    ...core,
    for (final x in core) ...?before.referrers[x],
    for (final x in core) ...?after.referrers[x],
  }.where(after.objects.containsKey).toList()
    ..sort(_byValue);
}

/// The record of a child the plan adds (spec 10 D13): the one builder for
/// every add in [_plan], a region's fill and boundary and a plain or TEXT
/// child alike. [g]'s flags, linetype, lineweight, `textAttrs` and string
/// are written here and nowhere else (06 D11, 10 D12, D13), and its colour
/// and transparency here and, on a match, by [_stampStyle] (plan colours
/// spec PC-3a); `draftRecord`'s defaults stand for everything a
/// [Generated] does not set. [boundary] marks a region's boundary record, which takes
/// [Generated.boundaryFlags] instead of the fill's [Generated.flags].
/// [layer] is the object's (`objectLayer`, spec 12b D2): every added
/// record, a region's fill and boundary both, is on it.
EntityRecord _recordOf(
        Handle handle, Handle owner, EntityKind kind, Generated g, Handle layer,
        {bool boundary = false}) =>
    draftRecord(handle, owner, kind, color: g.color, text: g.text, layer: layer)
        .copyWith(
            transparency: g.transparency,
            flags: boundary ? g.boundaryFlags : g.flags,
            linetype: g.linetype,
            lineweight: g.lineweight,
            textAttrs: g.textAttrs);

bool _samePayload(GeometryPayload a, GeometryPayload b) {
  if (a.coords.length != b.coords.length ||
      a.scalars.length != b.scalars.length) {
    return false;
  }
  for (var i = 0; i < a.coords.length; i++) {
    if (a.coords[i] != b.coords[i]) return false;
  }
  for (var i = 0; i < a.scalars.length; i++) {
    if (a.scalars[i] != b.scalars[i]) return false;
  }
  return true;
}

/// Spec 12b D2's stamp on one **matched** child [c]: a
/// `SetEntityLayerCommand.restore` onto [layer] when [c]'s stored layer
/// differs (exact `==`, a stored value), nothing otherwise. The guard is
/// load-bearing (R-15): without it every regeneration plans a command and
/// every `ParametricEdit` reports `geometry`.
void _stampLayer(
    CommandTarget t, List<DraftCommand> out, Handle c, Handle layer) {
  if (t.entities.layerAt(t.entities.slotOf(c)!) != layer) {
    out.add(SetEntityLayerCommand.restore(c, layer));
  }
}

/// Plan colours spec PC-3a: the stamp on one **matched** child [c] of its
/// generated colour and transparency, [g]'s: one
/// `SetEntityStyleCommand.restore` when the stored colour or transparency
/// differs (exact `==` on the stored encodings), nothing otherwise. The
/// guard is load-bearing, as [_stampLayer]'s (12b R-15): an object whose
/// style did not change plans no command.
void _stampStyle(
    CommandTarget t, List<DraftCommand> out, Handle c, Generated g) {
  final slot = t.entities.slotOf(c)!;
  if (t.entities.colorAt(slot) != encodeColor(g.color) ||
      t.entities.transparencyAt(slot) != g.transparency) {
    out.add(SetEntityStyleCommand.restore(c, g.color, g.transparency));
  }
}

/// The boundary a fill child names: its payload's one scalar (spec 07 D8).
Handle _boundaryOf(CommandTarget t, Handle fill) => Handle.checked(t.geometry
    .peek(t.entities.geomIndexAt(t.entities.slotOf(fill)!))
    .scalars[0]
    .toInt());

/// The boundary [fill] names, which must be a live child of [owner], the
/// object [fill] belongs to: a loaded file can name any handle (spec 07
/// D8). Anything else throws `StateError` from the plan, before anything
/// applies, so `_run` rolls the edit back. Every use of a fill's boundary
/// in the plan -- matched or surplus -- goes through here.
Handle _ownBoundaryOf(CommandTarget t, Handle owner, Handle fill) {
  final boundary = _boundaryOf(t, fill);
  final slot = t.entities.slotOf(boundary);
  if (slot == null || t.entities.ownerAt(slot) != owner) {
    throw StateError('fill ${fill.toHex()} of ${owner.toHex()} names '
        '${boundary.toHex()}, which is not a child of the same object');
  }
  return boundary;
}

/// A generated region whose boundary is not a closed polyline with a
/// non-empty triangulation is a client bug (spec 07 D8): `AddRegionCommand`
/// would refuse the open one and fill nothing for the other. Thrown from
/// the plan, before anything applies, so `_run` rolls the edit back.
void _checkRegion(Handle h, GeometryPayload boundary) {
  final triangles = triangulationFor(EntityKind.polyline, boundary);
  if (triangles == null || triangles.isEmpty) {
    throw ArgumentError('${h.toHex()} generated a region whose boundary is '
        'not a closed polyline with a non-empty triangulation (spec 07 D8)');
  }
}

/// Plans, and does not apply, the commands that bring [closure] up to date
/// (spec D4 step 7). New children get **reserved** handles above the seed,
/// which is not advanced: `AddEntityCommand.apply` raises it when the add
/// lands.
///
/// Regions (spec 07 D8) are planned before plain children, in generation
/// order, so a new object's handles run fill < boundary < later children.
/// A fill child and the boundary it names are one region, matched through
/// the fill; the boundary is never matched as a plain POLYLINE.
///
/// A matched child's payload is rewritten when it differs; a matched
/// TEXT's string too (spec 10 D12); then its layer, when it differs from
/// the object's ([_stampLayer], spec 12b D2) and its colour and
/// transparency when they differ from the generated ones ([_stampStyle],
/// plan colours spec PC-3a), a matched region's fill and boundary each.
/// Every added record comes from [_recordOf], on the
/// object's layer.
///
/// Then its generated instances (spec 2b S1, [_planInstances]): matched by
/// position, ascending by handle, their ATTRIBs by tag, every command
/// planned only on an exact-`==` difference of the stored value.
///
/// Each object is first asked whether it dissolves (spec 10 D15), with the
/// same [view], before its `generate`. A dissolving object is not
/// generated: its plan is [_subtreeRemoval] (the select tool's order),
/// whose last removal is the object's own node, and that removal takes the
/// object's component and its `ObjectLayer` with it (node-components spec
/// D-4), so nothing else is planned. The removals are planned commands,
/// never in the edit's `touched`, so 06 D6's guard does not see them.
List<DraftCommand> _plan(
    CommandTarget t, List<Handle> closure, _Survey s, ParametricView view) {
  var reserved = t.handleSeed.current.value;
  final out = <DraftCommand>[];
  for (final h in closure) {
    final registration = s.objects[h]!;
    if (registration.dissolves(view, h)) {
      out.addAll(_subtreeRemoval(t, s, h));
      continue;
    }
    final layer = objectLayer(t, h);
    final generated = registration.generate(view, h);
    final children = s.children[h] ?? const <Handle>[];
    final boundaries = <Handle>{
      for (final c in children)
        if (t.entities.kindAt(t.entities.slotOf(c)!) == EntityKind.fill)
          _boundaryOf(t, c),
    };
    final byKind = <EntityKind, List<Handle>>{};
    for (final c in children) {
      if (boundaries.contains(c)) continue;
      (byKind[t.entities.kindAt(t.entities.slotOf(c)!)] ??= []).add(c);
    }
    final used = <EntityKind, int>{};
    for (final g in generated) {
      if (!g.filled) continue;
      _checkRegion(h, g.payload);
      final i = used[EntityKind.fill] ?? 0;
      used[EntityKind.fill] = i + 1;
      final fills = byKind[EntityKind.fill];
      if (fills != null && i < fills.length) {
        final boundary = _ownBoundaryOf(t, h, fills[i]);
        final slot = t.entities.slotOf(boundary)!;
        // The fill record is never rewritten: rewriting the boundary
        // re-triangulates the fill (`SetEntityGeometryCommand`).
        if (!_samePayload(
            t.geometry.peek(t.entities.geomIndexAt(slot)), g.payload)) {
          out.add(SetEntityGeometryCommand(boundary, g.payload));
        }
        _stampLayer(t, out, fills[i], layer);
        _stampLayer(t, out, boundary, layer);
        _stampStyle(t, out, fills[i], g);
        _stampStyle(t, out, boundary, g);
      } else {
        // Fill first: `AddRegionCommand` requires the lower handle on it.
        out.add(AddRegionCommand(
            fill: _recordOf(
                Handle.checked(++reserved), h, EntityKind.fill, g, layer),
            boundary: _recordOf(
                Handle.checked(++reserved), h, EntityKind.polyline, g, layer,
                boundary: true),
            boundaryPayload: g.payload));
      }
    }
    for (final g in generated) {
      if (g.filled) continue;
      final i = used[g.kind] ?? 0;
      used[g.kind] = i + 1;
      final existing = byKind[g.kind];
      if (existing != null && i < existing.length) {
        final slot = t.entities.slotOf(existing[i])!;
        if (!_samePayload(
            t.geometry.peek(t.entities.geomIndexAt(slot)), g.payload)) {
          out.add(SetEntityGeometryCommand(existing[i], g.payload));
        }
        // Spec 10 D12: a matched TEXT's string is a stored value, compared
        // by exact `==` after the payload and rewritten in place when it
        // differs. Nothing else of the record is read or rewritten: every
        // other attribute but the colour and the transparency (PC-3a) is
        // fixed at creation (06 D11, 10 D13); the layer is stamped below.
        if (g.kind == EntityKind.text && t.entities.textAt(slot) != g.text) {
          out.add(SetEntityTextCommand(existing[i], g.text, ''));
        }
        _stampLayer(t, out, existing[i], layer);
        _stampStyle(t, out, existing[i], g);
      } else {
        out.add(AddEntityCommand(
            record: _recordOf(Handle.checked(++reserved), h, g.kind, g, layer),
            payload: g.payload));
      }
    }
    // A surplus region is removed through its boundary, whose removal takes
    // the fill with it; removing the fill alone would orphan the boundary.
    // The boundary is checked as a matched one is: a malformed load whose
    // surplus fill names another object's boundary must not remove it.
    final surplus = [
      for (final e in byKind.entries)
        for (final c in e.value.skip(used[e.key] ?? 0))
          e.key == EntityKind.fill ? _ownBoundaryOf(t, h, c) : c,
    ]..sort(_byValue);
    for (final c in surplus) {
      out.add(RemoveEntityCommand(c));
    }
    // Spec 2b S1 "Matching": the object's generated instances, after its
    // entities, from the same view.
    reserved = _planInstances(
        t, s, h, registration.instancesOf(view, h), layer, reserved, out);
  }
  return out;
}

/// Stored transforms compare exactly (12b R-15): `Transform2` has no `==`,
/// and `InstanceNode.==` compares with this tolerance.
const Tolerance _exact = Tolerance(linear: 0, angular: 0);

/// The record of an ATTRIB the plan adds onto [instance] (spec 2b S1): the
/// shape of today's table label, on layer 0 with BYBLOCK style, so it
/// follows its instance; the layer and style stamps never touch it.
EntityRecord _attribRecord(Handle handle, Handle instance, GeneratedAttrib a) =>
    EntityRecord(
      handle: handle,
      owner: instance,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
      text: a.text,
      tag: a.tag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: a.textAttrs,
    );

/// Spec 2b S1 "Matching": plans [object]'s generated instances against
/// [outputs] into [out], and returns the last handle reserved.
///
/// First, every output must name a live definition, or this throws
/// [GeneratedDefinitionError] (nothing has applied yet). Then the i-th
/// output meets the i-th existing instance, ascending by handle: a new
/// definition is a `SetInstanceDefinitionCommand`, a new transform a
/// `TransformNodeCommand` (exact, [_exact]), a node off [layer] (the
/// object's) a `SetInstanceLayerCommand.restore`; then its ATTRIBs
/// ([_planAttributes]). An unmatched output is added under reserved
/// handles, the node then its ATTRIBs, the node with `InstanceNode`'s
/// default style. A surplus instance is removed ([_instanceRemoval]).
int _planInstances(
    CommandTarget t,
    _Survey s,
    Handle object,
    List<GeneratedInstance> outputs,
    Handle layer,
    int reserved,
    List<DraftCommand> out) {
  for (final g in outputs) {
    if (t.tree.definition(g.definition) == null) {
      throw GeneratedDefinitionError(object, g.definition);
    }
  }
  final existing = s.instances[object] ?? const <InstanceNode>[];
  for (var i = 0; i < outputs.length; i++) {
    final g = outputs[i];
    if (i < existing.length) {
      final node = existing[i];
      final c = node.handle;
      if (node.definition != g.definition) {
        out.add(SetInstanceDefinitionCommand(c, g.definition));
      }
      if (!node.transform.equals(g.transform, _exact)) {
        out.add(TransformNodeCommand(c, g.transform));
      }
      if (node.layer != layer) {
        out.add(SetInstanceLayerCommand.restore(c, layer));
      }
      reserved = _planAttributes(t, s, c, g.attributes, reserved, out);
    } else {
      final c = Handle.checked(++reserved);
      out.add(AddNodeCommand(InstanceNode(
          handle: c,
          parent: object,
          transform: g.transform,
          definition: g.definition,
          layer: layer)));
      for (final a in g.attributes) {
        out.add(AddEntityCommand(
            record: _attribRecord(Handle.checked(++reserved), c, a),
            payload: a.payload));
      }
    }
  }
  for (final node in existing.skip(outputs.length)) {
    out.addAll(_instanceRemoval(t, s, node.handle));
  }
  return reserved;
}

/// A matched instance's ATTRIBs against [attributes] (spec 2b S1): bucketed
/// by tag, ascending, so the lowest handle of a tag is matched and the
/// rest are surplus (a loaded file). A matched one gets
/// `SetEntityGeometryCommand` for a new payload and `SetEntityTextCommand`
/// for a new text, **passing its own tag** (the TEXT call's `''` would
/// blank it, and the next regeneration would match nothing). An unmatched
/// tag is added; a surplus one, or one of a tag no output names, is
/// removed. Returns the last handle reserved.
int _planAttributes(CommandTarget t, _Survey s, Handle instance,
    List<GeneratedAttrib> attributes, int reserved, List<DraftCommand> out) {
  final byTag = <String, Handle>{};
  final surplus = <Handle>[];
  for (final c in s.leaves[instance] ?? const <Handle>[]) {
    final slot = t.entities.slotOf(c)!;
    if (t.entities.kindAt(slot) != EntityKind.attrib) continue;
    final tag = t.entities.tagAt(slot);
    if (byTag.containsKey(tag)) {
      surplus.add(c);
    } else {
      byTag[tag] = c;
    }
  }
  for (final a in attributes) {
    final c = byTag.remove(a.tag);
    if (c == null) {
      out.add(AddEntityCommand(
          record: _attribRecord(Handle.checked(++reserved), instance, a),
          payload: a.payload));
      continue;
    }
    final slot = t.entities.slotOf(c)!;
    if (!_samePayload(
        t.geometry.peek(t.entities.geomIndexAt(slot)), a.payload)) {
      out.add(SetEntityGeometryCommand(c, a.payload));
    }
    if (t.entities.textAt(slot) != a.text) {
      out.add(SetEntityTextCommand(c, a.text, t.entities.tagAt(slot)));
    }
  }
  for (final c in [...surplus, ...byTag.values]..sort(_byValue)) {
    out.add(RemoveEntityCommand(c));
  }
  return reserved;
}

/// A surplus generated instance's removal: every entity it owns, fills
/// first (a boundary's removal would take its fill), then its node.
List<DraftCommand> _instanceRemoval(
    CommandTarget t, _Survey s, Handle instance) {
  final leaves = s.leaves[instance] ?? const <Handle>[];
  bool isFill(Handle c) =>
      t.entities.kindAt(t.entities.slotOf(c)!) == EntityKind.fill;
  return [
    for (final c in leaves)
      if (isFill(c)) RemoveEntityCommand(c),
    for (final c in leaves)
      if (!isFill(c)) RemoveEntityCommand(c),
    RemoveNodeCommand(instance),
  ];
}

/// The first touched handle, ascending, that the guard refuses (spec 06 D6,
/// as amended by 2b S1), or null. Two disjoint branches by what the handle
/// was in [before], then the adds:
///
/// - **An owned entity** (`before.owned`: a child of a live object, or an
///   ATTRIB of one of its generated instances): refused if it **still
///   exists** -- a direct edit, regardless of what else the same command did
///   to its owner -- or, when it was removed, if its object's group node
///   still exists (spec D6's amendment for F4: whatever its component now
///   is; a compound that detaches the component and then removes a
///   still-live child must still be refused). Only a child removed
///   *together with* its object's group is allowed.
/// - **A generated instance** (`before.generated`): refused when, after the
///   edit, it is gone while its object's group lives, or its node differs
///   from the survey's value by `InstanceNode.==` (exact, every field): a
///   move, a definition, a layer or a style change. A components-only
///   write leaves the node as it was and passes (2b S1: per-unit data); it
///   seeds nothing (`_run`).
/// - **An add**: an entity the survey did not hold, owned by a live object
///   or by a generated instance of one; a node, a `GroupNode` included,
///   whose parent is a live object, unless the survey held it there (a
///   nested group a file brought in stays what it is).
///
/// A frozen object (spec 2a E2) is a plain group: a child added into it, or
/// one of its children or instances edited, is not refused.
Handle? _refused(CommandTarget t, List<_Registration<Component>> types,
    _Survey before, Set<Handle> touched, bool Function(Handle)? frozen) {
  for (final h in touched.toList()..sort(_byValue)) {
    final owner = before.owned[h];
    if (owner != null) {
      if (t.entities.slotOf(h) != null) return h;
      if (t.tree[owner] != null) return h;
      continue;
    }
    final seat = before.generated[h];
    if (seat != null) {
      final now = t.tree[h];
      if (now == null ? t.tree[seat.parent] != null : now != seat) return h;
      continue;
    }
    final slot = t.entities.slotOf(h);
    if (slot != null) {
      final holder = t.entities.ownerAt(slot);
      if (_isObject(t, types, holder, frozen)) return h;
      final held = before.generated[holder];
      if (held != null &&
          t.tree[held.parent] != null &&
          !(before.leaves[holder]?.contains(h) ?? false)) {
        return h;
      }
      continue;
    }
    final node = t.tree[h];
    if (node != null &&
        before.nested[h] != node.parent &&
        _isObject(t, types, node.parent, frozen)) {
      return h;
    }
  }
  return null;
}

/// [r]'s component on [h] in [s], or null when [h] carried none: from the
/// object snapshot when [r] names [h]'s object, else from [_Survey.stray].
Component? _heldBefore(_Survey s, _Registration<Component> r, Handle h) =>
    identical(s.objects[h], r) ? s.params[h] : s.stray[(h, r)];

/// The first touched handle, ascending, on which the edit **wrote** a
/// registered parametric component although the handle is not a live
/// root-level group after the edit (spec D5, as amended by fix/post-11,
/// post-11 found item (d)), with the registration it wrote; null when
/// there is none. `_run` then undoes `inner` and throws
/// [NonLiveWriteError].
///
/// "Wrote" means: the component is non-null now and not `==` to what the
/// before-survey held for the same type on the same handle ([_heldBefore];
/// a stored value, compared exactly). So these are never refused, because
/// the edit left the component as it was or removed it:
///
/// - a detach (`SetComponentCommand<T>(h, null)`) on any handle, dead or
///   nested: a file's misplaced component must stay removable;
/// - a delete: the removal takes the object's component with its node
///   (node-components spec D-4); undo and redo replay a
///   `ParametricReplay` and never come here, so the restore that rides in
///   the node's snapshot is untouched (a guard in `SetComponentCommand`
///   would break exactly that);
/// - a re-parent under another group (spec 08 D4, `CS7`): the object stops
///   being one and keeps its component, as specified;
/// - any edit that touches a holder of a component a file brought in
///   misplaced (a move of its line, removing its nested group) without
///   writing a new value.
///
/// Only [touched] (`inner`'s own) is read, so a file carrying a misplaced
/// component elsewhere never refuses an unrelated edit, and the cost is
/// O(|touched| log |touched| + |touched| · types), nothing per object.
/// Only registered types are read: any other component lands as before.
///
/// A frozen object (spec 2a E2) is not a live group here, so a new value of
/// its type written on it is refused; an unchanged one (the group moved)
/// equals its stray snapshot and is not.
(Handle, _Registration<Component>)? _written(
    CommandTarget t,
    List<_Registration<Component>> types,
    _Survey before,
    Set<Handle> touched,
    bool Function(Handle)? frozen) {
  for (final h in touched.toList()..sort(_byValue)) {
    if (_isObject(t, types, h, frozen)) continue;
    for (final r in types) {
      final now = r.componentOrNull(t, h);
      if (now == null) continue;
      if (now == _heldBefore(before, r, h)) continue;
      return (h, r);
    }
  }
  return null;
}

/// Undoes [r] after a failure; if that fails too, the target is in an
/// unknown state and the caller must know it. That failure is a
/// [PartialMutationError] (spec 2a E3).
void _undoInner(CommandTarget t, String label, CommandResult r, Object cause) {
  try {
    r.inverse.apply(t);
  } catch (rollbackError) {
    throw PartialMutationError(
        '"$label": $cause, and undoing the edit then threw '
        '($rollbackError); the target is partially mutated and nothing was '
        'recorded in history');
  }
}

/// Spec 08 D4 step 4: deletes, in the edit, every `cascade`-policy referrer
/// of an object that stopped being a live object, and returns [r0] extended
/// by the removals. [r0] itself is returned when nothing is doomed.
///
/// Rounds (Ruling 08-4): the doomed objects are the still-live `cascade`
/// referrers, before the edit, of each `before.referrers` key that is no
/// longer an object (06's `_isObject` on the current tree, so a removed
/// node, a detached component and a group that is no longer root-level
/// alike), in ascending order. Each loses its subtree as the select tool
/// deletes a group ([_subtreeRemoval]). A doomed object is then no longer
/// an object itself, so the next round picks up its own `cascade`
/// referrers. Each round costs O(referents).
///
/// Everything, deciding each command as well as applying it, every round,
/// runs under one rollback: a failure undoes what the cascade applied, then
/// [r0], and rethrows, so the target is as it was before the edit; a failed
/// rollback throws 06's "partially mutated" error, a [PartialMutationError]
/// since spec 2a E3, and undoes nothing more. The commands are applied one
/// at a time, like `_run`'s regeneration loop and for the same reason (06
/// debt): a child's refusal and a failed rollback stay apart.
///
/// It reads no frozen predicate: every handle it asks about is a key or a
/// value of the before-survey's referrers, which holds no frozen object.
CommandResult _cascade(CommandTarget t, List<_Registration<Component>> types,
    _Survey before, CommandResult r0, String label) {
  if (before.referrers.isEmpty) return r0;
  final inverses = <DraftCommand>[];
  final touched = <Handle>{...r0.touched};
  try {
    while (true) {
      final doomed = <Handle>{
        for (final e in before.referrers.entries)
          if (!_isObject(t, types, e.key))
            for (final d in e.value)
              if (before.objects[d]!.type.referencePolicy ==
                      ReferencePolicy.cascade &&
                  _isObject(t, types, d))
                d,
      }.toList()
        ..sort(_byValue);
      if (doomed.isEmpty) break;
      for (final d in doomed) {
        for (final c in _subtreeRemoval(t, before, d)) {
          final applied = c.apply(t);
          inverses.add(applied.inverse);
          touched.addAll(applied.touched);
        }
      }
    }
  } catch (error) {
    try {
      for (final i in inverses.reversed) {
        i.apply(t);
      }
    } catch (rollbackError) {
      throw PartialMutationError(
          '"$label": the reference cascade threw ($error) and '
          'its rollback threw ($rollbackError); the target is partially '
          'mutated and nothing was recorded in history');
    }
    _undoInner(t, label, r0, error);
    rethrow;
  }
  if (inverses.isEmpty) return r0;
  return CommandResult(
    inverse: CompoundCommand([...inverses.reversed, r0.inverse],
        label: r0.inverse.label),
    touched: touched,
  );
}

/// The commands that remove the doomed object [d]'s subtree, as the select
/// tool's `_groupCascade` does: a group's leaves, then its child instances
/// and nested groups (recursively) in its listed order, then the group.
///
/// **Every fill of the whole subtree goes first** (the doomed group's and
/// each nested group's, in that listed order), before any other leaf, so a
/// region's fill is removed before its boundary wherever each of the two
/// lives: `RemoveEntityCommand` on a fill is always available and undoes
/// exactly, whereas removing a boundary takes its fill with it only when
/// the pair could be rebuilt, and refuses a loaded, unfillable one (an open
/// boundary, or a fill in a nested group naming a boundary in [d], say),
/// which would refuse the whole edit.
///
/// [d]'s own leaves are the survey's (an edit cannot add into a live
/// object, 06 D6 as amended by 2b S1), and so are its generated instances'
/// entities (2b S1). A nested group's leaves, and the entities of an
/// instance the survey does not know (a nested group's), are found by one
/// scan of the live slots, paid only when there is one. Every instance
/// removed takes its entities first, so no ATTRIB is left behind (2b S1,
/// "The dissolve gap closes").
///
/// Two callers: [_cascade], with the before-survey, for a doomed referrer;
/// [_plan], with the after-survey, for a dissolving object (spec 10 D15).
List<DraftCommand> _subtreeRemoval(CommandTarget t, _Survey before, Handle d) {
  final groups = <Handle>[];
  final instances = <Handle>[];
  void collect(Handle g) {
    groups.add(g);
    final node = t.tree[g];
    if (node is! GroupNode) return;
    for (final c in t.tree.childNodesOf(node.children)) {
      final child = t.tree[c];
      if (child is GroupNode) {
        collect(c);
      } else if (child is InstanceNode) {
        instances.add(c);
      }
    }
  }

  collect(d);
  bool live(Handle c) => t.entities.slotOf(c) != null;
  final leaves = <Handle, List<Handle>>{
    d: [
      for (final c in before.children[d] ?? const <Handle>[])
        if (live(c)) c,
    ],
    for (final i in before.instances[d] ?? const <InstanceNode>[])
      i.handle: [
        for (final c in before.leaves[i.handle] ?? const <Handle>[])
          if (live(c)) c,
      ],
  };
  final scanned = <Handle>{
    ...groups.skip(1),
    for (final i in instances)
      if (!leaves.containsKey(i)) i,
  };
  if (scanned.isNotEmpty) {
    for (final slot in t.entities.liveSlots) {
      final owner = t.entities.ownerAt(slot);
      if (scanned.contains(owner)) {
        (leaves[owner] ??= []).add(t.entities.handleAt(slot));
      }
    }
    for (final o in scanned) {
      leaves[o]?.sort(_byValue);
    }
  }
  bool isFill(Handle c) =>
      t.entities.kindAt(t.entities.slotOf(c)!) == EntityKind.fill;
  final out = <DraftCommand>[
    for (final g in [...groups, ...instances])
      for (final c in leaves[g] ?? const <Handle>[])
        if (isFill(c)) RemoveEntityCommand(c),
  ];
  void remove(Handle g) {
    for (final c in leaves[g] ?? const <Handle>[]) {
      if (!isFill(c)) out.add(RemoveEntityCommand(c));
    }
    final node = t.tree[g];
    if (node is GroupNode) {
      for (final c in t.tree.childNodesOf(node.children)) {
        final child = t.tree[c];
        if (child is GroupNode) {
          remove(c);
        } else if (child is InstanceNode) {
          for (final e in leaves[c] ?? const <Handle>[]) {
            if (!isFill(e)) out.add(RemoveEntityCommand(e));
          }
          out.add(RemoveNodeCommand(c));
        }
      }
    }
    out.add(RemoveNodeCommand(g));
  }

  remove(d);
  return out;
}

/// Spec 08 D5, Ruling 08-5: every seed that is a live `cascade`-policy
/// object after the edit must name only live objects. The first failure, in
/// ascending (seed, referent) order, is thrown. Reads the survey's declared
/// lists and never calls `references` again (Ruling 08-3). Only seeds are
/// checked, so an unrelated edit never trips over a bad object elsewhere.
void _checkDangling(Set<Handle> seeds, _Survey after) {
  if (seeds.isEmpty || after.declared.isEmpty) return;
  for (final s in seeds.toList()..sort(_byValue)) {
    final declared = after.declared[s];
    if (declared == null ||
        after.objects[s]!.type.referencePolicy != ReferencePolicy.cascade) {
      continue;
    }
    Handle? first;
    for (final x in declared) {
      if (!after.objects.containsKey(x) &&
          (first == null || x.value < first.value)) {
        first = x;
      }
    }
    if (first != null) throw DanglingReferenceError(s, first);
  }
}

/// Spec 06 D4 steps 1-9, in spec 08 D4's order:
///
/// 1. `before`, the survey, with references and referrers;
/// 2. `r0`, the edit;
/// 3. 06 D6's guard on `r0.touched`, then [_written] (06 D5, amended by
///    fix/post-11): either refusal undoes `r0`;
/// 4. the reference cascade ([_cascade]), which returns `r`: `r0` extended
///    by the removals, its inverse included;
/// 5. inside one `try`: the after-survey, `lost`, the
///    seeds, the dangling-reference check ([_checkDangling]), the page
///    seeds ([_pageSeeds], spec 10 D14: a changed page adds the live
///    objects of every type whose page key changed, unchecked for dangling
///    references, Ruling 10-4), the early return, the after-view, the
///    spatial trigger ([_triggered], spec 10 D16.2: the readers whose read
///    box touches a before or after place box of a contributor of the
///    spatial core whose place changed, and nothing when no reader is live;
///    the before-view is built there), the closure and the plan (a dissolving
///    object's removal included, spec 10 D15), which receives
///    the trigger's after-view (Ruling 10-5). Any failure applies
///    `r.inverse`, the cascade's included, so a refused edit leaves the
///    document byte for byte as it was;
/// 6. the apply loop, whose inverse wraps `r.inverse`.
///
/// The after-survey never sees a doomed referrer, so the plan never
/// generates it; `lost` picks each one up by itself (its node is gone), so
/// it seeds the closure like any deleted object. Its component went with its
/// node, in the removal (node-components spec D-4): there is no cleanup.
CommandResult _run(ParametricEdit edit, CommandTarget t) {
  final types = edit._system._types;
  // Spec 2a E2: one predicate for the whole edit, both surveys and both
  // guards.
  final frozen = edit._system._frozen;
  final before = _survey(t, types, frozen);
  final r0 = edit.inner.apply(t);

  final refused = _refused(t, types, before, r0.touched, frozen);
  if (refused != null) {
    _undoInner(t, edit.label, r0, GeneratedGeometryError(refused));
    throw GeneratedGeometryError(refused);
  }

  // Spec D5, amended by fix/post-11: a component written off a live
  // root-level group would never be regenerated. A client bug, like the
  // plan's malformed-boundary refusal (`_ownBoundaryOf`), so a
  // `StateError`: `GeneratedGeometryError` names a generated child, which
  // this is not. Typed (spec 2a E2, amended in the final review): a
  // `NonLiveWriteError` naming the handle. Refused like 06 D6's guard:
  // `inner` undone, nothing planned, nothing in history.
  if (_written(t, types, before, r0.touched, frozen) case (final h, final r)?) {
    final error = NonLiveWriteError(
        h,
        r.typeId,
        '"${edit.label}": ${r.typeId} written on '
        '${h.toHex()}, which is not a live root-level group after the edit, '
        'would never be regenerated (spec 06 D5); the edit is refused');
    _undoInner(t, edit.label, r0, error);
    throw error;
  }

  final r = _cascade(t, types, before, r0, edit.label);

  // The after-survey calls every registered type's `reach` again, with
  // whatever `inner` just wrote — a client's `reach` can throw on the new
  // parameters (a negative width, say). `inner` has already applied at
  // this point, so that throw, `lost`'s own computation, the
  // dangling-reference check and `_plan`'s call into `generate` all share
  // one try: any of them failing must still undo `inner` and the cascade
  // and leave nothing in history (spec D4 step 8).
  final _Survey after;
  final List<DraftCommand> plan;
  try {
    after = _survey(t, types, frozen);
    // Ruling 06-3: only objects that were live before the edit.
    final lost = [
      for (final h in before.objects.keys)
        if (!after.objects.containsKey(h) && t.tree[h] == null) h,
    ];
    // Spec 2b S1: a generated instance seeds nothing. It is neither an
    // object nor in `owned`, so a components-only write on one (per-unit
    // data) regenerates nothing and pays no `_checkDangling`. Any other
    // edit of it was refused above.
    final seeds = <Handle>{
      for (final h in r.touched) ...[
        // Ruling 06-4: a handle that was an object seeds too.
        if (after.objects.containsKey(h) || before.objects.containsKey(h)) h,
        if (before.owned[h] case final owner?) owner,
      ],
      ...lost,
    };
    _checkDangling(seeds, after);
    // Spec 10 D14, Ruling 10-4: after the dangling-reference check, which
    // checks only what the edit touched (a page-seeded object was not
    // edited, so a loaded one with a dead reference must not refuse a page
    // change), and before the early return (a page-only edit touches the
    // root, which is not an object, so its seeds are otherwise empty).
    // Guarded here, so no other edit builds the iterable or calls a
    // `pageKey`.
    if (before.page != after.page) {
      seeds.addAll(_pageSeeds(t, types, before, after));
    }
    // No neighbour has been computed up to here (spec 07 D10): an edit that
    // touches no object, a plain line drawn among them, pays for the two
    // surveys only and returns here.
    if (seeds.isEmpty) return r;
    // Ruling 10-5: one after-view, for the trigger and the plan alike.
    final view = ParametricView._(t, after);
    plan = _plan(
        t,
        _closure(
            seeds, before, after, _triggered(t, seeds, before, after, view)),
        after,
        view);
  } catch (error) {
    _undoInner(t, edit.label, r, error);
    rethrow;
  }
  // The cascade removes entities even when the plan is empty (a detached
  // host with no neighbour): the index must not skip it (spec 06 D9).
  edit._geometryChanged = plan.isNotEmpty || !identical(r, r0);

  // This loop is `CompoundCommand.apply` by hand, on purpose (06 debt). A
  // compound reports its own rollback failure as a `StateError`, which is
  // also what a child command throws when it refuses (a missing handle,
  // say); behind one `CompoundCommand.apply` the two would reach this
  // function as the same exception type. They need opposite handling: after
  // a child's error the regeneration is fully undone, so `inner` is undone
  // too and the error rethrown; after a failed rollback the target is in an
  // unknown state, so `inner` is left alone and the partial mutation is
  // reported. Applying the commands one by one keeps the two apart.
  final inverses = <DraftCommand>[];
  final touched = <Handle>{...r.touched};
  for (final c in plan) {
    final CommandResult applied;
    try {
      applied = c.apply(t);
    } catch (error) {
      try {
        for (final i in inverses.reversed) {
          i.apply(t);
        }
      } catch (rollbackError) {
        throw PartialMutationError(
            '"${edit.label}": regeneration threw ($error) and '
            'its rollback threw ($rollbackError); the target is partially '
            'mutated and nothing was recorded in history');
      }
      _undoInner(t, edit.label, r, error);
      rethrow;
    }
    inverses.add(applied.inverse);
    touched.addAll(applied.touched);
  }

  return CommandResult(
    inverse: ParametricReplay(
      CompoundCommand([
        if (inverses.isNotEmpty)
          CompoundCommand(inverses.reversed.toList(), label: 'Regenerate'),
        r.inverse,
      ], label: edit.label),
      edit.capabilities,
    ),
    touched: touched,
  );
}
