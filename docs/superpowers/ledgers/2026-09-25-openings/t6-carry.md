# Task 6 — carried (binding, in addition to the plan's Task 6)

1. **Task 5 m-1:** pin the exact corner comparison in opening.clamped: the
   reviewer's probe — a free 3,000 wall, 150, left-justified, far origin at 23°,
   a 900 window stored 5e-7 past uS (`position = uS + 450 − 5e-7`) — must report
   `opening.clamped [opening]` whose message contains "corner". Mutant
   rv5b-cornerTol (the corner judged with `± wallJoin.linear`) must go red.
   Also add a one-line comment in OG11 (d) saying why it filters
   `opening.clamped` for window A at [0, 1000] (rounding at uS), after checking
   that that is the reason.
2. **Spec amendments since the plan was written** (read them): D7 (a T obstacle
   covers the stem's whole footprint — Task 3 review S1), D8 (openings admitted
   in ascending handle order; a wall keeps a piece; a degenerate host's openings
   are no-fit and **draw nothing**), D17 (clamped names walls by exact overlap).
   D11's outside symbol applies to no-fit openings on a host WITH a frame; a
   degenerate host's openings generate no children — OD1's `kids(doc, hD)`
   assertion must stay green once generate draws symbols.
3. **Cost on the edit path (Task 5 review):** once each opening's generate needs
   its cut, n × hostCutsInView runs per host edit (~8 ms per wall edit at 50
   openings on one wall, measured on diagnostics). Measure a host edit with 50
   openings after your change (print, like RC2); if it exceeds ~5 ms, memoise
   the host's cuts per host within one generation pass (e.g. a cache on the
   ParametricView/survey keyed by host handle, or computing all of a host's
   openings' layouts once) — report the numbers before and after.
4. `HostCuts.params` (Task 5 m-3) is yours to use or remove.
5. Unique scratch-file prefix: `t6-`.
