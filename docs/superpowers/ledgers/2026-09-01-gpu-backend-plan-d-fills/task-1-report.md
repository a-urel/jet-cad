# Task 1 Report: The record learns a fourth kind

## Summary

Implemented the fourth `kind` tag for filled regions in the GPU-resident 2D CAD render backend. Added the `kKindFill` constant and the `writeFill` function to write fill-triangle instance records, along with comprehensive tests.

## Changes Made

### File: `lib/src/gpu/instance_record.dart`

1. **Updated `kKindStroke` documentation** (lines 37-49)
   - Changed "values are 0, 1, 2" to "values are 0, 1, 2, 3"
   - Added explicit mention of `kind < 2.5` dispatch condition
   - Clarified the load-bearing nature of the ordering

2. **Added `kKindFill` constant** (line 71)
   - Defined as `const double kKindFill = 3`
   - Includes comprehensive doc comments explaining:
     - The three corners stored in collection space
     - Zero halfWidth (no width expansion)
     - Relationship to the shader's join_weight roles and Ruling D1
     - Never dashed, never fades (Ruling D4)

3. **Added `writeFill` function** (lines 260-283)
   - Takes six coordinates (x0, y0, x1, y1, x2, y2) for the triangle corners
   - Takes argb color (0xAARRGGBB format)
   - Writes all 16 instance record slots:
     - kind = kKindFill
     - halfWidth = 0
     - Three corner coordinates
     - Color (via `_writeColor`)
     - Dash slots explicitly zeroed (via `_writeDash`)
   - Doc comment explains why dash slots must be explicitly written

### File: `test/gpu/instance_record_test.dart`

Added three test cases (lines 184-233):

1. **'a fill record carries three corners, no width and no dash'**
   - Uses pre-filled buffer (17.5) to catch degenerate fixtures
   - Verifies all 16 slots are written correctly
   - Tests specific color values (0x8033CC66)
   - Tests coordinate preservation (3.5, -4.25, 11.0, 2.5, -6.75, 9.5)

2. **'the four kind tags are distinct and ordered for a < dispatch'**
   - Verifies ordering [0, 1, 2, 3] for shader dispatch conditions
   - Documents load-bearing nature of the order

3. **'a fill at index 2 writes only its own record'**
   - Allocates 4 records, writes to index 2
   - Verifies records at indices 1 and 3 remain untouched (17.5)
   - Catches writers that ignore the index argument

## Test Results

### Instance Record Tests Only
```
00:00 +0: loading test/gpu/instance_record_test.dart
00:00 +1: the field offsets are contiguous and cover the stride
00:00 +2: the record is sixteen floats and kind_half is adjacent
00:00 +3: the three kind tags are distinct and ordered for the shader
00:00 +4: writeStroke fills every slot and leaves p2 zeroed
00:00 +5: writeJoin puts the vertex first and the neighbours after it
00:00 +6: writePoint carries one position and zeroes the unused slots
00:00 +7: a solid stroke writes zero into all four dash slots
00:00 +8: a dashed stroke carries its element extent and its phase
00:00 +9: a negative period is preserved bit for bit -- it is the collapse representative marker, not a magnitude
00:00 +10: a point is never dashed
00:00 +11: a fill record carries three corners, no width and no dash
00:00 +12: the four kind tags are distinct and ordered for a < dispatch
00:00 +13: a fill at index 2 writes only its own record
00:00 +14: All tests passed!
```

### Full Flutter Test Suite (exit code 0)
```
All 543 tests passed!
```
Partial output from tail:
```
00:09 +520 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: GeometryCollector shades dashes and the bracket is a no-op today (Task 5 implements it)
00:09 +521 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
...
00:10 +543 ~1: All tests passed!
```

### Flutter Analyze (exit code 0)
```
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 5.0s)
```

### Dart Format Check (exit code 0)
```
Formatted 91 files (0 changed) in 0.20 seconds.
```

## Commit

```
[plan-d/fills 2dbaf15] feat(gpu): the instance record learns a fill kind
 2 files changed, 105 insertions(+), 5 deletions(+)
```

Commit SHA: `2dbaf15`

## Notes for Future Tasks

- **Task 2-3 (Collector)**: The collector will need to call `writeFill` for each fill triangle produced by triangulation. The function signature and ordering of `kKindFill = 3` must be preserved.
- **Task 5 (Shader)**: The vertex shader dispatch logic is documented in the `kKindStroke` comment — it currently handles `kind < 0.5`, `kind < 1.5`, `kind < 2.5`, and will need to add logic for `kind >= 2.5` (fills).
- All slots are written explicitly (including zero-valued dash slots), following the pattern of `writePoint`, to catch degenerate fixtures where a buffer might be reused.
- The three-point storage pattern (x0/y0, x1/y1, x2/y2) directly maps to the shader's vertex roles for fills per Plan D's Ruling D1.

## No Deviations or Concerns

All changes follow the brief exactly as written. No deviations from specifications. No surprises encountered.
