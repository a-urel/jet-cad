# Task 8 report: `RulerFrame`, and the exports

Branch: `plan-04/page-grid-rulers`, worktree
`/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-04-page-grid-rulers`.
Commit: `96c09d876ea2a3549ae59b64cb8b306c161bbd86` — `feat(render): RulerFrame
with a pointer notifier; exports`.

## What I implemented

- `packages/jet_cad_2d_flutter/lib/src/ruler_frame.dart`: `RulerFrame`
  (`StatefulWidget`, `{camera, page, child}`) and public `RulerFrameState`
  holding the pointer `ValueNotifier<Offset?>`.
  - Layout: an outer `Column` of two rows. Top row is a `SizedBox(height:
    kRulerThickness)` containing a `Row` with `crossAxisAlignment:
    CrossAxisAlignment.stretch` — a `SizedBox(24×24)` (`ruler-corner`) then
    an `Expanded` (`ruler-top`). Bottom row is `Expanded(child: Row(...))`,
    also `crossAxisAlignment: CrossAxisAlignment.stretch` — a
    `SizedBox(width: kRulerThickness)` (`ruler-left`) then an `Expanded`
    holding the pointer surface and `widget.child`.
  - Each of the three `CustomPaint`s (`ruler-corner`, `ruler-top`,
    `ruler-left`) is wrapped in its own `RepaintBoundary`, keyed exactly as
    the test expects.
  - Pointer surface: `MouseRegion(onExit: (_) => pointer.value = null,
    child: Listener(behavior: HitTestBehavior.translucent, onPointerHover,
    onPointerMove, onPointerCancel, child: widget.child))`. The `Listener`
    is translucent so `widget.child`'s own opaque `Listener` still receives
    every event underneath it.
  - `pointer` is disposed in `RulerFrameState.dispose`.
  - `_repaint` merges `camera`, `page`, `pointer` for the two bar painters;
    `_cornerRepaint` is `page` alone for the corner painter (it never reacts
    to pointer or camera).
- `lib/jet_cad_2d_flutter.dart`: added `export 'src/ruler_frame.dart';`
  right after `ruler_painter.dart`, per the brief.
- `test/ruler_frame_test.dart`: the three widget tests from the brief,
  verbatim, with one deliberate deviation noted below.

### One correction to the brief's own code, not to the numeric expectation

The brief's Step 3 sample implementation uses a plain `Row` (default
`crossAxisAlignment: CrossAxisAlignment.center`) for both the top and bottom
bars. Under that alignment `Row` gives its children loose cross-axis
constraints, and `CustomPaint` with no intrinsic content collapses to a
zero-height (top row) / zero-width (irrelevant there, left row is `Expanded`
already tall) box — the first test failed with `Expected: <24.0> Actual:
<0.0>` on `top.height`. This is a layout-constraint bug in the sample code,
not a wrong number: the fix is `crossAxisAlignment:
CrossAxisAlignment.stretch` on both `Row`s, which forces `ruler-top` and
`ruler-corner` to fill the `SizedBox(height: 24)`, and `ruler-left` /the
pointer surface to fill the `Expanded` row's height. I applied this to the
implementation (not to a test expectation — the brief's own numbers were
correct; only the sample layout code needed the fix).

No numeric test expectation needed changing. The tick-recovery arithmetic in
the third test worked as given.

### Hover-exit fallback: not needed

Step 4 offered a fallback (`child.topLeft - const Offset(30, 30)`) in case
`gesture.moveTo(const Offset(1, 1))` didn't fire `MouseRegion.onExit` under
the test binding. I used the brief's original `Offset(1, 1)` verbatim and it
worked on the first pass — `state.pointer.value` came back `null` as
expected, no fallback needed.

## TDD evidence

### RED (compile failure before `ruler_frame.dart` existed)

Command:
```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/ruler_frame_test.dart
```
Output (tail):
```
test/ruler_frame_test.dart:11:11: Error: 'RulerFrameState' isn't a type.
        Future<(RulerFrameState, int Function())> pump(WidgetTester tester,
                ^^^^^^^^^^^^^^^
test/ruler_frame_test.dart:15:27: Error: 'RulerFrameState' isn't a type.
      final key = GlobalKey<RulerFrameState>();
                            ^^^^^^^^^^^^^^^
test/ruler_frame_test.dart:22:18: Error: Method not found: 'RulerFrame'.
          child: RulerFrame(
                 ^^^^^^^^^^
00:00 +0 -1: loading .../test/ruler_frame_test.dart [E]
  Failed to load ".../test/ruler_frame_test.dart": Compilation failed ...
00:00 +0 -1: Some tests failed.
```

### First implementation attempt (brief's sample `Row`, no stretch) — RED again, but for the right reason

```
00:00 +0: the bars are co-extensive with the child and the corner is 24 x 24
Expected: <24.0>
  Actual: <0.0>
00:00 +0 -1: the bars are co-extensive with the child and the corner is 24 x 24 [E]
00:00 +0 -1: hover feeds the pointer in child coordinates; exit clears it; the child still hears it
00:00 +1 -1: a major tick in the top bar sits at its world point's x in the child
Bad state: No element
00:00 +1 -2: a major tick in the top bar sits at its world point's x in the child [E]
00:00 +1 -2: Some tests failed.
```
(The second and third failures cascade from the first: with `ruler-top` at
zero height, no tick had room to be a labelled major, so `firstWhere`
found none.)

### GREEN (after adding `crossAxisAlignment: CrossAxisAlignment.stretch` to both `Row`s)

```
00:00 +0: loading .../test/ruler_frame_test.dart
00:00 +0: the bars are co-extensive with the child and the corner is 24 x 24
00:00 +1: hover feeds the pointer in child coordinates; exit clears it; the child still hears it
00:00 +2: a major tick in the top bar sits at its world point's x in the child
00:00 +3: All tests passed!
```

## Gate line (from `packages/jet_cad_2d_flutter`)

Command 1:
```
CI=true flutter test
```
Exit code: `1` (expected — the five pre-existing golden failures).
Printed summary line:
```
00:32 +795 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exactly the five pre-existing `text_ladder_golden_test.dart` failures and
nothing else — the new `ruler_frame_test.dart` tests are counted in the
`+795` passes.

Command 2:
```
flutter analyze
```
Output:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 3.1s)
```
Exit code: `0`.

Command 3:
```
dart format --output=none --set-exit-if-changed .
```
First run flagged my own new test file (long `testWidgets` description
strings needed re-wrapping): `Changed test/ruler_frame_test.dart` / exit `1`.
I ran `dart format` (writing) on the three touched files, then re-ran the
check:
```
Formatted 148 files (0 changed) in 0.39 seconds.
```
Exit code: `0`.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/ruler_frame.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (one export line
  added)
- `packages/jet_cad_2d_flutter/test/ruler_frame_test.dart` (new)

`git status --short` before committing showed only these three files;
no `analysis_options.yaml` was rewritten, so nothing needed
`git checkout --`.

## Self-review

- **Three tests**: present, all green, none skipped or weakened.
- **Keyed `CustomPaint`s**: the task's checklist text says "the four keyed
  `CustomPaint`s — `ruler-corner`, `ruler-top`, `ruler-left`" — that lists
  three names. The brief's own Step 3 code and Step 1 tests only ever
  reference three keys (`ruler-corner`, `ruler-top`, `ruler-left`); there is
  no fourth `CustomPaint` anywhere in Task 7's `ruler_painter.dart` or this
  task's scope. I built exactly the three the brief and tests specify, each
  in its own `RepaintBoundary`. Flagging the "four" in the checklist as a
  wording slip rather than a missed requirement — happy to add a fourth if
  one was actually intended, but nothing in the brief, spec point D11, or
  the test file names one.
- **Pointer notifier disposed**: yes, `pointer.dispose()` in
  `RulerFrameState.dispose`.
- **`MouseRegion` + translucent `Listener` over the child**: yes, and the
  child's own opaque `Listener` (in the test fixture) still counted
  `childHovers > 0`, confirming events reach both layers.
- **Export**: `ruler_frame.dart` exported from the barrel, positioned
  immediately after `ruler_painter.dart` as instructed.
- **Discipline**: no subagents dispatched, no mutation sweep run beyond
  what TDD naturally required (the RED→fail→fix→GREEN cycle above). No
  `analysis_options.yaml` touched. Commit trailer verified via
  `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.
- **Pristine output**: `flutter analyze` clean, `dart format` clean,
  `git status --short` clean of anything besides the three intended files
  before commit.

## Concerns

- The brief's own Step 3 sample code has the `Row`-without-stretch bug
  described above; I fixed it in the shipped implementation (adding
  `crossAxisAlignment: CrossAxisAlignment.stretch` to both `Row`s) rather
  than reproducing the bug, since the brief's own D11 requirement ("each bar
  is exactly co-extensive with the child on its own axis") and its own test
  demand the fix. Reviewers should double check this reasoning holds.
- The "four keyed `CustomPaint`s" line in the task instructions doesn't
  match the brief/spec, which only name three. Called out above in case it
  signals a missing requirement I'm not seeing.
