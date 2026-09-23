### Task 10: The invariants, and the greps

**Files:**
- Modify: `docs/superpowers/notes/plan-05-mutation-log.md` (append the
  greps' output)

**Interfaces:**
- Consumes: the whole branch.

- [ ] **Step 1: Run each check and paste its output into the log.**

```sh
# Invariant 4: 02's API is unchanged.
git diff main -- packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart | wc -l   # 0
# The allocation invariants are unedited.
git diff main -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l   # 0
# The engine stays pure Dart.
grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib | wc -l   # 0
# D12: each tool reuses one Path; no Path() is constructed on the paint path.
grep -rn "Path()" packages/jet_cad_2d_flutter/lib/src/draw   # exactly one hit, in placement_tool.dart's field
# Ruling 05-3: every handle a tool allocates goes through the builders.
grep -rn "handleSeed" packages/jet_cad_2d_flutter/lib/src/draw apps/floor_planner/lib   # no hits
# Transform2 is never compared with == in the new tests.
grep -rn "Transform2.*==" packages/jet_cad_2d_flutter/test/draw apps/floor_planner/test/planner_draw_test.dart   # no hits
```

- [ ] **Step 2: Run all four gate lines.** Paste each summary line. Name
  the five golden failures.
- [ ] **Step 3: Commit.**

```bash
git add docs/superpowers/notes/plan-05-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 05 invariants and greps

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

