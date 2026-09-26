# Task 8 — carried (binding, in addition to the plan's Task 8)

1. **Task 7 Minor 1:** OR2 (opening_object_test.dart) uses only whole-number
   positions and widths, so a lossy save survives it. Give OR2 at least one
   fractional position and one fractional width (e.g. 1400.37, 912.625);
   mutant rv7-posRound (`opening.dart` toJson: `'position': position.roundToDouble(),`)
   must turn OR2 red. Separate small commit or part of Task 8's — say which.
2. Spec amendments since the plan: D7, D8, D10, D12, D17 — read the ones your
   task touches (D13 is unchanged).
3. Scratch-file prefix: `t8-`.
