part of 'parametric_system.dart';

int _byValue(Handle a, Handle b) => a.value.compareTo(b.value);

/// Group-local to world for a parametric object. Mutant M-06g returns the
/// identity here.
Transform2 _worldOf(CommandTarget t, Handle h) =>
    t.tree.accumulatedTransform(h);

/// A root-level group carrying a registered parametric component (spec D5).
bool _isObject(
    CommandTarget t, List<_Registration<Component>> types, Handle h) {
  final node = t.tree[h];
  return node is GroupNode &&
      node.parent == t.tree.root &&
      types.any((r) => r.has(t, h));
}

/// Pairwise reach-overlap tests performed by the neighbour search (spec 07
/// D10), for tests that pin its cost. Never reset by the library.
@visibleForTesting
int debugOverlapTests = 0;

/// Everything the planner reads about the parametric objects at one moment.
///
/// Neighbours are not surveyed (spec 07 D10): [neighboursOf] computes one
/// object's list on demand, against this survey's own [reach] snapshot, and
/// memoises it. An edit asks only for its seeds and its closure, O(k·n);
/// an edit with no seeds asks for none.
final class _Survey {
  _Survey(this.objects, this.reach, this.children, this.owned);

  /// Live objects, ascending, with their registration.
  final Map<Handle, _Registration<Component>> objects;

  /// Each object's reach at this moment, one call per object.
  final Map<Handle, Aabb2> reach;

  /// Each object's children, ascending.
  final Map<Handle, List<Handle>> children;

  /// Every child of a live object, to its owner: the set G of spec D4.
  final Map<Handle, Handle> owned;

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
}

_Survey _survey(CommandTarget t, List<_Registration<Component>> types) {
  final found = <Handle, _Registration<Component>>{};
  for (final r in types) {
    for (final h in r.handles(t)) {
      if (_isObject(t, types, h)) found[h] = r;
    }
  }
  final order = found.keys.toList()..sort(_byValue);
  final objects = {for (final h in order) h: found[h]!};
  // Ascending, like [objects]: `neighboursOf` walks it in handle order.
  final reach = {for (final h in order) h: objects[h]!.reachOf(t, h)};
  final children = <Handle, List<Handle>>{};
  final owned = <Handle, Handle>{};
  for (final slot in t.entities.liveSlots) {
    final owner = t.entities.ownerAt(slot);
    if (!objects.containsKey(owner)) continue;
    final h = t.entities.handleAt(slot);
    (children[owner] ??= []).add(h);
    owned[h] = owner;
  }
  for (final list in children.values) {
    list.sort(_byValue);
  }
  return _Survey(objects, reach, children, owned);
}

/// Seeds plus their neighbours before and after, as a sorted list of live
/// objects (spec D4 step 6). One hop: generation reads parameters only.
/// Neighbours are asked for the seeds only (spec 07 D10).
List<Handle> _closure(Set<Handle> seeds, _Survey before, _Survey after) => {
      ...seeds,
      for (final s in seeds) ...before.neighboursOf(s),
      for (final s in seeds) ...after.neighboursOf(s),
    }.where(after.objects.containsKey).toList()
      ..sort(_byValue);

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

/// The boundary a fill child names: its payload's one scalar (spec 07 D8).
Handle _boundaryOf(CommandTarget t, Handle fill) => Handle.checked(t.geometry
    .peek(t.entities.geomIndexAt(t.entities.slotOf(fill)!))
    .scalars[0]
    .toInt());

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
List<DraftCommand> _plan(
    CommandTarget t, List<Handle> closure, _Survey s, ParametricView view) {
  var reserved = t.handleSeed.current.value;
  final out = <DraftCommand>[];
  for (final h in closure) {
    final generated = s.objects[h]!.generate(view, h);
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
        final boundary = _boundaryOf(t, fills[i]);
        final slot = t.entities.slotOf(boundary);
        if (slot == null || t.entities.ownerAt(slot) != h) {
          throw StateError('fill ${fills[i].toHex()} of ${h.toHex()} names '
              '${boundary.toHex()}, which is not a child of the same object');
        }
        // The fill record is never rewritten: rewriting the boundary
        // re-triangulates the fill (`SetEntityGeometryCommand`).
        if (!_samePayload(
            t.geometry.peek(t.entities.geomIndexAt(slot)), g.payload)) {
          out.add(SetEntityGeometryCommand(boundary, g.payload));
        }
      } else {
        // Fill first: `AddRegionCommand` requires the lower handle on it.
        out.add(AddRegionCommand(
            fill: draftRecord(Handle.checked(++reserved), h, EntityKind.fill,
                color: g.color),
            boundary: draftRecord(
                Handle.checked(++reserved), h, EntityKind.polyline,
                color: g.color),
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
      } else {
        out.add(AddEntityCommand(
            record: draftRecord(Handle.checked(++reserved), h, g.kind,
                color: g.color),
            payload: g.payload));
      }
    }
    // A surplus region is removed through its boundary, whose removal takes
    // the fill with it; removing the fill alone would orphan the boundary.
    final surplus = [
      for (final e in byKind.entries)
        for (final c in e.value.skip(used[e.key] ?? 0))
          e.key == EntityKind.fill ? _boundaryOf(t, c) : c,
    ]..sort(_byValue);
    for (final c in surplus) {
      out.add(RemoveEntityCommand(c));
    }
  }
  return out;
}

/// The first touched handle that edits a generated entity, removes one
/// while its group lives, or adds one into a live object (spec D6).
///
/// For `h` in `G` (before.owned[h] != null): refused if `h` **still
/// exists** — a direct edit of a generated entity, regardless of what else
/// the same command did to its owner — or, when `h` was removed, if the
/// owner's group node still exists (spec D6's amendment for F4: whatever
/// its component now is, not only while it is still a live parametric
/// object -- a compound that detaches the component and then removes one
/// of its still-live children in the same command must still be refused).
/// Only a child removed *together with* its owning group is allowed.
Handle? _refused(CommandTarget t, List<_Registration<Component>> types,
    _Survey before, Set<Handle> touched) {
  for (final h in touched.toList()..sort(_byValue)) {
    final owner = before.owned[h];
    if (owner != null) {
      if (t.entities.slotOf(h) != null) return h;
      if (t.tree[owner] != null) return h;
      continue;
    }
    final slot = t.entities.slotOf(h);
    if (slot != null && _isObject(t, types, t.entities.ownerAt(slot))) {
      return h;
    }
  }
  return null;
}

/// Undoes [r] after a failure; if that fails too, the target is in an
/// unknown state and the caller must know it.
void _undoInner(CommandTarget t, String label, CommandResult r, Object cause) {
  try {
    r.inverse.apply(t);
  } catch (rollbackError) {
    throw StateError('"$label": $cause, and undoing the edit then threw '
        '($rollbackError); the target is partially mutated and nothing was '
        'recorded in history');
  }
}

/// Spec D4 steps 1-9.
CommandResult _run(ParametricEdit edit, CommandTarget t) {
  final types = edit._system._types;
  final before = _survey(t, types);
  final r = edit.inner.apply(t);

  final refused = _refused(t, types, before, r.touched);
  if (refused != null) {
    _undoInner(t, edit.label, r, GeneratedGeometryError(refused));
    throw GeneratedGeometryError(refused);
  }

  // The after-survey calls every registered type's `reach` again, with
  // whatever `inner` just wrote — a client's `reach` can throw on the new
  // parameters (a negative width, say). `inner` has already applied at
  // this point, so that throw, `lost`/`cleanup`'s own computation, and
  // `_plan`'s call into `generate` all share one try: any of them failing
  // must still undo `inner` and leave nothing in history (spec D4 step 8).
  final _Survey after;
  final List<DraftCommand> cleanup;
  final List<DraftCommand> plan;
  try {
    after = _survey(t, types);
    // Ruling 06-3: only objects that were live before the edit.
    final lost = [
      for (final h in before.objects.keys)
        if (!after.objects.containsKey(h) && t.tree[h] == null) h,
    ];
    cleanup = [for (final h in lost) before.objects[h]!.detach(h)];
    final seeds = <Handle>{
      for (final h in r.touched) ...[
        // Ruling 06-4: a handle that was an object seeds too.
        if (after.objects.containsKey(h) || before.objects.containsKey(h)) h,
        if (before.owned[h] case final owner?) owner,
      ],
      ...lost,
    };
    // No neighbour has been computed up to here (spec 07 D10): an edit that
    // touches no object, a plain line drawn among them, pays for the two
    // surveys only and returns here.
    if (seeds.isEmpty && cleanup.isEmpty) return r;
    plan = _plan(
        t, _closure(seeds, before, after), after, ParametricView._(t, after));
  } catch (error) {
    _undoInner(t, edit.label, r, error);
    rethrow;
  }
  edit._geometryChanged = plan.isNotEmpty;

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
  for (final c in [...cleanup, ...plan]) {
    final CommandResult applied;
    try {
      applied = c.apply(t);
    } catch (error) {
      try {
        for (final i in inverses.reversed) {
          i.apply(t);
        }
      } catch (rollbackError) {
        throw StateError('"${edit.label}": regeneration threw ($error) and '
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
