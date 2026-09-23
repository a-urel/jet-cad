### Task 11: The allocation invariants, and the greps

**Files:**
- Modify: `docs/superpowers/notes/plan-03-mutation-log.md` (append the
  outputs under `## Invariants and greps`)

**Interfaces:**
- Consumes: the whole branch. It produces no code.

- [ ] **Step 1: Run the two allocation gates.** Both must pass unchanged
  (invariant 5):

```sh
cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
cd ../jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
```

- [ ] **Step 2: Run the greps**, from the worktree root, and paste every
  output:

```sh
# The invariants' tests are unedited; the frame path's files are untouched.
git diff --stat main..HEAD -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants                    # empty
git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d/lib/src/index/spatial_index.dart \
  packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
  packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart   # empty
# The engine stays pure Dart.
grep -n "dart:ui\|package:flutter" packages/jet_cad_2d/lib/src/document/grips.dart packages/jet_cad_2d/lib/src/index/drag_snap.dart   # nothing
# World is root space: nothing in the drag path reads the root node's transform.
grep -n "rootHandle\|accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/grip_drag.dart   # nothing
grep -n "accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/grip_cache.dart   # nothing
# No per-grip Rect or Offset in the grip path; one drawRawPoints per colour.
awk '/void _paintGrips/,/^  }$/' packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart | grep -n "drawRect\|Rect\.\|drawRawPoints"   # three drawRawPoints, no Rect
# No SnapResult.point is held: it is read only through setFrom.
grep -n "scratch.point" packages/jet_cad_2d/lib/src/index/drag_snap.dart   # one line: out.point.setFrom(scratch.point)
# Transform2 is never compared with == in the new tests.
grep -n "transform ==\|transform, same\|\.transform)\s*;\s*$" packages/jet_cad_2d_flutter/test/grip_drag_test.dart packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart   # nothing
```

- [ ] **Step 3: Commit.**

```bash
git add docs/superpowers/notes/plan-03-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 03 allocation gates and greps

query_allocation_test and paint_allocation_test pass unchanged; the frame
path's files and the harness are untouched; the engine stays pure Dart; the
drag path never reads the root's transform; the grip path draws with
drawRawPoints only.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

