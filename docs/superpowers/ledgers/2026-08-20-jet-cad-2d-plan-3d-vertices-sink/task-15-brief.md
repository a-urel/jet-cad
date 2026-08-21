### Task 15: The results note and the exit gate

- [ ] **Step 1: Run the exit gate, criterion by criterion**

Each of the eight in the design document. Run the check, paste the output, mark
it pass or fail. **A criterion nobody ran is a fail**, not a blank.

- [ ] **Step 2: Write the note**

`docs/superpowers/notes/2026-08-2X-plan-3d-results.md`, dated the day the runs
happened. It carries:

- machine, OS, Flutter and Dart versions, engine revision, and the Low Power
  Mode readings from before and after;
- the exact `flutter drive` invocations, including the web one;
- every cell as median of three with its spread beside it, desktop and web;
- criterion 6 evaluated per corpus size, with the crossover named if there is
  one;
- the peak buffer bytes from Task 12 step 4;
- what a steady-state frame allocates, and whether the `CLAUDE.md` amendment
  was approved, refused, or not needed;
- the five permitted divergences, with the sink-against-sink counts beside
  them;
- what 3d owes 3e and 3f.

- [ ] **Step 3: Say plainly what failed**

If criterion 6 tied at 500,000, the note says so, records the crossover, and
hands it to 3f — it does not round the number up. If the allocation amendment
was refused, the note says criterion 7 failed and the plan stopped. A results
note that reports only what went well is not a result.

- [ ] **Step 4: Update `STATUS.md`**

Replace the "The batching spike pulled the lever, on a branch" section with the
plan's outcome, the gate verdict, and the resume point.

- [ ] **Step 5: Commit, then finish the branch**

```bash
git add docs/superpowers/notes STATUS.md
git commit -m "docs: Plan 3d results and exit gate"
```

Then use the **superpowers:finishing-a-development-branch** skill. Do not merge
on your own initiative: the menu is the human's to answer.

---

## Self-review

Run against the design document at `aefb31f`.

**Spec coverage.** Backend selection → Task 1. The two backends drawing the
same picture → Tasks 6 and 11. Joins and caps → Tasks 4 and 5. `Vertices`
disposal → Task 2. The allocation question → Task 3, with the amendment left
to the human. Text and why `CanvasDrawSink` survives → Tasks 1, 8, 11. The
defines → Task 7. The rasterizer → Task 9. Goldens on both backends → Task 10.
Sink against sink → Task 11. Phase C's rows → Tasks 12 and 13. Mutants →
Task 14. Exit gate → Task 15. **No section without a task.**

**Placeholders.** None. Every code step carries the code; the one prose-only
step, Task 14's runner, names the file to model it on and the trap to avoid.

**Type consistency.** `RenderBackend` / `defaultRenderBackend()` (Task 1) are
used unchanged in 7, 10, 11, 13. `FlushObserver` (Task 8) is what
`TriangleRasterizer.observe` (Task 9) satisfies and what Tasks 10 and 11
attach. `frameSegmentCount` is renamed to `frameTriangleCount` in Task 4 step
10 and used under that name in Task 7. `_emitQuad` / `_emitSegment` /
`_emitTriangle` (Task 4) are consumed by Task 5's `_endRun`.

**One thing this plan does not decide, on purpose.** Whether `CLAUDE.md`'s
allocation non-negotiable is amended. Task 3 measures it and stops; the plan
cannot pass its own criterion 7 by editing the rule that criterion is measured
against.
