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
//
// **The two directions are separated by construction, not by hope.** Direction
// one drops the tiles a handle *was* baked into; direction two drops the tiles
// its new geometry *reaches*. A fixture whose edit extends a line rather than
// moving it makes the new tile set a superset of the old one, and then deleting
// the old-position loop changes nothing that any assertion can see -- M1
// survives, silently. Every edit below therefore *moves* its subject onto tiles
// it did not occupy, and each test asserts that the two sets are disjoint
// before it asserts anything about invalidation. That guard is what makes M1
// and M2 separable mutants rather than two names for one.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/fixtures.dart';
import 'support/tile_fixture.dart';

/// A root leaf on the left, and a definition placed twice: once on the left,
/// once far to the right.
///
/// At [tileCamera] the world→screen map is `x -> 1.4x - 37`, `y -> 323 - 1.4y`,
/// and a 64 device-pixel tile at `dpr` 2 is 32 logical pixels, so the two
/// placements land eight tiles apart on x: instance 300 covers tile columns
/// 0-1, instance 301 covers columns 8-9. "Did the other side survive" is
/// therefore a question the geometry can answer, and an implementation that
/// answers every edit by dropping the generation fails it.
DraftDocument instancedFixture(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  addLine(doc, doc.rootHandle, const Handle(1001), 20, 20, 60, 60);
  addDefinition(doc, const Handle(210), 'PLATE');
  addLine(doc, const Handle(210), const Handle(1002), 0, 0, 25, 25);
  addInstance(doc, doc.rootHandle, const Handle(300), const Handle(210),
      Transform2(1, 0, 0, 1, 30, 120));
  addInstance(doc, doc.rootHandle, const Handle(301), const Handle(210),
      Transform2(1, 0, 0, 1, 210, 120));
  // A group, in the top-right corner where nothing else in this fixture goes:
  // tile columns 9-10, rows 0-1, against instance 300's 0-1 x 3-4, instance
  // 301's 8-9 x 3-4 and leaf 1001's 0-1 x 7-9. A group is neither a leaf nor
  // an instance and `DraftPainter.debugOnVisit` names neither it nor anything
  // that would stand in for it, so without one in the matrix a cache can lose
  // every dragged group and stay green.
  addGroup(
      doc, doc.rootHandle, const Handle(400), Transform2(1, 0, 0, 1, 240, 190));
  addLine(doc, const Handle(400), const Handle(1003), 0, 0, 20, 20);
  return doc;
}

/// Two shapes that exist nowhere else in this repository, and that the
/// `_enclosingDefinition` climb is the only code able to classify: a **group
/// inside a definition** owning a leaf, and an **instance inside a definition**
/// placing a second definition.
///
/// Both are one step further from the definition than
/// `differentialFixture`'s `Handle(520)`, whose parent *is* the definition and
/// which a one-level test therefore already resolves. Here `tree[1005].owner`
/// is the group 410 and `tree[320].parent` is the definition only via its own
/// chain — a cache that stops at the first level calls both root-owned and
/// invalidates a handful of tiles where it must drop the generation, leaving
/// every other placement of the block stale.
DraftDocument nestedFixture(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  // A root leaf, so the drawing is not definition-owned end to end and a cache
  // that dropped everything unconditionally would still have to earn it.
  addLine(doc, doc.rootHandle, const Handle(1001), 20, 20, 60, 60);

  addDefinition(doc, const Handle(220), 'RIVET');
  addLine(doc, const Handle(220), const Handle(1004), 0, 0, 6, 6);

  addDefinition(doc, const Handle(210), 'PLATE');
  addLine(doc, const Handle(210), const Handle(1002), 0, 0, 25, 25);
  // A group *inside* the definition, owning a leaf.
  addGroup(
      doc, const Handle(210), const Handle(410), Transform2(1, 0, 0, 1, 4, 30));
  addLine(doc, const Handle(410), const Handle(1005), 0, 0, 14, 8);
  // An instance *inside* the definition, placing another definition.
  addInstance(doc, const Handle(210), const Handle(320), const Handle(220),
      Transform2(1, 0, 0, 1, 30, 6));

  addInstance(doc, doc.rootHandle, const Handle(300), const Handle(210),
      Transform2(1, 0, 0, 1, 30, 120));
  addInstance(doc, doc.rootHandle, const Handle(301), const Handle(210),
      Transform2(1, 0, 0, 1, 210, 120));
  return doc;
}

TileRig rigOver(DraftDocument document) =>
    TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000, document: document);

/// The tiles a *fresh* cache bakes [handle] into, over [document] as it stands
/// right now.
///
/// This is the oracle for direction two, and it is measured rather than
/// derived: the answer depends on the painter's own index query and on the
/// index's narrow-phase slack, neither of which a hand-computed screen
/// rectangle in this file could claim to reproduce. A second cache over the
/// same document, at the same camera, `dpr` and tile size, anchors on the same
/// lattice, so its keys are comparable with the first cache's.
List<TileKey> tilesFor(DraftDocument document, Handle handle) {
  final oracle = rigOver(document);
  try {
    oracle.paintOnce();
    return oracle.cache.tilesHolding(handle);
  } finally {
    oracle.dispose();
  }
}

GeometryPayload lineAt(double x0, double y0, double x1, double y1) =>
    GeometryPayload(
        coords: Float64List.fromList(<double>[x0, y0, x1, y1]),
        scalars: Float64List(0));

void main() {
  test('criterion 5: a leaf edit invalidates its own tiles and no others',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = rigOver(instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    final before = rig.cache.liveTileCount;
    expect(before, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport makes every '
            'claim below vacuous');

    final oldTiles = rig.cache.tilesHolding(const Handle(1001)).toSet();
    expect(oldTiles, isNotEmpty, reason: 'the fixture must be findable');
    // The far side of the drawing: instance 301, eight tile columns away from
    // anything this edit touches.
    final farTiles = rig.cache.tilesHolding(const Handle(301)).toSet();
    expect(farTiles, isNotEmpty);
    expect(farTiles.intersection(oldTiles), isEmpty,
        reason: 'the far side must be genuinely far');

    // A *move*, not an extension. See the header: an extension makes the new
    // tile set a superset of the old one and M1 becomes unobservable.
    rig.doc.commands.execute(
        SetEntityGeometryCommand(const Handle(1001), lineAt(100, 20, 140, 60)));
    final newTiles = tilesFor(rig.doc, const Handle(1001)).toSet();
    expect(newTiles, isNotEmpty);
    expect(newTiles.intersection(oldTiles), isEmpty,
        reason: 'fixture guard: unless the edit lands the leaf on tiles it did '
            'not occupy, direction one and direction two cannot be told '
            'apart and deleting either goes unnoticed');

    rig.cache.applyChange(
        const CommandApplied(label: 'move', touched: {Handle(1001)}), rig.doc);

    // Direction one: the tiles the leaf is baked into still carry its old
    // pixels, and `DocChange` carries no previous geometry, so only the tile's
    // own record of what it baked can find them.
    for (final key in oldTiles) {
      expect(rig.cache.holds(key), isFalse, reason: 'old position, $key');
    }
    // Direction two: the tiles the leaf has just moved onto have no record of
    // it at all, and would blit pixels that predate the edit.
    for (final key in newTiles) {
      expect(rig.cache.holds(key), isFalse, reason: 'new position, $key');
    }
    // And not a generation drop. An implementation that threw everything away
    // passes both loops above and destroys the reason the cache exists.
    for (final key in farTiles) {
      expect(rig.cache.holds(key), isTrue, reason: 'far side, $key');
    }
    expect(rig.cache.liveTileCount, lessThan(before),
        reason: 'something was dropped');
    expect(rig.cache.liveTileCount, greaterThan(before ~/ 2),
        reason: 'a local edit may not cost half the visible set');
    expect(rig.cache.invalidationCount, before - rig.cache.liveTileCount,
        reason: 'the counter reports what was actually dropped');
  });

  test('criterion 5: a dragged instance drops the tiles it left', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = rigOver(instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    final before = rig.cache.liveTileCount;

    // The node handle, not a leaf handle. This is the whole of M16.
    final oldTiles = rig.cache.tilesHolding(const Handle(300)).toSet();
    expect(oldTiles, isNotEmpty,
        reason: 'a tile that never recorded the node cannot find the pixels '
            'a drag left behind, and the ghost is invisible to every '
            'leaf-handle test');
    // The leaf inside the definition is recorded too, and it is *not* a
    // substitute: `touched` names 300 and never 1002.
    final leafTiles = rig.cache.tilesHolding(const Handle(1002)).toSet();
    expect(leafTiles, containsAll(oldTiles));
    // The ghost, named without going through the node's own record: the tiles
    // carrying this definition's pixels *other than* the far placement's are
    // the ones the drag is about to abandon. Stated this way the assertion
    // below survives a cache that stopped recording node handles -- it simply
    // demands more tiles be dropped, and none of them are, because `touched`
    // says 300 and nothing in a leaf-only record answers to that.
    final ghostTiles =
        leafTiles.difference(rig.cache.tilesHolding(const Handle(301)).toSet());
    expect(ghostTiles, isNotEmpty);

    rig.doc.commands.execute(TransformNodeCommand(
        const Handle(300), Transform2(1, 0, 0, 1, 150, 40)));
    final newTiles = tilesFor(rig.doc, const Handle(300)).toSet();
    expect(newTiles, isNotEmpty);
    expect(newTiles.intersection(oldTiles), isEmpty,
        reason: 'fixture guard: the drag must leave the tiles it started in');

    rig.cache.applyChange(
        const CommandApplied(label: 'drag', touched: {Handle(300)}), rig.doc);

    for (final key in ghostTiles) {
      expect(rig.cache.holds(key), isFalse,
          reason: "ghost at $key: this definition's pixels are still there and "
              'the instance that put them there has moved');
    }
    for (final key in oldTiles) {
      expect(rig.cache.holds(key), isFalse, reason: 'ghost at $key');
    }
    for (final key in newTiles) {
      expect(rig.cache.holds(key), isFalse, reason: 'stale arrival at $key');
    }
    // The *other* placement of the same definition did not move.
    for (final key in rig.cache.tilesHolding(const Handle(301))) {
      expect(rig.cache.holds(key), isTrue, reason: 'untouched sibling, $key');
    }
    expect(rig.cache.liveTileCount, greaterThan(before ~/ 2));
  });

  test('criterion 5: a dragged group leaves no ghost either', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = rigOver(instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    final before = rig.cache.liveTileCount;

    // **The pixels, named without going through the group's own record.**
    // Leaf 1003 is what is actually on screen; the group is only what moves it.
    // Stating the criterion this way is what lets it fail for a cache that
    // records no group handle at all, instead of failing on a guard that such
    // a cache would trip first and that a reader could dismiss as a fixture
    // problem.
    final ghostTiles = rig.cache.tilesHolding(const Handle(1003)).toSet();
    expect(ghostTiles, isNotEmpty);

    rig.doc.commands.execute(TransformNodeCommand(
        const Handle(400), Transform2(1, 0, 0, 1, 60, 190)));
    final newTiles = tilesFor(rig.doc, const Handle(1003)).toSet();
    expect(newTiles, isNotEmpty);
    expect(newTiles.intersection(ghostTiles), isEmpty,
        reason: 'fixture guard: the drag must leave the tiles it started in');

    // `TransformNodeCommand` on a group reports the group handle and nothing
    // else (`commands.dart:297-304`). Leaf 1003 is nowhere in this set.
    rig.cache.applyChange(
        const CommandApplied(label: 'drag group', touched: {Handle(400)}),
        rig.doc);

    for (final key in ghostTiles) {
      expect(rig.cache.holds(key), isFalse,
          reason: "ghost at $key: the group's pixels are still there and the "
              'group that put them there has moved');
    }
    for (final key in newTiles) {
      expect(rig.cache.holds(key), isFalse, reason: 'stale arrival at $key');
    }
    expect(rig.cache.liveTileCount, greaterThan(before ~/ 2),
        reason: 'and still not a generation drop');
  });

  test('criterion 6: a group and an instance nested inside a definition',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    // Both handles below sit two steps from the root: their own owner or
    // parent names neither a definition nor the root. Classifying them by
    // their immediate owner alone calls them root-owned, sends them down the
    // per-tile path, and leaves every *other* placement of the same block
    // showing the old geometry.
    Future<void> expectWholeDrop(Handle touched, String what) async {
      final rig = rigOver(nestedFixture(measurer));
      addTearDown(rig.dispose);
      rig.paintOnce();
      expect(rig.cache.liveTileCount, greaterThan(30));
      final holding = rig.cache.tilesHolding(touched);
      expect(holding, isNotEmpty, reason: '$what must be findable');
      expect(holding.length, lessThan(rig.cache.liveTileCount),
          reason: '$what occupies a few tiles, so a per-tile answer would '
              'leave most of the cache standing and be visibly wrong rather '
              'than accidentally right');

      rig.cache.applyChange(
          CommandApplied(label: what, touched: {touched}), rig.doc);
      expect(rig.cache.liveTileCount, 0,
          reason: '$what is inside a definition');
    }

    // A leaf owned by a group that is itself inside the definition.
    await expectWholeDrop(const Handle(1005), 'a leaf under a nested group');
    // The group itself.
    await expectWholeDrop(const Handle(410), 'a group inside a definition');
    // An instance inside the definition, placing a second definition.
    await expectWholeDrop(const Handle(320), 'a nested instance');
  });

  test('criterion 5: the undo of an instance transform invalidates both ends',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = rigOver(instancedFixture(measurer));
    addTearDown(rig.dispose);

    // Drag, settle, then undo -- clause 5 asks for the transform *and* its
    // undo, and the undo arm reaches the same code by a different subclass.
    rig.doc.commands.execute(TransformNodeCommand(
        const Handle(300), Transform2(1, 0, 0, 1, 150, 40)));
    rig.paintOnce();
    final draggedTiles = rig.cache.tilesHolding(const Handle(300)).toSet();
    expect(draggedTiles, isNotEmpty);

    rig.doc.commands.undo();
    final restoredTiles = tilesFor(rig.doc, const Handle(300)).toSet();
    expect(restoredTiles.intersection(draggedTiles), isEmpty,
        reason: 'fixture guard: the undo must move the instance back');

    rig.cache.applyChange(
        const CommandUndone(label: 'Move', touched: {Handle(300)}), rig.doc);

    for (final key in draggedTiles) {
      expect(rig.cache.holds(key), isFalse, reason: 'ghost at $key');
    }
    for (final key in restoredTiles) {
      expect(rig.cache.holds(key), isFalse, reason: 'stale arrival at $key');
    }
  });

  test('criterion 6: a definition edit drops the generation, and less does not',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = rigOver(instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    expect(rig.cache.liveTileCount, greaterThan(30));
    final generation = rig.cache.generation;

    // A leaf *inside* the definition. Anti-degenerate clause 4: a root-only
    // fixture never reaches this path at all. Note that the leaf's own handle
    // is all `touched` carries -- nothing in the change names the definition,
    // the instances, or the tiles they occupy.
    rig.doc.commands.execute(
        SetEntityGeometryCommand(const Handle(1002), lineAt(0, 0, 40, 12)));
    rig.cache.applyChange(
        const CommandApplied(label: 'edit block', touched: {Handle(1002)}),
        rig.doc);

    expect(rig.cache.liveTileCount, 0,
        reason: 'a definition edit changes every instance of it, so tile-level '
            'invalidation by definition is exact rather than coarse');

    // A generation drop, not a whole new generation. The grid survives, so the
    // next frame rebakes into the same lattice -- a definition edit is not a
    // scale change, and `_dropEverything` here would renumber every key and
    // throw away the carry-over Task 9 will hang off the same grid.
    rig.paintOnce();
    expect(rig.cache.generation, generation,
        reason: 'the lattice is unchanged, so the generation is unchanged');
    expect(rig.cache.liveTileCount, greaterThan(30),
        reason: 'and the next frame refills it');
  });

  test('criterion 9: all five change arms, none omitted', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    Future<int> tilesAfter(DocChange change) async {
      final rig = rigOver(instancedFixture(measurer));
      addTearDown(rig.dispose);
      rig.paintOnce();
      expect(rig.cache.liveTileCount, greaterThan(30));
      rig.cache.applyChange(change, rig.doc);
      return rig.cache.liveTileCount;
    }

    // Definition-owned: whichever arm carries it must reach the whole-drop
    // path, and an arm that quietly does nothing leaves the count untouched.
    const touched = {Handle(1002)};
    expect(await tilesAfter(const CommandApplied(label: 'a', touched: touched)),
        0);
    expect(
        await tilesAfter(const CommandUndone(label: 'a', touched: touched)), 0);
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

  test('criterion 9: a load starts a new generation, an edit does not',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = rigOver(instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    final generation = rig.cache.generation;

    // `_dropEverything` clears the grid as well as the tiles, so the next
    // frame anchors a fresh lattice; `_dropGeneration` keeps it. Nothing else
    // distinguishes the two, and criterion 6 asserts the other half.
    rig.cache.applyChange(const DocumentLoaded(), rig.doc);
    rig.paintOnce();
    expect(rig.cache.generation, generation + 1,
        reason: 'a load replaces the document, so the lattice it was anchored '
            'against means nothing');

    // And a purge, for the same reason and a different one: it renumbers every
    // slot in the entity store. Pinned separately because nothing else in this
    // file can tell `_dropEverything` from `_dropGeneration` on this arm --
    // both leave zero tiles, and only the next frame's generation says which
    // ran.
    rig.cache.applyChange(const DocumentPurged(), rig.doc);
    rig.paintOnce();
    expect(rig.cache.generation, generation + 2,
        reason: 'a purge rewrites the entity store wholesale');
  });
}
