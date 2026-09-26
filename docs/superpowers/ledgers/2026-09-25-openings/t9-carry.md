# Task 9 — carried (binding, in addition to the plan's Task 9)

First, as a separate small commit ("Task 8 minors"), in
apps/floor_planner/test/opening_end_drag_test.dart:
1. **m1 — EP6:** pin `_keptPut`'s liveness check (root-level GroupNode). Build
   by hand two stray components `OpeningParams(host: A)`: one on a GroupNode
   nested under a plain root group, one on a handle with no node. Start-drag
   A: the compound's opening sets are exactly `[door]`, the strays' positions
   are unchanged (==). Mutant rv8-noLive (the liveness check removed) → red.
2. **m2 — EP5 extended:** the reviewer's P2 — a 5000 wall shortened from its
   START to 1500 with a door at 600.5 and a window at 3900: nothing refused,
   positions p′ = L′ − (L − p) (possibly negative — legal, D6), diagnostics
   `[opening.clamped [door], opening.overlap [door, window], opening.clamped [window]]`,
   the wall keeps a piece, and dragging back restores positions exactly
   (600.5, 3900.0) and the wall bitwise.
3. **m3 — EP1:** the reason text claims the opening sets come "after the walls"
   but only handle order is asserted — drop that claim (the compound's internal
   order is not observable after `_run`).
Then the plan's Task 9. Spec amendments since the plan: D7, D8, D10, D12, D13
(unchanged), D14 (swing side from the band's midline — Ruling 08-23, M-08z3),
D17. Scratch-file prefix `t9-`.
