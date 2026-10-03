# Plan 14c results — selection-mode behaviour

**Branch:** `claude/exciting-pasteur-9m22jv` (after 14b-1, 14s, 14a, 14b-2).
**Spec:** [2026-10-03-selection-mode-design.md](../specs/2026-10-03-selection-mode-design.md),
revision 2. **Plan:** [2026-10-03-selection-mode.md](../plans/2026-10-03-selection-mode.md).
**Approval:** the human, travelling, asked not to be asked unless needed
(2026-10-03) and said "Devam et"; the umbrella's 14c rulings (single
select, long press for several, status colours, moves for the service
only) bind. **Not merged.**

In the selection mode a tap inside a table's top selects it and reports its
number to the host (`onTableTap`); Shift, Ctrl or ⌘ toggles; a long press
adds or removes a table; a drag on a table moves the selection in one undo
step on the service copy (`onLayoutChanged`); a drag on the floor pans; a
locked table is tapped only. The host colours tables by number with
`setTableStatus` (a colour and a caption of at most 12 characters, not
document state); the colours lie under the drafting, in `PlannerView`'s
new underlay slot. `apps/restaurant_demo` opens on two furnished sample
areas, Salon and Teras, with status buttons, random statuses and a log.

## Commits

| Task | Commits | Review |
|---|---|---|
| Spec rev 1, 2 | `b911cda`, `7487809` | rev 1: Ready with fixes (R-1..R-14), applied in rev 2 |
| Plan | `040a083` | — |
| 1 The picker | `851a2f3` (early), `b37152f` | **Approved with fixes** (shared review of 1–3) |
| 2 The tool, the callbacks | `31ec07b`, `65751ce` | idem |
| 3 The status layer | `f719b6d` | idem → `0ccda2e` (F-1..F-8) |
| 4 The demo | `e52918f`, `845901b` | review in progress at this commit |

One implementer (this session); independent reviewers re-ran the gates in
their own worktrees and fired their own mutants.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | **untouched**; 1,226 passed + 2 standing; analyze, format clean |
| render `packages/jet_cad_2d_flutter` | **1,197 passed** + 1 skip + 7 standing (text ladder rungs 1–5, text LOD ladder rungs 1–2, as before); analyze, format clean |
| planner `packages/jet_cad_floor_plan` | **961 passed**; analyze, format clean |
| restaurant symbols | untouched |
| app `apps/floor_planner` | **192 passed**; analyze, format clean |
| demo `apps/restaurant_demo` | **16 passed**; analyze, format clean |
| web builds | `apps/floor_planner` and `apps/restaurant_demo`: `✓ Built build/web` |
| `apps/dev_harness_2d` | analyze clean |

**Web smoke (Chromium, tr-TR), after `0ccda2e`:** the demo's Salon area in
the service mode shows the random status fills under the drafting, the
"Bill" captions below the stools' numbers; a tap selected table 3 and
logged it, a drag moved table 1 and logged the layout change; no page
error.

## Mutants fired

Spec-named, all red, fired again at `0ccda2e`: **M-14h** (the pick without
the inverse transform), **M-14c2-1** (the highest leaf, a chair, as the
top), **-2** (the lowest handle wins), **M-14l** (a locked table moved,
long-pressed or selected), **-3** (a step per move event), **-4** (the
translation snapped to 100), **-5** (a long press does not spend the
gesture), **-6** (the slop does not cancel the long press), **-8** (a
matrix per frame), **-9** (a tap reported on a drag), **-10** (a hidden
table painted; picked), **-11** (the inverse ignores the mirror; at Task
1), **M-14g** (the fill without the instance's linear part), **M-14d**
(a status change moves `revision`). **M-14c** (the topmost anything) is
excluded by construction (the picker reads table tops only) and pinned by
TP2's wall; **M-14c2-7** (statuses by handle) by SP4's renumber, not fired
as a code mutant.

The review's, red after `0ccda2e`: Q10 (a new status map ignored), S1 / S2
(the document changes / the statuses dropped from the layer's repaint),
Q3 / Q3b / Q4 (the caption's skip rule removed, always skipping, at the
origin), T1 (a 4 px slop), T14 (a drag on an unselected table keeps the
old selection), T18 (no zero-translation guard), T20 (Ctrl / ⌘ ignored),
T21 (the preview reversed), the cancelled timer left armed (F-2), and own:
the caption at the top's centre or 11 px below the number's anchor (F-5),
no eviction (F-8), an open first leaf served as a top (F-7), the step
applied to the transforms at the drag's start (R-6).

**Survive, recorded:** **P2** (the even-odd ray towards −x): equivalent,
either direction gives the same parity. **P12** (the circle's edge without
the 1e-6 tolerance): not observable. **T7** (the slop does not cancel the
timer, the gesture check in `_longPress` still holding) and **T8** (the
hover guard): equivalent — `InteractionLayer` sends hovers only while no
pointer is down, and the pointer check catches them, so ST9's hover line
cannot fail. **Q11** (`shouldRepaint` always false): equivalent, the
painter instance is stable for a copy. **T22** (Escape acting during a
gesture) and **T25** (dispose not cancelling the timer, which
`ServiceView`'s release cancels first): Info.

## Amended at execution

- **The render package was edited** (against the plan's "render
  untouched"): `RulerFrame._point` is guarded by `mounted`, since a
  pointer captured before a view was replaced (a reset mid-drag) kept
  writing the disposed frame's notifier; `test/ruler_frame_test.dart`
  pins it. The two allocation invariants and the goldens are untouched.
- **Statuses are resolved in the painter**, not in an internal controller
  view (R-4): the painter rebuilds its fills when the copy's state id,
  its tables' revision or the identity of the status map changes; one
  painter per copy makes that the same key. The layer repaints on the
  camera, the statuses and the document's changes (V17).
- **The caption goes below the number label** (review F-5): at the
  label's anchor, `max(11, h/2 · scale + 2)` px below it, `h` the label's
  stored height; S7's "11 px below the centre" overlapped the number
  above about 0.11 px/mm.
- **An open first leaf is no top** (review F-7, R-8): `tableTopOf` reuses
  `firstLeafOf` and requires the closing vertex by exact `==`.
- **The painter's caches are evicted** (review F-8): paints and captions no
  fill holds are dropped at each rebuild, so changing captions ("12 min",
  "13 min") do not grow them.
- **The allocation measurement lives in `table_status_painter_test.dart`**
  (SP1, structural, and a counter), not in a `status_allocation_test.dart`
  (review F-10).
- **The demo sets statuses on the selected tables** (S10 named a number
  field): the existing "Table numbers" field selects them, so the status
  row needs none. **The demo opens on two sample plans**
  (`assets/plans/salon.json`, `teras.json`), built by
  `test/sample_plans_test.dart` (`UPDATE_SAMPLES=1` rewrites them; the
  test fails when the assets differ from what it builds).

## Process

- **`31ec07b` did not end green:** it committed `test/host/view_test.dart`
  with a stray `show InteractionLayer;` line (the second line of a removed
  two-line import), which does not compile; `65751ce` repaired it
  (review F-9).

## Found, not fixed

- **A second finger:** after a first finger lifts, `InteractionLayer`
  turns a second finger's move into a down (review F-10). Multi-touch is
  the touch spike's (14t).
- **Service moves are lost** on leaving the selection mode, on
  `resetLayout` and on `load` (14b-2 decision 11, as designed).

## For the human

- **Look owed:** run `apps/restaurant_demo` (`flutter run -d chrome`, or a
  desktop or mobile runner): in Service, tap a table (the log shows its
  number), long-press a second, drag them, Random statuses, Export; the
  look at the colours and captions over the sample plans.
- **Next:** the touch spike 14t (pinch, two fingers, the long press on a
  real device), with its own spec.
