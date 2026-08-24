# Task 7 report — invalidation: two directions, five change arms, and the node list

Commit: `67b2e1f` — *feat: tile invalidation, in two directions and across all
five change arms*

Files: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (modified),
`packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` (created).

---

## 1. The real signatures, found in the tree

The brief described three helpers "in shape rather than in full". Here is what
the tree actually has, and what each helper became.

### `_isDefinitionOwned(DraftDocument, Handle) -> bool`

Built on:

| named in the brief | real signature | file:line |
|---|---|---|
| `DocumentTree.ancestorsOf` | `List<Handle> ancestorsOf(Handle handle)` | `tree.dart:240` |
| `DocumentTree.definition` | `Definition? definition(Handle handle)` | `tree.dart:69` |
| `EntityStore.slotOf` | `int? slotOf(Handle handle)` | `entity_store.dart:280` |
| `EntityStore.ownerAt` | `Handle ownerAt(int slot)` | `entity_store.dart:342` |

**One deviation from the brief's one-line test, and it is load-bearing.** The
brief says "a leaf is definition-owned when `tree.definition(entities.ownerAt(slot)) != null`".
That is right for a leaf whose *immediate* owner is the definition, and wrong
for a leaf owned by a **group that is itself inside a definition** — a shape
`differentialFixture` already builds (`Handle(520)`, an `InstanceNode` whose
parent is the definition `outer`). For such a leaf `ownerAt(slot)` names the
group, `tree.definition(group)` is `null`, and a one-level test reports
"root-owned". The consequence would be a definition edit taking the per-tile
path, which cannot reach the instances of that definition at all — exactly the
stale-block defect criterion 6 exists to forbid.

So the walk climbs:

```dart
static Handle? _enclosingDefinition(DocumentTree tree, Handle container) {
  if (tree.definition(container) != null) return container;
  if (tree[container] == null) return null;
  final chain = tree.ancestorsOf(container);
  final top = chain.isEmpty ? container : chain.last;
  final parent = tree[top]!.parent;
  return tree.definition(parent) != null ? parent : null;
}
```

The one non-obvious fact this rests on, verified at `tree.dart:240-256`:
`ancestorsOf` walks `parent` **while the parent is a node** (`_nodes.containsKey`),
and a definition lives in `_definitions`, not `_nodes`. A definition therefore
*never appears in the chain it returns*. The definition, when there is one, is
the `parent` of the chain's last element — which is the only place worth
looking, and why a naive `chain.any(tree.definition)` would always be false.

The brief's other warning is honoured: the test is for a **definition**, not
for "not the root". A leaf under a root-level group is neither, and groups draw
at root level, so it correctly takes the per-tile path.

### `_worldBoxOf(DraftDocument, Handle) -> Aabb2?`

| named in the brief | real signature | file:line |
|---|---|---|
| `DraftDocument.definitionBounds` | `Aabb2 definitionBounds(Handle definition, [Map<Handle, List<int>>? leavesByOwner])` | `draft_document.dart:176` |
| `DocumentTree.accumulatedTransform` | `Transform2 accumulatedTransform(Handle handle)` | `tree.dart:266` |
| `entityBounds` | `Aabb2 entityBounds({required EntityKind kind, required GeometryPayload payload, required TextMeasurer measurer, required TextStyleRecord textStyle, int textAttrs = 0, String text = '', EntityKind? boundaryKind, GeometryPayload? boundaryPayload})` | `extents.dart:27` |

Two findings here.

**`definitionBounds` takes a group handle as readily as a definition handle.**
Its doc comment names definitions, but it is a one-line delegate to
`_boundsOfContainer`, whose own comment (`draft_document.dart:241-242`) reads
"Union of everything a container holds, expressed in that container's own
space. **Works for both a group node and a definition.**" So a `GroupNode` is
passed straight through.

**An `InstanceNode` handle is the one thing it does not resolve**, and passing
one silently returns an empty box rather than throwing. `_childrenOf`
(`draft_document.dart:329-341`) looks up leaves by owner — an instance owns
none — and then switches: `GroupNode(:final children) => children`, `_ =>
tree.definition(container)?.children ?? const []`. An instance handle falls to
the `_` arm, `tree.definition(instanceHandle)` is null, and the answer is an
empty children list. An empty `Aabb2` is `isEmpty`, so direction two would have
skipped every instance and dropped nothing — a silent no-op, not a crash. The
definition is therefore named explicitly:

```dart
final content = switch (node) {
  InstanceNode(:final definition) => document.definitionBounds(definition),
  GroupNode() => document.definitionBounds(handle),
};
return content.transformedBy(tree.accumulatedTransform(handle));
```

**The `EntityKind.fill` boundary case**, copied from its real call site at
`container_index.dart:99-114`: a fill's own payload names a boundary handle
instead of carrying coordinates, so `boundaryKind`/`boundaryPayload` are
resolved through `boundaryHandleOf(payload)` and `slotOf`, and a dangling
boundary leaves both null. Without it a fill's box is whatever `entityBounds`
makes of a payload holding a handle in a coordinate slot.

`read`, not `peek`, for both payloads: the site in `container_index` uses
`peek` because it is a per-leaf hot path that keeps nothing; this runs once per
touched handle on an edit, and the box outlives the call.

### `_worldRectOf(TileKey, TileGrid) -> Aabb2`

All four corners of the tile's device rect, inverted through `grid.anchor`:

```dart
for (final p in <Vector2>[
  Vector2(left, top), Vector2(left + side, top),
  Vector2(left, top + side), Vector2(left + side, top + side),
]) box = box.expandedToPoint(grid.anchor.screenToWorld(p));
```

This is `ViewportTransform.visibleWorld`'s own shape (`viewport_transform.dart:65-76`)
and its own reason: "under rotation the axis-aligned box of two opposite
corners omits geometry that is genuinely on screen". Here the omitted world is
precisely the world whose tiles this method exists to condemn, so two corners
would under-invalidate under any rotated or skewed camera.

`grid._tileLogical` is reused rather than recomputed — same library file, and
recomputing it is how the tile side and the grid's tile side drift apart.

---

## 2. What the invalidation path allocates per change

**The frame path is untouched.** `onVisit` is `null` at all three non-bake call
sites into `_drawInto`, so a warm frame that blits and bakes nothing allocates
nothing new. `flutter test` includes `test/invariants/paint_allocation_test.dart`
and it is green in the full run below.

**Per bake** (not a steady-state frame — a bake is the work the cache exists to
amortise): one growable `List<int>`, one `Uint32List` copy of it, and one
`Handle` per visit, which the painter was already constructing at every call
site. Length is one entry per leaf drawn plus one per container descended, with
duplicates left in, per the brief: a handle drawn twice costs one slot and the
binary search does not care.

**Per `applyChange` call:**

| arm | allocation |
|---|---|
| `DocumentLoaded`, `DocumentPurged`, empty `touched` | none beyond the map clears |
| definition-owned `touched` | none beyond the map clears |
| per-tile path | one `Set<TileKey>` (`doomed`), one `List<Aabb2>` (`boxes`, `touched.length` entries at most), and per touched handle whatever `_worldBoxOf` costs: an `EntityRecord` + `GeometryPayload` from `read`, or a `definitionBounds` walk; then **one `Aabb2` and one four-element `List<Vector2>` per live tile** in the direction-two sweep |

The per-tile term is `_worldRectOf`'s corner list. It is O(live tiles), not
O(tiles x touched): the boxes are derived once ahead of the sweep rather than
inside it, which is a deviation from the brief's nesting (the brief recomputes
`_worldRectOf(key, grid)` for every `(handle, tile)` pair). Same answer, and
`touched` is small while the tile set is 130 in the rig and 154 at production
tile size.

Steady state is unaffected: `applyChange` runs once per edit, never per frame.

---

## 3. The failing run (Step 2), verbatim

Twenty-two errors, one per use of the four members the task produces. Head and
tail, unedited:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
00:00 +0: loading .../test/tile_invalidation_test.dart
test/tile_invalidation_test.dart:70:25: Error: The method 'tilesHolding' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing method, or defining a method named 'tilesHolding'.
    return oracle.cache.tilesHolding(handle);
                        ^^^^^^^^^^^^
test/tile_invalidation_test.dart:114:15: Error: The method 'applyChange' isn't defined for the type 'TileCache'.
    rig.cache.applyChange(
              ^^^^^^^^^^^
test/tile_invalidation_test.dart:121:24: Error: The method 'holds' isn't defined for the type 'TileCache'.
      expect(rig.cache.holds(key), isFalse, reason: 'old position, $key');
                       ^^^^^
test/tile_invalidation_test.dart:137:22: Error: The getter 'invalidationCount' isn't defined for the type 'TileCache'.
    expect(rig.cache.invalidationCount, before - rig.cache.liveTileCount,
                     ^^^^^^^^^^^^^^^^^
...
00:00 +0 -1: Some tests failed.

Failing tests:
  .../test/tile_invalidation_test.dart: loading .../test/tile_invalidation_test.dart
```

Full transcript: `scratchpad/step2-failing.txt`.

---

## 4. The fixture, measured rather than asserted

Before trusting six green tests that passed on the first run, the fixture was
probed with a throwaway test that printed every set. At `tileCamera()`
(`x -> 1.4x - 37`, `y -> 323 - 1.4y`), a 64 device-pixel tile at `dpr` 2, and
the 400x300 viewport:

```
live=130
1001 old 6: (0,7) (0,8) (0,9) (1,7) (1,8) (1,9)
300  old 4: (0,3) (0,4) (1,3) (1,4)
301  old 4: (8,3) (8,4) (9,3) (9,4)
1002 old 8: (0,3) (0,4) (1,3) (1,4) (8,3) (8,4) (9,3) (9,4)
9999 old 0:
1001 new 6: (3,7) (3,8) (3,9) (4,7) (4,8) (4,9)
after leaf edit live=118 inval=12
300 old 4: (0,3) (0,4) (1,3) (1,4)
300 new 4: (5,7) (5,8) (6,7) (6,8)
after drag live=122 before=130 inval=8
```

Every number matches the hand-derivation. 130 tiles, so anti-degenerate clause
3 is satisfied by a factor of four over the brief's `> 30`. The two placements
of `PLATE` are eight tile columns apart. `tilesHolding(Handle(9999))` is empty,
so the binary search is not answering "yes" to everything.

**A deviation from the brief's fixture, and the reason for it.** The brief's
leaf edit is `(20,20)-(60,60)` to `(20,20)-(55,58)`: a shortening, entirely
inside the tiles the line already occupied. The brief itself flags this against
M2 — "if it survives, the fixture's edit does not move the leaf into a new
tile; widen it" — but widening it into an *extension* is the other half of the
same trap, and the brief does not flag that half. An extension makes the new
tile set a **superset** of the old, and then deleting the old-position loop
drops the same tiles by direction two and M1 survives silently. Only a **move**
separates the two directions. Every edit in the file is therefore a move —
`(20,20)-(60,60)` to `(100,20)-(140,60)`, and the instance from `(30,120)` to
`(150,40)` — and **every test asserts `newTiles.intersection(oldTiles) is
empty` before it asserts anything about invalidation**. That guard is what
makes M1 and M2 separable mutants rather than two names for one, and it is
checked at runtime rather than trusted to the author's arithmetic.

The new-position tile set is not hand-computed. It comes from `tilesFor`, a
second `TileRig` painted over the same document after the edit: same camera,
`dpr` and tile size, therefore the same lattice and comparable keys. The
alternative — a screen rectangle worked out in the test file — would have to
reproduce the painter's own index query and the index's narrow-phase slack, and
could not.

The brief's numeric bound `greaterThan(before - 12)` was replaced. Twelve tiles
is exactly what a move costs (six old + six new), so the brief's bound is
satisfied only by an edit small enough not to redden M2. The replacement says
what the criterion is actually for, and names it: every tile of the far
placement `Handle(301)` must still be held, plus a coarse
`greaterThan(before ~/ 2)`, plus `invalidationCount == before - liveTileCount`.
A generation drop fails the first of those on the tile it names.

---

## 5. The passing run (Step 5), verbatim

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
00:00 +0: loading .../test/tile_invalidation_test.dart
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: criterion 5: a dragged instance drops the tiles it left
00:00 +2: criterion 5: the undo of an instance transform invalidates both ends
00:00 +3: criterion 6: a definition edit drops the generation, and less does not
00:00 +4: criterion 9: all five change arms, none omitted
00:00 +5: criterion 9: a load starts a new generation, an edit does not
00:00 +6: All tests passed!
```

Both packages, green:

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +797: All tests passed!
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.20 seconds.

$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:05 +336 ~1: All tests passed!
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 62 files (0 changed) in 0.11 seconds.
```

The `~1` is the pre-existing skip, not new.

`git status` before staging showed only the two intended paths; no
`analysis_options.yaml` was touched despite four `flutter pub get` runs. Staged
by explicit path.

---

## 6. Mutants

Method throughout, per the standing rule: `cp lib/src/tile_cache.dart <scratch>/tile_cache.dart.bak`
once, mutate with a python `assert`-guarded string replacement (so a mutation
that failed to apply is an error rather than a green run), restore by copying
the backup **back over** the file — never `git checkout` — and `diff` the two to
prove the restore. Every restore below printed `RESTORE CLEAN`, which is the
`diff` producing no output. M16 needed `draft_painter.dart` as well; it was
backed up and restored the same way.

### M1 — delete the old-position loop. **Red.**

Deleted the `for (final entry in _baked.entries)` block outright.

```
00:00 +0 -1: criterion 5: a leaf edit invalidates its own tiles and no others [E]
  Expected: false
    Actual: <true>
  old position, TileKey(0, 7)
  test/tile_invalidation_test.dart 121:7              main.<fn>

00:00 +0 -2: criterion 5: a dragged instance drops the tiles it left [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(0, 3)
  test/tile_invalidation_test.dart 171:7              main.<fn>

00:00 +0 -3: criterion 5: the undo of an instance transform invalidates both ends [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(5, 7)
  test/tile_invalidation_test.dart 207:7              main.<fn>

00:00 +3 -3: Some tests failed.
```

Criterion 5, both of the brief's tests plus the undo arm — exactly the row the
brief names. Restored, `RESTORE CLEAN`, six green.

### M2 — delete the new-position loop. **Red.**

Replaced the direction-two sweep with a call kept behind `grid.tileDevicePixels < 0`,
so `_worldRectOf` stays referenced and the mutant is the missing *sweep* rather
than an unused-method analyzer error.

```
00:00 +0 -1: criterion 5: a leaf edit invalidates its own tiles and no others [E]
  Expected: false
    Actual: <true>
  new position, TileKey(3, 7)
  test/tile_invalidation_test.dart 126:7              main.<fn>

00:00 +0 -2: criterion 5: a dragged instance drops the tiles it left [E]
  Expected: false
    Actual: <true>
  stale arrival at TileKey(5, 7)
  test/tile_invalidation_test.dart 174:7              main.<fn>

00:00 +0 -3: criterion 5: the undo of an instance transform invalidates both ends [E]
  Expected: false
    Actual: <true>
  stale arrival at TileKey(0, 3)
  test/tile_invalidation_test.dart 210:7              main.<fn>

00:00 +3 -3: Some tests failed.
```

`TileKey(3, 7)` is in `1001 new` and not in `1001 old`; `TileKey(5, 7)` is in
`300 new` and not in `300 old`. The brief's contingency ("if it survives,
widen it") was not needed **because the fixture was built as a move rather than
a shrink or an extension** — see §4. Restored, `RESTORE CLEAN`.

### M5 — `_isDefinitionOwned` always false. **Red.**

`if (true) return null;` at the top of `_enclosingDefinition`.

```
00:00 +3 -1: criterion 6: a definition edit drops the generation, and less does not [E]
  Expected: <0>
    Actual: <121>
  a definition edit changes every instance of it, so tile-level invalidation by definition is exact rather than coarse
  test/tile_invalidation_test.dart 234:5              main.<fn>

00:00 +3 -2: criterion 9: all five change arms, none omitted [E]
  Expected: <0>
    Actual: <122>
  test/tile_invalidation_test.dart 265:5              main.<fn>

00:00 +4 -2: Some tests failed.
```

Criterion 6, the row the brief names, plus criterion 9 (which routes its arms
through a definition-owned handle by design). `121` and `122` rather than `130`
is the tell: without the definition path the per-tile path still drops the eight
or nine tiles the edited leaf actually occupies, and leaves every other instance
of the block stale. Restored, `RESTORE CLEAN`.

### M12 — the redo arm. **Finding: the brief's literal mutant does not compile.**

The brief says "delete the `CommandRedone()` arm from the switch". Fired
literally:

```
lib/src/tile_cache.dart:379:13: Error: The type 'DocChange' is not exhaustively matched by the switch cases since it doesn't match 'CommandRedone()'.
 - 'DocChange' is from 'package:jet_cad_2d/src/document/doc_change.dart'
Try adding a default case or cases that match 'CommandRedone()'.
    switch (change) {
            ^
00:00 +0 -1: Some tests failed.
```

`DocChange` is `sealed`, and Dart 3 makes a non-exhaustive switch **statement**
over a sealed type a compile-time error. So the omission the brief describes
cannot reach a test at all — the compiler catches it, which is strictly
stronger than a red test, but it is not evidence that criterion 9's redo row
can see anything. **Reported rather than counted as a kill.** This is also why
the switch is written without a `default:` and why that choice is now documented
on `applyChange`: a `default:` arm would restore the silent-omission failure
mode that `SpatialIndex._onChange` avoids the same way.

**M12b — the arm present and doing nothing.** The defect a real cache would
have, and the one criterion 9's redo row is chartered against: the switch stays
exhaustive, `CommandRedone` gets its own arm, and the arm returns.

```dart
      case CommandRedone():
        return; // M12b: the redo arm is present, and does nothing.
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
```

```
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: criterion 5: a dragged instance drops the tiles it left
00:00 +2: criterion 5: the undo of an instance transform invalidates both ends
00:00 +3: criterion 6: a definition edit drops the generation, and less does not
00:00 +4: criterion 9: all five change arms, none omitted
00:00 +4 -1: criterion 9: all five change arms, none omitted [E]
  Expected: <0>
    Actual: <130>
  the arm an undo-only gate never sees
  test/tile_invalidation_test.dart 269:5              main.<fn>

00:00 +5 -1: Some tests failed.
```

**Criterion 9's redo row only** — the brief's stated target — and the failure
carries the reason string written for exactly this. The apply and undo rows
above it stayed green, which is what proves the row is specific to redo rather
than to the switch as a whole.

*A first attempt at M12b was malformed and is recorded here because it is
instructive:* inserting the no-op arm **after** the existing
`CommandApplied`/`CommandUndone` case labels made those two labels fall into
the no-op body, so all five tests went red. That is a mutant that broke three
arms, not one, and it would have "killed" criterion 9 for the wrong reason. It
was corrected to the form above before anything was recorded as a result.
Restored, `RESTORE CLEAN`.

### M16 — collect only leaves. **Red, and the test was strengthened because of it.**

Applied where the brief means it — `draft_painter.dart`, the two node call
sites at `:401` (`_drawInstance`) and `:485` (`_descend`). The two leaf sites at
`:374` and `:454` were left alone, so the cache records leaves and nothing else.

```
00:00 +0 -1: criterion 5: a leaf edit invalidates its own tiles and no others [E]
  Expected: non-empty
    Actual: Set:[]
  test/tile_invalidation_test.dart 99:5               main.<fn>

00:00 +0 -2: criterion 5: a dragged instance drops the tiles it left [E]
  Expected: non-empty
    Actual: Set:[]
  a tile that never recorded the node cannot find the pixels a drag left behind, and the ghost is invisible to every leaf-handle test
  test/tile_invalidation_test.dart 151:5              main.<fn>

00:00 +0 -3: criterion 5: the undo of an instance transform invalidates both ends [E]
  Expected: non-empty
    Actual: Set:[]
  test/tile_invalidation_test.dart 196:5              main.<fn>

00:00 +3 -3: Some tests failed.
```

The brief's target — criterion 5's dragged-instance test — is red, and with the
reason string written for it.

**But it dies on the fixture guard, not on an invalidation assertion**, and
that is the shape this plan has been bitten by three times: a criterion whose
red is a statement about the fixture rather than about the machine. `tilesHolding(Handle(300))`
returning empty is a true and relevant fact, but a reader could reasonably ask
whether anything downstream of it would have noticed.

So the test now also names the ghost **without going through the node's own
record**: `tilesHolding(Handle(1002)).difference(tilesHolding(Handle(301)))` —
the tiles carrying this definition's pixels other than the far placement's.
Under the correct implementation that is `{(0,3),(0,4),(1,3),(1,4)}`, instance
300's four tiles, and all four are dropped. Under M16 `tilesHolding(301)` is
empty, so the set is all eight and the assertion demands more, not less. It is
monotone in the right direction: the mutant cannot shrink its way out.

Proved rather than argued. A throwaway test reproduced the drag with the
node-record guard removed, so the ghost assertion was reached:

```
=== under M16 ===
leafTiles=8 ghostTiles=8
00:00 +0 -1: ghost tiles alone [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(0, 3)
  test/zz_m16_probe_test.dart 39:7                    main.<fn>

=== control, restored tree ===
leafTiles=8 ghostTiles=4
00:00 +1: All tests passed!
```

Eight ghost tiles demanded and four still held under M16; four demanded and
zero held under the real implementation. The strengthened assertion is
independently sensitive. Probe deleted; painter restored, `PAINTER RESTORE CLEAN`;
cache verified untouched, `CACHE RESTORE CLEAN`.

---

## 7. Deviations from the brief, collected

1. **`_isDefinitionOwned` climbs the owner chain** instead of testing the
   immediate owner. A leaf under a group inside a definition is definition-owned
   and the one-level test says it is not. §1.
2. **`_worldBoxOf` names an instance's definition explicitly.**
   `definitionBounds` on an instance handle returns an empty box silently —
   direction two would have skipped every instance and dropped nothing. §1.
3. **Direction two derives the boxes once, ahead of the tile sweep**, rather
   than calling `_worldBoxOf` and `_worldRectOf` per `(handle, tile)` pair. Same
   answer, O(tiles) instead of O(tiles x touched). §2.
4. **Every fixture edit is a move, and disjointness is asserted at runtime.**
   The brief's edit is a shrink (M2 could not fire); the obvious repair is an
   extension (M1 could not fire). Only a move separates them. §4.
5. **The `greaterThan(before - 12)` bound was replaced** by a named assertion —
   every tile of the far placement survives — plus a coarse count bound and a
   counter identity. Twelve is what a move costs, so the brief's bound is only
   satisfiable by an edit too small to redden M2. §4.
6. **M12 as literally specified is a compile error**, not a red test; the
   semantic equivalent (arm present, does nothing) was fired instead and is the
   recorded kill. §6.
7. **The dragged-instance test gained an assertion** that names the ghost
   without going through the node record, so M16 dies on an invalidation
   assertion and not only on the fixture guard. §6.
8. **Two tests were added** beyond the brief's four: the undo of an instance
   transform (anti-degenerate clause 5 asks for the transform *and* its undo,
   and the brief's file only had the transform), and `_dropEverything` versus
   `_dropGeneration` — a load bumps `generation` on the next frame, a definition
   edit does not. Nothing else in the file distinguishes the two, and the
   distinction is the brief's own ruling.

---

## 8. Known residual, recorded not papered over

`_worldBoxOf` returns a **geometric** bound. A bake's index query is widened by
the index's narrow-phase slack — roughly half a stroke width — so a tile whose
bake drew a hairline spilling in from just outside its world rect is not found
by direction two. Direction one catches this wherever the handle was already in
the tile. What remains is a handle *arriving* at a position that misses a tile
geometrically while its stroke clips into it, bounded by half the stroke width
in world units.

It was not closed by inflating the tile rect, because there is no principled
number available here: the index's `_margin` is private, and any constant would
be either wrong or so coarse it would drop the eight neighbours of every
affected tile — which is most of the cache, most of the time. Documented on
`_worldBoxOf` and raised here for whoever owns the eviction and carry-over
tasks, since a tile-level query against the index would close it exactly.

---

# Fix round 1

Commit: `a9f60a5` — *fix: a dragged group left ghosts, and the tile record said
otherwise*. Six findings, all addressed; three of them changed shipped
behaviour, three were corrections to claims.

Files touched this round:
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`,
`packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`,
`packages/jet_cad_2d_flutter/test/support/fixtures.dart`.

---

## C1 (Critical) — a dragged group left ghosts

**Confirmed before touching anything.** The reviewer's probe reproduced exactly:

```
$ CI=true flutter test test/zz_c1_probe_test.dart
groupTiles=[]
leafTiles=[TileKey(9, 0), TileKey(10, 0), TileKey(9, 1), TileKey(10, 1)]
inval=4
old leaf tile TileKey(9, 0) still held: true
old leaf tile TileKey(10, 0) still held: true
old leaf tile TileKey(9, 1) still held: true
old leaf tile TileKey(10, 1) still held: true
```

`groupTiles=[]` — no group handle was ever recorded. `inval=4` — direction two
fired on the arrival tiles and direction one found nothing, so the four
departure tiles kept their pixels. This is the M16 defect in shipped code,
presenting as the M2-only-survivor state.

**Mechanism, verified in the tree.** `debugOnVisit` has four call sites. The two
node sites, `draft_painter.dart:401` (`_drawInstance`) and `:485` (`_descend`),
are both preceded by `if (node is! InstanceNode) return;` — so only instances
reach the callback. A group is never "descended into" as far as the painter is
concerned at all: `ContainerIndex.build` flattens a group's leaves into its
container's leaf list with a composed transform, so the group's *leaves* are
visited and the group itself is invisible. `TransformNodeCommand` accepts a
`GroupNode` (`commands.dart:297-300`) and returns `touched: {handle}`, so the
group handle is the only thing the change carries and the only thing no tile
recorded.

**Fixed by including groups, per the reviewer's preference.** `_bake` now walks
each visited handle's owner chain rather than trusting the callback to be
complete:

```dart
final containers = <int>{};
final document = painter.document;

void recordOwners(Handle from) {
  var current = from;
  while (true) {
    final node = document.tree[current];
    if (node == null) return;                 // a definition handle
    if (!containers.add(current.value)) return;
    visited.add(current.value);
    if (node.parent.isNone) return;
    current = node.parent;
  }
}
```

and the visit callback dispatches on what the handle is: a leaf climbs from
`entities.ownerAt(slot)`, an instance node climbs from its own `parent`.

Three properties worth naming. `containers` is both the memo and the
termination guard — once a node is in, every ancestor of it is in too, so the
climb stops there; that keeps the pass linear in visits rather than
O(visits x depth), and it makes a malformed cyclic parent chain terminate
instead of hanging the bake. The climb stops at a definition handle
(`tree[current] == null`), because a definition is not a placement and an edit
inside one takes the generation-drop path. And the root is a `GroupNode` like
any other, so it is recorded too, which means a transform of the root reaches
every tile through direction one.

**Chosen in the cache rather than in the painter** so that M16 stays a valid
mutant. A leaf inside a definition has the *definition* as its owner, not the
instance placing it, so the owner chain cannot recover an instance handle — M16
re-fired below and still reddens.

**`_baked`'s doc comment was false and now says the true thing.** It claimed
"every leaf drawn and every container descended". It now states which handles
the painter supplies, which it does not and why (`node is! InstanceNode` at both
sites), and that the owner walk exists precisely because the callback is not
complete.

**Covering test:** `criterion 5: a dragged group leaves no ghost either`. The
fixture matrix gained a root-level group — **no fixture in the file had one**,
which is why three passes missed this. `addGroup` was added to
`test/support/fixtures.dart` beside `addInstance`, with a doc comment saying
what makes a group different from an instance for anything watching the painter.

Group 400 is placed at tile columns 9-10, rows 0-1 — measured free space against
instance 300's 0-1 x 3-4, instance 301's 8-9 x 3-4 and leaf 1001's 0-1 x 7-9. A
probe confirmed every pre-existing tile set is byte-for-byte unchanged by the
addition, and that the group now records exactly its leaf's tiles:

```
live=130
1001 -> 6: (0,7) (0,8) (0,9) (1,7) (1,8) (1,9)
300  -> 4: (0,3) (0,4) (1,3) (1,4)
301  -> 4: (8,3) (8,4) (9,3) (9,4)
1002 -> 8: (0,3) (0,4) (1,3) (1,4) (8,3) (8,4) (9,3) (9,4)
400  -> 4: (10,0) (10,1) (9,0) (9,1)
1003 -> 4: (10,0) (10,1) (9,0) (9,1)
9999 -> 0:
```

The test states its criterion on **leaf 1003's** tiles, not on
`tilesHolding(Handle(400))` — the same lesson as M16 in round 1. Leaf 1003 is
what is on screen; the group is only what moves it. A cache recording no group
handle would trip a `tilesHolding(400)` guard first, and a reader could dismiss
that as a fixture problem; stated on the pixels, the failure is unambiguous.

**Gating mutant G1** — the fix reverted, the owner chain not recorded:

```
00:00 +2 -1: criterion 5: a dragged group leaves no ghost either [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(9, 0): the group's pixels are still there and the group that put them there has moved
  test/tile_invalidation_test.dart 275:7              main.<fn>

00:00 +2 -2: criterion 6: a group and an instance nested inside a definition [E]
  Expected: non-empty
    Actual: []
  a group inside a definition must be findable
  test/tile_invalidation_test.dart 302:7              main.<fn>.expectWholeDrop

00:00 +6 -2: Some tests failed.
```

Red on the pixel assertion, not on a guard. Restored, `RESTORE CLEAN`.

---

## I2 (Important) — the `_enclosingDefinition` climb was ungated

Correct on both counts. Reducing the method to its first line left all 336 tests
green, and my justification misread the tree: `differentialFixture`'s
`Handle(520)` is an `InstanceNode` whose `parent` **is** the definition `outer`
(`fixtures.dart:88-97`), which `chain.isEmpty ? container : chain.last` already
resolves at the first level. No leaf-under-a-group-inside-a-definition exists
anywhere in this repository. The claim in round 1's §1 was wrong; the code was
right for the wrong stated reason.

**Built the shape rather than only re-wording the comment.** A new
`nestedFixture` carries both shapes that need the climb:

* a **group inside a definition** (410, parent 210) owning leaf 1005;
* an **instance inside a definition** (320, parent 210) placing a second
  definition 220, which owns leaf 1004.

Measured, both under both root placements of `PLATE`:

```
1005 -> 2: (0,3) (8,3)      410 -> 2: (0,3) (8,3)
1004 -> 2: (1,4) (9,4)      320 -> 2: (1,4) (9,4)
```

**Covering test:** `criterion 6: a group and an instance nested inside a
definition`, which runs three handles — 1005, 410 and 320 — through
`expectWholeDrop`. Each asserts the handle is findable, asserts it occupies
strictly fewer tiles than the cache holds (so a per-tile answer would be
*visibly* wrong rather than accidentally right), and then requires
`liveTileCount == 0`.

**Gating mutant G2** — the climb reduced to its first line:

```
00:00 +3 -1: criterion 6: a group and an instance nested inside a definition [E]
  Expected: <0>
    Actual: <128>
  a leaf under a nested group is inside a definition
  test/tile_invalidation_test.dart 310:7              main.<fn>.expectWholeDrop

00:00 +7 -1: Some tests failed.
```

`128` of 130 is the tell: the per-tile path drops the two tiles the leaf itself
occupies and leaves every other placement of the block stale. Restored,
`RESTORE CLEAN`.

The doc comment on `_enclosingDefinition` now says plainly which case the test
covers, which shape does *not* exist elsewhere in the repository, and why
`Handle(520)` is not an example of it.

---

## I3 (Important) — `definitionBounds` called without `leavesByOwner`

Correct, and the report's allocation table was wrong because of it.
`draft_document.dart:160-175` states it outright: the parameter replaces "a full
entity-store scan", and "a caller building many of these in one pass must pass
it". Round 1 called it with one argument at both sites.

Threaded, derived at most once per change and only when a node handle is
actually present:

```dart
Map<Handle, List<int>>? leavesByOwner;
for (final handle in touched) {
  if (leavesByOwner == null && document.tree[handle] != null) {
    leavesByOwner = document.leavesByOwner();
  }
  final box = _worldBoxOf(document, handle, leavesByOwner);
  ...
}
```

`_worldBoxOf` takes the map as a third parameter and hands it to both
`definitionBounds` calls.

**Corrected allocation table** — this supersedes the per-tile row in §2:

| arm | cost |
|---|---|
| `DocumentLoaded`, `DocumentPurged`, empty `touched` | two map clears, no allocation |
| definition-owned `touched` | the same |
| per-tile path, leaf handles only | one `Set<TileKey>`, one `List<Aabb2>`, one `EntityRecord` + `GeometryPayload` per touched leaf, and one `Aabb2` + one four-element `List<Vector2>` per live tile |
| per-tile path, **any node handle in `touched`** | the above, plus **one** `leavesByOwner()` scan — O(live entities), once per change, not once per handle — plus a `definitionBounds` container walk per touched node handle (internally memoised within each call) |

Before this change the O(live entities) scan ran **once per touched node
handle**. Round 1's report advertised the sweep as O(tiles); that was true of
the tile loop and false of the whole, and the sentence is retracted here.

Per bake, the C1 fix adds one `Set<int>` and the owner-chain entries. The frame
path is still untouched: `onVisit` is null at the live fallback, and
`paint_allocation_test.dart` is green in the full run below.

---

## Three Minors — all corrections to claims

**M-a. "all three non-bake call sites" — there is one.** `_drawInto` is called
twice in the whole file: once from `_bake` with the collector, and once from
`paintFrame`'s live-fallback path with `null`. The comment in `_bake` and §2 of
this report both now say "the only other call into `_drawInto`, the live
fallback in `paintFrame`".

**M-b. `DocumentPurged` -> `_dropEverything` was unpinned.** Confirmed:
downgrading it to `_dropGeneration()` stayed green, because both arms leave zero
tiles and only the *next* frame's generation distinguishes them. The
`criterion 9: a load starts a new generation` test now asserts the purge arm
too, and says in a comment why it needs its own assertion.

Gating mutant **G3** — purge downgraded to `_dropGeneration`:

```
00:00 +7 -1: criterion 9: a load starts a new generation, an edit does not [E]
  Expected: <3>
    Actual: <2>
  a purge rewrites the entity store wholesale
  test/tile_invalidation_test.dart 447:5              main.<fn>
```

Restored, `RESTORE CLEAN`.

**M-c. `_childrenOf` is at `draft_document.dart:331-341`**, not 329-341. §1 of
this report cited it wrongly; corrected here.

---

## Round 1's five mutants, re-fired against the changed code

The C1 fix changes what `_baked` contains, so every earlier kill was re-run
rather than assumed. Same method: `cp` aside, mutate, `diff` to prove the
restore, never `git checkout`.

| mutant | tests reddened | verdict |
|---|---|---|
| M1 — old-position loop deleted | leaf edit, dragged instance, **dragged group**, undo | still red, and now on one more test |
| M2 — new-position loop deleted | leaf edit, dragged instance, **dragged group**, undo | still red |
| M5 — `_isDefinitionOwned` always false | criterion 6 (both), criterion 9 | still red |
| M12b — redo arm present and doing nothing | criterion 9 only | still red, still exactly one test |
| M16 — node call sites removed from the painter | leaf edit, dragged instance, undo, **nested definitions** | still red |

The one worth reading twice: **M16 leaves the dragged-*group* test green.** That
is correct and is the separation the C1 fix was designed to keep. A group is
recovered from the owner chain, which M16 does not touch; an instance is
recovered only from the painter callback, which M16 removes. Two independent
mechanisms, two independent mutants, neither masking the other.

Restores verified: `RESTORE CLEAN` after each cache mutant, and
`PAINTER RESTORE CLEAN` plus `CACHE RESTORE CLEAN` after M16.

---

## Green, both packages

```
$ cd packages/jet_cad_2d && CI=true dart test
00:12 +797: All tests passed!
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.47 seconds.
fmt exit=0

$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:24 +338 ~1: All tests passed!
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 62 files (0 changed) in 0.23 seconds.
fmt exit=0
```

338, up from 336: the two new tests. The `~1` is the pre-existing skip.

The invalidation file itself:

```
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: criterion 5: a dragged instance drops the tiles it left
00:00 +2: criterion 5: a dragged group leaves no ghost either
00:00 +3: criterion 6: a group and an instance nested inside a definition
00:00 +4: criterion 5: the undo of an instance transform invalidates both ends
00:00 +5: criterion 6: a definition edit drops the generation, and less does not
00:00 +6: criterion 9: all five change arms, none omitted
00:00 +7: criterion 9: a load starts a new generation, an edit does not
00:00 +8: All tests passed!
```

`git status` before staging listed exactly the three intended paths and nothing
else; no `analysis_options.yaml` despite the `flutter pub get` on every run.
Staged by explicit path.

---

## What this round says about the method

The C1 defect survived a test file written specifically to hunt it, a mutation
matrix that named the exact failure mode (M16), and a report that explained the
mechanism at length. It survived because **every fixture in the file was built
from leaves and instances**, and the one container kind the painter treats
differently was absent. M16 mutated the painter to *simulate* the missing-node
case; a group made it real, and the real one was already there.

The lesson is narrower than "add more fixtures": a mutant that simulates a
condition is not evidence that no unmutated code exhibits it. M16 asked "what
if node handles were not recorded?" and the honest follow-up — "is there a node
kind that already is not?" — was never asked. The `_baked` doc comment asserted
the answer instead of checking it, and an assertion in a comment is exactly the
kind of gate that cannot see what it claims to measure.
