# Task 11 report — mutation testing, the two allocation gates, the greps

## Tally

28 fired, 28 killed, 0 survived, 2 equivalent (M-02c, M-02e — equivalent by
construction, per the spec's own reasons).

Every named mutant produced the failing test the spec's table names, or a
closely related one in the same file, with one noted exception below.

## Survived / non-discriminating entries

No mutant is logged SURVIVED. One mutant (M-02x) went red on only one of its
two named test files:

- **M-02x** (the `KeyDownEvent` gate removed from `select_tool.dart`'s
  `onKey`): fired on `test/select_tool_test.dart` (`a KeyUpEvent and a
  KeyRepeatEvent do nothing`, `Expected: KeyEventResult.ignored` /
  `Actual: KeyEventResult.handled`). It did **not** fire on
  `test/interaction_layer_test.dart`'s `one Delete press is one remove`: that
  fixture selects one key and sends a KeyDown then a KeyUp for Delete; the
  KeyDown's own `_deleteSelection` already empties the selection, so the
  mutated KeyUp's second `_deleteSelection` call walks an empty selection and
  is a no-op — the fixture's single-selection shape can't tell "gate present"
  from "gate absent" apart. This is a non-discriminating arm of one of the two
  named tests, not a surviving mutant — the mutant is killed by
  `select_tool_test.dart`.

Two further notes the spec calls for are recorded in the log itself:

- **M-02f** (`kBandSlopPixels` → 0): the kill is the `phase == pressed`
  assertion taken *before* release; the post-release selection check in the
  same test is not discriminating (`replace(∅)` reads the same as `clear()`
  on an empty selection).
- **M-02l** (`pickRadiusWorld` not divided by scale): the kill is the
  scale-0.25 arm of the fixture; the scale-4 arm is not discriminating.

One additional observation not required by the spec: **M-02b**'s recursive
`toWorld.multiply(...)` composes an instance transform only two-or-more
levels deep. Every hand-written fixture in `band_query_test.dart` places its
instance directly under the root, so only the generated differential corpus
(`groupCount`/nesting-depth-2) exercised the mutated line; it still fired
(`crossing and window agree with the brute-force arm on the generated
corpus`), just not via the single-level `placement` fixture the spec's table
names for that row. Recorded in the log.

## Tail commands

```
$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
...
00:02 +5: All tests passed!
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
...
00:00 +3: All tests passed!
```

```
$ git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
(empty)
```

```
$ grep -rn "kIsWeb\|dart:ui_web" packages/jet_cad_2d_flutter/lib/src/selection.dart packages/jet_cad_2d_flutter/lib/src/selection_style.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/outline_cache.dart
(no output)
```

Both allocation gates green; both checks empty, as required.

## Commit

`dd27af0` — `docs: plan 02 mutation log — 28 fired, 28 killed, 2 equivalent`,
trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` verified
(`git log -1 --format=%B | grep -c "Fable 5.1"` → 1). `git status --short`
showed only the new log file before staging; nothing else was touched
(every mutated `.dart` file was restored via `cp` from the scratchpad backup
and confirmed with a clean `diff` before moving to the next mutant — none
were `git checkout --`'d).

## Concerns

- A full, untargeted `flutter test` run of `packages/jet_cad_2d_flutter`
  (not part of this task's required tail, run only as an extra safety check
  after the sweep) shows 5 pre-existing failures in
  `test/golden/text_ladder_golden_test.dart` (`RenderBackend.canvas`, rungs
  1–5). These are unrelated to this task: `git status --short` was clean
  (no source diff at all) both before and after the check, so nothing this
  task did caused them — they are a pre-existing, presumably
  environment/font-rendering condition on this machine. Flagging for the
  record; not fixed here as it is out of this task's scope.
- The full untargeted `dart test` run of `packages/jet_cad_2d` is fully green
  (820 tests).

## Fix round 1

Reviewer finding (Important): M-02b was logged against `_bandDescend`'s
recursive composition (`toWorld.multiply(index.transformOfInstance(node))`
→ `toWorld`), which is reached only for an instance nested two or more
levels deep — every hand-written fixture in `band_query_test.dart` places
its instance directly under the root, so the spec-named fixture (instance
at (300, −200), 30°, ×1.5) stayed green under that mutation; only the
generated differential corpus caught it. The spec's row names the
composition at `forEachInstanceInBand`'s own call site instead.

Fix: re-fired M-02b at that call site —
`packages/jet_cad_2d/lib/src/index/spatial_index.dart`,
`forEachInstanceInBand`: `child, root.transformOfInstance(node), mode,
world, filter, 1` → `child, Transform2.identity(), mode, world, filter, 1`
(the instance transform dropped at the root level). Same `cp`/Edit/run/
`cp`-restore/`diff` discipline as every other mutant:

```
$ cp packages/jet_cad_2d/lib/src/index/spatial_index.dart <scratchpad>/spatial_index.dart.bak
# edit applied
$ CI=true dart test test/index/band_query_test.dart
...
00:00 +1 -1: an instance is selected where its leaf lands after the transform [E]
  Expected: [400]
    Actual: []
...
00:00 +7 -8: crossing and window agree with the brute-force arm on the generated corpus [E]
  Expected: Set:[437]
    Actual: Set:[]
  BandMode.crossing trial 12
Failing tests:
  a collapsed instance is judged by its image, not refused
  a grouped leaf inside a definition uses the group transform too
  a window refuses an instance whose far leaf lies outside the band
  an L-shaped block is not crossed by a band in the empty quadrant of its box
  ... and 4 more
$ cp <scratchpad>/spatial_index.dart.bak packages/jet_cad_2d/lib/src/index/spatial_index.dart
$ diff <scratchpad>/spatial_index.dart.bak packages/jet_cad_2d/lib/src/index/spatial_index.dart
(clean)
```

FIRED, killed directly by the spec-named fixture
(`an instance is selected where its leaf lands after the transform`), with
six further tests in the same file also going red. This is now the M-02b
entry of record in `docs/superpowers/notes/plan-02-mutation-log.md`. The
original recursive-composition run is kept beneath it as a clearly labelled
"M-02b (nested)" companion line, not a separate mutant id — the tally is
unchanged at 28 fired / 28 killed / 0 survived / 2 equivalent.

`git status --short` before staging showed only
`docs/superpowers/notes/plan-02-mutation-log.md` modified — nothing else
was touched. Committed as `afe7d64` —
`docs: fix M-02b to re-fire at the spec's own call site`, trailer
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` verified
(`git log -1 --format=%B | grep -c "Fable 5.1"` → 1).
