# Task 13 — carried (binding, in addition to the plan's Task 13)

First, as a separate commit ("Task 12 minors"), tests only:
1. **m1:** pin `_keptPut`'s `moved:` neighbour half — a node drag moving a host's
   start and a joined neighbour's end at once, with an opening near the host's
   start corner: its position must be exactly L′ − (L − p) (the neighbour's NEW
   geometry used for the host's stretches). Mutant rv12-movedHostOnly
   (`moved: {h: now[h]!}`) → red.
2. **m2 — EP8:** the reviewer's P5 — a door flush against the START stretch end,
   the start dragged 0.5 mm inward: position == L′ − (L − p) and diagnosed
   opening.clamped (not re-seated). Mutant rv12-seatWide (threshold 1 mm) → red.
3. **m3:** OS1 tests position == L (inclusive) is accepted; rv12-posEnd
   (`value < l`) → red.
4. **m4:** a no-fit opening dragged by the grip to within tolerance of its
   stored position returns null (no command); rv12-gripNoFit (no-fit counted as
   clamped) → red.

Then the plan's Task 13 (sample plan rebuilt, spec D18). **Its first step is
binding:** run a printing probe and compare with the spec's figures (549 live
entities, 24 pieces, 40 mm SP4 margins, exact extents, the door/window tables
and obstacle intervals). If any figure differs, STOP before pinning any literal
and report the measured numbers to the controller (end your turn with the
report); do not change the spec yourself. Spec amendments since the plan: D7,
D8 (admission order, keep-a-piece, degenerate host), D10, D12, D13 (re-seat),
D14, D16, D17. Scratch prefix `t13-`.
