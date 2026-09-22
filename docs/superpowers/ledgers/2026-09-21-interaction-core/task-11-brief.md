### Task 11: Mutation testing, the two allocation gates, the greps

**Files:**
- Create: `docs/superpowers/notes/plan-02-mutation-log.md`

For each of the thirty mutants in the spec's table: `cp` the file aside,
apply the mutation by hand (one edit), run **only the named test file**,
paste the failing test's name and the summary line, restore with `cp`,
`diff` to confirm. Log format per mutant:

```
### M-02a — swap window/crossing predicates
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `_leafPasses`: `mode == BandMode.window` → `mode == BandMode.crossing`
test: CI=true dart test test/index/band_query_test.dart -N "window keeps only"
result: FIRED — `Expected: {inside}` … `Actual: {inside, straddling}`; 1 failed
restored: diff clean
```

M-02c and M-02e: entries headed `EQUIVALENT` with the spec's sentence.
M-02f: note the non-discriminating half. M-02l: the scale-0.25 fixture.

Then:

```sh
cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
cd ../jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart   # empty
grep -rn "kIsWeb\|dart:ui_web" packages/jet_cad_2d_flutter/lib/src/selection*.dart packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/outline_cache.dart   # nothing
```

Paste all four outputs into the log's tail. Commit the log.

---

