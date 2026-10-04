# Plan 14c — selection-mode behaviour

**Spec:** [2026-10-03-selection-mode-design.md](../specs/2026-10-03-selection-mode-design.md),
revision 2 (S1–S10, R-1..R-14). Approval as recorded in the spec.
**Branch:** `claude/exciting-pasteur-9m22jv` (spec at `7487809`; the
picker landed early at `851a2f3`).

## Global constraints

- `CLAUDE.md` non-negotiables; engine and render **not edited**; no golden
  change; the two allocation invariants untouched.
- The selection mode executes only `TransformNodeCommand`s on the copy.
- Every task ends with the planner, app and demo gates green.

## Tasks

### Task 1 — the picker, finished (S1, S2, R-2, R-8)

Tops cached per definition for the picker's life; the asymmetric
servable fixture (an off-centre trapezoid) in the tests; M-14c2-11.

### Task 2 — the tool and the callbacks (S3, S4, S8, R-1, R-5, R-6, R-7)

`TableSelectTool` (tap, Shift/Ctrl tap, long press, drag-move, pan, Escape,
cancel; `kTouchSlop`, `kLongPressTimeout`); locked tables tapped only;
`ServiceView` builds it with its picker and a settings reader;
`FloorPlanView` gains `onTableTap` and `onLayoutChanged`. Tests under fake
async: M-14c2-3..-6, -9, M-14l, cancel mid-gesture.

### Task 3 — the status layer (S5–S7, R-3, R-4, R-10, R-12, R-14)

`TableStatus` (public); `tableStatuses` / `setTableStatus` on the
controller, resolved by number against the active plan; `PlannerView`'s
underlay slot; `TableStatusPainter` with a prebuilt list and identical
objects per frame. Tests: M-14d, M-14g (pixels), M-14c2-7, -8 (structural
and counter), -10.

### Task 4 — the barrel and the demo (S10, R-13)

The barrel shows `TableStatus`; the demo's status row, seeded random
statuses, tap and layout log lines; tests.

### Task 5 — the exit

Gates, both web builds, a Chromium smoke of the demo in the service mode,
results note, STATUS, roadmap.
