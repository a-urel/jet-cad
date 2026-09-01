# Task 3 Report: The Collector Fans a Filled Circle at the Outline's Step Count

## Summary of Changes

Implemented `GeometryCollector.fillCircle` to emit triangle fan instances around a circle's center at the same tessellation step count as the circle's own outline stroke. This ensures the fill and stroke silhouettes never disagree at any zoom level (Ruling D5).

### Files Modified

1. **lib/src/gpu/geometry_collector.dart**
   - Updated `skippedOps` documentation: changed from "Ops this plan does not draw yet — `text` and `fillCircle`" to "Ops this plan does not draw yet — `text` only"
   - Replaced `fillCircle` stub (which only incremented `_skipped`) with full implementation:
     - Validates radius > 0 and device radius > 0
     - Calls `_flattenSteps(deviceRadius, theta)` to determine step count
     - Reserves buffer space for the triangle instances
     - Emits fan triangles with center at `(ccx, ccy)` and rim points calculated at ascending angles from 0 to 2π
     - Uses `writeFill` with `style.argb` directly (never `_coveredArgb`, per Ruling D3)

2. **test/gpu/geometry_collector_test.dart**
   - Updated test "counts the ops it does not draw instead of dropping them silently":
     - Changed expectation from `c.instanceCount == 0` and `c.skippedOps == 2` to `c.instanceCount > 0` and `c.skippedOps == 1`
     - Updated comments to reflect that fillCircle is now drawn and only text remains skipped
   - Updated test "after Plan D Task 2, fillCircle and text are skipped":
     - Renamed to "after Plan D Task 3, text is the only skipped op"
     - Updated expectation from `c.skippedOps == 2` to `c.skippedOps == 1`
     - Updated comments and reason messages to reflect the new state
   - Added three new tests from the brief:
     1. "a filled circle is a fan at the same step count as its own outline" — verifies instance count matches the outline's step count
     2. "the fan shares one centre and walks the rim in ascending angle" — verifies fan topology and transform application
     3. "a zero or negative radius fills nothing" — boundary condition test

## Gate Command Results

```
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

### flutter test
Exit code: 0
All 549 tests passed.

### flutter analyze
Exit code: 0
No issues found! (ran in 0.9s)

### dart format
Exit code: 0
Formatted 91 files (0 changed) in 0.14 seconds.

## Carried-Forward Items

1. **Skipped Operations Documentation**: Updated `skippedOps` getter documentation (line 83 in geometry_collector.dart) to remove `fillCircle` from the list of skipped operations, leaving only `text`.

2. **Test Updates**: 
   - Test at line 139 "counts the ops it does not draw instead of dropping them silently" was updated to verify that fillCircle now draws instances while text remains skipped.
   - Test at line 692 "after Plan D Task 2..." was renamed and updated to reflect that only text is now skipped after Task 3.

## New Tests Killability Check

All three new tests (added at the end of the test file) are mutation-killable:

1. **"a filled circle is a fan at the same step count as its own outline"**
   - Killable by: removing the `_flattenSteps` call and hardcoding a different step count, or by changing the steps reservation size
   - This test catches if the fill and outline disagree on tessellation

2. **"the fan shares one centre and walks the rim in ascending angle"**
   - Killable by: removing the `_residual` transform application, reversing the loop iteration order, changing the angle calculation formula, or removing the center point validation
   - This test catches off-by-one errors, transform bugs, and traversal order issues

3. **"a zero or negative radius fills nothing"**
   - Killable by: removing the `if (r <= 0) return;` guards or the device radius check
   - This test catches boundary condition handling

All tests verify actual data written to the buffer rather than just instance counts, making them robust against degenerate implementations.

## Commit

Commit SHA: ef5b834

Message: "feat(gpu): the collector fans a filled circle at the outline's step count"

## Implementation Notes

The implementation strictly follows the pattern from `VerticesDrawSink.fillCircle` (the correctness oracle at line 773-794 in vertices_draw_sink.dart):
- Calculates center point by applying the residual transform
- Starts rim at angle 0 (point `(cx + r, cy)`)
- Walks angles in ascending order for emission order stability
- Reuses each iteration's next point as the next triangle's second edge
- Never sorts or reorders the buffer; emission order = draw order

The shared `_flattenSteps` call is critical (Ruling D5): both the fill and its own outline outline call the same method with the same parameters, guaranteeing identical tessellation.

---

## Fix Round 1 Report

### Issues Fixed

1. **Important: Missing `_coveredArgb` mutation test** — None of the three original tests would catch if `fillCircle` were wrongly routed through `_coveredArgb`. All three used `lineweightHundredths: 25`, keeping device width above the fade threshold.
   - **Fix**: Added test "a fill circle keeps its own colour on a hairline layer" using `lineweightHundredths: 1`, ensuring device width is sub-pixel and `_coveredArgb` fades if invoked. Asserts unfaded alpha (1.0) and all three color channels.
   - **Mutation Evidence**: Swapped `argb = style.argb` to `argb = _coveredArgb(style.argb, style.lineweightHundredths)` inside `fillCircle`. Test failed with:
     ```
     Expected: a numeric value within <0.000001> of <1.0>
       Actual: <0.07450980693101883>
     ```
     The alpha faded from 1.0 to ~0.075, confirming the test kills the mutation. Restored from `cp` backup after verification.

2. **Minor: Missing `y1` assertion** — Test "the fan shares one centre and walks the rim in ascending angle" only checked `x1` for angle-0 rim point. Since `sin(0) == 0`, angle formula errors in the y computation would not be caught.
   - **Fix**: Added `y1` assertion parallel to `x1`, verifying both coordinates of the angle-0 rim point.

### Gate Results

```
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**flutter test**: Exit code 0. All 550 tests passed (1 new test added in fix round).

**flutter analyze**: Exit code 0. No issues found! (ran in 0.7s)

**dart format**: Exit code 0. Formatted 91 files (0 changed) in 0.13 seconds.

### Commit

Commit SHA: a102be5

Message: "fix(tests): add fillCircle colour-preservation test and y1 angle-0 assertion"
