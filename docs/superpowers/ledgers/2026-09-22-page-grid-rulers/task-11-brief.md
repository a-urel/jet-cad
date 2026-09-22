### Task 11: Mutation testing, the two allocation gates, the greps

**Files:**
- Create: `docs/superpowers/notes/plan-04-mutation-log.md`

For each of the twenty-two mutants M-04a…v in the spec's table: `cp` the
file aside, apply the mutation by hand (one edit), run **only the named test
file**, paste the failing test's name and the summary line, restore with
`cp`, `diff` to confirm. Log format per mutant:

```
### M-04a — drop the camera translation from ruler tick placement
file: packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart, `cam.worldToScreen(Vector2(world, 0)).x` → `world * cam.scale`
test: CI=true flutter test test/ruler_painter_test.dart
result: FIRED — `major ticks sit where the oracle says` [E]; 1 failed
restored: diff clean
```

M-04g fires on `grid_scale_test`'s `minorMinPixels` test and on the
painter's `minor != null` branch (mutate `if (minor != null)` to `if (true)`
with `minor ?? scale.majorMm / scale.divisor` — the painter test's
coincidence check goes red). Record Ruling 04-7 beside it.

Then:

```sh
cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
cd ../jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart   # empty
git diff --stat main..HEAD -- packages/jet_cad_2d_flutter/lib/src/tile_cache.dart   # one hunk, the skip
grep -rn "dart:ui" packages/jet_cad_2d/lib/src/document/page_component.dart packages/jet_cad_2d/lib/src/document/page_geometry.dart packages/jet_cad_2d/lib/src/geometry/grid_scale.dart   # nothing
```

Paste all outputs into the log's tail. Commit the log.

---

