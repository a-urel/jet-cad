# Task 6 report: `BoxParams` and `BoxType`

## Implementation

Created verbatim from the brief:

- `apps/floor_planner/test/box_test.dart` (BT1–BT6), 86 lines.
- `apps/floor_planner/lib/parametric/box.dart`, 133 lines: `BoxParams`
  (value-equal `Component`, `toJson`/`fromJson`, `copyWith`), `BoxType`
  (`ParametricType<BoxParams>`, `editCapability = Capability.geometry`,
  `reach` as the world AABB of transformed corners, `generate` as the
  spike's clipped-rectangle algorithm against `BoxParams` neighbours),
  `_insideInterval` copied verbatim from the engine test client's
  `insideInterval` (Ruling 06-9), `boxCatalog` (a `ParametricCatalog`
  registering `BoxParams`/`BoxType`), and `installBoxes(DraftDocument)`.

No `box_tool.dart`, `selection_panel.dart` or `main.dart`/`shortcut_guard.dart`
wiring — those are Tasks 7/8 per the brief's file list for Task 6.

## Deviations from the brief

None. `box.dart` and `box_test.dart` match the brief's code blocks exactly
(confirmed by construction — I copied the brief's blocks directly and only
reformatted with `dart format`, which reflowed a few lines in the test file
without changing content).

## RED / GREEN

RED (box.dart absent, compile error):

```
$ CI=true flutter test test/box_test.dart
...
test/box_test.dart:18:41: Error: Method not found: 'BoxParams'.
test/box_test.dart:30:15: Error: Method not found: 'BoxParams'.
test/box_test.dart:32:12: Error: Undefined name 'BoxParams'.
test/box_test.dart:33:41: Error: Couldn't find constructor 'BoxParams'.
test/box_test.dart:39:5: Error: Method not found: 'installBoxes'.
test/box_test.dart:47:5: Error: Method not found: 'installBoxes'.
test/box_test.dart:52:34: Error: Undefined name 'boxCatalog'.
test/box_test.dart:58:5: Error: Method not found: 'installBoxes'.
test/box_test.dart:66:18: Error: Couldn't find constructor 'BoxType'.
test/box_test.dart:70:21: Error: Couldn't find constructor 'BoxType'.
test/box_test.dart:70:43: Error: Couldn't find constructor 'BoxParams'.
00:00 +0 -1: Some tests failed.
```

GREEN (after writing box.dart):

```
$ CI=true flutter test test/box_test.dart
00:00 +0: BT1 BoxParams: value equality, key order, round trip
00:00 +1: BT2 an isolated box is four lines at its corners
00:00 +2: BT3 a rotated overlapping pair clips each other: A 5, B 3 (M-06g app, M-06o)
00:00 +3: BT4 two boxes sharing an edge exactly are not neighbours (Review Focus 5)
00:00 +4: BT5 editCapability is geometry
00:00 +5: BT6 a box reaches exactly its transformed corners
00:00 +6: All tests passed!
```

## Mutant fires

Both fired directly on `lib/parametric/box.dart`, with a `cp` backup taken
before each edit, `CI=true flutter test test/box_test.dart` run from
`apps/floor_planner`, then restored with `cp` and proven clean with `diff`.
No `git checkout` was used on the .dart file.

### M-06o — `view.toWorld(self).invert()` → `view.toWorld(self)`

```
$ cp lib/parametric/box.dart lib/parametric/box.dart.bak
# edit: final toLocal = view.toWorld(self); (drop .invert())
$ CI=true flutter test test/box_test.dart
00:00 +0: BT1 BoxParams: value equality, key order, round trip
00:00 +1: BT2 an isolated box is four lines at its corners
00:00 +2: BT3 a rotated overlapping pair clips each other: A 5, B 3 (M-06g app, M-06o)
00:00 +2 -1: BT3 a rotated overlapping pair clips each other: A 5, B 3 (M-06g app, M-06o) [E]
  Expected: an object with length of <5>
    Actual: [1001, 1002, 1003, 1004]
     Which: has length of <4>
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/box_test.dart 50:5                             main.<fn>
00:00 +2 -1: BT4 two boxes sharing an edge exactly are not neighbours (Review Focus 5)
00:00 +3 -1: BT5 editCapability is geometry
00:00 +4 -1: BT6 a box reaches exactly its transformed corners
00:00 +5 -1: Some tests failed.
```

**Result: killed by BT3.** BT4/BT5/BT6 still "pass" per the runner's count
but only because BT3's failure short-circuited nothing — the reported
`+5 -1` at the end reflects the whole file exiting non-zero; BT3 itself is
the failing assertion, exactly as the brief predicts (comparing 4 kids vs.
expected 5, i.e. no clipping happened once local space stopped being
local).

```
$ cp lib/parametric/box.dart.bak lib/parametric/box.dart
$ diff lib/parametric/box.dart lib/parametric/box.dart.bak
DIFF CLEAN
```

### M-06g (app) — `reach` using untransformed corners

```
$ cp lib/parametric/box.dart lib/parametric/box.dart.bak
# edit: Aabb2.fromPoints([for (final c in _corners(params)) c]) (drop toWorld.transformPoint)
$ CI=true flutter test test/box_test.dart
00:00 +0: BT1 BoxParams: value equality, key order, round trip
00:00 +1: BT2 an isolated box is four lines at its corners
00:00 +2: BT3 a rotated overlapping pair clips each other: A 5, B 3 (M-06g app, M-06o)
00:00 +3: BT4 two boxes sharing an edge exactly are not neighbours (Review Focus 5)
00:00 +4: BT5 editCapability is geometry
00:00 +5: BT6 a box reaches exactly its transformed corners
00:00 +5 -1: BT6 a box reaches exactly its transformed corners [E]
  Expected: <6510.0>
    Actual: <0.0>
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/box_test.dart 73:5                             main.<fn>
00:00 +5 -1: Some tests failed.
```

**Result: BT3 does not kill this mutant — it survives BT3.** BT1, BT2, BT3,
BT4 and BT5 all pass unchanged; only **BT6** fails.

**Why, and why the fixture is not changed.** `reach` is consulted only to
build the neighbour map (which pairs of objects overlap); `generate` never
calls `reach` again, it always recomputes corners from the real
`view.toWorld(...)`. Under this mutation every object's reported "world"
AABB collapses to its own local rectangle `[0,w]x[0,h]`, which always
contains the origin — so *every* pair of boxes is reported as overlapping,
regardless of true world position. In BT3, A and B genuinely do overlap in
world space, so they were already neighbours before the mutation; the
mutation doesn't change the neighbour *set* for this fixture, and `generate`
still clips correctly from the true transforms. So no rotated-pair count
assertion can distinguish this mutant from correct code — the corner
positions it corrupts are consumed only by the AABB overlap test, not by any
downstream geometry BT3 inspects.

This mutant is killed by the full test file (BT6 fails), which is what
Ruling 06-8 actually commits to ("killed by the app's rotated-pair
**tests**", plural — not by BT3 specifically). The brief's task-level
callout to BT3 for this mutant does not hold in isolation; I did not touch
BT3's or BT6's assertions, since BT6 already kills it and BT3's fixture
cannot be made to distinguish a reach-only bug through clip counts (any
fixture where BT3's two boxes truly overlap in world space will remain
neighbours under this mutation, by the mutation's own nature of always
reporting overlap). Flagging this as a documentation mismatch between the
brief and the ruling rather than a code or test defect.

```
$ cp lib/parametric/box.dart.bak lib/parametric/box.dart
$ diff lib/parametric/box.dart lib/parametric/box.dart.bak
DIFF CLEAN
$ rm lib/parametric/box.dart.bak
```

Post-restore, the full BT1–BT6 suite is green again (verified: `+6: All
tests passed!`).

## Gate summary

All run from `apps/floor_planner`, `CI=true` where applicable.

| Step | Command | Result |
|---|---|---|
| Tests | `CI=true flutter test` | `+52: All tests passed!`, exit 0 (46 baseline + 6 new BT tests) |
| Analyze | `flutter analyze` | `No issues found! (ran in 1.5s)`, exit 0 |
| Format check | `dart format --output=none --set-exit-if-changed .` | `Formatted 14 files (0 changed)`, exit 0 |
| macOS build | `flutter build macos --release` | `✓ Built build/macos/Build/Products/Release/floor_planner.app (51.3MB)`, exit 0 |
| Web build | `flutter build web --release` | `✓ Built build/web`, exit 0 |

`git status --short` before and after the whole task shows only the two new
files (`apps/floor_planner/lib/parametric/` and
`apps/floor_planner/test/box_test.dart`); no `analysis_options.yaml` was
modified by `pub get`.

## Files

- `apps/floor_planner/lib/parametric/box.dart` (new)
- `apps/floor_planner/test/box_test.dart` (new)

## Self-review

- `BoxParams` is a `final class implements Component`, value-equal on
  `width`/`height`, `toJson` key order `width` then `height` (BT1 pins
  this), `fromJson` tolerant of `int`/`double` JSON via `num.toDouble()`.
- `BoxType.reach` uses `toWorld.transformPoint` on all four corners — BT6
  pins this directly, and the M-06g app mutant fire confirms BT6 (not BT3)
  is what kills a regression here.
- `BoxType.generate` clips each of the 4 local edges against every
  `BoxParams` neighbour's quad (transformed into this object's local frame
  via `view.toWorld(self).invert()` composed with `view.toWorld(n)`), using
  `Tolerance.standard` for the inside test and the minimum-piece-length
  check, consistent with the global constraint that geometric decisions use
  `Tolerance` and stored values use `==`. `BoxParams` equality itself stays
  exact `==`.
- `_insideInterval` is a verbatim copy of the engine test client's
  `insideInterval` (character-for-character, per Ruling 06-9), not a
  refactor or an import of the test file.
- `boxCatalog` registers `BoxParams` under `floor_planner.box` with
  `const BoxType()`; `installBoxes` builds a `ParametricSystem(doc,
  boxCatalog)` and calls `.install()`, matching the brief and Ruling 06-1
  (catalog is document-free, system is per-document).
- BT4 (edge-sharing pair) passed on the first GREEN run with no fixture
  change needed — the tolerance-based `_insideInterval` correctly treats an
  exactly-shared edge as "not strictly inside," so no neighbour clipping
  occurs and both boxes keep all 4 sides.
- Draw order / allocation invariants are untouched: no changes to
  `query_allocation_test.dart`, `paint_allocation_test.dart`, or any engine
  file.

## Concerns

- The task brief's instruction "BT3 must really kill... the app M-06g" does
  not hold: the app M-06g mutant survives BT3 and is only caught by BT6, for
  the structural reason explained above (reach only feeds neighbour
  detection, and BT3's neighbours are already correct before and after this
  particular mutation). I did not edit BT3's or BT6's assertions since (a)
  BT6 already kills the mutant, satisfying the file-level testing bar, and
  (b) I could not find a rotated-pair-count fixture where this specific
  reach corruption would flip a neighbour decision without coincidentally
  still overlapping (any two positive-size boxes' local rectangles both
  contain the origin, so this mutation always reports overlap for any pair
  actually placed anywhere). This looks like a mismatch between the task
  brief's paraphrase and Ruling 06-8's actual (correct) claim that the app
  mutants are killed by "the app's rotated-pair tests" (plural) rather than
  by BT3 specifically. Worth a note back to whoever authored the task brief
  for Task 11's spec-amendment pass, but no code or test change was made on
  the strength of it.
- `apps/floor_planner/build/` now contains fresh macOS and web release
  build output from the gate; not committed (build/ is presumably
  gitignored — `git status --short` shows nothing from it).

## Fix round 1: BT1 did not pin `BoxParams.operator==` field coverage

**Finding (Important):** every BT1 equality assertion compared instances
that already agreed on both fields, so a mutation dropping `height` (or
`width`) from `operator ==` left the whole suite green — nothing asserted
that two params differing in exactly one field are *unequal*.

**Change:** added three assertions to BT1 in
`apps/floor_planner/test/box_test.dart`:

```dart
expect(const BoxParams(1200, 800) == const BoxParams(1200, 801), isFalse);
expect(const BoxParams(1200, 800) == const BoxParams(1201, 800), isFalse);
expect(const BoxParams(1200, 800).hashCode,
    const BoxParams(1200, 800).hashCode);
```

No change to `lib/parametric/box.dart`.

**GREEN after the fix:**

```
$ CI=true flutter test test/box_test.dart
00:00 +0: BT1 BoxParams: value equality, key order, round trip
00:00 +1: BT2 an isolated box is four lines at its corners
00:00 +2: BT3 a rotated overlapping pair clips each other: A 5, B 3 (M-06g app, M-06o)
00:00 +3: BT4 two boxes sharing an edge exactly are not neighbours (Review Focus 5)
00:00 +4: BT5 editCapability is geometry
00:00 +5: BT6 a box reaches exactly its transformed corners
00:00 +6: All tests passed!
```

**Mutant fires**, each with a `cp` backup of `lib/parametric/box.dart`
taken first, `CI=true flutter test test/box_test.dart` run from
`apps/floor_planner`, then restored with `cp` and proven clean with `diff`
(no `git checkout` used on the .dart file):

Mutant 1 — drop `other.height == height` (operator becomes
`other is BoxParams && other.width == width`):

```
$ CI=true flutter test test/box_test.dart
00:00 +0: BT1 BoxParams: value equality, key order, round trip
00:00 +0 -1: BT1 BoxParams: value equality, key order, round trip [E]
  Expected: false
    Actual: <true>
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/box_test.dart 39:5                             main.<fn>
00:00 +0 -1: BT2 an isolated box is four lines at its corners
00:00 +1 -1: BT3 a rotated overlapping pair clips each other: A 5, B 3 (M-06g app, M-06o)
00:00 +2 -1: BT4 two boxes sharing an edge exactly are not neighbours (Review Focus 5)
00:00 +3 -1: BT5 editCapability is geometry
00:00 +4 -1: BT6 a box reaches exactly its transformed corners
00:00 +5 -1: Some tests failed.
```

Killed by BT1 (line 39, the height-only inequality assertion). Restored:

```
$ cp lib/parametric/box.dart.bak lib/parametric/box.dart
$ diff lib/parametric/box.dart lib/parametric/box.dart.bak
DIFF CLEAN
```

Mutant 2 — drop `other.width == width` (operator becomes
`other is BoxParams && other.height == height`):

```
$ CI=true flutter test test/box_test.dart
00:00 +0: BT1 BoxParams: value equality, key order, round trip
00:00 +0 -1: BT1 BoxParams: value equality, key order, round trip [E]
  Expected: false
    Actual: <true>
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/box_test.dart 40:5                             main.<fn>
00:00 +0 -1: BT2 an isolated box is four lines at its corners
00:00 +1 -1: BT3 a rotated overlapping pair clips each other: A 5, B 3 (M-06g app, M-06o)
00:00 +2 -1: BT4 two boxes sharing an edge exactly are not neighbours (Review Focus 5)
00:00 +3 -1: BT5 editCapability is geometry
00:00 +4 -1: BT6 a box reaches exactly its transformed corners
00:00 +5 -1: Some tests failed.
```

Killed by BT1 (line 40, the width-only inequality assertion). Restored:

```
$ cp lib/parametric/box.dart.bak lib/parametric/box.dart
$ diff lib/parametric/box.dart lib/parametric/box.dart.bak
DIFF CLEAN
$ rm lib/parametric/box.dart.bak
```

Post-restore, BT1–BT6 confirmed green again (`+6: All tests passed!`).

**Covering test after the fix:**

```
$ CI=true flutter test test/box_test.dart   # +6: All tests passed! (exit 0)
$ flutter analyze                            # No issues found! (ran in 1.3s) (exit 0)
$ dart format --output=none --set-exit-if-changed .   # Formatted 14 files (0 changed) (exit 0)
```

`git status --short` at the repo root shows only
`apps/floor_planner/test/box_test.dart` modified; no `analysis_options.yaml`
drift. Release builds were not re-run for this test-only change, per the
coordinator's instruction.

**Files touched:** `apps/floor_planner/test/box_test.dart` (modified).
