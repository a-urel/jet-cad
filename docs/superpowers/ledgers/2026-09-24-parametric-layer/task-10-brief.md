### Task 10: Invariants and greps

**Files:**
- Modify: `docs/superpowers/notes/plan-06-mutation-log.md` (append)

- [ ] **Step 1: Run each check and paste its output.**

```sh
git diff main -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l   # 0
grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib | wc -l   # 0
# document/ never imports parametric/ (spec D1); component.dart gains isRegistered only
git diff main -- packages/jet_cad_2d/lib/src/document/component.dart | grep '^+' | grep -v '^+++'
grep -rn "parametric" packages/jet_cad_2d/lib/src/document | wc -l   # 0
# The render layer changed only placement_tool.dart (spec, Files)
git diff --stat main -- packages/jet_cad_2d_flutter/lib   # one file
# No handleSeed.next() in the planner (spec D4 step 7)
grep -n "handleSeed.next" packages/jet_cad_2d/lib/src/parametric   # no hits
```

- [ ] **Step 2: Run all four gate lines** and paste each summary. Name the
  five golden failures.
- [ ] **Step 3: Commit** with the message `docs: Plan 06 invariants and
  greps` and the trailer.

---

