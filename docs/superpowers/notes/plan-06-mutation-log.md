# Plan 06 mutation log -- M-06a..y

26 fired: 26 killed, 0 survived, M-06e N/A (no iteration exists, spec D4
step 6; recorded, not fired).

Procedure, per mutant: `cp` the target file to
`.superpowers/sdd/2026-09-24-parametric-layer/mutation-backups/<basename>.<id>`,
apply the one edit by hand, run only the named test file(s) with `CI=true`
(`dart test` for `packages/jet_cad_2d`, `flutter test` for
`packages/jet_cad_2d_flutter` and `apps/floor_planner`), paste the failing
test names and the summary line, restore with `cp` from the backup, then
`diff <backup> <file>` and confirm it prints nothing. Every restore below was
verified empty at the time it was done.

One mutant (M-06b') first fired as a survivor; its fixture was fixed
(test-only, no production code) and it was re-fired, killed. See its entry
below for the before/after detail.

---

### M-06a — the compound's own inverse not reversed

- **file:** `packages/jet_cad_2d/lib/src/document/commands.dart`,
  `CompoundCommand.apply`
- **edit:** `inverses.reversed.toList()` → `inverses.toList()`
- **test:** `packages/jet_cad_2d/test/document/compound_command_test.dart`
  (covered there as the engine's own mutant, marked "M-C1" in that file's
  comments; ruling: fire it there and log the kill, per the task brief)
- **result:** KILLED -- `the inverse applies the children's inverses in
  reverse order` (target); `Bad state: no node with handle 12` at
  `commands.dart 301:7 TransformNodeCommand.apply`, called from
  `undo.dart 140:24 CommandDispatcher.undo` -- undo tries to restore the
  transform before the node that carries it exists, because the node's own
  restoring inverse now runs last instead of first. Summary `+2 -1`.

### M-06b — every stable-order sort dropped (survey, closure, store)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`
  (`_survey`'s `final order = found.keys.toList()..sort(_byValue);` →
  `.toList();`, and `_closure`'s trailing `..sort(_byValue)` dropped), and
  `packages/jet_cad_2d/lib/src/document/component.dart`
  (`ComponentStore.handles`'s `final list = _byHandle.keys.toList()..sort(...)`
  → `.toList()`) -- Ruling 06-5, all three sorts in one mutant
- **test:** `packages/jet_cad_2d/test/parametric/neighbourhood_test.dart`
  (N5)
- **result:** KILLED -- `N5` (target); the reload-and-replay comparison
  diverges at the child handle 3006's owner (`1000` expected, `2000`
  actual) -- with insertion order no longer normalised, `x` and its reload
  `y` (built from a different on-disk component/handle order) process their
  objects in different sequence and reserve the shared new handle for
  different owners. Summary `+13 -1`.

### M-06b' — the closure's own sort dropped

- **file:** `regeneration.dart`, `_closure`
- **edit:** drop the trailing `..sort(_byValue)` only
- **test:** `neighbourhood_test.dart` (N6)
- **First fire: SURVIVED.** `dart test test/parametric/neighbourhood_test.dart`
  printed `00:00 +14: All tests passed!` -- N6's original fixture used the
  standard `atA`/`atB` pierce-and-swallow pair (A gains a child, B only
  loses one), so only one side of the move ever reserves a new handle.
  `_plan`'s shared `reserved` counter then lands on the same value
  regardless of which object the unsorted closure visits first, since the
  other object never reserves anything -- the mutation had nothing to
  disturb. Recorded as a finding: a degenerate fixture (CLAUDE.md's
  "dominant failure mode"), not a code defect.
- **Fixture fix (test-only, no production code):** N6's geometry was
  changed from the pierce-and-swallow pair to a cross overlap -- B (200 x
  1600, A-local x:[900,1100], y:[-300,1300]) passes fully through A
  (2000 x 1000) top to bottom, so *both* objects' boundaries are split by
  the other and neither swallows a child (4 → 6 each side). With both
  seeds needing new handles inside the same `_plan` call, an unsorted
  closure hands the first two reserved handles to whichever object the
  compound touched first, so hA and hB trade owners on a fixed handle value
  depending on `bFirst`. Confirmed green on clean code first:
  `dart test test/parametric/neighbourhood_test.dart` → `00:00 +14: All
  tests passed!`.
- **Re-fire, KILLED** -- `N6` (target); the byte comparison diverges at
  handle 2005 (`owner:1000` expected, `owner:2000` actual) -- `bFirst=true`
  and `bFirst=false` now produce genuinely different, non-isomorphic
  documents instead of merely reordered ones. Summary `+13 -1`. Restored
  and diffed empty against the fresh backup
  `regeneration.dart.M-06b-prime-refire`.

### M-06c — the regeneration's own inverse dropped from the replay

- **file:** `regeneration.dart`, `_run`
- **edit:** dropped the `if (inverses.isNotEmpty) CompoundCommand(...)`
  element from the `ParametricReplay`'s wrapped list, leaving only
  `r.inverse`
- **test:** `packages/jet_cad_2d/test/parametric/regeneration_test.dart`
  (P3)
- **result:** KILLED -- `P3` (target); after undo, the byte comparison
  against `before` diverges at the first regenerated line's second
  coordinate (`2000.0` expected, `2600.0` actual) -- undo restored the raw
  edit but never rolled back the regeneration it triggered. Summary
  `+11 -1`.

### M-06d — the closure collapsed to the seeds alone

- **file:** `regeneration.dart`, `_closure`
- **edit:** `{...seeds, for (s in seeds) ...?before.neighbours[s], for (s in
  seeds) ...?after.neighbours[s]}.where(...).toList()..sort(_byValue)` →
  `seeds.where(after.objects.containsKey).toList()..sort(_byValue)` (drops
  both neighbour spreads)
- **test:** `neighbourhood_test.dart` (N2, N3)
- **result:** KILLED -- `N2` and `N3` (both targets): N2 expected B's world
  segments to change when A's `ClipRect` changes and they don't (B is never
  pulled into the closure); N3 expected B's children to regrow to 4 after A
  moves away and they stay at 3 (`has length of <3>`). Collateral: `N1`,
  `N5`, `N7`, `N9`, `N10`, `N13`, `N14` (every test that depends on a
  neighbour actually regenerating). Summary `+5 -9`.

### M-06e — N/A by construction

No iteration exists to mutate: spec D4 step 6 is a fixed one-hop closure
(seeds plus their neighbours, once), not a loop, so there is no "drop the
loop" or "off-by-one" edit to make. Recorded per the task brief; not fired.

### M-06f — `install()` forces an eager regeneration

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`,
  `ParametricSystem.install`
- **edit:** after taking the expander slot, added a `regenerateAll`: survey
  the document, plan every object, and `execute` the results as one
  `CompoundCommand` if non-empty (Ruling 06-7's shape: `_plan` per object,
  concatenated into `install`'s own compound edit)
- **test:** `neighbourhood_test.dart` (N9, N10)
- **result:** KILLED -- both named tests, by a thrown
  `GeneratedGeometryError` rather than a value mismatch: `install` on a
  document reloaded with a deliberately-staled child immediately tries to
  regenerate it, and the parametric system's own guard refuses the touched
  generated handle before N9/N10 ever reach their assertions. This is
  itself the point of both tests: stale geometry on load must be *trusted*,
  never silently regenerated, and `drift()` is the only sanctioned way to
  detect it. Summary `+12 -2`.

### M-06g — group-local-to-world collapsed to identity (engine)

- **file:** `regeneration.dart`, `_worldOf`
- **edit:** `t.tree.accumulatedTransform(h)` → `Transform2.identity()`
- **test:** `neighbourhood_test.dart` (N1, N4),
  `regeneration_test.dart` (P3)
- **result:** KILLED -- `N1`, `N4` and `P3` (all three targets), plus
  collateral `N2`, `N3`, `P4`, `N5`, `N6`, `N13`, `N14`. Every reach and
  every generated child is computed in local space mislabelled as world, so
  overlap detection and absolute coordinates both break as soon as a
  fixture is off the identity transform (which every fixture here is).
  Summary `+16 -10`.

### M-06g (app) — `BoxType.reach` never applies `toWorld`

- **file:** `apps/floor_planner/lib/parametric/box.dart`, `BoxType.reach`
- **edit:** `Aabb2.fromPoints([for (c in _corners(params)) toWorld
  .transformPoint(c)])` → `Aabb2.fromPoints([for (c in _corners(params)) c])`
- **test:** `apps/floor_planner/test/box_test.dart` (BT6, per the
  controller's ruling -- BT3's exact-outline assertion survives this
  mutant by design: a wrong reach only changes which boxes count as
  neighbours, and neither box here needs a neighbour it would lose, so
  `generate`'s own clipping still produces the same 5/3 split)
- **result:** KILLED -- `BT6` (target); expected `6510.0` (the corner's
  world `x`), got `0.0` (the untransformed local corner). `BT3` was also
  run and, exactly as the controller predicted, still passed (5/5 tests
  green apart from BT6). Summary `+5 -1`.

### M-06h — `ParametricEdit.capability` never escalates to geometry

- **file:** `parametric_system.dart`, `ParametricEdit.capability`
- **edit:** `_geometryChanged && inner.capability.index <
  Capability.geometry.index ? Capability.geometry : inner.capability` →
  `inner.capability`
- **test:** `regeneration_test.dart` (P4)
- **result:** KILLED -- `P4` (target); expected the spatial index to find a
  child of the newly-widened A near its new geometry and it finds nothing
  (`Set:[]`) -- the dispatcher's `CommandApplied.capability` never says
  `geometry` for a components-only edit that happened to also regenerate
  geometry, so `SpatialIndex` (which reconciles only on a geometry-tagged
  change) never re-indexes it. Summary `+11 -1`.

### M-06i — `ParametricReplay.apply` returns a bare compound inverse

- **file:** `parametric_system.dart`, `ParametricReplay.apply`
- **edit:** `final r = replay.apply(target); return CommandResult(inverse:
  ParametricReplay(r.inverse as CompoundCommand, capabilities), touched:
  r.touched);` → `final r = replay.apply(target); return r;`
- **test:** `packages/jet_cad_2d/test/parametric/guards_test.dart` (G4)
- **result:** KILLED -- `G4` (target); `redo()` throws
  `PermissionDeniedError: "Set component" needs geometry` under runtime
  permissions, even though the edit only ever needed `components` --
  without the `ParametricReplay` wrapper, the pushed inverse carries the
  raw `CompoundCommand`'s own capability union (which includes `geometry`
  from the underlying entity commands) instead of the narrower set the
  original edit was authorised under. Summary `+8 -1`.

### M-06j — the direct-edit-of-generated-geometry guard removed

- **file:** `regeneration.dart`, `_run`
- **edit:** deleted the `_refused`/`throw GeneratedGeometryError` block
  entirely
- **test:** `guards_test.dart` (G1, G2)
- **result:** KILLED -- `G1` and `G2` (both targets); G1 expected
  `GeneratedGeometryError` on a direct edit of a generated line and got
  `null` (the edit silently "succeeded"); G2 expected the same for adding
  an entity into a parametric group. Summary `+7 -2`.

### M-06k — delete's cleanup list emptied

- **file:** `regeneration.dart`, `_run`
- **edit:** `cleanup = [for (h in lost) before.objects[h]!.detach(h)];` →
  `cleanup = <DraftCommand>[];`
- **test:** `guards_test.dart` (G3)
- **result:** KILLED -- `G3` (target); expected the deleted object's
  `ClipRect` component to be `null` after the delete and it is still the
  live instance -- the node and its entities are gone, but nothing detaches
  the now-dangling parametric component from the deleted handle. Summary
  `+8 -1`.

### M-06l — the closure's "before" neighbours dropped

- **file:** `regeneration.dart`, `_closure`
- **edit:** deleted `for (final s in seeds) ...?before.neighbours[s],`
- **test:** `neighbourhood_test.dart` (N3)
- **result:** KILLED -- `N3` (target); expected B's children to regrow to 4
  after A moves away and they stay at 3 (`has length of <3>`) -- B was A's
  neighbour *before* the move but not after, so without the pre-move
  neighbour set B never gets a chance to regenerate back to its unclipped
  shape. Summary `+13 -1`.

### M-06m — children matched by overall ordinal, not by kind first

- **file:** `regeneration.dart`, `_plan`
- **edit:** replaced the per-kind `byKind`/`used` bookkeeping with one flat
  `allChildren = s.children[h] ?? const <Handle>[]` list matched to
  `generated` purely by position (`generated[i]` ↔ `allChildren[i]`,
  surplus = `allChildren.skip(i)`), ignoring `EntityKind` entirely
- **test:** `regeneration_test.dart` (P5)
- **result:** KILLED -- `P5` (target); expected the flipped `Hinge`'s arc
  child to still report `scalars.length == 3` and it reports `(2, 3)`
  instead of `(4, 0)` for the line-turned-arc slot -- the ordinal match
  overwrites the line entity's geometry with the arc's payload (and vice
  versa) instead of keeping each generated shape matched to its own kind's
  existing child. Summary `+11 -1`.

### M-06n — undo runs the expander

- **file:** `packages/jet_cad_2d/lib/src/document/undo.dart`,
  `CommandDispatcher.undo`
- **edit:** `final inverse = _history.takeUndo();` → `final inverse =
  expander?.call(_history.takeUndo()) ?? _history.takeUndo();` (kept
  compiling per the brief; with an expander installed, as in every fixture
  here, `takeUndo()` is still called exactly once, since `?.call` short
  -circuits the `??` branch)
- **test:** `packages/jet_cad_2d/test/document/expander_test.dart` (X2),
  `neighbourhood_test.dart` (N10)
- **result:** KILLED in both named files.
  - `expander_test.dart` X2: expected the counting expander to be called
    exactly once (from the original `execute`) and it is called three
    times -- once for `execute`, once for `undo`, once for `redo`.
  - `neighbourhood_test.dart` N10: undo now re-wraps the popped inverse in
    a fresh `ParametricEdit` and re-regenerates, throwing
    `GeneratedGeometryError` on the touched, still-generated child instead
    of replaying the exact stale geometry undo is supposed to restore
    byte-for-byte.
  - Summary `+16 -2`.

### M-06o — `generate`'s world-to-local conversion never inverted

- **file:** `apps/floor_planner/lib/parametric/box.dart`, `BoxType.generate`
- **edit:** `final toLocal = view.toWorld(self).invert();` → `final toLocal
  = view.toWorld(self);`
- **test:** `apps/floor_planner/test/box_test.dart` (BT3)
- **result:** KILLED -- `BT3` (target); expected A to have 5 children (the
  overlap-clipped outline) and it has 4 (unclipped) -- neighbour corners
  projected through the un-inverted transform land nowhere near A's own
  local rectangle, so no edge ever intersects a neighbour's quad and no
  split ever happens. Summary `+5 -1`.

### M-06p — a changed payload becomes remove-then-add, not set-in-place

- **file:** `regeneration.dart`, `_plan`
- **edit:** the `_samePayload` mismatch branch, `out.add
  (SetEntityGeometryCommand(existing[i], g.payload));` →
  `out.add(RemoveEntityCommand(existing[i])); out.add(AddEntityCommand
  (record: draftRecord(Handle.checked(++reserved), h, g.kind), payload:
  g.payload));` (Ruling 06-6's concrete shape)
- **test:** `regeneration_test.dart` (P2)
- **result:** KILLED -- `P2` (target); expected every child handle to
  survive a width edit unchanged (`[1001, 1002, 1003, 1004]`) and they are
  all replaced with fresh, higher handles (`[1005, 1006, 1007, 1008]`).
  Collateral: `P3` (the undo/redo byte comparison, since the handles
  churned mid-edit no longer match the pre-edit snapshot on undo). Summary
  `+10 -2`.

### M-06q — the fast-path guard's parametric-command check dropped

- **file:** `parametric_system.dart`, `ParametricSystem._expand`
- **edit:** `if (!_types.any((t) => t.handles(document).isNotEmpty) &&
  !_setsParametric(command)) return command;` → `if (!_types.any((t) =>
  t.handles(document).isNotEmpty)) return command;`
- **test:** `regeneration_test.dart` (P1)
- **result:** KILLED -- `P1` (target); the very first object in an empty
  document (no parametric objects exist yet, so the fast path always
  fires) is created as a bare `CompoundCommand`, never wrapped in a
  `ParametricEdit`, so it is never regenerated at all -- `expectWorld`
  fails on the un-generated document. Widespread collateral (`P2`, `P5`,
  `P9`, `P10`, `P11`, `P12`): every test whose *first* command creates an
  object depends on `_setsParametric` catching it before any parametric
  object exists. Summary `+6 -6`.

### M-06r — delete's cleanup applied eagerly, outside the rollback loop

- **file:** `regeneration.dart`, `_run`
- **edit:** applied `cleanup` immediately after computing it, inside the
  survey's own `try` (`for (final c in cleanup) { c.apply(t); }` right
  after `cleanup = [...]`), and dropped `cleanup` from the later
  `for (final c in [...cleanup, ...plan])` loop, leaving only `...plan`
  (revision 1's shape, per the brief)
- **test:** `guards_test.dart` (G6)
- **result:** KILLED -- `G6` (target); expected the deleted object's
  `ClipRect` to survive a mid-delete `generate` throw (`Instance of
  'ClipRect'`) and it is `null` -- the detach already landed on `t` before
  the throw, and the plain `_undoInner(t, edit.label, r, error)` path only
  replays `r.inverse` (the original delete's own undo), which never
  reverses the cleanup's `SetComponentCommand<ClipRect>(hA, null)` that ran
  outside the tracked-inverses rollback. Collateral: `G3` (the same
  detach-then-undo path, exercised without a throw, now leaves the
  component permanently null after undo instead of restoring it). Summary
  `+7 -2`.

### M-06s — the reentrancy guard on `_expand` removed

- **file:** `parametric_system.dart`, `ParametricSystem._expand`
- **edit:** deleted the `if (_applying) throw StateError(...)` block
- **test:** `guards_test.dart` (G8)
- **result:** KILLED -- `G8` (target); expected a `StateError` from
  `generate` calling `execute` reentrantly and instead the call recurses
  without bound (`generate` → `execute` → `_expand` → `_run` → `_plan` →
  `generate` → ...) until the runtime throws a stack-overflow error, which
  is not a `StateError` and fails the `throwsStateError` matcher. Summary
  `+8 -1`.

### M-06t — new children get seed-advanced handles, not locally reserved ones

- **file:** `regeneration.dart`, `_plan`
- **edit:** `Handle.checked(++reserved)` → `t.handleSeed.next()`
- **test:** `guards_test.dart` (G7)
- **result:** KILLED -- `G7` (target); expected `handleSeed` unchanged
  after a plan that fails partway through (A would gain a child, then B's
  `generate` throws) and it advanced by one anyway -- `handleSeed.next()`
  mutates the seed immediately and permanently, unlike the local `reserved`
  counter, which the caller is free to discard on failure without leaving
  a gap. Summary `+8 -1`.

### M-06u — `commit`'s permission check ignores `needs`

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `PlacementTool.commit`
- **edit:** `if (!needs.every(permissions.allows)) return false;` →
  `if (!permissions.allows(Capability.geometry)) return false;`
- **test:** `packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart`
  (CN1)
- **result:** KILLED -- `CN1` (target); expected the build closure never to
  run when `structure` (part of the caller-supplied `needs`) is denied, and
  it runs anyway because only `geometry` (which permissions still allow)
  is checked -- the probe's `CompoundCommand(const [])` then throws
  `ArgumentError: must not be empty` from inside the now-reached build,
  which is itself proof the gate was bypassed. Summary `+1 -1`.

### M-06v — `registerInto` re-registers over an already-loaded store

- **file:** `parametric_system.dart`, `_Registration.registerInto`
- **edit:** `if (!r.isRegistered<T>()) r.register<T>(typeId, factory);` →
  `r.register<T>(typeId, factory);`
- **test:** `regeneration_test.dart` (P10)
- **result:** KILLED -- `P10` (target); expected a second `ParametricSystem`
  built over an already-populated document to leave `hA`'s `ClipRect`
  intact and it is `null` -- `register` unconditionally replaces the
  component store (Ruling 06-13), wiping every live `ClipRect` the moment
  the second system's constructor registers the same type again. Summary
  `+11 -1`.

### M-06w — the after-survey and cleanup computed outside the rollback `try`

- **file:** `regeneration.dart`, `_run`
- **edit:** moved `after = _survey(t, types)`, the `lost` list, `cleanup`
  and the `seeds` set out of the `try` block and ahead of it (so only
  `plan = _plan(...)` remains inside `try`)
- **test:** `regeneration_test.dart` (P11)
- **result:** KILLED -- `P11` (target); a `reach` that throws on the
  *new*, already-applied parameters (`TripMode.throwingReach` with a
  negative width) now propagates straight out of `_run` -- past
  `_undoInner`, since the after-survey that calls `reach` no longer sits
  inside the `try`/`catch` that would have rolled `r` back -- so the
  original edit's mutation is never undone and the component is left at
  its (invalid) new value instead of the pre-edit one. The test still sees
  the same *kind* of thrown `Trip` instance either way, but the follow-on
  assertions (undo depth, the restored component value, the restored
  bytes) diverge. Summary `+11 -1`.

### M-06x — a touched generated child refused only while its owner still lives

- **file:** `regeneration.dart`, `_refused`
- **edit:** dropped the `if (t.entities.slotOf(h) != null) return h;`
  branch from the `owner != null` arm, leaving only the
  `if (_isObject(t, types, owner)) return h;` check
- **test:** `regeneration_test.dart` (P12)
- **result:** KILLED -- `P12` (target); expected a compound that first
  detaches a group's `ClipRect` (so it is no longer "an object" by the time
  `_refused` runs) and then directly edits one of its still-live generated
  children to throw `GeneratedGeometryError`, and it returns `null`
  (silently allowed) instead -- without the still-exists check, detaching
  the owner's parametric component in the same command is enough to smuggle
  a direct edit of its generated geometry past the guard. Summary
  `+11 -1`.

### M-06y — `onTapOutside` removed from the panel's fields

- **file:** `apps/floor_planner/lib/selection_panel.dart`, the shared
  `field(...)` builder
- **edit:** removed the `onTapOutside: (_) => _submit(h, c.text, isWidth:
  isWidth),` line (one edit covers both the width and height fields, since
  both are built by the same closure)
- **test:** `apps/floor_planner/test/selection_panel_test.dart` (SE8)
- **result:** KILLED -- `SE8` (target); expected a tap outside the width
  field (with no `TextInputAction.done`) to commit the typed value and the
  model's width stays at its old value (`Expected: <150> Actual: <120.0>`)
  -- with no `onTapOutside` handler, only Enter commits. Summary `+7 -1`.

---

## Verification

- `git status --short` after every restore in this run printed nothing for
  the `.dart` production files under `packages/` and `apps/`; the only
  outstanding change throughout was N6's fixture (`neighbourhood_test.dart`,
  fixed for M-06b' -- see above).
- Full gate lines, run once at the end against the fully-restored tree
  (production code identical to before this task; the only diff is the
  N6 test fixture):

**`packages/jet_cad_2d`:**
```
$ CI=true dart test
...
00:03 +950: All tests passed!
```
```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```
```
$ dart format --output=none --set-exit-if-changed .
Formatted 141 files (0 changed) in 0.26 seconds.
```

**`packages/jet_cad_2d_flutter`:**
```
$ CI=true flutter test
...
00:14 +925: Some tests failed.

Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exactly the standing exception: the five `text_ladder_golden_test.dart`
rungs, nothing else.
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
```
```
$ dart format --output=none --set-exit-if-changed .
Formatted 176 files (0 changed) in 0.32 seconds.
```

**`apps/floor_planner`:**
```
$ CI=true flutter test
...
00:03 +67: All tests passed!
```
```
$ flutter analyze
Analyzing floor_planner...
No issues found! (ran in 1.2s)
```
```
$ dart format --output=none --set-exit-if-changed .
Formatted 19 files (0 changed) in 0.05 seconds.
```

`git status --short` after all three gate lines listed only the N6 test
fixture; no `analysis_options.yaml` and no `.dart` production file.
