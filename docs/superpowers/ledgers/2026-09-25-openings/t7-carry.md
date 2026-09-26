# Task 7 — carried (binding, in addition to the plan's Task 7)

1. **Task 6 m-2:** OG9 (opening_cut_test.dart) checks, for every opening in
   the random run, that its drawn symbol matches the oracle
   (`OpeningOracle.drawn` / `expectDoorOnOracle` / `expectLinesOnOracle`), and
   that no FITTING symbol lies strictly inside its host's pieces (D12; no-fit
   symbols are exempt — spec D12's recorded limit). Report the counts in OG9's
   print. Mutants: rv6-clampedStored (a fitting clamped opening drawn over its
   stored interval) and a symbol mutant of your choice must turn OG9 red. If
   the oracle's `capUs` throws "no face edges" on geometry OG9 builds, report
   it; do not widen the generator to hit it.
2. Spec amendments since the plan: D7, D8, D10 (arc anticlockwise in own
   space), D12 (no-fit limit), D17 — read them.
3. Scratch-file prefix: `t7-`.
