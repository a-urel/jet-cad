# Task 5 report: Band geometry

## What changed

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`: added `TileBand`
  (value type: `row`, `keys`, `deviceRect`) and `TileGrid.bandsFor(camera,
  viewport)`, placed immediately after `visibleKeys`/`destRectFor` and before
  the `_floorDiv` helper, exactly as the brief specifies. `TileBand` is
  constructed with `keys:` before `deviceRect:` in source order, so the
  in-place sort on the row's list happens before `deviceRect` reads
  `.first.x` — the ordering the brief calls out as load-bearing. No other
  code in `tile_cache.dart` touches `bandsFor`'s output yet (Task 6 is the
  first caller).
- `packages/jet_cad_2d_flutter/test/tile_band_test.dart` (new): the three
  tests from the brief, verbatim, with one addition — `import 'dart:ui';`.
  The brief's test file as written does not import `dart:ui` but uses `Rect`
  directly; every sibling test in this directory (e.g. `tile_grid_test.dart`)
  imports it explicitly, since `jet_cad_2d_flutter.dart` does not re-export
  `dart:ui`. Added the import to match that convention. No other line
  differs from the brief.
- No changes to `lib/jet_cad_2d_flutter.dart`: it already does
  `export 'src/tile_cache.dart';`, which is sufficient — `TileBand` and
  `bandsFor` are both surfaced through that one export.
- `packages/jet_cad_2d` untouched.
- `analysis_options.yaml` not staged (checked `git status` before commit).

## RED — `CI=true flutter test test/tile_band_test.dart` (before implementing `bandsFor`/`TileBand`)

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.2 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart
test/tile_band_test.dart:47:20: Error: Undefined name 'Rect'.
    final device = Rect.fromLTWH(0, 0, kTileViewport.width * kTileDpr,
                   ^^^^
test/tile_band_test.dart:13:24: Error: The method 'bandsFor' isn't defined for the type 'TileGrid'.
 - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing method, or defining a method named 'bandsFor'.
    final bands = grid.bandsFor(camera, kTileViewport);
                       ^^^^^^^^
test/tile_band_test.dart:30:34: Error: The method 'bandsFor' isn't defined for the type 'TileGrid'.
 - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing method, or defining a method named 'bandsFor'.
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
                                 ^^^^^^^^
test/tile_band_test.dart:43:34: Error: The method 'bandsFor' isn't defined for the type 'TileGrid'.
 - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing method, or defining a method named 'bandsFor'.
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
                                 ^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart: test/tile_band_test.dart:47:20: Error: Undefined name 'Rect'.
      final device = Rect.fromLTWH(0, 0, kTileViewport.width * kTileDpr,
                     ^^^^
  test/tile_band_test.dart:13:24: Error: The method 'bandsFor' isn't defined for the type 'TileGrid'.
   - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'bandsFor'.
      final bands = grid.bandsFor(camera, kTileViewport);
                         ^^^^^^^^
  test/tile_band_test.dart:30:34: Error: The method 'bandsFor' isn't defined for the type 'TileGrid'.
   - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'bandsFor'.
      final bands = gridAt(camera).bandsFor(camera, kTileViewport);
                                   ^^^^^^^^
  test/tile_band_test.dart:43:34: Error: The method 'bandsFor' isn't defined for the type 'TileGrid'.
   - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'bandsFor'.
      final bands = gridAt(camera).bandsFor(camera, kTileViewport);
                                   ^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart
```

Matches the brief's expectation ("FAIL to compile — `bandsFor` and `TileBand`
are not defined"), plus the pre-existing `Rect` gap from the missing import.

## GREEN — `CI=true flutter test test/tile_band_test.dart` (after implementing, and after adding the `dart:ui` import)

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  ... (pub resolution output, unchanged from RED run) ...
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart
00:00 +0: the bands partition the visible keys, in row order, without gaps
00:00 +1: a band is one tile tall and the full union width
00:00 +2: the union overhangs the viewport, and the bands carry the overhang
00:00 +3: All tests passed!
```

3/3, as expected.

## GATE — `cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .`

Ran as three separate invocations (pub-resolution banner identical each
time, elided below); full package suite, not a single file.

**`CI=true flutter test`** — tail of output:

```
00:06 +372 ~1: /Users/.../test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:06 +373 ~1: /Users/.../test/vertices_differential_test.dart: the same holds at 4.5e6 with the view over one nested instance
00:06 +374 ~1: /Users/.../test/vertices_differential_test.dart: the sink inks nothing the painter did not ask for
00:06 +375 ~1: /Users/.../test/vertices_differential_test.dart: the comparison is not vacuous
00:06 +376 ~1: /Users/.../test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:06 +377 ~1: /Users/.../test/lineweight_test.dart: an instance past the anisotropy threshold takes the bypass
00:06 +378 ~1: /Users/.../test/lineweight_test.dart: a mirrored but conformal instance also takes the screen-space path
00:06 +379 ~1: /Users/.../test/lineweight_test.dart: a bypassed leaf lands exactly where the residual path would put it
00:06 +380 ~1: /Users/.../test/lineweight_test.dart: a bypassed leaf hands the sink small numbers
00:06 +381 ~1: /Users/.../test/lineweight_test.dart: a bypassed leaf gets the exact paper width
00:06 +382 ~1: /Users/.../test/lineweight_test.dart: curves cannot be bypassed an anisotropic circle stays on the residual path and is counted
00:06 +383 ~1: /Users/.../test/lineweight_test.dart: curves cannot be bypassed an anisotropic arc is counted too
00:06 +384 ~1: /Users/.../test/lineweight_test.dart: curves cannot be bypassed a conformal circle is not counted
00:06 +385 ~1: /Users/.../test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:06 +386 ~1: All tests passed!
```

386 tests total, "All tests passed!" — the `~1` markers are pre-existing
skip counters unrelated to this task (present before this change too).

**`CI=true flutter analyze`**:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

**`dart format --output=none --set-exit-if-changed .`**:

First run reported `Changed test/tile_band_test.dart` (exit 1) — the brief's
test body, transcribed verbatim, has one line (`bands.map(...).reduce(...)`
and the `Rect.fromLTWH(...)` call in the third test) that this repo's `dart
format` wraps differently than the brief's own line breaks. Ran
`dart format test/tile_band_test.dart` to apply the repo's canonical
formatting (semantically identical, only line-wrap changed), then re-ran the
full gate:

```
Formatted 69 files (0 changed) in 0.13 seconds.
```

Exit 0. Re-ran `CI=true flutter test test/tile_band_test.dart` after the
reformat to confirm the 3 tests still pass (they do, unchanged pass/fail
shape) before committing.

## What `bandsFor` allocates per call

Given `visibleKeys` returning `n` keys across `r` rows:

- One `Map<int, List<TileKey>>` (`byRow`), plus one `List<TileKey>` per
  distinct row (`r` lists), each grown via `??=` and `.add` — standard
  growable-list reallocation as each row fills.
- One `List<int>` for `rows` (`byRow.keys.toList()`), sorted in place.
- One `List<TileBand>` of length `r` (the returned list), built by a
  list-literal `for`.
- One `TileBand` instance per row (`r` allocations), each holding a `Rect`
  (`r` more allocations) and reusing the row's own `List<TileKey>` from
  `byRow` as `keys` (no extra copy — the sort on that list happens in place
  before `deviceRect` is read, per the source-order note in the brief).
- The per-row lists are sorted in place with `List.sort`, which for
  `List<TileKey>` (a general Dart `List`) uses an in-place algorithm with no
  extra list allocation, though the sort's own comparator closures
  (`(a, b) => a.x.compareTo(b.x)`) are allocated once per row.

So total allocation is `O(r)` `TileBand`/`Rect` objects plus `O(n)` `TileKey`
list-storage (already produced by `visibleKeys`, not duplicated) plus the one
`byRow` map and `rows` list — no allocation scales worse than linear in the
number of visible keys, and nothing is retained past the call. This matches
the doc comment's framing: `bandsFor` runs once per resting frame, not per
steady-state frame, so this allocation is out of the frame-path invariant's
scope (confirmed against `query_allocation_test.dart` /
`paint_allocation_test.dart`, neither of which exercises `bandsFor`).

## Anything surprising

- The brief's test file is missing `import 'dart:ui';`, which every sibling
  tile test (`tile_grid_test.dart`, etc.) includes; `Rect` is used directly
  in test 3. Added the import — a one-line, non-substantive fix, no test
  logic changed.
- The brief's own code sample for the third test, when passed through this
  repo's `dart format`, wraps two lines differently than as printed in the
  brief (cosmetic only — `bands.map(...).reduce(...)` and
  `Rect.fromLTWH(...)` each collapse to a single wrapped line instead of the
  brief's two-line break). Ran `dart format` to match the repository's
  canonical style rather than leave the format gate red.
- No other surprises: `TileGrid`, `TileKey`, `deviceDeltaFrom`, `visibleKeys`,
  `quantiseCamera`, and the test fixtures (`kTileViewport`, `kTileDpr`,
  `tileCamera()`) all matched the brief's description of them exactly, and
  `lib/jet_cad_2d_flutter.dart` already exported `tile_cache.dart` in full,
  so no export-list edit was needed.
