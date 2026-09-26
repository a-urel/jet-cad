# Task 5 — carried (binding, in addition to the plan's Task 5)

1. **Spec D8 amended** (controller, "A wall keeps a piece"; commit after
   4950c40): after merging, if the wall would have no piece longer than
   `wallJoin.linear`, the fitting opening with the HIGHEST handle becomes
   no-fit (outside symbol later in Task 6; `opening.nofit` now) and the cuts
   are placed and merged again without it; repeat until a piece remains or
   no fitting opening is left. Tests: (a) a free wall with a gap spanning its
   whole span (w ≈ L); (b) Task 4 reviewer's probe — a free centred wall
   2,000 long with windows at 500 (1,000) and 1,500 (1,000): each alone gives
   3 kids, both together gave 0 kids — now the higher-handle one is no-fit
   and the wall keeps its pieces; (c) the perpendicular-T probe whose span is
   [100.0000000006, 1499.99999999989] with a gap 5e-7 shorter than the span
   (end pieces of 2.5e-7). Mutant: "allow a zero-piece wall" → red. The
   diagnostics must report it as opening.nofit (and not also clamped).
2. **Task 4 m2:** assert `isSimpleCcw` on every stored piece (extend
   `storedPiecesTriangulate` or add a sibling used by OG1/OG2/OG9); mutant
   RV-4 (the middle piece reversed to `[R(b), L(b), L(a), R(a)]`) must go red.
3. **Task 4 m3:** assert the first centreline piece starts exactly at the
   stored start and the last ends exactly at the stored end (`==`, stored
   values) — per wall in OG9 or in OG8; mutant RV-1 (end centreline stops at
   `f.at(f.len, 0)` instead of `f.e`) must go red.
4. **Task 3 m5 (verbatim):** `mergeCuts` joining only when
   `c.$1 <= out.last.$2` (no `+ linear`) must make OG6 go red (a sliver
   piece); `overlaps` without the `− linear` must make a touching pair
   report `opening.overlap`.
5. Task 3's recorded limits (a short stem over-blocks; the parallel skip's
   jump) are NOT to be fixed.
