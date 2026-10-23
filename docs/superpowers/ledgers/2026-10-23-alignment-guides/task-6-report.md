# Task 6 report: alignment guides in design moves

Commit: da43f3c3 `feat(plan): alignment guides in design moves` (on 09d04ccd).

## What was built
- `lib/src/guides/plan_move_guides.dart`: `PlanMoveGuides implements MoveAdjuster`.
  `begin` is eligible only if every moved handle is `movable` and `unionOf` succeeds
  (box kept in one `Float64List(4)`); `adjust` returns (solution cleared) when not
  eligible, `!settings.on` or Alt; else solves on box + (raw - base) with aperture
  (touch ? 10 : 6) / camera.scale, ortho pin by `resolveDragPoint`'s rule
  (`|dx| >= |dy|` pins y), fallback = target - raw, and writes ONLY captured axes
  (`target.x = raw.x + dx`). `objectSnapped` does not stop the solve. `suppress`/`end`
  reset the one `GuideSolution`; `paint` draws it via `GuidePainter`.
  `@visibleForTesting debugSolution`.
- `lib/src/guides/guide_painter.dart`: `GuidePainter` (one Paint, one Float32List of
  16 line + 16*3 mark segments, `drawRawPoints(PointMode.lines)`, unused tail zeroed to
  degenerate segments), `kGuideOverhangPixels = 8`, `kGuideTickPixels = 4` (tick reaches
  4 px to each side of the mark's end, 8 px total; overhang and ticks along the segment's
  own screen direction, normalised without allocation).
- Wiring: `buildGenericTools(moveAdjuster:)`; `DocumentSession` takes `guideSettings` and
  `guideStrokePixels`, owns `late final GuideReferenceCache guides` (`units: () => units`)
  and `late final PlanMoveGuides moveGuides` (`movable` = root-level `InstanceNode`);
  `PlanController` passes `_alignmentGuides` / `() => guideStrokePixels` and has
  `@visibleForTesting PlanMoveGuides get debugMoveGuides`.
- Test: `test/guides/design_move_guides_test.dart` (20 tests, DG-1..DG-15 + premise +
  4 painter tests).

## Deviations to know
- The brief says "restaurant kit". `jet_cad_2d_plan` has no dependency on it; the rig uses
  the plan tests' own real-`PlanController` fixtures (`fxKit`, `tableSymbol`, `placementAt`,
  tool_events-style driving with Shift/Alt/touch added). Tables: A 30 deg at (6000,4000),
  B 90 deg at (9000,6800) (mover), C mirrored+0.2 rad at (3400,1800); camera scale 1.5,
  y flipped, off origin. All expectations are computed from the transforms.
- Attachment test (DG-14) is tool-level (a real `SelectTool` + real `PlanMoveResolver` +
  `PlanMoveGuides` over a hand-built document with the wall shelf scene of
  move_resolver_test), because a controller needs a kit with an attachment provider.
  It has a positive control (no attachment: lineCount 1).
- DG-15 calls `adjust` directly: through a drag the equivalent mutant
  (`raw + (target - raw)` for an uncaptured axis) vanishes in rounding downstream.

## TDD evidence
Stub `PlanMoveGuides` (no-op) and `GuidePainter` (no-op) were wired first so the tests
compiled. Red run (before implementation): 14 failures of 19 (DG-1, 3, 4, 5, 6, 7, 8, 9,
11, 12, 14 + 3 painter tests; e.g. `DG-1 ... Expected: true Actual: <false>` at the
`capturedX` check; `GuidePainter a line overhangs ... Expected: within 0.001 of
-76.635 Actual: 0.0`). DG-2, DG-10, DG-13 and the premise pass without an implementation
by design (they pin "no capture"); their mutations are below. Then green: 19 passed
(DG-15 added afterwards, 20 total).

## Mutations (each applied alone to the committed code, whole test file run, then reverted)
Command: `flutter test test/guides/design_move_guides_test.dart` in packages/jet_cad_2d_plan.
Real output, trimmed to the failing test line and its first lines:
=== MUTATION M1-objectSnapped-short-circuits
00:00 +7 -1: DG-7 guides beat a pointer object snap: a wall endpoint 3 px from the pointer does not pull x off the guide, on three moves 1 px apart; y [E]
    Expected: true
    Actual: <false>
    move -1
=== MUTATION M2-pin-rule-inverted
00:00 +8 -1: DG-8 Shift: a mostly horizontal drag keeps y at the base exactly and draws no y line, though y would have captured [E]
    Expected: true
    Actual: <false>
=== MUTATION M3-fallback-from-raw-not-target
00:00 +6 -1: DG-6 spacing recheck reads the chain's y: a between capture whose row stops overlapping once the grid moves y is dropped; the same drag w [E]
    Expected: false
    Actual: <true>
    the spacing capture is dropped
=== MUTATION M4-begin-ignores-movable
00:00 +12 -1: DG-12 a selection of a table and a wall line moves as it does with the guides off; so does one of a table and a group [E]
    Expected: <0>
    Actual: <1>
    not eligible (group: false)
00:01 +18 -1: Some tests failed.
=== MUTATION M5-suppress-does-not-clear
00:00 +14 -1: DG-14 a wall-attaching symbol over a wall: the attachment's transform is committed and no guide is drawn [E]
    Expected: <0>
    Actual: <1>
    suppressed: no guide for the event
=== MUTATION M6-aperture-not-divided-by-scale
00:00 +2 -1: DG-2 the same drag 7 px away captures nothing and equals the drag with the guides off (differential) [E]
    Expected: false
    Actual: <true>
=== MUTATION M7-touch-ignored
00:00 +3 -1: DG-3 a fingertip's aperture is 10 px: 7 px away captures [E]
    Expected: true
    Actual: <false>
=== MUTATION M8-alt-ignored
00:00 +9 -1: DG-9 Alt held: the move equals the guides-off move [E]
    Expected: <0>
    Actual: <1>
=== MUTATION M9-setting-ignored
00:00 +4 -1: DG-4 grid mixing: with grid snap on, an x capture lands on A's edge and y stays on the grid; the jump is at most half a step plus the ape [E]
    Expected: a value greater than <0>
    Actual: <0.0>
    Which: is not a value greater than <0>
    the capture changed x
00:00 +6 -2: DG-7 guides beat a pointer object snap: a wall endpoint 3 px from the pointer does not pull x off the guide, on three moves 1 px apart; y [E]
    Expected: a numeric value within <1e-9> of <-3146.6152422706627>
    Actual: <-3144.6152422706627>
    Which:  differs by <2.0>
00:00 +7 -3: DG-9 Alt held: the move equals the guides-off move [E]
    Expected: [
    6.123233995736766e-17,
    1.0,
    -1.0,
    6.123233995736766e-17,
00:00 +7 -4: DG-10 setting off: with the canvas allowance off nothing captures and the move is the guides-off move [E]
    Expected: <0>
    Actual: <1>
00:00 +7 -5: DG-11 toggled mid-drag with no pointer move: the preview falls back to the chain's point at once, and comes back on the next toggle [E]
    Expected: false
    Actual: <true>
=== MUTATION M10-uncaptured-axis-overwritten
00:00 +19: All tests passed!
=== MUTATION M11-box-shifted-by-chain-delta
00:00 +4 -1: DG-4 grid mixing: with grid snap on, an x capture lands on A's edge and y stays on the grid; the jump is at most half a step plus the ape [E]
    Expected: true
    Actual: <false>
00:00 +4 -2: DG-5 an off-grid press: the base is the snapped press, and the guided edge still lands exactly [E]
    Expected: true
    Actual: <false>
00:00 +4 -3: DG-6 spacing recheck reads the chain's y: a between capture whose row stops overlapping once the grid moves y is dropped; the same drag w [E]
    Expected: true
    Actual: <false>
00:00 +4 -4: DG-7 guides beat a pointer object snap: a wall endpoint 3 px from the pointer does not pull x off the guide, on three moves 1 px apart; y [E]
    Expected: a numeric value within <1e-9> of <5105.384757729337>
    Actual: <5106.051424396004>
    Which:  differs by <0.6666666666669698>
    move 0 lands on the guide
=== MUTATION M12-box-not-shifted
00:00 +1 -1: DG-1 a drag to 3 px from table A's left edge snaps B's box to it exactly; the commit is the preview; one undo restores B with ==, a redo [E]
    Expected: true
    Actual: <false>
00:00 +2 -2: DG-3 a fingertip's aperture is 10 px: 7 px away captures [E]
    Expected: true
    Actual: <false>
00:00 +2 -3: DG-4 grid mixing: with grid snap on, an x capture lands on A's edge and y stays on the grid; the jump is at most half a step plus the ape [E]
    Expected: true
    Actual: <false>
00:00 +2 -4: DG-5 an off-grid press: the base is the snapped press, and the guided edge still lands exactly [E]
    Expected: true
    Actual: <false>
00:00 +2 -5: DG-6 spacing recheck reads the chain's y: a between capture whose row stops overlapping once the grid moves y is dropped; the same drag w [E]
    Expected: true
    Actual: <false>
00:00 +2 -6: DG-7 guides beat a pointer object snap: a wall endpoint 3 px from the pointer does not pull x off the guide, on three moves 1 px apart; y [E]
    Expected: true
    Actual: <false>
    move -1
00:00 +2 -7: DG-8 Shift: a mostly horizontal drag keeps y at the base exactly and draws no y line, though y would have captured [E]
    Expected: true
    Actual: <false>
00:00 +2 -8: DG-9 Alt held: the move equals the guides-off move [E]
    Expected: true
    Actual: <false>
00:00 +3 -9: DG-11 toggled mid-drag with no pointer move: the preview falls back to the chain's point at once, and comes back on the next toggle [E]
    Expected: true
    Actual: <false>
    premise: a capture is shown
00:00 +3 -10: DG-12 a selection of a table and a wall line moves as it does with the guides off; so does one of a table and a group [E]
    Expected: true
    Actual: <false>
00:00 +4 -11: DG-14 a wall-attaching symbol over a wall: the attachment's transform is committed and no guide is drawn [E]
    Expected: <1>
    Actual: <0>
    positive control: the guide is drawn

=== MUTATION M10-uncaptured-axis-overwritten
00:00 +15 -1: DG-15 an uncaptured axis keeps the chain's value bit for bit, object-snapped or not; the captured axis is raw + the offset [E]
    Expected: <240.60325381162752>
    Actual: <240.60325381162755>
    bit for bit, not raw + (chain - raw)
=== MUTATION M13-seats-are-references
00:00 +13 -1: DG-13 a plan whose only other objects are seats and walls draws no guide and moves as it does with the guides off [E]
    Expected: <0>
    Actual: <1>
=== MUTATION M14-overhang-along-screen-x
00:00 +16 -1: GuidePainter a line overhangs 8 px past each end along its own screen direction under a rotated camera [E]
    Expected: a numeric value within <0.001> of <-76.63514448555274>
    Actual: <-80.66010284423828>
    Which:  differs by <4.024958358685538>
=== MUTATION M15-no-overhang
00:00 +16 -1: GuidePainter a line overhangs 8 px past each end along its own screen direction under a rotated camera [E]
    Expected: a numeric value within <0.001> of <-76.63514448555274>
    Actual: <-72.66010284423828>
    Which:  differs by <3.975041641314462>
=== MUTATION M16-tick-along-span
00:00 +17 -1: GuidePainter a gap mark is a segment across the gap with a 4 px tick at each end, perpendicular on screen [E]
    Expected: a numeric value within <0.001> of <0>
    Actual: <8.000091898648694>
    Which:  differs by <8.000091898648694>
    tick 1 is perpendicular
=== MUTATION M17-stale-tail-not-cleared
00:01 +18 -1: GuidePainter a shorter solution after a longer one leaves nothing stale [E]
    Expected: <1608.6712646484375>
    Actual: <-3612.12890625>
=== MUTATION M18-mark-axis-swapped
00:00 +17 -1: GuidePainter a gap mark is a segment across the gap with a 4 px tick at each end, perpendicular on screen [E]
    Expected: a numeric value within <0.001> of <-2859.8661017838185>
    Actual: <-1468.8447265625>
    Which:  differs by <1391.0213752213185>
=== MUTATION M19-session-movable-always-true
00:00 +12 -1: DG-12 a selection of a table and a wall line moves as it does with the guides off; so does one of a table and a group [E]
    Expected: <0>
    Actual: <1>
    not eligible (group: false)

Note on M10: the first mutation run (before DG-15 existed) survived (`All tests passed`),
because the mutant is equal to the chain's value up to rounding that does not survive
the committed transform. DG-15 was added for it and then turned red (output above).
M3/M11/M12 etc. map to the brief's named mutations: objectSnapped short-circuiting
(M1), pin rule inverted (M2), fallback from raw instead of target (M3), `begin` ignoring
`movable` (M4, plus M19 in session.dart), paint ignoring suppress (M5).
M13 mutates guide_references.dart (task 4 code) to show DG-13 pins "seats are no reference".

## Gate (jet_cad_2d_plan)
- `flutter test --enable-vmservice`: `04:01 +1704: All tests passed!` (was +1684; +20)
- `flutter test --enable-vmservice test/invariants`: `00:11 +15: ... All tests passed!`
- `flutter analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 334 files (0 changed)`, exit 0
- `git status --short` before commit: only the 3 modified lib files, the 2 new lib files and
  the new test; no analysis_options.yaml.
`jet_cad_2d_flutter` untouched (no gate run needed).

## Concerns
- Allocation: `adjust`/`paint` allocate nothing by construction (reused solution, box,
  painter list; `begin` iterates). No allocation test added here (invariants belong to a later
  task); `ctx.camera.value.scale` is a pure getter.
- Mid-drag toggle (DG-11) is checked on the adjuster's solution, since the tool's preview target
  is private; the preview-vs-commit identity is checked in DG-1.
- Tick convention (4 px each side) is my reading of "4 px ticks"; change `kGuideTickPixels`
  semantics in guide_painter.dart if the spec means 4 px total.
- Only `movable` roots handled; units generated by a root group (group handle) are references
  but a drag of the group itself is not guided (group is not an InstanceNode), as briefed.
