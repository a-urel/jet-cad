# Task 10a report — the end-to-end test

Commit: c8f7a21 `test(app): the symbol palette end to end` (on 5566da3; ec908e2 amended once before any review, see Mutants: the snap fixture was strengthened).
Files: apps/floor_planner/test/symbols/symbol_palette_end_to_end_test.dart (new, 1 test). No lib change.

## Gates (app; engine and render untouched, unchanged)
- `CI=true flutter test`: `03:03 +885: All tests passed!` (884 + 1) (at c8f7a21)
- `CI=true flutter analyze`: `No issues found! (ran in 1.5s)`
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 153 files (0 changed) in 0.71 seconds.` fmt=0
- `CI=true flutter build web --release`: `✓ Built build/web`
- New file alone: `00:02 +1: All tests passed!`

## The flow (no direct tool call)
App over FakeDocumentFiles, loader over the real asset by File, the real
SymbolThumbnails (a subclass that only records the futures it returns).
aimCamera(far): rotated 0.3 rad, 0.1 px/mm, centred (41234.5, 27345.25).
A short line is drawn first with L + two clicks + Esc Esc at 2.5 px/mm (fine
grid), so its stored end (read from the payload) is off the 200 mm grid of the
0.1 px/mm placement zoom; then aimCamera(far). tap tab-symbols; enterText 'bed';
receiveAction(search) (the platform's Enter) -> canvas focus; gallery ids
contain bed.double@1, not dining.chair@1, fewer than the library.
ensureVisible; runAsync(cache.settle); the bed cell's RawImage is non-null
and isCloneOf an image from the given cache. Select active before the tap;
tap the cell -> SymbolPlaceTool active, armed == bed.double, canvas focused.
Mouse down at far+(900.5,-650.25); sendKeyEvent(R) mid-press (tool stays
active); move; move to lineEnd+(62.5,-55.25); up.
Asserts: one InstanceNode; one undo step; the snapped release point
(resolveDragPoint from the shell's index/page/camera/snap on the raw
release world point) == the line's stored end, > 50 from raw, > 10 from the
grid-only resolution of raw (so the object snap decides), > 1000 from the
press's resolution; linear part exactly placementTransform(at: snapped,
basePoint: bed.double's, quarterTurns: 1, mirrored: false)'s and equal to
[0,1,-1,0]; translation within Tolerance.standard; SymbolComponent on the
definition. Cmd+Z: no instance, definition gone, no SymbolComponent, tool
still armed. Cmd+Shift+Z: same handle, definition, exact transform.
saveAsStep -> bytes == codec bytes; openFlow with them -> swapped document,
same transform; saveStep -> second bytes == first.

## Decisions
- Save As / Open / Save through the host's steps (as DO1 in document_open_test),
  not the toolbar: 12a tests the toolbar wiring; here the round trip's bytes matter.
- Snapping: the "near a drawn line" variant (snapped != raw), the line drawn
  through the real Line tool.

## Mutants
Driver scratchpad/b10a/mut.sh (cp backup, one python replace asserting one
match, run the e2e file in the foreground, cp back, diff). Every restore
printed `restore diff exit=0`; final `git status --short` shows only
packages/jet_cad/analysis_options.yaml (pub get, never staged). Lines at c8f7a21.
Test name abbreviated: `E2E the Symbols tab, search "bed", ...`.

| id | file:line | mutation | result (real output) |
|---|---|---|---|
| cell tap not arming | main.dart:785 | `onSelect: _armSymbol,` -> `onSelect: (_) {},` | RED `Expected: not <Instance of 'SelectTool'> Actual: <Instance of 'SelectTool'>` `00:02 +0 -1: E2E ... [E]` |
| R not reaching the tool | symbol_place_tool.dart:211 (inserted) | `if (key == LogicalKeyboardKey.keyR) return KeyEventResult.ignored;` | RED `Expected: same instance as <Instance of 'SymbolPlaceTool'> Actual: <Instance of 'RectangleTool'>` `00:03 +0 -1: ... [E]` |
| R swallowed, no turn (extra) | symbol_place_tool.dart:212 | `keyR ||` dropped from the R/M test | RED `Expected: [0.0, 1.0, -1.0, 0.0] Actual: [1.0, 0.0, 0.0, 1.0]` `00:03 +0 -1: ... [E]` |
| M-09b1, places at the press (end to end) | symbol_place_tool.dart:163 + :176 | pressed moves ignored (`if (pressedMove) return;`) AND up's `_resolve(ctx, e.world);` removed | RED `translation [43175.0, 25950.0] vs [40505.0, 27550.0]` `00:03 +0 -1: ... [E]` |
| M-09b1, Task 6's one-line form | symbol_place_tool.dart:176 | up's `_resolve(ctx, e.world);` removed | SURVIVES `00:03 +1: All tests passed!` -- equivalent through the widget path, see below |
| shell not passing the cache | main.dart:778 | `thumbnails: widget.thumbnails ?? (_own...)` -> `thumbnails: (_own...)` | RED `Expected: non-empty Actual: []` (the given cache got no request) `00:03 +0 -1: ... [E]` |
| app not passing the cache (extra) | main.dart:149 | `thumbnails: _thumbnails` removed | RED `Expected: non-empty Actual: []` `00:02 +0 -1: ... [E]` (fired on ec908e2; that part of the test is unchanged) |
| cells show no image | jet_cad_2d_flutter symbol_gallery.dart:384 | `image: _image,` -> `image: null,` | RED `Expected: not null Actual: <null>` `00:02 +0 -1: ... [E]` |
| M-09b16 (extra) | symbol_place_tool.dart:178 | `_place(ctx, entry, _at.point)` -> `e.world` | RED `Expected: true Actual: <false>` (translation) `00:03 +0 -1: ... [E]` |
| M-09b17 (extra) | symbol_place_tool.dart:138 | aperture not divided by `cam.scale` | RED `Expected: true Actual: <false>` `00:03 +0 -1: ... [E]` (SURVIVED on ec908e2, see below) |
| object snap off (extra) | symbol_place_tool.dart:139 | `objectSnap: false` | RED `Expected: true Actual: <false>` `00:03 +0 -1: ... [E]` |

Honest record:
- On ec908e2 M-09b17 SURVIVED (`00:02 +1: All tests passed!`): the line had
  been drawn at 0.1 px/mm, so its end sat on the 200 mm grid, and a release
  within the 100 mm aperture rounds to that same grid point: object snap and
  grid snap were indistinguishable (the aperture disk lies inside the grid
  cell). Fixed by drawing the line at 2.5 px/mm (its end off the coarse grid)
  and a premise that the grid-only resolution of the raw release differs from
  the snapped point by > 10 mm; M-09b17, M-09b16 and object-snap-off then red.
  The commit was amended before any review: c8f7a21. All mutants above were
  re-fired on the final file (except the app-level cache one, whose assertion
  is unchanged).
- M-09b1's one-line form (Task 6's) is EQUIVALENT end to end: a pointer up
  arrives at the last reported position (a `TestGesture.up()` has no position,
  and the engine's pointer converter synthesizes a move before an up at a new
  location), and the tool resolves every pressed move, so `_at` already holds
  the release point at the up. The tool-level test of Task 6 (an up at a point
  no move reported) remains its red test. The two-line form above is the
  "places at the press point" mutant at this level.
- One malformed extra mutation of symbol_gallery.dart was run by mistake and
  discarded unrecorded; it was restored by the same cp and the tree is clean.

## Defects found
None. The flow passed through the real widgets; no lib code touched.

## Observations (no change made)
- Mid-press, a key the tool returns `ignored` for reaches the shell's letter
  bindings and switches the tool during a press (seen under the "R ignored"
  mutant: RectangleTool active mid-press). The real tool swallows every key
  mid-press except F/F3, so this is unreachable today; noted as the shell
  having no mid-press guard of its own for letters.
