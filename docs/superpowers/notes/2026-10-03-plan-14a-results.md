# Plan 14a results — table identity

**Branch:** `claude/exciting-pasteur-9m22jv` (after plan 14b-1 + 14s).
**Spec:** [2026-10-03-table-identity-design.md](../specs/2026-10-03-table-identity-design.md),
revision 2; the human's rulings on Q-1 to Q-4, and "bu branch'te devam
edebiliriz" (2026-10-03). **Plan:**
[2026-10-03-table-identity.md](../plans/2026-10-03-table-identity.md).
**Not merged.** Merging is the human's word.

In the design mode, every servable symbol placed is a numbered table: the
next free number on placement, drawn upright at the top's centre on the
screen and on paper, editable in a **Table** section of the Selection
panel, with the seats shown and two buttons turning the table 90° in
place. Deleting a table deletes its number; clicking the number selects
the table; a turned or mirrored table's number reads upright.

## Commits

| Task | Commits | Review |
|---|---|---|
| Spec rev 1, 2; rulings | `fcf03ba`, `c68df27`, `aa3759c`, `dfe00db` | rev 1: Ready with fixes (R-1..R-13), applied in rev 2 |
| Plan | `3892024` | — |
| 1 Render: the pick mapping, the delete cascade | `955e6f8` | **Approved with fixes** (shared review of 1–3) |
| 2–3 The table model; placement numbers a table | `b4b586a` | idem → `355e12f` (F-1..F-8, all in tests) |
| 4 The table system | `fc0dbe3` | **Approved with fixes** (shared review of 4–5) |
| 5 The Table section, the rotate buttons | `c951bf7` | idem → `c3b8278` (F-1 an unchanged commit showed an error line; F-2..F-10 tests and small fixes) |

One implementer (this session) for every task; the reviews were
independent agents that re-ran the gates in their own worktrees and fired
their own mutants. A first reviewer of Task 1 ended early on an API error
before reporting; its worktree was removed and the review re-run with
Tasks 2–3.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | untouched by this plan (1,226 + 2 standing, as recorded) |
| render `packages/jet_cad_2d_flutter` | **1,196 passed**, 1 skipped, **7 failed** — exactly the standing seven (`text_ladder` rungs 1–5, `text_lod_ladder` rungs 1–2, canvas goldens); analyze, format clean |
| planner `packages/jet_cad_floor_plan` | **892 passed**; analyze, format clean |
| restaurant `packages/jet_cad_restaurant_symbols` | **91 passed**; analyze, format clean |
| app `apps/floor_planner` | **192 passed**; analyze, format clean |
| app web build | `✓ Built build/web` |

**Web smoke (Chromium, tr-TR, the built app):** four round tables and a
round booth placed from the palette carry 1–4 at their centres; a click
on the booth's number selects the booth; two presses of *Rotate 90°
right* turn it 180° in place with its number upright; renumbering it 12
redraws it; giving table 2 the number 12 is refused with "Number 12 is
already used" and the field reverts. No page error.

## Mutants fired

Spec-named, all red: M-14a-1 (count + 1), -2 (a deleted number), -3
(non-numeric counted), -4 (self-clash, case folding), -5 (no cascade, at
the root and in a group), -6 (the ATTRIB picked alone), -7 (mirror
ignored), -8 (rotation ignored), -9 (a translation stamps), -10 (the stamp
dropped from the inverse), -11 (replace instead of stack), -12 (the label
off layer 0 — killed through the layer filter), -13 (an unservable symbol
numbered), -14 (fixed height), -15 (about the origin; right turning left),
-16 (the label on the definition), -17 (thumbnails numbered), -18 (no
eight-digit fallback), -19 (cascade not de-duplicated), -20 (the inverse
with the stamp's authority). Own, all red: the error line cleared by the
focus-loss re-parse; the rotate buttons in runtime; a foreign slot
released (after moving the assert behind the release); the review's
survivors R3, R5, R8, R10, P5–P7, P21, P34, P36, P39, P41, P42 (Tasks
1–3) and A3, A9, A12, A13, B1, B2, B4, B5, B11, B17, B21 (Tasks 4–5).
**Survive, recorded:** A1 (the table system's rollback: no stamp can be
made to throw), B15 (the section in a tool mode: needs the whole shell),
F-9's fix (clearing the survey right after a write; no visible effect).
**Equivalent, removed:** P28/P33 (the survey's two sorts) — `tree.nodes`
is ascending by contract, so the sorts were dead and are gone.

## Amended at execution

- **T12, the out-of-order dispose.** The spec asked the table system to
  catch the parametric system being disposed first. It cannot: the
  parametric system's `dispose` is a silent no-op while the slot holds the
  table system's tear-off, and nothing tells the table system. The debug
  assert catches the case it can see (the slot taken by someone else, which
  is never released); the shell's order is fixed in code and pinned by
  `document_host_test`'s empty-slot checks (DH5 goes red when the order
  is swapped) and, since the review, a debug assert in
  `PlannerShell.dispose` that the slot is empty after both disposes.
- **The Number field needs `geometry` only** (T14), not `components` too
  as the other fields do; the duplicate line is drawn in the theme's
  tertiary colour (a warning), the refusal in its error colour.
- **"Design mode only" for the rotate buttons (Q-4)** is, until 14b-2
  names the modes, "the permissions allow `geometry`": the selection
  mode's `runtime` does not.
- **The placement test** lives in `test/tables/table_placement_test.dart`
  (TP1–TP7), not in an extended `seating_test.dart` SE8 (review F-9).

## Found, not fixed

- **A plan placed before 14a** (on this branch only; `main` never had a
  servable table) carries unnumbered tables: the Table section numbers one
  on its first commit; there is no "number all".
- **Three or more characters on a bar stool** overflow its Ø 380 seat
  (spec risk, accepted).
- **A negative width factor** is written for a mirrored table's label; the
  future DXF writer must map it to the "backward" flag (spec risk).

## For the human

- **Look owed (macOS and web):** place tables, turn and mirror them while
  placing (R, M), turn them after with the Table section's buttons or the
  rotation grip, renumber one, try a taken number, delete one and undo,
  print a PDF: the numbers must read upright everywhere.
- **Next:** 14b-2 (the host API, the design / selection modes, the undo
  barrier, `apps/restaurant_demo`), its own spec first; the touch spike
  (14t); 14c (the selection mode).
