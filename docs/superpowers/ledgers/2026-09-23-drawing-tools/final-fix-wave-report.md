# Plan 05 — final whole-branch review fix wave: report

**Findings fixed:** F-1, F-2, F-3, F-6 (all of the final review's rulings;
F-4 and F-5 are debt/look-list items per the rulings, not code fixes).
**Commits:** `1d80caf` (F-1), `89c8051` (F-3), `eb6efba` (F-2), `f8b4269`
(F-6, docs). Each ends `Co-Authored-By: Claude Sonnet 5
<noreply@anthropic.com>`.

---

## F-1 (Important): furniture hid four door leaves/swings

**What changed** — `apps/floor_planner/lib/startup_plan.dart`:

- **The kitchen counter** moved from the south/west-wall L (touching the
  hall/kitchen door's and the front door's swing boxes) to a north/east-
  wall L, same 400 mm wall margin and 600 mm leg thickness as before:

  ```dart
  p.polygonRegion([
    x0 + 9100, y0 + 3100, //
    x0 + 5400, y0 + 3100,
    x0 + 5400, y0 + 2500,
    x0 + 8500, y0 + 2500,
    x0 + 8500, y0 + 400,
    x0 + 9100, y0 + 400,
  ]);
  ```

- **Bed 2** narrowed and moved from `(x0+2900, y0+6800)-(x0+4500,
  y0+8600)` to `(x0+2750, y0+5200)-(x0+4000, y0+7200)`: it now sits in the
  gap between the bedroom-1/2 door's swing (starts at `y0+7400`) and the
  hall/living partition door's swing (starts at `x0+4100`), clear of each
  by 100 mm.
- **The sofa** moved from `(x0+6000, y0+4200)-(x0+9000, y0+5100)` to
  `(x0+6000, y0+4500)-(x0+9000, y0+5400)`, clear of the kitchen/bath-
  living partition door's swing (ends at `y0+4300`) by 200 mm.

Every piece stays inside its own room and clear of walls/partitions. The
live count is unchanged at 509 (no entities added or removed, only
coordinates).

**Covering test** — `apps/floor_planner/test/startup_plan_test.dart`,
new `SP3`: reads every furniture boundary that has a fill (SP1's eight,
either a polyline or a circle) and every door's arc + leaf, sampled at
`t = 0, 0.25, 0.5, 0.75, 1.0` along each. A door's leaf line is the line
entity whose one endpoint is exactly the arc's centre and whose far
endpoint sits the arc's radius away (`Tolerance.standard`: which line is
the leaf is a geometric decision; the endpoints compared are the exact
stored values). Asserts none of the 70 sampled points (7 doors × 2
shapes × 5 samples) lands inside any furniture boundary (point-in-polygon
for polylines, distance-to-centre for circles).

**Commands and output:**

```
$ cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart
...
00:00 +7: SP3 no door leaf or swing lies under a furniture fill (Ruling F-1, M-05aa)
00:00 +8: All tests passed!
```

Also re-ran, unaffected:

```
$ CI=true flutter test test/planner_shell_test.dart
...
00:02 +12: All tests passed!
```
(covers the wall-click probes — the walls themselves are untouched).

**Named mutant M-05aa** (the L counter put back at its old coordinates):
backed up `startup_plan.dart` with `cp`, restored the pre-fix polygon,
ran SP3:

```
00:00 +7 -1: SP3 no door leaf or swing lies under a furniture fill (Ruling F-1, M-05aa) [E]
  Expected: false
    Actual: <true>
  door point [17900.0,9050.0] lies under a furniture fill
```

KILLED. Restored from the `cp` backup and `diff`'d empty (exit 0) before
re-running SP3 green.

---

## F-2 (Important): F3 and F swallowed mid-shape

**What changed** —
`packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
`onKey`: added, right after the Enter/finish branch and before the
catch-all `return KeyEventResult.handled`:

```dart
// Ruling F-2 (spec 05 D3, amended at execution): F3 (object snap) and
// F (Fill), with no modifier held, bubble to the shell even mid-shape.
// Neither ever touches the document, so the reason D3 swallows every
// other key-down -- keeping undo and redo off a half-placed shape --
// does not apply to them, and F3 is otherwise unreachable while a
// polyline is pending.
if ((key == LogicalKeyboardKey.f3 || key == LogicalKeyboardKey.keyF) &&
    !_hasModifier()) {
  return KeyEventResult.ignored;
}
```

with a new private helper:

```dart
static bool _hasModifier() {
  final hw = HardwareKeyboard.instance;
  return hw.isControlPressed || hw.isMetaPressed || hw.isAltPressed;
}
```

`HardwareKeyboard` added to the `flutter/services.dart` import list.
Every other key-down mid-shape, and both undo keys, are unaffected
(still `handled` mid-shape, `ignored` when idle).

**Covering tests:**
- `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart`, new
  `B10`: mid-shape, both F3 and F return `ignored` and the line stays
  pending; Z still returns `handled`. (Needed
  `TestWidgetsFlutterBinding.ensureInitialized()` at the top of `main()`
  — `HardwareKeyboard.instance` throws without a bound `ServicesBinding`,
  and this file's other tests are plain unit tests that never bind one.)
- `apps/floor_planner/test/planner_draw_test.dart`, new `A16`: `P`,
  two clicks (pending polyline), F3 — asserts the `osnap-text` flips from
  `OSNAP` to `osnap off`, the status stays `Polyline`, and the tool is
  still pending.

**Commands and output:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/placement_tool_test.dart
...
00:00 +12: B10 F3 and F bubble to the shell mid-shape; the shape stays pending (Ruling F-2)
00:00 +13: B11 a returning tool paints no stale snap marker until the next hover (Ruling F-3)
00:00 +14: All tests passed!

$ cd apps/floor_planner && CI=true flutter test test/planner_draw_test.dart
...
00:03 +15: A16 F3 mid-polyline flips OSNAP and keeps the shape pending (Ruling F-2)
00:03 +16: All tests passed!
```

**Named mutant M-05ab** (dropping the F3/F exception): backed up
`placement_tool.dart` with `cp`, removed the `if` block, ran both test
files:

```
00:00 +12 -1: B10 F3 and F bubble to the shell mid-shape; the shape stays pending (Ruling F-2) [E]
  Expected: KeyEventResult:<KeyEventResult.ignored>
    Actual: KeyEventResult:<KeyEventResult.handled>
```

```
   Which: is different.
          Expected: osnap off
            Actual: OSNAP
                    ^
           Differ at offset 0
the tool ignores F3, so it reaches the shell
...
00:03 +15 -1: A16 F3 mid-polyline flips OSNAP and keeps the shape pending (Ruling F-2) [E]
```

Both KILLED. Restored from the `cp` backup and `diff`'d empty (exit 0)
before re-running both files green.

**Spec:** added the "Amended at execution (Plan 05, final review)"
paragraph to D3 in
`docs/superpowers/specs/2026-09-23-drawing-tools-design.md`, citing
Ruling F-2.

---

## F-3 (Minor): stale snap marker on a returning tool

**What changed** — `placement_tool.dart`, `cancel`:

```dart
@override
void cancel(ToolContext ctx) {
  clearShape();
  // Ruling F-3: a tool that returns after a switch away paints no stale
  // snap marker; the next pointer move resolves a fresh one.
  _hoverVisible = false;
  _syncCamera(ctx);
  notifyListeners();
}
```

`ToolController.activate` calls `cancel` on the *outgoing* tool, so
switching away and back (`activate(SelectTool())` then
`activate(originalTool)`) leaves the original tool's `_hoverVisible`
stuck at whatever it was before the switch, unless `cancel` itself clears
it.

**Covering test** — `placement_tool_test.dart`, new `B11`: hovers near
the anchor (marker visible), `rig.tools.activate(SelectTool())`, then
`rig.tools.activate(rig.tool)` back. Asserts `paintOverlay` on a
`SpyCanvas` records no calls (the stale marker does not repaint), then
hovers again and asserts a fresh `drawRect` call appears.

**Command and output:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/placement_tool_test.dart
...
00:00 +13: B11 a returning tool paints no stale snap marker until the next hover (Ruling F-3)
00:00 +14: All tests passed!
```

**Kill** (removing the line): backed up `placement_tool.dart` with `cp`,
removed `_hoverVisible = false;` from `cancel`, ran the file:

```
00:00 +13 -1: B11 a returning tool paints no stale snap marker until the next hover (Ruling F-3) [E]
  Expected: empty
    Actual: [Instance of 'RecordedCall']
  the old marker must not repaint
```

KILLED. Restored from the `cp` backup and `diff`'d empty (exit 0) before
re-running the file green.

---

## F-6 (docs)

All in `STATUS.md`, `docs/superpowers/notes/2026-09-23-plan-05-results.md`
and `docs/superpowers/notes/plan-05-mutation-log.md`:

- **Task ranges.** `c4fcac4` is Task 8's head, not Task 9's (Task 9 is
  `6d98d72..5c55000`, per the ledger's own `progress.md`: `6d98d72` is
  the mutation-log commit that opens Task 9, `5c55000` is PL8's fixture
  fix that closes it). Split "Tasks 1–9 at `7dac3b5..c4fcac4`" into
  "Tasks 1–8 at `7dac3b5..c4fcac4`; Task 9 at `6d98d72..5c55000`" in
  STATUS.md (two places) and the results note.
- **`A9` → `SP1`.** The results note's sample-plan-count paragraph cited
  `A9 in startup_plan_test.dart`; `A9` is in `planner_draw_test.dart` (a
  different file, a different test). The count witness is `SP1`.
- **TX2 dropped from criterion 1's "both cameras" witness.** Checked
  `text_tool_test.dart`: `TX1` is inside the `for (flipY in [true,
  false])` loop; `TX2` is a standalone `test(...)` outside it, so it runs
  flipY true only. Criterion 1's row now reads `..., TX1` (was `TX1–TX2`).
- **M-05x's heading corrected.** It read "a zero-length first segment
  refused only by `==`, not by distance", which does not describe the
  edit (dropping the `_segments > 0 &&` clause in `LineTool.selfSnap`).
  Reread `line_tool.dart`: without that guard, a second click near the
  *unstarted* line's own start point self-snaps and `accept`'s
  `acceptingSelf` branch clears the shape outright, instead of refusing
  the self-snap and letting the normal resolve chain (and
  `isDegenerateSegment`) handle it. Retitled: "dropping the `_segments >
  0` guard self-snaps before any segment commits".
- **Deviations:** added a paragraph — only the first test/group in each
  draw test file loops over both `flipY` values (checked all seven files
  under `test/draw/`: `arc_tool_test.dart`, `circle_tool_test.dart`,
  `line_tool_test.dart`, `placement_tool_test.dart`,
  `polyline_tool_test.dart`, `rectangle_tool_test.dart`,
  `text_tool_test.dart` each have exactly one `for (final flipY in const
  [true, false])`, wrapping only their first test/group); the rest,
  including this wave's new B10/B11/A16, run once.
- **Debt:** added a paragraph on Ruling F-4 — `InteractionLayer._onCancel`
  (02, frozen) maps a platform `PointerCancelEvent` straight to
  `tool.cancel(ctx)`, which for a `PlacementTool` is `clearShape()`: the
  whole pending shape is lost, not just the point in flight. Not fixed;
  recorded as debt.
- **Criterion 14's look list:** added items 11–13 to all three platform
  sections (macOS, Chrome, Firefox) — door swings against the furniture
  (F-1), F3 mid-polyline (F-2), and text placed near the canvas's top/
  right edges for field clipping (Ruling F-5). Updated "Ten items per
  platform" to "Thirteen items per platform".
- **Mutation log:** added a "Final fix wave" section with full entries
  for M-05aa, M-05ab and the F-3 kill (file, edit, test, RED result for
  each); updated the top tally from "27 fired: 27 killed" to "30 fired:
  30 killed", and the title to note the fix wave's two new named mutants.
- **Results note counts:** mutation tally paragraph updated to 30/30 and
  a new paragraph naming the three fix-wave mutants; exit-gate row 10
  gained `SP3`; row 11's count updated to "30 fired, 30 killed"; Spec
  amendments list gained a D3 bullet (Ruling F-2) and the paragraph count
  corrected from five to six; "Files this task touched" note updated to
  match.

---

## Gates (final committed tree, `f8b4269`)

**Engine** (`packages/jet_cad_2d`):

```
$ CI=true dart test
...
00:03 +911: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 133 files (0 changed) in 0.26 seconds.
```

Exit 0 on all three.

**Render layer** (`packages/jet_cad_2d_flutter`):

```
$ CI=true flutter test
...
00:14 +913 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exactly the five standing golden failures, nothing else (912 passed + 1
skip, up from the pre-wave 911 + 1 skip by B10 and B11).

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
$ dart format --output=none --set-exit-if-changed .
Formatted 175 files (0 changed) in 0.35 seconds.
```

Exit 0 on both.

**Harness** (`apps/dev_harness_2d`, `--concurrency=1`):

```
$ CI=true flutter test --concurrency=1
...
00:20 +82: All tests passed!
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.06 seconds.
```

Exit 0 on all three (82, unchanged — this fix wave touched no harness
code).

**Floor planner** (`apps/floor_planner`), plus both release builds:

```
$ CI=true flutter test
...
00:03 +45: All tests passed!
$ flutter analyze
Analyzing floor_planner...
No issues found! (ran in 1.0s)
$ dart format --output=none --set-exit-if-changed .
Formatted 12 files (0 changed) in 0.04 seconds.
$ flutter build macos --release
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.3MB)
$ flutter build web --release
...
✓ Built build/web
```

Exit 0 on all five (45 = the pre-wave 43 + A16 + SP3 is counted under
`startup_plan_test.dart`, not this suite — see note below).

Note on the app count: `flutter test` under `apps/floor_planner` runs
every file in `apps/floor_planner/test/`, including
`startup_plan_test.dart` (SP3) and `planner_draw_test.dart` (A16); the
45 above is the whole app suite's total, not just `planner_draw_test.dart`
(16, shown separately above under F-2).

`git status --short` after every gate line printed nothing beyond the
files this wave intentionally changed (no `analysis_options.yaml`
rewritten; checked before every commit).

---

## Files changed

- `apps/floor_planner/lib/startup_plan.dart` (F-1: counter, bed 2, sofa
  moved).
- `apps/floor_planner/test/startup_plan_test.dart` (F-1: SP3 + helper).
- `apps/floor_planner/test/planner_draw_test.dart` (F-2: A16).
- `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart` (F-2:
  `onKey`'s F3/F exception, `_hasModifier`; F-3: `cancel`'s
  `_hoverVisible = false`).
- `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart` (F-2:
  B10; F-3: B11).
- `docs/superpowers/specs/2026-09-23-drawing-tools-design.md` (F-2: D3's
  spec amendment).
- `STATUS.md`, `docs/superpowers/notes/2026-09-23-plan-05-results.md`,
  `docs/superpowers/notes/plan-05-mutation-log.md` (F-6).

## Concerns / deviations from the brief's literal text

- The brief's SP3 description says "sample points along every door arc
  and door leaf line: the entities the door helper emits". The door
  helper also emits two jamb lines per door; these are not sampled
  (they sit on the wall itself, not swinging into the room, and the
  finding's four listed collisions are all leaf/swing collisions, never
  jamb collisions). Only the leaf line and the arc are sampled, matching
  the finding's own wording ("no door leaf or swing arc lies under a
  furniture fill").
- Because F-2 and F-3 touch adjacent code in the same two files
  (`placement_tool.dart` and `placement_tool_test.dart`), committing them
  separately needed a temporary intermediate state (F-3 alone, with F-2's
  block and B10 removed) rather than a straight `git add -p` hunk split,
  since git merged both changes into one unified-diff hunk. Verified
  green at each intermediate state before committing.
- `TestWidgetsFlutterBinding.ensureInitialized()` was added to
  `placement_tool_test.dart`'s `main()` for F-2's B10 (needed because
  `HardwareKeyboard.instance` throws without a bound `ServicesBinding`,
  and this file's tests are plain `test()`s, not `testWidgets()`); it is
  a no-op for every other test in the file.
