### Task 2: `forEachLeafInBand` and `forEachInstanceInBand`

**Files:**
- Modify: `lib/src/index/spatial_index.dart` (after `forEachInstanceInRect`, before the pick section)
- Test: `test/index/band_query_test.dart`

**Interfaces:**
- Consumes: Task 1's predicates; `ContainerIndex.searchLeaves/searchInstances/boxOfLeaf/dirty/transformOfLeaf/transformOfInstance`; `_filters`, `_beginQuery/_endQuery`, `_scratch`, `_instanceScratch`, `_scratchForDepth`, `_localQueryBox`, `_composeLeafTransform` and `_lta.._ltf`, `_broadPhaseMargin()`, `_textLayout`-style text access (via `document.textMeasurer`).
- Produces (spec D8):

```dart
enum BandMode { window, crossing }
void forEachLeafInBand(Aabb2 world, BandMode mode, QueryFilter filter, void Function(int slot) visit);
void forEachInstanceInBand(Aabb2 world, BandMode mode, QueryFilter filter, void Function(Handle instance) visit);
```

- [ ] **Step 1: Write the failing tests**

`test/index/band_query_test.dart`, reusing `addEntity` from `pick_test.dart`
(copy the helper; do not import a test file). Every document is built with
`DraftDocument.empty()`; instances via `AddNodeCommand(InstanceNode(...))`
at `placement` from Task 1; groups via `AddNodeCommand(GroupNode(...))`.

1. **M-02a / M-02g truth** — `'window keeps only the enclosed line; crossing adds the straddler'`:
   three root lines at world `y = 1000`: inside `[100,1000, 120,1000]`,
   straddling `[190,1000, 230,1000]`, outside `[300,1000, 320,1000]`; band
   `Aabb2.raw(90, 990, 200, 1010)`. Window visits `{inside}`, crossing
   `{inside, straddling}`, in ascending handle order.
2. **M-02b** — `'an instance is selected where its leaf lands after the transform'`:
   definition with line `[0,0, 10,0]`; instance at `placement`; a crossing
   band around `placement.transformPoint(Vector2(5, 0))` half 1 visits the
   instance; the same band at raw `(5, 0)` visits nothing.
3. **M-02o** — `'an L-shaped block is not crossed by a band in the empty quadrant of its box'`:
   definition with lines `[0,0, 10,0]` and `[0,0, 0,10]`; instance at
   `Transform2.translation(500, 700)` composed with a 30° rotation and ×1.5;
   band at the world image of local `(7, 7)` half 1 → crossing visits
   nothing; band at the image of `(5, 0)` → visits the instance.
4. **M-02s** — `'the window band sees a leaf edited since the last rebuild'`:
   the M-02a fixture; `SetEntityGeometryCommand(straddler, pl([100,1020,
   120,1020]))` moves the straddler inside; **no** rebuild; window visits
   `{inside, straddler}`.
5. **M-02t** — `'a grouped leaf inside a definition uses the group transform too'`:
   definition `def`; `GroupNode(handle: g, parent: def, transform:
   Transform2.translation(40, 0))` added via `AddNodeCommand`; leaf
   `addEntity(doc, g, line, [0,0, 10,0])`; instance of `def` at
   `placement`; band around `placement.transformPoint(Vector2(45, 0))` half
   1 → visits the instance; band around `placement.transformPoint(Vector2(5,
   0))` → nothing.
6. **M-02u** — `'a fill slot is never reported'`: `AddRegionCommand.allocate`
   (copy the `region()` helper's arguments from
   `test/document/region_command_test.dart`, with `squareLoop()` from
   there); crossing band on the boundary's edge visits the **boundary
   slot only**; window band enclosing the region visits the boundary only.
7. **M-02z** — `'results are ascending by handle even when the tree order differs'`:
   add lines with handles allocated in the order `c, a, b` (three
   `doc.handleSeed.next()` calls taken first, then `AddEntityCommand`s in
   the order 3rd, 1st, 2nd) at x positions that put them in a different
   R-tree leaf order; assert the visit sequence is ascending.
8. **Reentrancy** — `'a nested query inside the band visitor throws'`:
   `expect(() => index.forEachLeafInBand(..., (s) => index.forEachInRect(...)), throwsA(isA<QueryReentrancyError>()))`.
9. **Filter** — `'a locked layer is skipped under picking, kept under all'`:
   put one line on a locked layer (`LayerRecord(..., locked: true)` via
   `doc.tables.layers.put`); `QueryFilter.picking()` skips it,
   `QueryFilter.all()` reports it.
10. **Differential** (spec, Testing) — `'crossing and window agree with the brute-force arm on the generated corpus'`:

```dart
final doc = generateDocument(400,
    definitionCount: 8, instanceCount: 40, nestingDepth: 2,
    mirroredFraction: 0.2, nonUniformFraction: 0.3, groupCount: 6);
final index = SpatialIndex(doc);
addTearDown(index.dispose);
final ext = doc.extents;
final rng = math.Random(0xBAD5EED);
for (var trial = 0; trial < 12; trial++) {
  final cx = ext.minX + rng.nextDouble() * (ext.maxX - ext.minX);
  final cy = ext.minY + rng.nextDouble() * (ext.maxY - ext.minY);
  final hw = 5 + rng.nextDouble() * 200, hh = 5 + rng.nextDouble() * 200;
  final band = Aabb2.raw(cx - hw, cy - hh, cx + hw, cy + hh);
  for (final mode in BandMode.values) {
    final leaves = <int>[];
    index.forEachLeafInBand(band, mode, const QueryFilter.all(), leaves.add);
    final instances = <Handle>[];
    index.forEachInstanceInBand(band, mode, const QueryFilter.all(), instances.add);
    final brute = bruteForce(doc, band, mode);   // Ruling 02-6, below
    expect(leaves.toSet(), brute.leaves, reason: '$mode trial $trial');
    expect(instances.toSet(), brute.instances, reason: '$mode trial $trial');
    expect(leaves, orderedEquals(leaves.toList()..sort((a, b) =>
        doc.entities.handleAt(a).value.compareTo(doc.entities.handleAt(b).value))));
  }
}
```

`bruteForce`: for every live root-container slot (owner is the root or a
group whose ancestors reach the root without passing an instance),
compute the leaf's world `Transform2` (`tree.accumulatedTransform(owner)`
for a group owner, identity for the root), window → `entityBounds(...)
.transformedBy(t)` enclosed; crossing → `leafTouchedByBandT`. For every
root-level `InstanceNode`, recurse into its definition's leaves and child
nodes with `t.multiply(node.transform)` (and `accumulatedTransform` for
groups inside the definition), window → every leaf's box enclosed and at
least one leaf, crossing → any leaf touched. Skip `EntityKind.fill`
everywhere. Text boxes via `textBoxOf` with `doc.textMeasurer`.

- [ ] **Step 2: Run, expect failure**

```sh
cd packages/jet_cad_2d && CI=true dart test test/index/band_query_test.dart
```

- [ ] **Step 3: Implement**

In `spatial_index.dart`, import `../geometry/band_predicates.dart`, add
`enum BandMode { window, crossing }` above the class, and inside the class
after `forEachInstanceInRect`:

```dart
  // --- band selection (spec 02, D8) ----------------------------------

  /// Root-container leaves the band selects, ascending handle order, each
  /// slot once, fills skipped. Window: the leaf's world box (tree, else
  /// dirty overlay) is enclosed. Crossing: some point of its stroke lies
  /// inside, tested after a broad phase widened by the pick margin.
  void forEachLeafInBand(Aabb2 world, BandMode mode, QueryFilter filter,
      void Function(int slot) visit) {
    final root = rootIndex;
    if (world.isEmpty) return;
    _beginQuery();
    try {
      _scratch.reset();
      final query = mode == BandMode.crossing
          ? world.expandedBy(_broadPhaseMargin().pick)
          : world;
      root.searchLeaves(query, (slot) {
        if (!_filters.acceptsEntity(slot, filter)) return;
        if (document.entities.kindAt(slot) == EntityKind.fill) return;
        if (_scratchContains(slot)) return; // tree and overlay may both report it
        if (_leafPasses(root, Transform2.identity(), slot, mode, world)) {
          _scratch.add(slot);
        }
      });
      _scratch.sortByHandle(document.entities);
      for (var i = 0; i < _scratch.length; i++) {
        visit(_scratch[i]);
      }
    } finally {
      _endQuery();
    }
  }

  /// Root-level instances the band selects, ascending, descending into the
  /// definition: window when every member leaf is enclosed (and there is at
  /// least one), crossing when any member leaf is touched.
  void forEachInstanceInBand(Aabb2 world, BandMode mode, QueryFilter filter,
      void Function(Handle instance) visit) {
    final root = rootIndex;
    if (world.isEmpty) return;
    _beginQuery();
    try {
      _instanceScratch.reset();
      // Window must consider every root instance: one whose box straddles
      // the band fails on its own, and one wholly inside is found either
      // way. The all box keeps the two walks on one rule (`_bandDescend`).
      final query = mode == BandMode.crossing
          ? world.expandedBy(_broadPhaseMargin().pick)
          : _kAllBox;
      final level = _scratchForDepth(0)..reset();
      root.searchInstances(query, (node) {
        if (_filters.acceptsNode(node, filter)) level.add(node.value);
      });
      for (var i = 0; i < level.length; i++) {
        final node = Handle(level[i]);
        final resolved = document.tree[node];
        if (resolved is! InstanceNode) continue;
        final child = _byContainer[resolved.definition];
        if (child == null) continue;
        _containerPath[0] = root.container.value;
        final r = _bandDescend(child, root.transformOfInstance(node), mode,
            world, filter, 1);
        if (r == _BandVerdict.pass) _instanceScratch.add(node.value);
      }
      _instanceScratch.sortByValue();
      for (var i = 0; i < _instanceScratch.length; i++) {
        visit(Handle(_instanceScratch[i]));
      }
    } finally {
      _endQuery();
    }
  }
```

Helpers, private, below:

```dart
  bool _scratchContains(int slot) {
    for (var i = 0; i < _scratch.length; i++) {
      if (_scratch[i] == slot) return true;
    }
    return false;
  }

  /// One leaf against the band, in world space. [toWorld] is the container's
  /// placement; the leaf's own flattened-group transform is composed on top,
  /// exactly as [_descend] does at its leaf visitor.
  bool _leafPasses(ContainerIndex index, Transform2 toWorld, int slot,
      BandMode mode, Aabb2 world) {
    _composeLeafTransform(toWorld, index.transformOfLeaf(slot));
    final kind = document.entities.kindAt(slot);
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    if (mode == BandMode.window) {
      final local = index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot);
      if (local == null || local.isEmpty) return false;
      // Boxes are stored in the container's space; lift to world.
      final box = toWorld.isIdentity
          ? local
          : local.transformedBy(toWorld);
      return boxEnclosedByBand(box, world);
    }
    TextBox? textBox;
    if (kind == EntityKind.text || kind == EntityKind.attrib) {
      final style = document.textStyleOf(document.entities.textStyleAt(slot));
      final metrics = document.textMeasurer
          .measure(text: document.entities.textAt(slot), style: style);
      textBox = textBoxOf(
          payload, document.entities.textAttrsAt(slot), style, metrics);
    }
    return leafTouchedByBand(kind, payload, _lta, _ltb, _ltc, _ltd, _lte,
        _ltf, world, textBox: textBox);
  }

  /// Window: `pass` only if every member leaf under this container is
  /// enclosed and at least one exists (nested instances must pass too);
  /// crossing: `pass` on the first leaf that is touched.
  ///
  /// **Window walks the whole container, not the band's local box.** A leaf
  /// the local box does not find lies outside the band and therefore fails
  /// window on its own; an every-leaf rule that only saw the box's subset
  /// would pass a container half outside the band.
  _BandVerdict _bandDescend(ContainerIndex index, Transform2 toWorld,
      BandMode mode, Aabb2 world, QueryFilter filter, int depth) {
    _ensurePathCapacity(depth);
    _containerPath[depth] = index.container.value;
    final Transform2 toLocal;
    try {
      toLocal = toWorld.invert();
    } on SingularTransformError {
      return _BandVerdict.empty;
    }
    final Aabb2 localQuery;
    if (mode == BandMode.window) {
      localQuery = _kAllBox;
    } else {
      localQuery = _localBandBox(toLocal, world.expandedBy(_broadPhaseMargin().pick));
    }
    var anyLeaf = false;
    var allPass = true;
    var anyPass = false;
    index.searchLeaves(localQuery, (slot) {
      if (!_filters.acceptsEntity(slot, filter)) return;
      if (document.entities.kindAt(slot) == EntityKind.fill) return;
      if (mode == BandMode.crossing && anyPass) return;
      anyLeaf = true;
      if (_leafPasses(index, toWorld, slot, mode, world)) {
        anyPass = true;
      } else {
        allPass = false;
      }
    });
    if (mode == BandMode.crossing && anyPass) return _BandVerdict.pass;
    if (mode == BandMode.window && anyLeaf && !allPass) return _BandVerdict.fail;

    final level = _scratchForDepth(depth)..reset();
    index.searchInstances(localQuery, (node) {
      if (_filters.acceptsNode(node, filter)) level.add(node.value);
    });
    var childPass = false;
    for (var i = 0; i < level.length; i++) {
      final node = Handle(level[i]);
      final resolved = document.tree[node];
      if (resolved is! InstanceNode) continue;
      final child = _byContainer[resolved.definition];
      if (child == null) continue;
      var cyclic = false;
      for (var d = 0; d <= depth; d++) {
        if (_containerPath[d] == child.container.value) {
          cyclic = true;
          break;
        }
      }
      if (cyclic) continue;
      final r = _bandDescend(child,
          toWorld.multiply(index.transformOfInstance(node)), mode, world,
          filter, depth + 1);
      if (mode == BandMode.crossing) {
        if (r == _BandVerdict.pass) return _BandVerdict.pass;
      } else {
        if (r == _BandVerdict.fail) return _BandVerdict.fail;
        if (r == _BandVerdict.pass) childPass = true;
      }
    }
    if (mode == BandMode.crossing) return _BandVerdict.fail;
    return (anyLeaf && allPass) || childPass
        ? _BandVerdict.pass
        : _BandVerdict.empty;
  }

  /// Every container-space box; window mode walks the whole container.
  static final Aabb2 _kAllBox = Aabb2.raw(
      -double.maxFinite, -double.maxFinite, double.maxFinite, double.maxFinite);
```

The same-depth scratch reuse is safe: `_scratchForDepth(depth)` is consumed
by the loop before any recursion at `depth + 1` reads its own. In
`forEachInstanceInBand`, `root.searchInstances` uses `_kAllBox` for window
and the widened band for crossing, the same rule.

`_localBandBox(Transform2 toLocal, Aabb2 world)` is `_localQueryBox`'s
four-corner pullback applied to a rectangle instead of a point ± half-size;
write it beside `_localQueryBox`.

```dart
enum _BandVerdict { pass, fail, empty }
```

`empty` (no leaves anywhere under the container) is treated as `fail` by the
callers — a container with no member leaves is never band-selected (spec
D8).

- [ ] **Step 4: Run the tests until green, then the gate line**

```sh
cd packages/jet_cad_2d && CI=true dart test test/index/band_query_test.dart
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

`query_allocation_test.dart` must still pass unedited — it does not call the
band walks, but the file was touched.

- [ ] **Step 5: Commit**

```sh
git add lib/src/index/spatial_index.dart test/index/band_query_test.dart
git commit -m "feat(index): window and crossing band walks, descending into instances"
```

---

