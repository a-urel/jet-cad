# Task 1 report — the frame-global audit, and `DraftPainter`'s injectable rebase origin

Base: `477d4c5` on `main`. Worked directly on `main`, no worktree (human consent
per Plans 3e, 3f, 3f.1, and this plan's own stated arrangement). Final commit:
`cb49f0d`.

## Step 1: the frame-global audit

Read `DraftPainter.paint` at `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
(the method, before this task's edits, spanned lines 296-349; the specific
lines below are from that pre-edit file, matching the brief's own numbering).

| quantity | line | frame-global? |
|---|---|---|
| `rebaseOriginFor(world)` → `origin` | `:307-308` | **yes** — snaps to a power-of-two grid from the view span (`camera_controller.dart:18-33`); a per-tile camera has its own span, its own exponent and its own origin |
| `_screenOrigin = camera.worldToScreen(origin)` | `:311` | derived from the above — inherits its frame-globalness rather than adding a new source of it |
| `_screenSpaceClip` / `_rebasedClip` (inflated by `kScreenClipInflate`) | `:312-318` | **no** — must be the tile's own rect; each tile bakes through a camera whose viewport crops a different rectangle out of the same scene, and the tile's own clip is exactly the crop it should have |
| `minTextCapPixels` level-of-detail threshold | field, `:102` (now `:104` after the two new fields were inserted above it) | already a field, so already frame-global; nothing to change |

No fifth was found. `world = camera.visibleWorld(viewport)` (`:305`) and the
`_worldRect` field it feeds (`:306`) are also derived per call from `camera`
and `viewport`, but they are deliberately *not* pinned: a tile is supposed to
see a different slice of world space than the live frame (that is the entire
point of tiling), so `world`/`_worldRect` varying per tile is correct behaviour,
not the defect D1 warns about. The four rows above are exactly what later tasks
in the plan's ledger (`progress.md`, row P1) assume.

## Step 2/3: the failing test

Created `packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart` with
the brief's two tests verbatim, plus a local `unitCamera()` per Ruling R3 (see
Deviations below).

Verbatim transcript:

```
$ CI=true flutter test test/draft_painter_rebase_test.dart
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart
test/draft_painter_rebase_test.dart:70:9: Error: No named parameter with the name 'debugRebaseOrigin'.
        debugRebaseOrigin: shifted));
        ^^^^^^^^^^^^^^^^^
lib/src/draft_painter.dart:58:3: Context: Found this candidate, but the arguments don't match.
  DraftPainter({
  ^^^^^^^^^^^^
test/draft_painter_rebase_test.dart:100:7: Error: No named parameter with the name 'debugOnVisit'.
      debugOnVisit: seen.add,
      ^^^^^^^^^^^^
lib/src/draft_painter.dart:58:3: Context: Found this candidate, but the arguments don't match.
  DraftPainter({
  ^^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart: test/draft_painter_rebase_test.dart:70:9: Error: No named parameter with the name 'debugRebaseOrigin'.
          debugRebaseOrigin: shifted));
          ^^^^^^^^^^^^^^^^^
  lib/src/draft_painter.dart:58:3: Context: Found this candidate, but the arguments don't match.
    DraftPainter({
    ^^^^^^^^^^^^
  test/draft_painter_rebase_test.dart:100:7: Error: No named parameter with the name 'debugOnVisit'.
        debugOnVisit: seen.add,
        ^^^^^^^^^^^^
  lib/src/draft_painter.dart:58:3: Context: Found this candidate, but the arguments don't match.
    DraftPainter({
    ^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart
```

Exactly the expected compile failure — `DraftPainter` has no `debugRebaseOrigin`
and no `debugOnVisit`. `addLine`, `addDefinition`, `addInstance` resolved with
no complaint, confirming the fixture additions (Step 2 continued, below) were
already correct at this point.

## Step 4: the implementation

`packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`:

- Constructor gained `this.debugRebaseOrigin` and `this.debugOnVisit` (both
  optional, both non-final per the task's explicit instruction).
- Two new mutable fields, `Vector2? debugRebaseOrigin;` and
  `void Function(Handle handle)? debugOnVisit;`, with the doc comments from
  the brief verbatim.
- Origin derivation in `paint` changed to
  `debugRebaseOrigin ?? (debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world))`
  — an injected origin wins over `debugDisableRebasing`.
- `debugOnVisit?.call(...)` calls added at the four sites the brief named. Two
  of the four anchor comments in the brief (`_rootLeaves++`, `_defLeaves++`) do
  not exist in this codebase's current `draft_painter.dart` — there is no such
  counter at either location. This is a **deviation**, recorded below; the
  calls were placed at the structurally equivalent points instead (immediately
  beside where each leaf/instance is identified, before it is drawn or
  descended into).

## Step 5: the passing run

```
$ CI=true flutter test test/draft_painter_rebase_test.dart
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart
00:00 +0: an injected rebase origin overrides the one the view span would give
00:00 +1: debugOnVisit reports every leaf drawn and every container descended
00:00 +2: All tests passed!
```

## Step 6: mutant M17

Backed up `lib/src/draft_painter.dart` to the session scratchpad (not `/tmp`,
per this session's environment guidance — same intent as the brief's
copy-aside instruction, different directory) before mutating:

```
$ cp lib/src/draft_painter.dart "$SCRATCH/draft_painter.dart.bak"
```

Applied M17 — dropped the `debugRebaseOrigin ??` override so `origin` ignores
the injected value:

```dart
    final origin = debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world);
```

Red run:

```
$ CI=true flutter test test/draft_painter_rebase_test.dart
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  ... (dependency resolution output, identical to the runs above)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart
00:00 +0: an injected rebase origin overrides the one the view span would give
00:00 +0 -1: an injected rebase origin overrides the one the view span would give [E]
  Expected: <-4064.0>
    Actual: <32.0>
  x rebased against the injected origin

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/draft_painter_rebase_test.dart 74:7            main.<fn>

00:00 +0 -1: debugOnVisit reports every leaf drawn and every container descended
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart: an injected rebase origin overrides the one the view span would give
```

Failed exactly where expected: the x assertion in the first test
("x rebased against the injected origin"). The second test still shows as
passed in this transcript (`debugOnVisit reports every leaf drawn and every
container descended` completed with no `[E]` against it — the `-1` in its
summary line is the running failure tally carried over from the first test,
not a second failure).

Restored from the scratchpad backup (never `git checkout`):

```
$ cp "$SCRATCH/draft_painter.dart.bak" lib/src/draft_painter.dart && rm "$SCRATCH/draft_painter.dart.bak"
```

`git diff lib/src/draft_painter.dart` against `HEAD` at that point showed
exactly the intended implementation (the two fields, the two constructor
parameters, the `??` origin line, and the four `debugOnVisit?.call` sites) —
nothing more, nothing less. Restored green run:

```
$ CI=true flutter test test/draft_painter_rebase_test.dart
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  ... (dependency resolution output, identical to the runs above)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart
00:00 +0: an injected rebase origin overrides the one the view span would give
00:00 +1: debugOnVisit reports every leaf drawn and every container descended
00:00 +2: All tests passed!
```

## Step 7: the whole suite, green

`packages/jet_cad_2d` (unaffected by this task's changes, run as the global
exit gate requires):

```
$ CI=true dart test
00:00 +0: loading test/core/tolerance_test.dart
00:00 +0: test/core/tolerance_test.dart: standard tolerance is absolute in document units
00:00 +1: test/core/list_equality_test.dart: compares element-wise
00:00 +2: test/core/handle_test.dart: Handle none is zero and reports isNone
...
00:02 +790: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +791: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +792: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +793: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +793: All tests passed!

$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 112 files (0 changed) in 0.20 seconds.
```

`packages/jet_cad_2d_flutter`:

```
$ CI=true flutter test
... (interleaved per-test lines from many files; see note below)
00:04 +302 ~1: .../test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +303 ~1: .../test/vertices_differential_test.dart: the sink inks nothing the painter did not ask for
00:04 +304 ~1: .../test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:04 +305 ~1: .../test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:04 +306 ~1: All tests passed!

$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 55 files (0 changed) in 0.10 seconds.
```

306 tests passed, 1 skipped (the `rig` tag, skipped by `dart_test.yaml` unless
run with `--tags rig --run-skipped` — expected, unrelated to this task), 0
failed.

**Note on the interleaved transcript:** `flutter test`'s live reporter, run
non-interactively across many concurrently-executing test files, does not
print a line for every completed test — fast files finish inside one print
interval and their names never surface individually, while slower files (e.g.
`draft_painter_recursion_test.dart`'s per-depth loop) get one line per test.
Grepping the saved transcript for several files that never appeared by name
(`canvas_draw_sink_test.dart`, `draft_painter_test.dart`, `draft_canvas_test.dart`,
`draw_sink_test.dart`, `draft_painter_order_test.dart`, `point_shape_test.dart`,
`lineweight_test.dart`, `flutter_text_measurer_test.dart`,
`invariants/frame_accounting_test.dart`, `vertices_join_test.dart`,
`fill_render_test.dart`, `drawvertices_antialiasing_test.dart` — this task's
own `draft_painter_rebase_test.dart` was also one of them) found zero
mentions, so as a check I ran exactly those twelve files together on their
own:

```
$ CI=true flutter test test/canvas_draw_sink_test.dart test/draft_painter_test.dart \
    test/draft_canvas_test.dart test/draw_sink_test.dart test/draft_painter_order_test.dart \
    test/point_shape_test.dart test/lineweight_test.dart test/flutter_text_measurer_test.dart \
    test/invariants/frame_accounting_test.dart test/vertices_join_test.dart \
    test/fill_render_test.dart test/drawvertices_antialiasing_test.dart
...
00:01 +115: .../test/drawvertices_antialiasing_test.dart: drawVertices ignores isAntiAlias: the paint flag changes nothing
00:01 +116: .../test/drawvertices_antialiasing_test.dart: drawVertices shows no coverage ramp on a shared edge where drawPath does
00:01 +117: All tests passed!
```

117/117 passed, confirming the full-suite run's silence on these files was the
reporter's print-interval behaviour, not a sign they didn't run — the full
run's final tally (`+306`, no `-N`) already carried them.

## Deviations from the brief

1. **The `unitCamera()` and anchor-comment ruling (R3, pre-dispatch).** Defined
   a local `unitCamera()` at the top of `draft_painter_rebase_test.dart` rather
   than adding one to `support/fixtures.dart`, exactly as Ruling R3 instructs.
   Not a new deviation — recording it here for completeness since the brief's
   test body assumes it exists somewhere.

2. **`addLine`, `addDefinition`, `addInstance` did not exist in
   `support/fixtures.dart`.** Added all three with the signatures the brief's
   test calls use:
   - `Handle addLine(doc, owner, handle, x0, y0, x1, y1)`
   - `Handle addDefinition(doc, handle, name)`
   - `Handle addInstance(doc, owner, handle, definition, transform)`

   These mirror the existing `addEntity`/`addText` helpers and the node
   construction already used in `differentialFixture`.

3. **Two explicit imports the brief's test code block omits.** The brief's
   Step 2 code block uses `Size` and `Float64List` by name but lists only four
   imports (`flutter_test`, `jet_cad_2d`, `jet_cad_2d_flutter`, `vector_math`)
   plus the fixtures import — none of which bring those two names into scope
   in this codebase (`dart:ui`'s `Size` and `dart:typed_data`'s `Float64List`
   are neither exported by `jet_cad_2d.dart` nor by `jet_cad_2d_flutter.dart`;
   every other test file in this package that spells either name imports it
   directly). Added `import 'dart:typed_data';` and `import 'dart:ui' show
   Size;` to the top of the new test file. Without them the file does not
   compile at all, for a reason unrelated to the two missing `DraftPainter`
   parameters — this was caught immediately by the editor's diagnostics before
   the Step 3 run and fixed before that transcript was taken, so Step 3's
   failing run reflects only the intended compile failure.

4. **`_rootLeaves++` and `_defLeaves++` do not exist in this codebase's
   `draft_painter.dart`.** The brief's Step 4 says to place the `debugOnVisit`
   calls "beside" these two counters. Neither counter is present at either
   named call site (the root-leaf visitor inside `paint`'s `forEachInRect`
   callback, and `_drawContainer`'s leaf loop) — this file has no per-leaf
   counters by that name anywhere. Placed the two calls at the structurally
   equivalent spot in each case instead: in `paint`, immediately before the
   `_drawLeaf` call for the root-leaf visitor; in `_drawContainer`, immediately
   after the tree/overlay-duplicate check (`previous = leafHandle;`) and before
   the instance/leaf drawing that follows, so it fires exactly once per
   distinct leaf, matching the letter of the brief's example
   (`debugOnVisit?.call(Handle(leafHandle));`, using the already-computed
   `leafHandle`). The `_drawInstance` and `_descend` call sites matched the
   brief exactly — both counters/guards it named there exist as described.

No other deviations. `analysis_options.yaml` was not touched or staged;
`git status` was checked immediately before `git add` and only the three
intended paths were staged.
