# Task 11 — carried (binding, in addition to the plan's Task 11)

First, as a separate commit ("Task 10 minors"):
1. **m1 — OT3 drawn vs stored edges:** add the reviewer's P1 — a 6000 wall with a
   T obstacle and a window stored at o2+400, width 1000, drawn clamped at
   [o2, o2+1000]; a 600 door pressed at scale 0.5: a click at o2+312 snaps to the
   DRAWN edge (stored ≈ o2+300), a click at o2+205 does NOT snap to the undrawn
   stored edge (stored ≈ o2+205). Add a no-fit other opening whose stored edges
   must not attract. Mutant rv10-storedCuts (candidates from stored centre ± w/2)
   → red.
2. **m2 — aperture:** the local aperture divides by the length of the host's
   `toWorld` applied to the frame direction `f.d` (exact for non-uniform scale),
   not by `scaleMagnitude`. Test: a host group scaled non-uniformly (e.g. 2 × 0.5)
   along a rotated centreline — the snap engages exactly at the world aperture.
   Mutant: `scaleMagnitude` → red.
Then the plan's Task 11. Binding notes for it:
- The slide grip stores the centre with `storedCentreOf` (Task 9's ulp fix; D14/D16)
  and snaps edges with `edgeSnap` (Task 10) on the point the select tool has
  already snapped (Ruling 08-15) — M-08sn becomes a multi-site mutant: fire it
  at every site and name each red test.
- Spec amendments since the plan: D7, D8, D10, D12, D14 (swing from the midline),
  D17. Ruling 08-16: `movable` is honoured at all four select-tool call sites, in
  hitsRotationGrip and the hover cursor.
Scratch prefix `t11-`.
