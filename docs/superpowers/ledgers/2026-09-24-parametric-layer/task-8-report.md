# Task 8 report: The Selection panel section

Branch `plan-06/parametric-layer`, worktree
`.claude/worktrees/quizzical-jemison-7537de`, on top of `dcced6a`.

## Implementation

- **New:** `apps/floor_planner/lib/selection_panel.dart` — `SelectionPanel`,
  a `StatefulWidget` taking `document` and `selection`. It listens to both
  `widget.selection` (a `ChangeNotifier`) and `widget.document.commands.changes`
  (a `Stream<DocChange>`), and shows/hides/repopulates on either. `_box`
  computes the single selected root-level `GroupNode` carrying `BoxParams`,
  or `null` (hiding the panel) otherwise. Two `TextField`s, keyed
  `box-width`/`box-height`, `readOnly` under a permission set that denies
  `BoxType().editCapability` (`Capability.geometry`). `_submit` parses the
  text, rejects non-finite/≤0/unparseable values by reverting the field
  (`_sync`), and otherwise executes one
  `SetComponentCommand<BoxParams>(h, next)` — the parametric system turns
  that into one undo step including regeneration (existing engine
  behaviour from earlier tasks, not touched here). A no-op edit (new value
  equal to the current one) executes nothing.
- **Modified:** `apps/floor_planner/lib/main.dart` — imports
  `selection_panel.dart`; the `chrome-right` `ShellShortcutGuard`'s child is
  now a `Column` with `SelectionPanel(document: _document, selection:
  _selection)` first (sized to content) and `Expanded(child: PagePanel(...))`
  below it, matching the brief's Step 4 exactly.
- **Modified:** `apps/floor_planner/test/support/box_rig.dart` — added
  `drawTwoBoxes(tester, view)`: presses B, then BX4's four clicks at
  (7010,3020), (7130,3090), (7100,3060), (7190,3120), then `pump()`.
- **New:** `apps/floor_planner/test/selection_panel_test.dart` — SE1–SE7
  (see Deviations for the rename), adapted from the brief's SP1–SP7 with no
  assertions weakened. Added the `vector_math` `Vector2` import as
  instructed.

## Deviations from the brief, with reasons

1. **Test names SP1–SP7 → SE1–SE7.** Per the controller's ruling for this
   task: `startup_plan_test.dart` already defines SP1–SP5, so the panel
   tests are named SE1–SE7 instead, same bodies and order as the brief's
   SP1–SP7.
2. **`onTapOutside` kept, not dropped.** The brief's fallback instruction
   was: if `onTapOutside` fires during the test's own tap on the field (so
   SE4/SE7 misbehave), drop it and keep `onSubmitted` only, recording Ruling
   06-14. I implemented the field with both `onSubmitted` and
   `onTapOutside` (as the brief's own draft code has it) and ran SE1–SE7
   twice: once with `onTapOutside` present, once with it removed. Both runs
   are 7/7 green — the predicted interaction does not occur in this test
   suite (SE4 drives the field via `enterText` + `TextInputAction.done`,
   never a tap elsewhere while it holds focus; SE7's `tester.tap(width)`
   focuses the field for the first time, so there is no prior focus for
   `onTapOutside` to fire against). I kept `onTapOutside` in the shipped
   code because spec D13 explicitly requires "Enter **or focus-out**
   commits one `SetComponentCommand<BoxParams>`," and keeping it is the
   closer reading of the spec with no test cost. **Ruling 06-14 was not
   invoked** — recording this here per the task's guidance to report a
   disagreement rather than silently picking one path.
3. **Extra defensive check in `_box`:** added `if (key.chain.isNotEmpty)
   return null;` before resolving `key.target`, matching the spec's "a
   root-level group" and `SelectionKey`'s own doc (`chain` is empty only
   for a root-level selection). No test exercises a non-empty chain (no
   task before this one produces one), so this is inert today but closer
   to the spec than the brief's draft, which relied only on
   `node.parent != rootHandle`.

No other deviations. `SelectionPanel`'s shape, keys, and field behavior
otherwise match the brief's draft code exactly.

## RED

Before creating `lib/selection_panel.dart` or touching `main.dart` (with
`drawTwoBoxes` already added to `box_rig.dart`):

```
$ CI=true flutter test test/selection_panel_test.dart
...
00:02 +1: SE2 hidden for none, two, and a non-box
00:02 +1 -1: SE1 shown for exactly one selected box [E]
00:02 +1 -2: SE3 Enter commits one step and regenerates [E]
00:02 +1 -3: SE4 an invalid value reverts and commits nothing [E]
00:02 +1 -4: SE5 under runtime the fields are read-only [E]
00:02 +1 -5: SE6 undo after a panel edit shows the old width (Review Focus 4) [E]
00:02 +1 -6: SE7 typing B in the width field does not switch tools [E]
00:02 +1 -6: Some tests failed.
```

6 of 7 red (all except SE2, which asserts *absence* — trivially true with
no `SelectionPanel` mounted at all). Every test that asserts the panel's
presence or behavior failed, as expected with no `selection_panel.dart` and
no `box-width`/`box-height` keys in the tree.

## GREEN

After implementing `selection_panel.dart` and wiring `main.dart`:

```
$ CI=true flutter test test/selection_panel_test.dart
00:01 +0: SE1 shown for exactly one selected box
00:00 +1: SE2 hidden for none, two, and a non-box
00:01 +2: SE3 Enter commits one step and regenerates
00:01 +3: SE4 an invalid value reverts and commits nothing
00:01 +4: SE5 under runtime the fields are read-only
00:01 +5: SE6 undo after a panel edit shows the old width (Review Focus 4)
00:01 +6: SE7 typing B in the width field does not switch tools
00:01 +7: All tests passed!
```

Full suite:

```
$ CI=true flutter test
...
00:04 +66: All tests passed!
```

Baseline was 46 (per global-constraints' branch-point count) plus the app
tests added across Tasks 6-7; the brief states "App baseline: 59 tests."
Task 8 adds the 7 SE tests: 59 + 7 = 66, matching the observed total.

## Gate summary

All run from `apps/floor_planner`, `CI=true`.

| Command | Result |
|---|---|
| `flutter test` | `+66: All tests passed!` — exit 0 |
| `flutter analyze` | `No issues found! (ran in 1.5s)` — exit 0 |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 19 files (0 changed)` — exit 0 |
| `flutter build macos --release` | `✓ Built build/macos/Build/Products/Release/floor_planner.app (51.4MB)` — exit 0 |
| `flutter build web --release` | `✓ Built build/web` — exit 0 |

`git status --short` before commit showed only the four intended files
touched; `analysis_options.yaml` is untouched.

## Files

- `apps/floor_planner/lib/selection_panel.dart` (new)
- `apps/floor_planner/lib/main.dart` (modified: import + `chrome-right` layout)
- `apps/floor_planner/test/selection_panel_test.dart` (new)
- `apps/floor_planner/test/support/box_rig.dart` (modified: `drawTwoBoxes`)

## Self-review: what each SE test would catch

- **SE1** (shown for exactly one selected box): catches a panel that never
  renders, a wrong visibility predicate, or a field that doesn't load the
  model's current width (`120` after BX4's first box) — e.g. an off-by-one
  in `_number`, or `_load` never being called on selection change.
- **SE2** (hidden for none/two/non-box): catches a predicate that shows the
  panel for any non-empty selection, or one that checks only
  `components.get<BoxParams>` without checking selection cardinality or
  root-level-ness — e.g. dropping the `keys.length != 1` guard, or matching
  on entity kind instead of `BoxParams` presence (the line has neither).
- **SE3** (Enter commits one step and regenerates): catches a submit that
  executes more than one command (undo depth `+1` exactly, not `+2` for a
  naive component-set-then-regenerate pair), a submit that doesn't call
  `execute` at all, or a regeneration that leaves drift — e.g. writing to
  `document.components` directly instead of through
  `SetComponentCommand`, which would change the stored value with no undo
  step and no regeneration.
- **SE4** (invalid value reverts, commits nothing): catches a missing or
  wrong validation (`value <= 0`, non-finite, unparseable), and catches a
  revert that doesn't restore the *current model value* — the loop reuses
  the same field three times and asserts `70` (the drawn height) after
  each bad input, so a `_sync` that clears the field instead of reloading
  it, or that reloads a stale cached value, goes red. `undoDepth`
  unchanged catches a validator that still calls `execute` on a rejected
  value.
- **SE5** (runtime read-only): catches a widget that checks the wrong
  `Capability` (e.g. `structure` or `components` instead of `geometry`,
  which is what `BoxType.editCapability` actually is), or that hardcodes
  `readOnly: false`.
- **SE6** (undo restores the old width, Review Focus 4): catches a submit
  whose undo entry is wrong-shaped so that undoing it doesn't restore
  `BoxParams` — e.g. if the parametric system's wrapper dropped the
  component half of the inverse (this is also the app-level face of engine
  mutant M-06c, though the actual kill for that mutant is the engine's own
  unit test; this widget test is an integration check that the panel's
  commit path composes correctly with undo, not a substitute for the
  engine-level mutant kill).
- **SE7** (typing B in the field doesn't switch tools): catches a missing
  or misplaced `ShellShortcutGuard` around the panel — since `SelectionPanel`
  sits inside the same guard as `PagePanel` in the `chrome-right` `Column`,
  this also guards against a future refactor that moves the panel outside
  the guard's subtree.

## Concerns

- **`onTapOutside` behavior is untested by SE1–SE7 as written.** Every test
  either submits via `TextInputAction.done` or taps a field that was not
  previously focused; none simulates "focus one field, then tap elsewhere
  (or the other field) without pressing Enter." Spec D13 requires
  focus-out to commit, and `onTapOutside` is wired for it, but there is no
  green test pinning that specific path today. Task 11 (spec amendment) or
  a follow-up task may want to add one, or explicitly downgrade the D13
  claim if `onTapOutside`'s general Flutter semantics (it only fires on a
  tap not claimed by another focusable target, and never on
  focus-loss-by-keyboard-navigation) turn out not to cover every
  "focus-out" the spec has in mind.
- **No test drives the height field's Enter path** the way the width
  field's is driven in SE3/SE6; SE4 exercises height only for the
  reject-and-revert case. Symmetric behavior is by construction (`field`
  is one function parameterized on `isWidth`), but nothing pins that
  `isWidth: false` really writes `height` and not `width` end-to-end.
- `_box`'s `key.chain.isNotEmpty` guard (deviation 3) is currently
  unreachable from any test in the app; it is a no-op safety net until a
  later task produces a non-root selection key.

---

## Fix round 1 of 5 (review findings)

Controller ruling: keep `onTapOutside` (spec D13: "Enter or focus-out
commits"); Ruling 06-14 is **not** made. Two findings fixed.

### Finding 1: stale class doc comment

`lib/selection_panel.dart:13-16` still described the Ruling 06-14 fallback
(`onSubmitted` only) even though the shipped code keeps `onTapOutside`.
Rewritten to describe the actual behavior, no ruling reference:

```dart
/// Enter or a tap outside the field commits (spec 06 D13); an invalid value
/// reverts the field to the model's current value instead.
```

### Finding 2: no test pinned the focus-out commit path

Added `SE8` to `test/selection_panel_test.dart`. While writing it, the
literal instruction ("tap somewhere outside the width field that is
harmless (the Height field is fine)") turned out not to hold: tapping the
Height field does **not** commit the Width field, because
`TextField`/`EditableText` default `groupId` is the `EditableText` type
object itself, shared by every plain `TextField` that does not set its own
`groupId`. Flutter's `TapRegion` group semantics count a tap on *any*
member of the same group as inside, not outside -- so a tap on the Height
field is inside the Width field's tap-outside group, and
`EditableText._onTapOutside` (gated on `widget.onTapOutside != null`,
itself wired only when the field currently has focus) never fires.

I confirmed this empirically before changing the test:
- First wrote SE8 exactly as instructed (`enterText(width, '150')`, then
  `tester.tap(height)`, then `pump()`, then assert `width == 150` and
  `undoDepth == depth + 1`). It failed even with `onTapOutside` present and
  correct: `Expected: <150> Actual: <120.0>`.
- Added a temporary debug `print` inside `onTapOutside` (backed up first
  with `cp`) and reran with `--plain-name "SE8"`: the print never fired,
  confirming the callback itself was never invoked, not that `_submit`
  silently rejected the value.
- Traced this to Flutter's `editable_text.dart`
  (`groupId = EditableText` default) and `text_field.dart` (same default,
  passed straight through) -- documented, intentional Flutter behavior:
  a group's members never trigger `onTapOutside` for each other, so a
  toolbar or a sibling field in the same group doesn't dismiss a field's
  panel every time the user moves between them.
- Removed the debug print, restored the clean `_submit(...)` callback, and
  changed the test to tap the panel's "Box" label (a plain `Text`, not an
  `EditableText`, so genuinely outside every field's tap-region group)
  instead of the Height field:

  ```dart
  await tester.tap(find.descendant(
      of: find.byKey(const Key('selection-panel')),
      matching: find.text('Box')));
  ```

  (`find.descendant` because the top status bar also shows the text "Box"
  while the Box tool is armed -- a bare `find.text('Box')` is ambiguous.)
  With the print back in and this target, `onTapOutside fired for width`
  printed and the test passed; with the print removed, SE8 passes cleanly
  against the shipped implementation.

**Deviation from the coordinator's literal instruction**, reported per the
task's "if a test disagrees, report it" guidance: SE8 taps the panel's
"Box" label, not the Height field, because tapping the Height field cannot
exercise `onTapOutside` at all under Flutter's default `groupId` semantics
(verified above, not merely inferred). The test still does exactly what
the finding asked for in substance -- select one box, type into Width with
no Enter, tap something else in the UI, and assert the commit happened
with exactly one new undo step.

### Mutant fire (SE8's own kill)

Backed up `lib/selection_panel.dart` with `cp` to `/tmp/selection_panel_good.bak`,
removed the `onTapOutside:` line, and ran:

```
$ CI=true flutter test test/selection_panel_test.dart
...
00:01 +7: SE8 a tap outside the width field commits it, with no Enter
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═══...
The following TestFailure was thrown running a test:
Expected: <150>
  Actual: <120.0>
...
00:02 +7 -1: SE8 a tap outside the width field commits it, with no Enter [E]
  Test failed. See exception logs above.
00:02 +7 -1: Some tests failed.
```

Exactly SE8 went red (SE1-SE7 stayed green: `+7 -1`). Restored with
`cp /tmp/selection_panel_good.bak lib/selection_panel.dart`, then
`diff /tmp/selection_panel_good.bak lib/selection_panel.dart` printed
nothing (`DIFF CLEAN`) -- confirmed byte-identical to the pre-mutation
file. No `git checkout --` was used.

### Gate

From `apps/floor_planner`, `CI=true`:

```
$ CI=true flutter test test/selection_panel_test.dart
...
00:02 +8: All tests passed!

$ CI=true flutter test
...
00:05 +67: All tests passed!

$ flutter analyze
Analyzing floor_planner...
No issues found! (ran in 1.8s)

$ dart format --output=none --set-exit-if-changed .
Formatted 19 files (0 changed) in 0.06 seconds.
```

All exit 0. Release builds were not required for this fix round (no
`lib/` behavior change, only a doc comment; the app-facing behavior itself
is unchanged from what the two release builds in the original report
already covered) and were not run again.

`git status --short` after the fix showed only the two touched files:

```
 M apps/floor_planner/lib/selection_panel.dart
 M apps/floor_planner/test/selection_panel_test.dart
```

`analysis_options.yaml` untouched.

### Files touched this round

- `apps/floor_planner/lib/selection_panel.dart` (doc comment only)
- `apps/floor_planner/test/selection_panel_test.dart` (added SE8)
