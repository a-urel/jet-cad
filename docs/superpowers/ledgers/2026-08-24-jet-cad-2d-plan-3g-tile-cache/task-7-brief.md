## Task 7: Invalidation — two directions, five change arms, and the node list

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Create: `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`

**Interfaces:**
- Consumes: `DraftPainter.debugOnVisit`, `TileGrid.destRectFor`.
- Produces: `TileCache.applyChange(DocChange change, DraftDocument document)`, `TileCache.invalidationCount`, `TileCache.tilesHolding(Handle)` (test-only).

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`:

```dart
// Criteria 5, 6 and 9.
//
// `DocChange` has five subclasses and five emitters -- `CommandApplied`,
// `CommandUndone`, `CommandRedone`, `DocumentLoaded` and `DocumentPurged`, at
// `undo.dart:112`, `:140`, `:161`, `:169` and `:178`. A cache that handles
// apply and undo and forgets redo shows stale pixels after every redo while
// passing an undo-only gate, so all five are here.
//
// Every fixture reaches a definition, per anti-degenerate clause 4, and the
// matrix includes an instance transform and its undo, per clause 5:
// `TransformNodeCommand` reports only the moved node's handle
// (`commands.dart:304`) and the leaves it moved keep their own.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/fixtures.dart';
import 'support/tile_fixture.dart';

/// A root leaf on the left, and a definition placed twice: once on the left,
/// once far to the right. Left and right are many tiles apart at a 64
/// device-pixel tile, so "did the other side survive" is a real question.
DraftDocument instancedFixture(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  addLine(doc, doc.rootHandle, const Handle(1001), 20, 20, 60, 60);
  addDefinition(doc, const Handle(210), 'PLATE');
  addLine(doc, const Handle(210), const Handle(1002), 0, 0, 25, 25);
  addInstance(doc, doc.rootHandle, const Handle(300), const Handle(210),
      Transform2(1, 0, 0, 1, 30, 120));
  addInstance(doc, doc.rootHandle, const Handle(301), const Handle(210),
      Transform2(1, 0, 0, 1, 210, 120));
  return doc;
}

void main() {
  test('criterion 5: a leaf edit invalidates its own tiles and no others',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    final before = rig.cache.liveTileCount;
    expect(before, greaterThan(30));

    final holdingLeft = rig.cache.tilesHolding(const Handle(1001));
    expect(holdingLeft, isNotEmpty, reason: 'the fixture must be findable');

    rig.doc.commands.execute(SetEntityGeometryCommand(
        handle: const Handle(1001),
        coords: Float64List.fromList(<double>[20, 20, 55, 58])));
    rig.cache.applyChange(
        CommandApplied(label: 'move', touched: {const Handle(1001)}),
        rig.doc);

    expect(rig.cache.liveTileCount, lessThan(before),
        reason: 'something was dropped');
    expect(rig.cache.liveTileCount, greaterThan(before - 12),
        reason: 'the far side of the drawing must survive: an edit that drops '
            'the generation passes every correctness criterion and destroys '
            'the reason the cache exists');
    for (final key in holdingLeft) {
      expect(rig.cache.holds(key), isFalse, reason: 'old position, $key');
    }
  });

  test('criterion 5: a dragged instance drops the tiles it left', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();

    // The node handle, not a leaf handle. This is the whole of M16.
    final holding = rig.cache.tilesHolding(const Handle(300));
    expect(holding, isNotEmpty,
        reason: 'a tile that never recorded the node cannot find the pixels '
            'a drag left behind, and the ghost is invisible to every '
            'leaf-handle test');

    rig.doc.commands.execute(TransformNodeCommand(
        handle: const Handle(300), transform: Transform2(1, 0, 0, 1, 30, 240)));
    rig.cache.applyChange(
        CommandApplied(label: 'drag', touched: {const Handle(300)}), rig.doc);

    for (final key in holding) {
      expect(rig.cache.holds(key), isFalse, reason: 'ghost at $key');
    }
  });

  test('criterion 6: a definition edit drops the generation, and less does not',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    expect(rig.cache.liveTileCount, greaterThan(30));

    // A leaf *inside* the definition. Anti-degenerate clause 4: a root-only
    // fixture never reaches this path at all.
    rig.doc.commands.execute(SetEntityGeometryCommand(
        handle: const Handle(1002),
        coords: Float64List.fromList(<double>[0, 0, 40, 12])));
    rig.cache.applyChange(
        CommandApplied(label: 'edit block', touched: {const Handle(1002)}),
        rig.doc);

    expect(rig.cache.liveTileCount, 0,
        reason: 'a definition edit changes every instance of it, so tile-level '
            'invalidation by definition is exact rather than coarse');
  });

  test('criterion 9: all five change arms, none omitted', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    Future<int> tilesAfter(DocChange change) async {
      final rig = TileRig(
          tileDevicePixels: 64,
          tilesBakedPerFrame: 1000,
          document: instancedFixture(measurer));
      addTearDown(rig.dispose);
      rig.paintOnce();
      expect(rig.cache.liveTileCount, greaterThan(30));
      rig.cache.applyChange(change, rig.doc);
      return rig.cache.liveTileCount;
    }

    const touched = {Handle(1002)};  // definition-owned: drops everything
    expect(await tilesAfter(const CommandApplied(label: 'a', touched: touched)),
        0);
    expect(await tilesAfter(const CommandUndone(label: 'a', touched: touched)),
        0);
    expect(
        await tilesAfter(const CommandRedone(label: 'a', touched: touched)), 0,
        reason: 'the arm an undo-only gate never sees');
    expect(await tilesAfter(const DocumentLoaded()), 0);
    expect(await tilesAfter(const DocumentPurged()), 0,
        reason: 'a purge rewrites the entity store wholesale');
    expect(
        await tilesAfter(
            const CommandApplied(label: 'whole document', touched: {})),
        0,
        reason: 'DocChange documents an empty set as "the whole document '
            'changed" (doc_change.dart:11-12)');
  });
}
```

Correct the command constructor calls against `commands.dart` before running — the tree is the authority.

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
```

- [ ] **Step 3: Implement**

In `tile_cache.dart`, hold a visit list per tile and switch on all five arms:

```dart
  /// What each tile baked: every leaf drawn and every container descended,
  /// ascending, for a binary search on change.
  ///
  /// **Both halves, and the node half is not a refinement.**
  /// `TransformNodeCommand` reports only the moved node's handle
  /// (`commands.dart:304`); the leaves it moved keep their own and appear
  /// nowhere in `touched`. A tile recording leaves alone cannot find the
  /// pixels a drag left behind.
  final Map<TileKey, Uint32List> _baked = <TileKey, Uint32List>{};

  int _invalidations = 0;
  int get invalidationCount => _invalidations;

  bool holds(TileKey key) => _tiles.containsKey(key);

  /// Every live tile whose bake touched [handle]. Test-only.
  List<TileKey> tilesHolding(Handle handle) => [
        for (final entry in _baked.entries)
          if (_contains(entry.value, handle.value)) entry.key
      ];

  static bool _contains(Uint32List sorted, int value) {
    var lo = 0, hi = sorted.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final at = sorted[mid];
      if (at == value) return true;
      if (at < value) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return false;
  }

  void applyChange(DocChange change, DraftDocument document) {
    switch (change) {
      // A purge rewrites the entity store's slots wholesale and a load
      // replaces the document; neither leaves anything worth keeping.
      case DocumentLoaded():
      case DocumentPurged():
        _dropEverything();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        if (touched.isEmpty) {
          // `DocChange.touched` is documented as empty when the whole document
          // changed (`doc_change.dart:11-12`).
          _dropEverything();
          return;
        }
        _invalidateTouched(touched, document);
    }
  }

  void _invalidateTouched(Set<Handle> touched, DraftDocument document) {
    // **A definition edit drops the generation.** If a tile baked a definition
    // and that definition changed, every instance of it in that tile changed,
    // so invalidation by definition is exact at tile granularity. The one case
    // it does not cover -- a definition whose content bounds grew, spilling an
    // instance into a tile that never baked it -- is why this is a generation
    // drop rather than a per-tile pass. A definition edit is a block edit, not
    // ordinary drawing.
    for (final handle in touched) {
      if (_isDefinitionOwned(document, handle)) {
        _dropGeneration();
        return;
      }
    }

    final grid = _grid;
    if (grid == null) return;
    final doomed = <TileKey>{};

    // Direction one: the old position. `DocChange` carries no previous
    // geometry, and this is why each tile records what it baked.
    for (final key in _baked.keys) {
      final list = _baked[key]!;
      for (final handle in touched) {
        if (_contains(list, handle.value)) {
          doomed.add(key);
          break;
        }
      }
    }

    // Direction two: the new position. Both are needed, for the reason
    // `_letBoundRecede` exists in the index.
    for (final handle in touched) {
      final box = _worldBoxOf(document, handle);
      if (box == null || box.isEmpty) continue;
      for (final key in _baked.keys) {
        if (doomed.contains(key)) continue;
        if (_worldRectOf(key, grid).intersects(box)) doomed.add(key);
      }
    }

    for (final key in doomed) {
      _tiles.remove(key)?.dispose();
      _baked.remove(key);
      _invalidations++;
    }
  }
```

`_isDefinitionOwned`, `_worldBoxOf` and `_worldRectOf` are the three helpers. Write them against the APIs the tree actually has — `DocumentTree.ancestorsOf`, `DocumentTree.definition`, `DocumentTree.accumulatedTransform`, `EntityStore.slotOf`, `EntityStore.ownerAt`, `DraftDocument.definitionBounds` — and copy `entityBounds`'s argument shape from its real call site at `container_index.dart:105-114`, which handles the `EntityKind.fill` boundary case this must handle too.

`_worldRectOf(key, grid)` inverts the anchor camera over the tile's device rect. Every corner, not two: `ViewportTransform.visibleWorld` documents why, and a rotated camera makes a two-corner box wrong.

Then in `_bake`, collect the list:

```dart
    final visited = <int>[];
    _drawInto(into, Size(side, side), grid.bakeCameraFor(key), painter, sink,
        vertices, origin, (handle) => visited.add(handle.value));
    visited.sort();
    _baked[key] = Uint32List.fromList(visited);
```

Duplicates are left in: a handle drawn twice costs one extra slot and the binary search does not care. Deduplicating would be a sweep over a list that is already the right answer.

`_dropEverything` clears the carry-over too, once Task 9 adds one; for now it is `_retireGeneration()` plus `_grid = null`. `_dropGeneration` drops the tiles and keeps the grid, so the next frame rebakes into the same lattice rather than starting a new generation — **a definition edit is not a scale change**.

- [ ] **Step 4: Run, then fire M1, M2, M5, M12 and M16**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

| mutant | change | must redden |
|---|---|---|
| M1 | delete the old-position loop | criterion 5, both tests |
| M2 | delete the new-position loop | criterion 5's leaf test — **if it survives, the fixture's edit does not move the leaf into a new tile; widen it** |
| M5 | make `_isDefinitionOwned` return `false` always | criterion 6 |
| M12 | delete the `CommandRedone()` arm from the switch | criterion 9's redo row only |
| M16 | pass `null` for `onVisit` on nodes — collect only leaves | criterion 5's dragged-instance test |

Restore from the copy after each. Record every transcript.

- [ ] **Step 5: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
git commit -m "feat: tile invalidation, in two directions and across all five change arms

DocChange has five subclasses and five emitters, and a cache that handles apply
and undo and forgets redo shows stale pixels after every redo while passing an
undo-only gate. All five are switched on exhaustively.

Each tile records what it baked: leaf handles and node handles both. The node
half is not a refinement -- TransformNodeCommand reports only the moved node's
handle and its leaves keep their own, so a tile recording leaves alone cannot
find the pixels a drag left behind, and the ghost is invisible to every
leaf-handle test.

A definition edit drops the generation rather than a set of tiles. If a tile
baked a definition and that definition changed, every instance of it in that
tile changed, so invalidation by definition is exact at tile granularity; the
generation drop covers the one case it does not, a definition whose bounds grew
and spilled an instance into a tile that never baked it."
```

---

