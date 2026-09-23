### Task 9: Mutation testing — all twenty-six

**Files:**
- Create: `docs/superpowers/notes/plan-05-mutation-log.md`

**Interfaces:**
- Consumes: every test from Tasks 1–8. No code change survives this task.

For each mutant in the table, in order:
1. `cp` the file to
   `.superpowers/sdd/2026-09-23-drawing-tools/mutation-backups/<basename>.<id>`.
2. Apply the one edit by hand.
3. Run **only the named test file**, with `CI=true`.
4. Paste the failing test names and the summary line.
5. Restore with `cp` back from the backup.
6. Run `diff <backup> <file>` and paste its empty output.

**Never `git checkout --` a `.dart` file.**

**Log format** per mutant: the heading `### M-05x — <title>`, then `file:`,
`edit:`, `test:` and `result: KILLED -- <test names> [E]; <summary>`. A
survivor is `SURVIVED`, with the reason and what was done (a fixture change
plus a re-fire, or an equivalence argument). The spec permits no designed
survivor.

The paths below are relative to the repo root.

| ID | file | edit | test file |
|---|---|---|---|
| M-05a | `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`, `onPointerDown` | `_resolve(ctx, e.world, e.shift)` → `_resolve(ctx, Vector2(e.screen.dx, e.screen.dy), e.shift)` | `test/draw/placement_tool_test.dart` (B1) |
| M-05b | `packages/jet_cad_2d/lib/src/document/drafting.dart`, `rectanglePayload` | drop the last pair `c1.x, c1.y` | `test/document/drafting_test.dart` (E5) |
| M-05c | `drafting.dart`, `textPayload` | `[heightMm, 0, 1, 0]` → `[heightMm * kCapHeightRatio, 0, 1, 0]` (import `text_metrics.dart`) | `drafting_test.dart` (E7) |
| M-05d | `drafting.dart`, `addDrafted` | `doc.handleSeed.next()` → `Handle(doc.entities.liveCount + ReservedHandles.firstFree)` | `drafting_test.dart` (E3) |
| M-05e | `packages/jet_cad_2d_flutter/lib/src/draw/arc_tool.dart`, `accept` | `arcPayload(points.first, _r, _tracker.start, sweep)` → `arcPayload(points.first, _r, _tracker.start + sweep, -sweep)` | `test/draw/arc_tool_test.dart` (AR1) |
| M-05f | `drafting.dart`, `SweepTracker.track` | `_travel += wrapAngle(angle - _previous);` → `_travel += angle - _previous;` | `test/document/sweep_tracker_test.dart` (S4) |
| M-05g | `drafting.dart`, `sweepTo` | `return _travel >= 0 ? delta : delta - _tau;` → `return delta;` | `sweep_tracker_test.dart` (S3) |
| M-05h | `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`, `orthoBase` | `points.last` → `points.first` | `test/draw/polyline_tool_test.dart` (PL6) |
| M-05i | `placement_tool.dart`, `onPointerDown` | `accept(self ?? Vector2.copy(_hover.point), ctx);` → `accept(self != null ? Vector2.copy(e.world) : Vector2.copy(_hover.point), ctx);` | `polyline_tool_test.dart` (PL3) |
| M-05j | `drafting.dart`, `textHeightMm` | `page.scaleDenominator` → `50` | `drafting_test.dart` (E8) |
| M-05k | `line_tool.dart`, `accept` | `..add(point)` (after a commit) → `..add(ctx.camera.value.screenToWorld(ctx.camera.value.worldToScreen(point)))` | `test/draw/line_tool_test.dart` (L1) |
| M-05l | `placement_tool.dart`, `onKey` | Escape's `cancel(ctx);` → `finish(ctx); cancel(ctx);` | `polyline_tool_test.dart` (PL9) |
| M-05m | `placement_tool.dart`, `onKey` | `if (event is KeyUpEvent \|\| !isPending) return KeyEventResult.ignored;` → put `if (key == LogicalKeyboardKey.escape) return KeyEventResult.handled;` before it | `apps/floor_planner/test/planner_draw_test.dart` (A4), and `placement_tool_test.dart` (B4) |
| M-05n | `apps/floor_planner/lib/text_entry_overlay.dart`, the camera builder | `left: s.x, top: s.y - …` → `left: placed.point.x, top: placed.point.y - …` | `planner_draw_test.dart` (A7) |
| M-05o | `rectangle_tool.dart`, `accept` | `fillable: true` → `fillable: false` | `test/draw/rectangle_tool_test.dart` (R3) |
| M-05p | `placement_tool.dart`, `commitShape` | Ruling 05-15's two executes in place of `return region;` (return the second command; execute the first inline) | `rectangle_tool_test.dart` (R3), `polyline_tool_test.dart` (PL4) |
| M-05q | `drafting.dart`, `addDraftedRegion` | delete `if (boundaryKind == EntityKind.polyline && triangles.isEmpty) return null;` | `drafting_test.dart` (E9), `polyline_tool_test.dart` (PL5) |
| M-05r | `apps/floor_planner/lib/startup_plan.dart` | move the furniture block back before the finishes | `apps/floor_planner/test/startup_plan_test.dart` (SP2) |
| M-05s | `polyline_tool.dart`, `paintRubberBand` | one `canvas.drawLine` per segment (and to the hover) instead of `band` plus one `drawPath` | `test/draw/draw_overlay_test.dart` (OV1) |
| M-05t | `drafting.dart`, `draftRecord` | `textAttrs: 0` → `textAttrs: packTextAttrs(overrideWidthFactor: true, overrideOblique: true)` | `drafting_test.dart` (E1, E7) |
| M-05u | `text_entry_overlay.dart` | move `field` into the camera builder, with `key: ValueKey(widget.camera.value.worldToScreenMatrix.e)` on the `SizedBox` | `planner_draw_test.dart` (A7) |
| M-05v | `text_entry_overlay.dart` | remove the `ShellShortcutGuard` around the field | `planner_draw_test.dart` (A8) |
| M-05w | `placement_tool.dart`, `_resolve` | run `resolveDragPoint` first and consult `selfSnap` only when `_hover.objectKind == null && !_hover.grid` | `polyline_tool_test.dart` (PL8) |
| M-05x | `line_tool.dart`, `selfSnap` | drop the `_segments > 0 &&` clause | `line_tool_test.dart` (L3) |
| M-05y | `text_tool.dart`, `accept` | `commitText(controller.text, ctx);` → `cancelText(ctx);` | `test/draw/text_tool_test.dart` (TX4) |
| M-05z | `drafting.dart`, `sweepTo` | `_travel >= 0` → `_travel > 0` | `sweep_tracker_test.dart` (S5), `arc_tool_test.dart` (AR4) |

- [ ] **Step 1: Fire each mutant as above.** Append each result to the log
  as it lands. For M-05k, **paste the round trip's actual bits** (the
  first line's end next to the second line's start), so the log shows the
  kill is not luck (Ruling 05-5).
- [ ] **Step 2: Tally.** "26 fired: N killed, M survived". Any survivor
  gets a fixture change in the owning test and a re-fire, logged as
  `M-05x′`.
- [ ] **Step 3: Verify the tree.** `git status --short` lists only the log.
  `git diff --stat` shows no `.dart` change.
- [ ] **Step 4: Commit.**

```bash
git add docs/superpowers/notes/plan-05-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 05 mutation log -- M-05a..z

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

