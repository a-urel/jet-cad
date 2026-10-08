# Zone focus: results

**Asked by the human:** *"evet, bölgelerle devam et"* (2026-10-08). At
the question of what a zone is, the human ruled: **a zone lives in the
host's database**, as the table's attribute; jet-cad stores none.

**Spec:** [2026-10-08-zone-focus-design.md](../specs/2026-10-08-zone-focus-design.md),
revision 2. Revision 1 was reviewed independently (*Approve with
fixes*, V-1 to V-19, all accepted).

**Plan:** [2026-10-08-zone-focus.md](../plans/2026-10-08-zone-focus.md).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `14616d9`
(release 0.2.0).

**Process.** Each of Tasks 1–3 had a fresh implementer, then an
independent reviewer working in its own clone. Task 4, the docs and the
exit, was the controller's. An independent review of the whole range
closes the slice.

## What a host gets

- **`fitToTables(numbers)`**:
  - It frames the tables carrying those numbers, in either mode, with a
    500 mm margin and at least 3 m per axis. The scale is clamped to the
    zoom limits.
  - It returns `false`, and changes nothing, when no table matches.
  - It rides `fitToView`'s machinery:
    - with no view shown, the next view frames on its first frame;
    - the last request wins;
    - the numbers resolve when the fit is performed;
    - the view's size is read then too;
    - `load` and `newPlan` drop the request, and `setMode` keeps it.
- **`setTableFocus(numbers)` and `tableFocus`**:
  - In the selection mode, a veil of the paper's colour at 0.6 covers
    the tables outside the focus. It covers each table's rotated box,
    minus the focused tables' boxes.
  - A group with no focused member fades with them.
  - Faded tables still work.
  - The focus is not saved, and it is kept across loads and mode
    switches.
- **`FloorPlanTable.visible`**: false for a table on a hidden layer.
- **The host guide's "Zones: framing and focus"** covers:
  - zone tabs, *All* and "My tables";
  - how to make a faded table inert;
  - the unplaced-tables recipe;
  - the number rules a POS code must keep.
- **The schema is unchanged.** There is no new planner string.
- **The demo:** the Salon gains zones A, B and C, with *All* and a "Fade
  the others" switch.

## The tasks

| Task | Commit | Review | Fixes |
|---|---|---|---|
| 1, the candidate rule and the framing (Z0–Z9) | `ba7eec2` | **Approved.** R-1: a table near the double range gave an infinite camera. R-2: aliasing the host's set was unpinned. R-4: a doc word. | In `fdc8918`: an overflow-safe centre and a page fallback; VZ12; the doc |
| 2, the focus and the veil (Z10–Z13, Z15–Z17) | `fdc8918` | **Approved; tests only.** The veil's repaint on a service move and on a paper change, and its order under the outlines and chips, were unpinned (O1–O4, O13). | In `3531e7d`: RV1–RV3, TG-Z4, FP7 |
| 3, groups, `visible`, the demo (Z14, Z22, Z24) | `3531e7d` | **Approved.** R-1: a locked focused member, unpinned. R-3: the demo's per-area state, unpinned. R-4: `visible`'s doc. | `3d9c827`: RX1, DZ1's two lines, the doc, the CHANGELOG's `toString` line |
| 4, docs and the exit (Z20, Z21, Z23) | `5022cc9`, this note | — | — |

Per-task reports, reviews and fixes are in
`.superpowers/sdd/2026-10-08-zone-focus/` (git-ignored). They are archived
to `docs/superpowers/ledgers/` on merge.

## Named mutants

Every named mutant from M-Z1 to M-Z43 went red. The tasks' reports
list each one with its killer.

- **Task 1:** 21, plus 4 extras. M-Z33's killer, VZ10, was strengthened,
  because the spec's half passed with the `!mounted` guard removed.
  M-Z32 needed a table in the new plan to go red.
- **Task 2:** 17, plus the four mutants of Task 1's review, plus 2
  extras.
- **Task 3:** 4, in 27 variants, plus the Task 2 review's O1–O4 and
  O13.
- **Task 4:** M-Z28. An edited `showZone` in the probe makes
  `check_guide` exit 1.
- **After Task 3's review:** N3, fading over selectable members only,
  is red under RX1.

**Equivalent mutants:**
- **The degenerate-camera guard (O10):** a camera with a degenerate
  determinant cannot be constructed, so removing the guard changes
  nothing.
- **`tableFocus` dropped from the group painter's `shouldRepaint`
  (N9):** `ServiceView`'s painters are `late final`, so the old and new
  delegates are the same object.

**Accepted gaps:**
- **R-2 of Task 3's review:** a layer missing from the table counts as
  shown. Only a corrupt file reaches it.
- **R-5:** the demo's toggle keeps its zone after *Fit*.
- **R-5 of Task 2's review:** measuring the service painters with the VM
  allocation profiler is left as a follow-up. The structural recording
  canvas (14c R-3) is the gate today.

## Gates (at `5022cc9`)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | "1255 tests; the standing failures and skips, exactly". Analyze and format clean. |
| render `packages/jet_cad_2d_flutter` | "1363 tests; the standing failures and skips, exactly". Analyze and format clean. |
| GPU `packages/jet_cad_2d_gpu` | **20 passed**, exact. Analyze and format clean. |
| planner `packages/jet_cad_floor_plan` | **1,435 passed**, exact (1,380 at `14616d9`). Analyze and format clean. |
| restaurant symbols | **97 passed**, exact. |
| app `apps/floor_planner` | **212 passed**, exact. `flutter build web` ✓, from a clean `build/`, 42M, no `flutter_scene` assets. |
| demo `apps/restaurant_demo` | **39 passed** (37 before), exact. `flutter build web` ✓, from a clean `build/`, 42M. |
| harness `apps/dev_harness_2d` | **82 passed**, exact. |
| `tool/ci` | **58 passed**. `check_guide`: all 16 code blocks are in the host probe. |
| host probe at `5022cc9` | exit 0, run from a clone at the full SHA: "no GPU renderer, no build hook; build/web is 42M". |

After `3d9c827` (RX1, DZ1's two lines, a doc comment):
- the planner's group painter test passes 15 of 15;
- the demo passes 39;
- analyze and format are clean.

The engine and the renderer are untouched by the slice.

**Smoke test** in Chromium, on the web builds at `5022cc9`, with
Playwright:
- **The demo:**
  1. The Salon is put in Service.
  2. Zone B frames tables 6 and 7, with table 3 at the edge.
  3. "Fade the others" veils table 3 under the paper's colour, while 6
     and 7 stay clear. The veil's `Path.combine` ran on CanvasKit.
  4. No console error.
- **The floor planner:** *Open sample* shows the plan, with no console
  error.

## Found, not fixed

- **Headless Chromium's language in this container is `en-US@posix`.**
  Under it, both apps fail at start with "Incorrect locale information
  provided" (the floor planner) or a load error (the demo).
  - This is the container's environment, not a browser a person uses.
  - It is the same at release 0.2.0; nothing in this slice touched it.
  - With `locale: 'en-US'` both start clean.
  - Whether a host should guard against a malformed browser locale is
    left as a question.
- **A table far out (corners about 1e308)** frames by falling back to the
  page, and the veil does not throw natively. The web renderers were not
  tried with such a table.

## Owed

- **To the human:**
  - Q-Z3: a look on a tablet and a terminal, light and dark, covering:
    - the 500 mm margin;
    - the 3 m minimum span;
    - the 0.6 veil;
    - a caption overhanging the veil at low zoom (R-5 of the spec).
  - The German and Turkish read of the demo's three strings.
- **To Monépro:**
  - Q-Z1: whether its phase 2 needs a public world-to-screen mapping for
    its own status widgets.
  - Q-Z4: its D21 should say the link is `pos_tables.code`, under 14a's
    number rules.
- **The merge**, on the human's word. Unreleased: CHANGELOG
  *Unreleased*.
