# Task 6 report

## Commits
- ba812dd test(app): a placed symbol through paint, pick, snap and the codec (Part A)
  files: apps/floor_planner/test/symbols/symbol_end_to_end_test.dart, apps/floor_planner/test/support/select_rig.dart. No lib change.
- 22bc83d test(app): tolerance sweep boundary and a read-only library entry (Part B, test-only)
  files: test/symbols/symbol_library_test.dart (R27b-e), test/symbols/symbol_placer_test.dart (P19).

## Part A: what the end-to-end test proves
bed.double from the committed asset (basePoint (800,1000)), at (12345,-6789), quarter turn 1, mirrored, TrueColor(0x33AA77), lineweight 70.
Expected positions come from a hand formula (mirror local x, rotate 90 ccw, move base to at), not Transform2.
1. Painter: 4 strokes in ascending handle order at the transformed vertices (1e-6 slack for the camera round trip), each argb 0xFF33AA77 and weight 70.
   Control: the same placement at the default style draws 0xFFFFFFFF / 25 (so the test cannot pass at defaults).
2. Pick on the line mid-span, pillow 1 edge (11665,-6414) and pillow 2 edge: each returns its own leaf, chain = [instance]. Pillow 1's world point unmirrored would belong to pillow 2, so the mirror is pinned by pick too. A miss at the origin.
3. Snap (SnapMask.cheap, radius 10) onto pillow 1 vertex (11665,-6089) and the line endpoint (12045,-5989): kind endpoint, right leaf, within Tolerance.standard.linear. Insertion point not asserted (F-12).
4. Extents (11345,-7589)-(13345,-5989). 5. validate() empty. 6. save, load (registerAppComponents), save byte-identical.

Case 2 (Select tool, P-6 item 2), real SelectTool through a small rig built on the render package's public exports (select_rig.dart): a press on the selected placed instance classes as selectedBody, a drag moves it (one undo step, transform e/f + (200,-125), definition/style untouched, pick finds the leaf at the moved position); the rotation grip of the selection box turns it about the box centre (one undo step, leaves found by pick at the independently rotated positions, validate() empty).
FINDING: move and rotate grips WORK on a placed, mirrored InstanceNode. Nothing to record for 09b except that an instance has no per-leaf reshape grips (spec D3, by design).
FINDING: GripCache/OutlineCache follow the change stream asynchronously; a test must yield (Future.delayed(Duration.zero)) before reading box/pivot after a command.
FINDING (P-5, R-T5-2): a BYBLOCK symbol leaf under a default-style instance resolves to StyleContext.documentRoot: ACI 7 (argb 0xFFFFFFFF with the default foreground) and lineweight 25 (0.25 mm). Recorded by the control.
No engine or render defect found (P-7 not triggered).

## Part A mutants (symbol_end_to_end_test.dart only; every backup restored, diff exit 0)
| Mutant (symbol_placer.dart) | First red assertion | Both tests? |
|---|---|---|
| M-09c rotation: line 49 Transform2(1,0,0,1,0,0) | painter "leaf 0 vertex 0: got [13145,-7789], want [13345,-5989]" | test 1 and test 2 red (-2) |
| M-09c mirror: line 50 scale(1,1) | painter "leaf 0 vertex 0: got [13345,-7589] want [13345,-5989]" | -2 |
| M-09d colour: line 135 ByBlockColor() | "leaf 0 colour" expected 4281576055 actual 4294967295 | -1 |
| M-09d lineweight: line 136 kByBlock | "leaf 0 weight" expected 70 actual 25 | -1 |
| M-09a: line 51 translation(0,0) | painter "leaf 0 vertex 0: got [12345,-6789]" | -2 |
| identity transform at the placer (line 129) | painter "leaf 0 vertex 0: got [0,0]"; test 2: pressClass empty, not selectedBody | -2 |
Because the painter block runs first, I also ran M-09a and identity against temporary copies of the test with the painter block removed (deleted afterwards): pick goes red ("the line leaf, mid-span"); with painter AND pick removed, the snap assertion goes red alone ("pillow 1's first vertex (11665, -6089)"). So the snap assertion catches M-09a independently. The mirror is also pinned by pick (pillow 1 vs pillow 2) and by the literal (11665,-6089).
Test names: "a real symbol, rotated and mirrored ... codec" and "the Select tool moves and rotates a placed, mirrored instance (P-6 item 2)".

## Part B
B1 (m-T3-1), symbol_library.dart line 291 `p.scalars[2].abs() <= Tolerance.standard.angular`. New cases: R27b sweep 5e-10 refused, R27c -5e-10 refused, R27d exactly 1e-9 refused, R27e 2e-9 and -2e-9 load.
- mutant `p.scalars[2] == 0`: R27b, R27c, R27d red (3 failures), "the library was accepted; expected a rejection naming [1074, zero sweep]".
- mutant `.abs() < angular`: R27d red.
- mutant without `.abs()`: R27e (-2e-9) red, "SymbolLibraryError: leaf 1074 of 1068 has a zero sweep".
B2 (i-T4-1), P19: snapshot of every field of every leaf record and payload coords/scalars plus the entry fields; place rotated+mirrored twice into one document (copy then reuse) and once into another; entry byte-equal afterwards; copies are equal values but not identical buffers.
- mutant `leaf.payload.coords[0] += 1` in the copy loop: P19 red (snapshot differs, only it). Mutant scalars[0] += 1: P19 red.

## Gates (Linux, CI=true, after commit 22bc83d)
- app: +776 all passed (768 + 8 new: 2 e2e, 5 sweep, 1 P19); analyze: No issues found; format: 0 changed.
- engine: +1121 -2 (2 standing); analyze clean; format clean.
- render: +974 ~1 -7 (standing); analyze clean; format clean.
- `CI=true flutter build web --release`: "Compiling lib/main.dart for the Web... 41.2s", "Built build/web".
packages/jet_cad/analysis_options.yaml stays modified and unstaged.
