# Task 6 report — the placement tool: pointer, snap, ghost

Commit: df916b7 `feat(app): the symbol placement tool` (on 8a44a5c; b981cf4
amended with test-only tightening found by the mutant run, lib unchanged).
Files: apps/floor_planner/lib/symbols/symbol_place_tool.dart (new),
apps/floor_planner/test/symbols/symbol_place_tool_test.dart (new, 14 tests).
Engine and render untouched (no file under packages/ changed; not re-run).

## Gate (app), after the amend
```
02:37 +841: All tests passed!          (827 + 14)
No issues found! (ran in 1.3s)
Formatted 149 files (0 changed) in 0.75 seconds.   format_exit=0
✓ Built build/web          (built at b981cf4; the amend touched only the test file)
```

## API
`SymbolPlaceTool(ValueNotifier<SymbolEntry?> armed) extends Tool`; `name`
'Symbol'; `phase` pressed/idle; `isMidShape` = a live press; `cursor` precise
when armed, defer when idle; `ghostVisible`, `ghostAt` (the resolved point),
`@visibleForTesting ghostPath`, `quarterTurns`, `mirrored` (read-only);
`const kGhostCrossPixels = 6.0` (the cross half-size, px).

## Decisions
- D6-1 cancelled press: no marker field. A move carrying the primary button
  with no live press (or another pointer's) is ignored; an up with no live
  press places nothing. This covers pointer cancel, `cancel` from the
  controller/layer, and (Task 7) Esc, without a stale marker when a pointer
  cancel sends no up. Hover moves (no buttons) always move the ghost.
- D6-2 re-arm (`armed` listener): drops the press (its remaining moves/up are
  ignored by D6-1), looks up the new cached path, notifies. Turns and mirror
  are kept (spec silent; Task 7 may decide otherwise).
- D6-3 the matrix's `update` is called once, in `paintWorldOverlay` (it
  recomputes P only on change, Task 5), so every mutation site need not.
- D6-4 after a placement the ghost stays visible at the release point (the
  pointer is there; as `PlacementTool`'s marker). On touch it lingers until
  the next event: acceptable, noted.
- D6-5 `_quarterTurns` / `_mirrored` are `final` (prefer_final_fields) with a
  comment: Task 7 makes them mutable. Every placement goes through the one
  private `_place(ctx, entry, at)`, where Task 7 adds the permission check.
- D6-6 `onKey` returns `ignored` (Task 7).
- Not done (as in `PlacementTool`, which only re-resolves on camera change
  while a shape is pending): no camera listener; a wheel zoom leaves the
  ghost at its last world point until the next pointer event. Task 7/9 may
  revisit; low value.

## Fixtures
office.chair (base off origin) and bath.toilet (re-arm), from the asset;
`prepareDocument(InsertionPointMeasurer())`; a page grid 25 mm from origin
(70000.3, -40000.7); a line whose start E = (73250.5, -41810.25) is off the
grid; camera 0.05 px/mm, y up, centred at (76000, -41000) (aperture 200 mm);
paint origin (70000, -40000). Snap test: a release 75 mm from E snaps to E
(not raw, not grid); a hover 234 mm away gets the grid point. The test that
checks the ghost paint uses a `RecordingCanvas implements ui.Canvas`
(noSuchMethod) to read `transform`, `drawPath` (path identity, stroke,
colour), the two cross lines, and to see that nothing is drawn when hidden.

## Mutants
Driver: scratchpad/b6/mut.sh (cp backup, one-line python replace, run
test/symbols/symbol_place_tool_test.dart in the foreground, cp back; every
restore printed `restore diff exit=0`). Lines are symbol_place_tool.dart at
df916b7. All red.

| id | line | mutation | red test(s) (real output) |
|---|---|---|---|
| M-09b1 | 161 | `_resolve(ctx, e.world);` removed (places at the press) | `+1 -1: pointer a release places at the snapped release point, not the press [E]` |
| M-09b16 | 163 | `_place(ctx, entry, e.world)` (raw) | release test, touch, cancel, stays-armed, `+5 -5: snap a release within 10 px (not 10 mm) of an endpoint places on it; beyond the aperture, on the grid [E]` |
| M-09b17 | 123 | `apertureWorld: kSnapAperturePixels` | `+9 -1: snap a release within 10 px (not 10 mm) ... [E]`, `+9 -2: snap the snap marker is drawn in screen space at the snapped point [E]` |
| M-09m | 79 | `isMidShape => false` | `+3 -1: pointer isMidShape is true between press and release, and notifies [E]` |
| M-09b18 (exit) | 171 | `_ghostVisible = false` removed | `+13 -1: the ghost hides on pointer exit and on cancel [E]` |
| M-09b18 (cancel) | 188 | `_ghostVisible = false` removed | `+4 -1: pointer a pointer cancel drops the press ... [E]`, `+12 -2: the ghost hides on pointer exit and on cancel [E]` |
| cancel keeps the press | 186 | `_pressed = false` removed | `+4 -1: pointer a pointer cancel drops the press: its moves are ignored and its up places nothing; the next press places [E]` |
| cancelled moves followed | 148 | the pressed-move guard removed | `+4 -1: pointer a pointer cancel drops the press ... [E]` |
| M-09b19 | 44 | `armed.addListener` removed | `+7 -1: pointer re-arming notifies, drops the press and swaps the ghost path; the next placement is the new symbol [E]` |
| re-arm keeps the press | 109 | `_pressed = false` removed | `+7 -1: pointer re-arming notifies ... [E]` |
| listener not removed | 243 | `armed.removeListener` removed | `+8 -1: pointer dispose removes the armed listener [E]` (first fire survived: the notifier swallows the disposed-notifier assert; the test now counts listeners) |
| path per paint (M-09b13 analogue) | 220 | `ui.Path()..addPath(_path!, …)` | `+11 -1: the ghost paints the cached path ... [E]`, `+11 -2: the ghost a second paint reuses the path, the matrix storage and the paint [E]` |
| matrix per paint | 228 | `Float64List.fromList(_matrix.forOrigin(origin))` | `+12 -1: the ghost a second paint reuses the path, the matrix storage and the paint [E]` |
| origin ignored (M-09b14 in the tool) | 228 | `forOrigin(Vector2.zero())` | `+11 -1: the ghost paints the cached path ... [E]`, `+11 -2: ... reuses ... [E]` |
| stroke not scaled | 229 | `kPreviewStrokePixels` | `+11 -1: the ghost paints the cached path ... [E]` |
| ghost ignores `at` | 224 | `at: Vector2(73000, -41000)` | `+11 -1: ... [E]`, `+11 -2: ... [E]` |
| cross not scaled | 230 | `k = kGhostCrossPixels` | `+11 -1: the ghost paints the cached path ... [E]` |
| idle not inert | 134 | the null-armed guard removed | `+5 -1: pointer a secondary press does nothing; idle (nothing armed) is inert [E]` |
| secondary presses | 135 | the primary-button guard removed | `+5 -1: pointer a secondary press does nothing; idle ... [E]` |
| marker at raw point | 205 | `p = Vector2(E + (60, -45))` | `+10 -1: snap the snap marker is drawn in screen space at the snapped point [E]` |

Test tightening found by the run (in the amend): the release test sends the
up at a point no move reported (so M-09b1 is the press point, not the last
move); the dispose test counts the notifier's listeners.

## Open / notes
- 'the fixtures are not degenerate' is a precondition guard; no mutant.
- Rotated/mirrored placements are not exercised here: the turns and mirror
  are Task 7's keys (fields final until then). P-3's "rotated and mirrored"
  for the tool lands in Task 7's tests.
- Brief asked for "no ghostPathFor call count change": ghostPathFor has no
  counter (Expando-cached); identity of the drawn path across two paints and
  against `ghostPathFor(entry)`, plus the reused matrix storage and Paint, is
  what the test pins (mutants path-per-paint and matrix-per-paint red).

## Task 6b (review finding 1, test-only)
Commit: 76e5f8b `test(app): the placement tool follows the snap settings and the adaptive grid (6b)` (on 67688a1).
Only apps/floor_planner/test/symbols/symbol_place_tool_test.dart changed; Task 7's tests are untouched.
The Rig gained `objectSnap` (non-null: a SnapSettings in the context) and `step` (null: the page has no fixed grid step). Both default to the old behaviour.
Two new tests:
- 'with object snap off (F3), a release near E lands on the grid'
- 'with no fixed grid step, a release lands on the zoom-adaptive step of dragGridStepMm'. It asserts that the step is not 25 mm, and that the expected point differs from the raw point and from the 25 mm grid point.

Gate (app):
```
03:34 +859: All tests passed!          (857 at 67688a1 + 2)
No issues found! (ran in 1.5s)
Formatted 149 files (0 changed) in 0.72 seconds.   format_exit=0
```
Mutants (scratchpad/b6b/mut.sh; symbol_place_tool.dart at 67688a1; each restore printed `restore diff exit=0`):
| mutation | line | red test (real output) |
|---|---|---|
| `objectSnap: true` | 139 | `+9 -1: snap with object snap off (F3), a release near E lands on the grid [E]` |
| `gridStepMm: page?.gridStepMm` | 141 | `+10 -1: snap with no fixed grid step, a release lands on the zoom-adaptive step of dragGridStepMm [E]` |
