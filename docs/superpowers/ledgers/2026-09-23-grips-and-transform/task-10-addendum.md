# Task 10 — controller addendum (binding, read after the brief)

The brief's tables were written before Tasks 1–9 ran. Reviews since then changed some code and found coverage gaps. Rules for this addendum:
- Where a row's `old` text no longer matches the code, re-express the **same idea** against the current code and log both the brief's text and what you actually edited.
- New tests land **in their own commits** (test-only, `test(...)` subject), each shown RED against its new mutant before the commit, then GREEN. Production code does not change in Task 10 — if a new test exposes a real production bug, STOP and report DONE_WITH_CONCERNS with the details instead of fixing it.
- New mutants get ids **M-03ay onward**, in the order below, and go into the log after the plan's twenty-three under a heading "Controller-added mutants (review findings)".

## Rows changed by earlier tasks
1. **M-03ab** — the cursor is no longer a `ListenableBuilder`: `interaction_layer.dart` mirrors the tool's cursor into a `ValueNotifier<MouseCursor>` rendered by a `ValueListenableBuilder<MouseCursor>` (Task 7 fix for a mid-drag-removal assert). Re-express: render `MouseRegion(cursor: _tool.cursor, …)` directly (no builder, no mirror). Must turn `test/interaction_cursor_test.dart` I1 red.
2. **M-03as** — `_pressGrip` (int) became `GripRef? _pressRef` re-found live at the slop. Re-express: in `_classify`, when a grip is hit, record the ref but do not return `PressClass.grip` (fall through). Must turn T1 red.
3. **M-03ah** — per the Task 4 review, C2 cannot kill M-03ah (it compares against `worldBoundsOf`, which the mutant changes alike); O1 kills it. Log C2 as "not a killer for ah (compares against the mutated function)", O1 as the killer.
4. **M-03ai** — also log: dropping the `ref.ordinal < bestOrdinal` tie clause is an **equivalent** mutant (grips iterate in ascending ordinal and a tie needs strict improvement); fire it, show it survives, and log it as `EQUIVALENT — by construction` with that reason. It does not count against the "only M-03e survives" rule.

## Controller-added tests and mutants (from the task reviews)
Each: write the test, fire the mutant (cp backup → edit → run the named test file → RED → restore → diff clean), commit the test.

- **M-03ay — grips.dart `_degenerateSweep` near-2π branch** (Task 1). Test in `packages/jet_cad_2d/test/document/grips_test.dart`: an arc end stretch whose resulting sweep lands within `Tolerance.standard.angular` of 2π (e.g. positive sweep, drag the end to just short of the start angle, `start - 1e-12`) → `reshapeLeaf` returns null. Mutant: drop the "or of 2π" clause.
- **M-03az — DragPoint reuse** (Task 3). Test in `packages/jet_cad_2d/test/index/drag_snap_test.dart`: one `DragPoint`, first call lands an object snap (`objectKind != null`), second call with nothing in the aperture and no grid → `objectKind == null && grid == false`. Mutant: delete the per-call reset of `out.objectKind` / `out.grid`.
- **M-03ba — GripCache hover skip** (Task 4). Test C8 in `packages/jet_cad_2d_flutter/test/grip_cache_test.dart`: select a line, `grips.hot = 1`, change the selection's hover (`setHover(other)`), expect `grips.hot == 1`. Mutant: delete the early `return` on an unchanged key set (`grip_cache.dart` ~160).
- **M-03bb — hitTest nearest wins** (Task 4). Test in `grip_cache_test.dart`: two grips of different objects both within `kGripHitPixels` of the probe at different screen distances, lower-handle one nearer → the nearer wins. Mutant: `d < bestDistance` → `d > bestDistance` (or drop the distance comparison).
- **M-03bc — camera listener leak** (Task 7). Already guarded by the extended T14 (fix round b7de33a). Fire: delete `removeListener(_onCamera)` in `_endDrag` → T14 red (expected 1 notification, got 2). Log it.
- **M-03bd — centre grip base = grip** (Task 7). Already guarded by the M-03at test pressing 5 px off the grip. Fire: route the centre grip through `_moveBase` instead of `drag!.base.setValues(ref.grip.x, ref.grip.y)` → red. Log it.
- **M-03be — class 3b refuse-before-toggle** (Task 7, Ruling 03-6). Test in `select_tool_drag_test.dart`: under `DraftPermissions.runtime`, shift-press an UNSELECTED root leaf (geometry refused), cross the slop, release → selection toggled exactly once net (the click's toggle), no drag, no command; and assert the selection is unchanged at the moment the slop is crossed. Mutant: move the 3b selection change before the `_permitted` check.
- **M-03bf — overlay buffer exact size** (Task 8, Ruling 03-10). Test in `test/selection_overlay_grips_test.dart`: ONE painter instance; paint at 300 grips, reselect to 10, paint twice more (via the spy canvas): the stretch `drawRawPoints` list length == 2 × current stretch count on every frame, and the last two frames pass an `identical` buffer. Mutants: (a) reallocate the Float32List every frame → the `identical` check red; (b) capacity-grow `_stretchPoints.length < 2*count` instead of `!=` → the length check red (stale grips drawn). Log as M-03bf and M-03bf′.
- **M-03bg — reshape preview arc** (Task 8). Test in `selection_overlay_grips_test.dart`: reshape-drag an arc's radius grip under `gripCamera` (non-zero rebase origin) and assert the preview path's bounds (rebased, via the spy canvas) match the expected arc bounds in rebased world within 1e-3. Mutant: in `_reshapePath`'s arc branch, drop the origin subtraction on the arc centre.

## Tally
Update Step 3's tally to include these: fired N, killed N − 1 − E, survived 1 (M-03e, designed), equivalent E (M-03ai's ordinal clause, plus any other you can justify by construction — each with its reason).

## Commit trailer
Per Ruling T2-a, each commit's trailer names the model that wrote it (not the brief's fixed "Opus 5.5").
