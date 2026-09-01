# Task 2: The Collector Fills a Polygon — Report

## Changes Made

Implemented `GeometryCollector.fillPolygon` to write instances for each triangle in the triangulation, replacing the previous behavior of simply incrementing `_skipped`.

### Files Modified

1. **lib/src/gpu/geometry_collector.dart**
   - Replaced `fillPolygon` stub (lines 627-630) with full implementation (lines 627-667)
   - Updated `skippedOps` documentation to reflect that only `text` is skipped since Plan D
   - Implementation transcribes `VerticesDrawSink.fillPolygon` (lines 745-768):
     - Early return if triangulation is empty
     - Iterates by triangles (i += 3)
     - Applies residual transform to each vertex
     - Uses style.argb directly (not _coveredArgb)
     - No degenerate-triangle test (matching reference behavior)
     - Calls `writeFill` for each triangle

2. **test/gpu/geometry_collector_test.dart**
   - Added four new tests (lines 1167-1280):
     - `a fill polygon is one instance per triangle, in triangulation order`
     - `a fill keeps its own colour on a hairline layer`
     - `an empty triangulation writes nothing`
     - `a degenerate triangle is written, not dropped`
   - Updated existing test `after Plan B, only fills and text are skipped` to:
     - Renamed to `after Plan D Task 2, fillCircle and text are skipped`
     - Changed expected `skippedOps` from 3 to 2
     - Updated comment to reflect current task status

## Gate Command Results

### flutter test
```
00:06 +547 ~1: All tests passed!
```
Exit code: 0

### flutter analyze
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
```
Exit code: 0

### dart format --output=none --set-exit-if-changed .
```
Formatted 91 files (0 changed) in 0.13 seconds.
```
Exit code: 0

## Test Updates

The existing test at line 692-714 (now renamed) required updates because:
- It explicitly tests the `skippedOps` count against the documentation
- With `fillPolygon` now drawing, the count decreased from 3 (fillPolygon, fillCircle, text) to 2 (fillCircle, text)
- The comment was updated to reflect that only fillCircle and text remain skipped, pending Tasks 3 and 5 respectively

## Key Implementation Details

1. **Transform application**: Uses the formula `t.a * x + t.c * y + t.e` for x-coordinates and `t.b * x + t.d * y + t.f` for y-coordinates
2. **Color handling**: Uses `style.argb` directly, never `_coveredArgb`, to preserve fill color on hairline layers
3. **Triangulation indexing**: Correctly handles that `triangles` triple-indexes into `points`' own point numbering, so each index is doubled (`a * 2`, `a * 2 + 1`) to reach a coordinate pair
4. **Draw order**: Maintains triangulation order (no sorting) to match the reference implementation
5. **Degenerate triangles**: Written without filtering, matching reference behavior

## Notes

All four new tests pass, including the mutation-catching test for triangulation order verification and the color-preservation test for hairline layers. The differential test contract with `VerticesDrawSink` is maintained.

---

## Fix Round 1

**Commit:** `3094312` — "fix(gpu): correct the fillPolygon doc, drop non-killing test, add loop comment"

### Changes

1. **Doc fix**: Updated `skippedOps` doc to correctly state that both `text` and `fillCircle` are skipped (was incorrectly saying "text alone")
2. **Test deletion**: Removed "an empty triangulation writes nothing" — did not kill any meaningful mutation because:
   - With guard: `if (triangles.isEmpty) return;` prevents `_reserve()` call
   - Without guard: `_reserve(_instances + 0)` is called, but is a no-op when buffer has capacity
   - Loop condition `i + 2 < triangles.length` is also false when `triangles.length == 0`
   - Both paths produce identical results, so no mutation is caught
3. **Loop comment**: Added explanation that the loop bound `i + 2 < triangles.length` drops incomplete tails, unlike the oracle which would throw

### Covering Tests
```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

All tests pass:
```
00:06 +546 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
Formatted 91 files (0 changed) in 0.14 seconds.
```
Exit code: 0
