# Task 8 report: shared shape helpers (K6)

Commit 21d14ff0 feat(kit): the shared shape helpers (K6)
Files: packages/jet_cad_2d_kit/lib/src/authoring/shapes.dart, lib/authoring.dart (one export), test/authoring/shapes_test.dart. Code and test copied verbatim from the brief, then `dart format`.

Tests: shapes_test.dart 8/8 pass; full package `flutter test` 196 passed; `flutter analyze` no issues; format gate exit 0. (The RED compile-failure step was skipped; the mutations below are the red evidence.)

Mutations (committed file, each reverted with git checkout, `git diff --quiet` exit 0 each time). Red lines as printed:
- M-H2 (rect swaps w/h): `+1 -1: H2 rect and inset are closed, off the origin [E]`; also `H7 ... [E]`
- M-H3a (_chairBack 70): `+2 -1: H3 a chair: a 450 square on its centre, the back 165 away from the table [E]`; also H4
- M-H3b (back on table side): `H3 a chair ... [E]`; also H4
- M-H4a (_around without -pi/2): `+3 -1: H4 chairs around a round top ... [E]`; `H6 stools around a round top ... [E]`
- M-H4b (r + 225 + 100): `+3 -1: H4 chairs around a round top ... [E]`
- M-H4c (facing a, not a+pi): `+3 -1: H4 chairs around a round top ... [E]`
- M-H5 (circles swapped): `+4 -1: H5 a stool: the seat, then the footrest, on one centre [E]`
- M-H6 (+ stoolTuck): `+5 -1: H6 stools around a round top reach 40 under it, the first below [E]`
- M-H7a (_p uncleaned): `+6 -1: H7 every coordinate is cleaned to 1e-6, and no zero is negative [E]`
- M-H7b (return r): `H7 ... [E]` and `+6 -2: H8 cleanCoordinate [E]`
- M-H7c (rect without _p): `H7 ... [E]`
