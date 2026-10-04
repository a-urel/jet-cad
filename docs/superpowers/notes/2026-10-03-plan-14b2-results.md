# Plan 14b-2 results — the host API and the two modes

**Branch:** `claude/exciting-pasteur-9m22jv` (after 14b-1, 14s, 14a).
**Spec:** [2026-10-03-host-api-and-modes-design.md](../specs/2026-10-03-host-api-and-modes-design.md),
revision 2. **Plan:** [2026-10-03-host-api-and-modes.md](../plans/2026-10-03-host-api-and-modes.md).
**Approval:** the human, travelling, asked not to be asked unless needed
(2026-10-03); the umbrella's 14b-2 decisions were approved; the spec's
amendments A-1 to A-3 are for the human's later look. **Not merged.**

A Flutter host embeds the planner through
`package:jet_cad_floor_plan/jet_cad_floor_plan.dart`: a
`FloorPlanController` (the designed plan and, in the selection mode, a
**service copy** under `runtime` permissions, so service edits and their
Undo never reach the design), a `FloorPlanView` (the editor in the design
mode, the canvas alone in the selection mode; Export and Print in both),
and value types. `apps/restaurant_demo` shows two dining areas with a
Design / Service toggle, on every platform's runner.

## Commits

| Task | Commits | Review |
|---|---|---|
| Spec rev 1, 2 | `efd013e`, `8b4d303` | rev 1: Ready with fixes (R-1..R-15), applied in rev 2 |
| Plan | `b9e0757` | — |
| 1 The seams, the export helpers | `d0fd6ef` | **Needs fixes** (shared review of 1–4) |
| 2 The controller | `9fa5513`, `e4fc4a4` | idem |
| 3–4 The views, the barrel | `8f94fc7` | idem → `bb81e6a` (F-1..F-7) |
| 5 The demo | `07f42c1` | **Needs fixes** (F-1 the side panel went stale: the API had no change signal; tests) → `7dc38fa` |

One implementer (this session); independent reviewers re-ran the gates in
their own worktrees and fired their own mutants.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine, render | **untouched** by this plan (`git diff 8e86bdb..HEAD` empty for both) |
| planner `packages/jet_cad_floor_plan` | **925 passed**; analyze, format clean |
| app `apps/floor_planner` | **192 passed**; analyze, format clean |
| demo `apps/restaurant_demo` | **11 passed**; analyze, format clean |
| web builds | `apps/floor_planner` and `apps/restaurant_demo`: `✓ Built build/web` |
| `apps/dev_harness_2d` | analyze clean |

**Web smoke (Chromium, tr-TR):** the demo opens with no page error; the
Salon area in the design mode shows the editor with the side panel of the
demo (Save, Revert, Fit, select by number, tables, log).

## Mutants fired

Spec-named, red: M-14f (the copy is the design), M-14b2-1 (dirty follows
the active plan), -2 (the copy kept), -3 (load keeps the selection), -4 (one
table per number), -5 / -13 (a stale renumber), -6 (the copy with `all`),
-7 (Export plots the design: PNG bytes compared), -8 (a bad plan replaces;
the raw error), -9 (a barrel leak), -10 (the shell disposes a host
selection), -11 (no settle on a switch), -14 (`markSaved` marks now). Own
and the review's, red: the selection lost on a switch, a locked or hidden
table selectable, fit on every switch, the Undo chord, the busy chord, the
export name, Print in the selection mode, a rebuild or removal mid-flow, a
swap mid-flow, a pending fit after a switch, a load without a refit, the
shared loader not loaded, the page condition, the save state kept over a
load, the copy's systems not LIFO, the old design not dropped, an
unnumbered table or a planter in `selectedTables`, the discard question
skipped (demo).

**Survive, recorded:** **M-14b2-12** (the copy disposed synchronously): no
observable failure in the current tree; the post-frame drop is kept as
defensive. **m21, m21c** (one of the two identity guards in a flow
removed): equivalent, the other guard catches it. **m27** (the
numbering-warnings filter): equivalent under the current diagnostics.
**M8 (demo)** (the number field not trimmed): equivalent, the controller
trims. **M9, M11, M23 (demo)** (the view's key, a removed listener,
controllers not disposed): harmless or unmeasured, as the demo review
recorded.

## Amended at execution

- **The barrel** also shows `SymbolLibraryLoader` and `SymbolThumbnails`:
  a host with several plans shares them (R-11), which needs their types.
- **The shell's camera seam.** R-13 asked for the last camera to be handed
  over as `initialCamera`; the shell takes the controller's
  `CameraController` (never disposed) and a `fitOnStart` flag instead, and
  `PlannerView` reports each fit (`onFitted`) so a pending `fitToView`
  survives a switch (review F-2). The controller places the camera
  nominally when a plan arrives (review F-6).
- **`PlannerView.grips` and `textTool` are nullable** (R-5): the planner's
  and the app's tests that read `view.grips` use `!` — the app's tests
  changed beyond imports, against the plan's constraint, by this type
  change only.
- **The controller is a factory** that decodes first (review F-5).
- **`revision`** (a `ValueListenable<int>`) is added to the controller:
  it moves on every change of the active plan, so a host re-reads
  `tables` and `numberingWarnings` (demo review F-1; the API had no such
  signal before 14c's callbacks).
- **An empty label is no number** (`TableSurvey`, demo review F-7): the
  table is unnumbered, not "Number  is used by 2 tables".

## Found, not fixed

- **The selection mode has no pointer behaviour** but the camera's: taps,
  status colours and moves by drag are 14c (A-2). The demo's service
  edits in its tests go through the controller's internal document.
- **Service moves are lost** on leaving the selection mode, on
  `resetLayout` and on `load` (decision 11 and D12, as designed); a host
  that wants them to outlive a restart needs a later `serviceJson()`.
- **Export in the selection mode plots the service copy** (A-3): the file
  name does not say so; the demo's log does.

## For the human

- **Look owed:** run `apps/restaurant_demo` (`flutter run -d chrome`, or
  macOS / Windows / Linux / Android / iOS): place tables in Salon's
  design mode from the Symbols tab, switch to Service, select by number,
  Export and Print; switch back (the discard question appears after a
  service edit, which 14c makes possible by hand).
- **Next:** 14c (selection-mode behaviour: table pick by tap, status
  colours, moves) and the touch spike 14t, each with its own spec.
