### Task 10: The look, the results note, the spec's owed lines, and the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-21-plan-01-results.md`
- Modify: `docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md` (D4's check; Ruling 01-1's line)
- Modify: `roadmap/00-README.md` (the table row), `roadmap/01-app-skeleton.md` (status line), `STATUS.md`

- [ ] **Step 1: macOS — run it and look (spec criterion 12)**

`cd apps/floor_planner && flutter run -d macos --profile`. Report each as
**seen / not seen / could not judge**, in those words:

1. A two-finger scroll pans; the drawing follows the fingers with no drift
   and no stick, and does not change size.
2. A pinch zooms and the point between the fingers stays put.
3. A mouse-wheel notch zooms under the cursor, not about the window centre
   (put the cursor near a corner).
4. Zoom in past the maximum and out past the minimum: the view comes to
   rest without a jump and does not creep.
5. A two-finger scroll with cmd held still pans (D3, desktop row).
6. A middle-button drag pans; a left-button drag does nothing.
7. The walls close; every door swings into a room; the tile grids are
   square.

- [ ] **Step 2: Browser — Chrome or Safari, then Firefox**

```sh
cd apps/floor_planner && flutter run -d chrome --release
```

then open the same build in Firefox (`flutter build web` and serve
`build/web` with `python3 -m http.server 8080` from that directory). In
**each**, report:

1. Chrome/Safari: a two-finger trackpad scroll pans and a mouse-wheel notch
   zooms. Firefox: both pan.
2. A trackpad pinch zooms about the pointer (both).
3. ctrl+wheel zooms and does **not** zoom the page (both). On a Mac browser,
   real ctrl+wheel goes through the `HardwareKeyboard` path; note which
   machine and browser the look was on.
4. A ctrl+wheel *notch* with a mouse: how coarse it is (spec D3, ≈1.65× on
   Windows/Linux browsers; on macOS it is the 1.1× path). Judged, not
   measured.
5. A middle-button drag pans and does not start the browser's autoscroll.
6. The bounds come to rest without a jump.

The heuristic's misclassification, if seen (a flick that zooms once, a
notch that pans once), is recorded as seen, with the browser.

- [ ] **Step 3: The results note**

`docs/superpowers/notes/2026-09-21-plan-01-results.md`: the branch-point
harness count and the final one; the `STARTUP fit scale` line and the two
clamp ratios (D4's check, now done); the web build's outcome (first ever for
the package) with the command's last lines; the look, macOS and both
browser families, item by item; the mutation summary; the exit-gate table
below with PASS / MISS / OWED per row and the number beside each.

- [ ] **Step 4: The spec's owed lines**

In the spec: under D4, after *"The plan must sanity-check both constants…"*,
add one paragraph stating the fit scale at 1440×900 and the two ratios from
`startup_plan_test.dart`, and "checked 2026-MM-DD, unchanged" or the new
values. In the Architecture block, change
`analysis_options.yaml  generated and NOT committed (CLAUDE.md)` to
`analysis_options.yaml  generated, committed once at scaffold, never a rewrite (plan Ruling 01-1)`.
In Open questions, strike "The exact clamp constants" with a pointer to the
results note.

- [ ] **Step 5: Roadmap and STATUS**

`roadmap/00-README.md`: the 01 row gets the plan link and, on merge,
"executed". `roadmap/01-app-skeleton.md`: `**Status:** not started` →
`**Status:** spec 2026-09-21 (rev 2), plan 2026-09-21, executed on
plan-01/app-skeleton`. `STATUS.md`: a Plan 01 section in the shape of Plan
F's — what it delivers, the gate table, what was not looked at — and the
"Resume here" paragraph updated to say 01 has a plan and where it stands.

- [ ] **Step 6: Commit, then hand off**

```sh
git status --short
git add docs/superpowers/notes/2026-09-21-plan-01-results.md docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md roadmap/00-README.md roadmap/01-app-skeleton.md STATUS.md
git commit -m "docs: Plan 01 results -- the look on macOS and in two browser families, the gate, the resume point"
```

Then `superpowers:finishing-a-development-branch`: the ledger under
`.superpowers/sdd/2026-09-21-floor-planner-app-skeleton/` is archived to
`docs/superpowers/ledgers/2026-09-21-floor-planner-app-skeleton/` in its own
commit before the merge, and the merge is `--no-ff`.

---

## Exit gate

Pre-committed from the spec; a miss is recorded as a miss.

1. `apps/floor_planner` builds and runs on macOS and shows the startup
   plan, non-empty, off-origin (`planner_shell_test.dart`, Task 10 step 1).
2. `flutter build web` succeeds (Task 8 step 5, pasted).
3. Desktop trackpad two-finger scroll pans and does not zoom, from a
   non-identity transform (`camera_gesture_trackpad_test.dart`).
4. Pinch zooms about the anchor, cumulative handling correct (same file).
5. Mouse wheel zooms 1.1× per notch about the pointer
   (`camera_gesture_signal_test.dart`).
6. Scroll signals: trackpad-kind pans under `wheelZooms`; mouse-kind zooms
   under `wheelZooms` and pans under `wheelPans`; direction asserted;
   modifier + scroll zooms under both; `PointerScaleEvent` compounds;
   `forBrowser` answers both ways (signal test, `gesture_policy_test.dart`).
7. Middle-button drag pans on both policies; left does nothing on either
   (`camera_gesture_button_test.dart`).
8. The camera rests on `minScale` and `maxScale` within `Tolerance` from
   one oversized zoom each way, and a second push notifies no listener
   (`camera_controller_test.dart`).
9. All sixteen mutants M-01a…M-01q (M-01h struck) fired and killed, E-01e′
   fired and recorded equivalent, with pasted output.
10. The harness passes at its branch-point count; `git diff --stat
    main..HEAD -- apps/dev_harness_2d` is empty.
11. All eleven gate commands exit 0; no `analysis_options.yaml` rewrite in
    any commit after Task 6's.
12. A human looked, on macOS and in both browser families, and each item
    is recorded seen / not seen / could not judge.

## Self-review

**Spec coverage.** D1 — Task 3 (a separate widget; `draft_canvas.dart`
untouched, checked by the file list). D2 — Task 2 (the value, `forBrowser`,
`forPlatform`, the conditional import) and Task 9's greps and E-01e′. D3 —
Tasks 3, 4, 5, row by row: trackpad scroll and pinch and drift (3), mouse
wheel and ctrl/cmd and `kind` and `PointerScaleEvent` (4), middle and left
(5); the sign rules are in Task 4's handler and asserted absolutely. D4 —
Task 1 (bounds, `Tolerance`, the early return) and Task 7's constants
check, recorded in Task 10. D5 — Task 7. D6 — Task 8's `PlannerView`
(`tiles: false`, `backend` unset) and step 5's first web build. D7 — Task
6 step 3. D8 — Task 8 builds web in the same plan; Task 10 looks in two
browser families. Invariants 1–6 — Global Constraints, Task 1 step 5, Task
5 step 4, Task 9 step 3. Every mutant in the spec's list has a row in Task
9; M-01h is struck there as in the spec. The cross-policy test — Task 5.
**Not covered, deliberately:** Windows and Linux (spec, open questions);
web performance (spec D8); touch (spec non-goals).

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Three steps name a fallback the repository decides: Task 2 step 5
(`dart:ui_web` under `flutter analyze`), Task 4 step 4 (`sendKeyDownEvent`
vs `simulateKeyDownEvent`), Task 7 step 4 (the count outside 500–1,000),
each with the exact action.

**Type consistency.** `CameraController(initial, {minScale, maxScale})` —
Tasks 1, 3 (fixture), 8. `GesturePolicy({mouseWheel, wheelZoomStep,
panButtons})`, `wheelZooms`, `wheelPans`, `forBrowser({firefox})`,
`forPlatform()` — Tasks 2, 3, 4, 5, 8, 9. `CameraGestureDetector({camera,
policy, child})` — Tasks 3, 8. `ScrollAction.{pan, zoom}` — Tasks 2, 4.
`isFirefoxBrowser()` — Task 2 both files. `fitOffOrigin({minScale,
maxScale})`, `pumpDetector(tester, camera, policy)`, `screenOf(camera,
world)`, `globalFocus()`, `kLocalFocus`, `kWorldProbe`, `kDetectorSize` —
Tasks 3, 4, 5. `startupPlan(measurer)`, `kMinScale`, `kMaxScale`,
`kPlanOriginX/Y`, `kPlanWidth/Height` — Tasks 7, 8. `PlannerView({document,
index, camera, policy})` — Task 8 both files.
