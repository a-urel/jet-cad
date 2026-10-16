### Task 8: The exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-10-16-architecture-demo-results.md`
- Modify: `docs/superpowers/specs/2026-10-13-kit-architecture-design.md`
  (Amendments: one line, spec 3b's "Amendments to other specs" first
  bullet), `docs/superpowers/specs/2026-10-15-architecture-kit-design.md`
  (Amendments: one line, the second bullet)
- Modify: `docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md`
  (a "Closed" column or a closing section: each row's outcome and where)
- Modify: `STATUS.md`

- [ ] **Step 1: Audit closure.** For every row of the audit, its outcome:
  ported (file:test), split (both names), covered (checked file:line),
  dropped (reason). A script or a grep over the test files, not memory.
  Any open row is a defect: fix it before the gate.

- [ ] **Step 2: The gates,** each run fresh, last lines transcribed into
  the results note: the app's test/analyze/format; `jet_cad_2d_plan`
  (`--enable-vmservice`), `jet_cad_2d_integration` (`--enable-vmservice`);
  `flutter build macos` and `flutter build web` in the app;
  `git diff --stat main -- packages/jet_cad packages/jet_cad_2d
  packages/jet_cad_2d_flutter packages/jet_cad_2d_gpu
  packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols
  apps/floor_planner` prints nothing; the `jet_cad_2d_plan` dry-run with 0
  warnings (Task 1 touched it).

- [ ] **Step 3: The smoke run (controller, not a subagent):** `flutter run
  -d macos` from `apps/architecture_demo`; Open sample; draw a wall; Save
  As into the scratchpad; New; Open the saved file; screenshot the
  reopened plan (computer-use or `screencapture`), saved to
  `docs/superpowers/notes/2026-10-16-architecture-demo-smoke.png`; the
  console's last lines transcribed. Then the same on web (`flutter run -d
  chrome` or `flutter build web` served locally) as far as Open sample and
  an Export → PNG download.

- [ ] **Step 4:** The results note (gates, smoke, audit totals by outcome,
  library-gap findings, rulings); the amendment lines; STATUS (3b done on
  the branch, the resume line); commit `docs: 3b results, amendments and STATUS`.

- [ ] **Step 5 (controller):** the whole-branch Sonnet review, its one fix
  wave and re-review, the ledger archived onto the branch, then tell the
  human the demo runs on the new packages, and offer the merge menu.
