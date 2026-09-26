# Task 12 — carried (binding, in addition to the plan's Task 12)

First, as a separate commit ("Task 11 minors and the ulp re-seat"):
1. **I1, part 1 (wall_grips.dart `_keptPut`, Task 8's D13 rewrite):** when the
   rewritten position p′ = L′ − (L − p) would make the opening clamped only by
   rounding (its cut against the new stretches is clamped by ≤ wallJoin.linear),
   store `storedCentreOf(...)` instead. Test: the Task 11 reviewer's probe — 200
   walls, each with a door placed flush against the far end with storedCentreOf,
   each wall's start grip dragged once with WallGrips.drag — after the fix,
   0 opening.clamped (before: 99 of 200). Keep EP1–EP6 green (their positions
   must still equal L′ − (L − p) where that is unclamped). Mutant: the old rule
   → red.
2. **I1, part 2 (opening_grips.dart `drag`):** return null only when the new
   centre == the stored position, or when it is within wallJoin.linear AND the
   opening's current cut is unclamped. Test: a door clamped by 1e-7 (hand-made)
   and a door left ulp-clamped by a D13 drag are re-seated by a grip drag onto
   their own edge (a command, and opening.clamped gone); SG1's "back to start"
   stays null. Mutant: the old tolerance rule → red.
3. **m1:** SG1 gains a nudge: a door at 1000 dragged to 1030 with aperture 67
   (F3 on) must move to 1030 (its own edges are never candidates);
   rv11-selfCand (drop `j != index`) → red.
4. **m2:** a one-line render/app test: a fill plus an opening selected draws no
   rotation grip; rv11-fillMovable → red.
Then the plan's Task 12 (the Opening section of the Selection panel). Follow the
panel conventions from fix/post-07 and 07 (PanelFieldFocusNode.handBack on
Enter and tap-outside, tool-settings mode, pinned commit targets, refused-edit
catches) — spec D16. The tool-settings for D/N/G widths live here too. Scratch
prefix `t12-`.
