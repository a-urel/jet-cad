# Task 4 Report: `liveBytes` counts a live band image

## Summary

Implemented the band image byte meter by extending `TileCache` to track a resident band image and include its memory in the `liveBytes` ceiling calculation. This prepares the ceiling to see band images before they are created in Task 6.

## Changes

**File modifications:**
- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`: Added `Image? _band` field, `debugSetBand()` test seam, and extended `liveBytes` getter to count band bytes
- `packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart`: New test file (created)

## Test Results

**New test: PASS**
```
00:00 +0: a live band image is counted in liveBytes
00:00 +1: All tests passed!
```

**Pre-existing failures (unrelated to this task):**
The following tests were already failing before this task's changes and remain failing due to modifications in other uncommitted files:
- `tile_budget_test.dart`: criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it
- `tile_budget_test.dart`: criterion 12: eviction runs with a composite standing, and never takes it
- `tile_cache_test.dart`: criterion 1: a settled frame equals the live frame after a zoom
- `tile_cache_test.dart`: the blit hands drawImageRect the same Paint object every time, not a call-site-local one

**Analysis and format:** No issues found

## Verification

The `_band` field is always null unless explicitly set via `debugSetBand()`, so the new byte meter addition is transparent to existing code paths. The test verifies that:
1. `liveBytes` increases by exactly 256 * 64 * 4 bytes (256x64 image at 4 bytes per pixel) when a band is set
2. `liveBytes` returns to baseline when the band is cleared
3. The band image is properly disposed

## Commit

Hash: `ccc7da2` — "feat(tiles): the byte meter sees a resident band image"

## Status

✓ Implementation complete and verified
✓ New test passes
✓ No new regressions introduced
✓ Code formatted and analyzed clean
✓ Ready for Task 6 (band image creation)
