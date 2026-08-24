// Gap G7: nothing in Plan 3g gates what a tile's bake is allowed to contain.
//
// Mutant **M7** -- clip each tile to the viewport instead of to its own rect
// -- was fired on device in Task 12 and killed nothing. The spec called it
// "the mutation that passes every correctness gate and destroys the plan's
// entire reason for existing" and said "a suite that cannot kill it is not
// gating this plan". Criterion 10 is *structurally* blind to it (a settled
// frame reads `bakeFrames=0/60`, so the clip M7 breaks is never executed) and
// criterion 11 was already red on clean source, so no green-to-red transition
// existed anywhere. `plan-3g-mutation-log.md:445` carries both runs.
//
// **This file is the bake-time assertion that was owed**, and it is
// deliberately not another timing. A timing needs a device, needs a frame that
// actually bakes, and needs a threshold that is green before the mutation --
// three preconditions the criterion-10 and criterion-11 rows each failed one
// of. What follows instead is a structural fact about the walk, in the shape
// trap 5 recommends: the same command-time-assertion shape that proved fills
// eager in Plan 3e, after the allocation gate could not.
//
// **What it gates, precisely.** M7 has two halves, and the mutation log's own
// note (`:479`) is why both had to change: `_drawInto`'s `Size` argument is
// what the painter culls against, so **widening only the `clipRect` is a
// no-op** -- every bake would walk the same leaves, and the run would report
// "M7 changes nothing" for entirely the wrong reason. The half that carries
// the damage is therefore the walk, and the walk is what this file reads. A
// mutation that widens only the clip is left to the pixel criteria, where it
// is invisible for a stated reason: `toImageSync` crops to the tile's own
// device-pixel square, so the overflow never reaches a pixel anyone compares.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/tile_fixture.dart';

/// The nine handles [_isolatedSegments] places, in the order it places them.
const List<Handle> _segments = <Handle>[
  Handle(1000),
  Handle(1001),
  Handle(1002),
  Handle(1003),
  Handle(1004),
  Handle(1005),
  Handle(1006),
  Handle(1007),
  Handle(1008),
];

/// World-unit spacing between two neighbouring segments, on both axes.
///
/// **This number is the whole test, so here is where it comes from.** At the
/// rig's 64 device-pixel tile and [kTileDpr] of 2, a tile is 32 logical pixels
/// square. `TileCache._worldRectOf` grows a tile by [kTileSlack] -- 32.0 --
/// on every side before querying, so the rectangle one bake asks the index
/// about is 32 + 32 + 32 = **96 logical pixels** across. [tileCamera]'s scale
/// is 1.4, so that is **68.57 world units**.
///
/// For one bake to see two of these segments, its query would have to span
/// from one segment's near edge to the other's far edge: 90 + 6 = **96 world
/// units**. 96 against 68.57 leaves 27.4 world units of margin, which is what
/// makes the assertion below a fact about the code rather than about a lucky
/// rounding.
const double _spacing = 90.0;

/// Each segment's length in world units. Short on purpose: a segment longer
/// than a tile would sit on several tiles legitimately and the count below
/// would stop meaning anything.
const double _length = 6.0;

/// Nine short, well-separated segments, all of them on screen.
///
/// **Not [crossingGrid], and that is the point.** Every existing tile fixture
/// draws lines eight tiles long precisely so that boundary crossing is
/// exercised; a line that legitimately sits on twenty tiles cannot distinguish
/// a bake that stayed inside its rect from one that did not. This fixture is
/// the complement: nothing here crosses anything.
///
/// The three columns sit at world x 35, 125, 215 and the three rows at world y
/// 30, 120, 210. At [tileCamera] -- `sx = 1.4x - 37`, `sy = 323 - 1.4y` --
/// those land at screen x 12..17.6, 138..143.6, 264..269.6 and screen y 281,
/// 155, 29: every one of them inside [kTileViewport], none of them against an
/// edge. Visibility is asserted rather than assumed by the second test below.
DraftDocument _isolatedSegments(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var row = 0; row < 3; row++) {
    for (var column = 0; column < 3; column++) {
      final x = 35.0 + column * _spacing;
      final y = 30.0 + row * _spacing;
      addLine(doc, doc.rootHandle, Handle(handle++), x, y, x + _length, y);
    }
  }
  return doc;
}

/// Inverts [TileCache.tilesHolding] into the direction the claim is stated in:
/// for each tile, which of [_segments] its bake recorded.
///
/// The cache exposes only the handle-to-tiles direction, and inverting it here
/// rather than adding a tile-to-handles getter is deliberate: this plan
/// shipped two test-only mutable knobs on a production type already, and the
/// implementer's own bar was that a third should trigger revisiting the
/// design. Nine `tilesHolding` calls cost nothing and add no surface.
Map<TileKey, List<Handle>> _segmentsPerTile(TileCache cache) {
  final byTile = <TileKey, List<Handle>>{};
  for (final handle in _segments) {
    for (final key in cache.tilesHolding(handle)) {
      (byTile[key] ??= <Handle>[]).add(handle);
    }
  }
  return byTile;
}

void main() {
  test('no tile bakes geometry from beyond its own rect', () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: _isolatedSegments(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();

    final byTile = _segmentsPerTile(rig.cache);

    // The claim, stated as the arithmetic above derives it. Under M7 every
    // tile's bake walks the whole viewport, so every tile that records one of
    // these handles records all nine and this reads 9.
    for (final entry in byTile.entries) {
      expect(entry.value, hasLength(1),
          reason: 'tile ${entry.key.x},${entry.key.y} recorded '
              '${entry.value.length} of the nine isolated segments; two of '
              'them are $_spacing world units apart and a bake queries '
              '68.57 world units across');
    }
  });

  test('the fixture is on screen and the frame really baked', () {
    // The negative claim above is satisfied trivially by a cache that bakes
    // nothing, or by a fixture that is entirely off camera -- both of which
    // are this repository's dominant failure mode rather than a hypothetical.
    // This is the half that makes the first test mean something.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: _isolatedSegments(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();

    // Every one of the nine reached a bake: none of them culled, none of them
    // off screen.
    for (final handle in _segments) {
      expect(rig.cache.tilesHolding(handle), isNotEmpty,
          reason: 'segment $handle was never recorded on any tile');
    }

    // And the frame covered the viewport with many tiles rather than one, so
    // "at most one segment per tile" is a partition and not a tautology about
    // a single tile that happens to hold everything.
    expect(rig.cache.bakeCount, greaterThan(_segments.length));
  });
}
