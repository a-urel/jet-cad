# Task 4 report: the document owns the measurer

Commit: `cc26039bd7b6433f951fb82640c4a717311d7820`

## Step 1 — tests added

Added to `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`:
- `const TextStyleRecord _roboto = TextStyleRecord(handle: Handle(7), name: 'Standard', fontFamily: 'Roboto');` near the top.
- `refuses a document whose measurer cannot lay out paragraphs`
- `disposing one canvas leaves a sibling cache warm`

Both verbatim from the brief.

## Step 2 — verified failing, against the pre-fix widget

I applied the Step 3 widget edit first, then went back and verified the
baseline honestly: `git stash push -- packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`
to restore the original `_attach()`/`dispose()`, ran the two new tests against
it, then `git stash pop` to restore the fix. Verbatim output:

```
00:00 +11: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: drawText reaches the painter, and a change to it rebuilds one
00:00 +12: refuses a document whose measurer cannot lay out paragraphs
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <Instance of 'ArgumentError'>
  Actual: <null>
   Which: is not an instance of 'ArgumentError'

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart:365:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart line 365
The test description was:
  refuses a document whose measurer cannot lay out paragraphs
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +12 -1: refuses a document whose measurer cannot lay out paragraphs [E]
  Test failed. See exception logs above.
  The test description was: refuses a document whose measurer cannot lay out paragraphs

00:00 +12 -1: disposing one canvas leaves a sibling cache warm
00:00 +13 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: refuses a document whose measurer cannot lay out paragraphs
```

**Discrepancy from the brief's prediction, reported rather than smoothed over:**
the refusal test failed exactly as expected. The split-view test
(`disposing one canvas leaves a sibling cache warm`) *passed* at baseline
instead of failing. Reading the pre-fix `_attach()`: `DraftCanvasState` built
its own private `_measurer` and handed it only to the sink — it never touched
`widget.document.textMeasurer` at all. The test calls
`measurer.paragraphFor(...)` directly on the *document's* measurer object,
which the pre-fix widget's paint path never reaches (the test document has no
entities, so nothing internal calls into it either). So `dispose()` clearing
the widget's own unrelated `_measurer` had no way to touch the count the test
reads — the test passed vacuously, for the wrong reason, rather than failing.
This is consistent with the bug description (document and sink measurer were
two disconnected objects) and resolves correctly post-fix, where both borrow
the same document-owned instance and the assertion is now meaningful.

## Step 3 — widget change

`packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`:
- Deleted the `late final FlutterTextMeasurer _measurer = FlutterTextMeasurer();` field.
- `_attach()` now reads `widget.document.textMeasurer`, throws `ArgumentError.value` unconditionally when it is not a `FlutterTextMeasurer` (message references `FlutterTextMeasurer` and `DraftDocument.empty(measurer:` verbatim, matching the test's `contains` assertions), and passes that measurer to `CanvasDrawSink`.
- `dispose()` no longer calls `.clear()`; replaced with the ownership comment from the brief.

## Step 4/5 — the nine documents (construction sites touched, with teardown)

| Site | Change |
|---|---|
| `draft_canvas_test.dart` `setUp()` (shared `differentialFixture()` used by most `testWidgets` in the file) | Built local `measurer`, `addTearDown(measurer.clear)`, passed to `differentialFixture(measurer: measurer)`. **Not explicitly itemized by line number in the brief**, but required: this fixture backs most of this file's `DraftCanvas` widget tests, and without it every one of them throws under the new unconditional guard. Added an optional `measurer` parameter (default `InsertionPointMeasurer`, unchanged) to `test/support/fixtures.dart`'s `differentialFixture()` so other non-widget callers (`differential_test.dart`, `large_coordinate_test.dart`, `vertices_differential_test.dart`) are unaffected. |
| `draft_canvas_test.dart:116` (`disposing stops listening`) | `FlutterTextMeasurer()` + `addTearDown(measurer.clear)` + `DraftDocument.empty(measurer: measurer)` |
| `draft_canvas_test.dart:~180` (`a small container does not draw its off-screen leaves`) | same shape |
| `draft_canvas_test.dart:~289` (`drawText reaches the painter...`) | swapped `MetricModelMeasurer()` for `FlutterTextMeasurer()` + `addTearDown` |
| `draft_canvas_test.dart` (two new tests, Step 1) | own `FlutterTextMeasurer()` + `addTearDown` each |
| `render_backend_test.dart:9` (`_pump` helper) | `FlutterTextMeasurer()` + `addTearDown` + `generateDocument(..., measurer: measurer)` |
| `render_backend_test.dart:~72` (`changing the backend prop rebuilds the sinks`) | same shape |
| `frame_path_seam_test.dart:39` (`_fixture` helper) | `FlutterTextMeasurer()` + `addTearDown` + `DraftDocument.empty(measurer: measurer)` |
| `golden/dash_ladder_golden_test.dart:22` (`dashLadderFixture()`) | same shape (`addTearDown` valid — always invoked from inside a `testWidgets` body) |
| `golden/fill_ladder_golden_test.dart:46` (`fillLadderFixture()`) | same shape |
| `apps/dev_harness_2d/lib/main.dart` (`harnessDocument()`) | added library-level `final FlutterTextMeasurer harnessMeasurer = FlutterTextMeasurer();`; replaced the `kTextCorpus ? FlutterTextMeasurer() : const InsertionPointMeasurer()` ternary with `measurer: harnessMeasurer`; `_HarnessState.dispose()` now calls `harnessMeasurer.clear()` after `index.dispose()`/`camera.dispose()`, before `super.dispose()`. |

Note: `test/golden/text_ladder_golden_test.dart` already used
`DraftDocument.empty(measurer: FlutterTextMeasurer())` (added by an earlier
task in this plan) and needed no change; it is not in the brief's file list
and I left it untouched.

## Step 6 — full verification

### `flutter test` (jet_cad_2d_flutter), tail

```
00:03 +282: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:03 +283: All tests passed!
```

283 passed, 1 pre-existing skip (tagged `rig`, unrelated: "Skip: run explicitly: flutter test --tags rig --run-skipped").

### `flutter test --tags golden`, tail

```
00:01 +27: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
00:01 +28: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
00:01 +29: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:02 +29: All tests passed!
```

29/29 golden tests passed, including both ladders this task's fixtures fed.

### `flutter analyze` (jet_cad_2d_flutter)

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```

### `flutter analyze` (apps/dev_harness_2d)

```
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)
```

### `dart format --output=none --set-exit-if-changed .` (jet_cad_2d_flutter)

First run flagged `test/support/fixtures.dart` (the new `differentialFixture`
parameter list wrapped past 80 columns); ran `dart format test/support/fixtures.dart`
and reformatted. Second run: `Formatted 49 files (0 changed) in 0.09 seconds.`

### Also ran, beyond the brief's Step 6, per CLAUDE.md's "every task ends green" gate

- `cd packages/jet_cad_2d && CI=true dart test` — `777 tests passed!`
- `cd packages/jet_cad_2d && dart analyze` — `No issues found!`
- `cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .` — `Formatted 110 files (0 changed)`

### `git status` — no golden PNG regenerated, no trap file staged

Before commit:

```
On branch main
Your branch is ahead of 'origin/main' by 10 commits.

Changes not staged for commit:
	modified:   apps/dev_harness/analysis_options.yaml
	modified:   apps/dev_harness/macos/Podfile
	modified:   apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
	modified:   apps/dev_harness_2d/lib/main.dart
	modified:   packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart
	modified:   packages/jet_cad_2d_flutter/test/draft_canvas_test.dart
	modified:   packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart
	modified:   packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart
	modified:   packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart
	modified:   packages/jet_cad_2d_flutter/test/render_backend_test.dart
	modified:   packages/jet_cad_2d_flutter/test/support/fixtures.dart
```

`git status --porcelain -- '*.png' packages/jet_cad_2d_flutter/test/golden`
showed only the two `_test.dart` files, no `.png`.

Staged and committed only the brief's file list
(`draft_canvas.dart`, `test/` under `jet_cad_2d_flutter`, `apps/dev_harness_2d/lib/main.dart`);
the three pre-existing trap files
(`apps/dev_harness/analysis_options.yaml`, `apps/dev_harness/macos/Podfile`,
`apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj`) were never staged
and remain modified-but-untracked-for-commit exactly as found at session start.

## Step 7 — commit

`cc26039bd7b6433f951fb82640c4a717311d7820` — "feat: the document owns the text measurer and DraftCanvas borrows it"

8 files changed, 143 insertions(+), 24 deletions(-).

---

# Fix round 1

Commit: `4cd23da` (full: run `git log -1 4cd23da` to confirm)

The review came back spec-compliant and quality-approved, with three Minor
findings; the coordinator promoted the first to Important. All three are
addressed below.

## Important (promoted): nothing pinned the borrowed measurer's identity

`DraftCanvasState._attach()` read `widget.document.textMeasurer`, checked its
*type*, then passed it to `CanvasDrawSink` — but no test asserted that the
object handed to the sink was *the same object* as the document's. A private
`FlutterTextMeasurer()` built at the sink's construction site instead of the
borrowed one would satisfy the type guard and pass every test in the suite,
silently reintroducing the exact defect this plan removes: two independent
caches (one the document's extents/pick path reads, one the sink draws from),
laying every string out twice and letting a full `extents` sweep evict
whatever the paint path had warm.

Added, in `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`, to the
existing `'one sink serves every paint'` test (which already holds both a
`DraftCanvasState` via `tester.state<DraftCanvasState>(...)` and the shared
`doc`):

```dart
expect(identical(state.sink.measurer, doc.textMeasurer), isTrue,
    reason: "the sink must borrow the document's measurer, not build "
        'its own');
```

`identical`, not `==`, per the coordinator's note — two distinct measurers
with equal (empty) cache state would pass a value comparison.

### Named-killer transcript

Backed up the file by copy (not `git checkout`, which would restore HEAD and
discard the round's other two fixes already applied to the working file):

```
cp packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart \
   packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart.bak
```

Mutated `_attach()` to give the sink a private throwaway measurer instead of
the borrowed one:

```dart
  void _attach() {
    _requireMeasurer();
    // MUTATION (temporary, for the review's named-killer transcript): a
    // private throwaway measurer instead of the borrowed one.
    final measurer = FlutterTextMeasurer();
    sink = CanvasDrawSink(
        pixelsPerPaperMm: widget.pixelsPerPaperMm,
        lineweightScale: widget.lineweightScale,
        measurer: measurer,
        textStyleOf: widget.document.textStyleOf);
```

Ran the one test the assertion lives in:

```
$ CI=true flutter test test/draft_canvas_test.dart --plain-name "one sink serves every paint"
...
00:00 +0: one sink serves every paint
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: true
  Actual: <false>
the sink must borrow the document's measurer, not build its own

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart:166:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart line 166
The test description was:
  one sink serves every paint
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -1: one sink serves every paint [E]
  Test failed. See exception logs above.
  The test description was: one sink serves every paint

00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: one sink serves every paint
```

Confirmed red. Restored by copying the backup back over the mutated file, then
deleting the backup:

```
cp packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart.bak \
   packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart
rm packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart.bak
```

`git diff` afterward showed only the round's three real changes (see below),
and a full `flutter test` run (below) confirmed 283/283 pass again — the
restore was clean.

## Minor: `didUpdateWidget` could double-dispose `_changes`

Extracted the type guard out of `_attach()` into a new private method,
`FlutterTextMeasurer _requireMeasurer()`, on `DraftCanvasState` in
`packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`. `_attach()` now
opens with `final measurer = _requireMeasurer();`. `didUpdateWidget` now calls
`_requireMeasurer();` as the first statement inside the changed-props branch,
before `_changes.dispose()` — so a prop change that swaps in an invalid
measurer throws before anything is torn down, and the widget's own
`dispose()` cannot double-dispose `_changes`.

## Minor: stale doc comment on `harnessDocument()`

Rewrote the doc comment in `apps/dev_harness_2d/lib/main.dart` above
`harnessDocument()` to describe the current unconditional-real-measurer
behaviour, while still recording what the old `kTextCorpus`-branched behaviour
was and why it changed (a workaround for a problem that, even then, applied to
every document, not just the text corpus). Trimmed the now-redundant inline
comment at the `measurer: harnessMeasurer` call site to a one-line pointer at
the doc comment, since keeping both in full duplicated the explanation.

## Verification

### `CI=true flutter test` (jet_cad_2d_flutter), tail

```
00:04 +281 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +282 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:04 +283 ~1: All tests passed!
```

283 passed, 1 pre-existing unrelated skip (same `rig`-tagged skip as before).

### `CI=true flutter test --tags golden`, tail

```
00:01 +28: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
00:01 +29: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:02 +29: All tests passed!
```

29/29 golden tests passed.

### `flutter analyze` (jet_cad_2d_flutter)

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```

### `flutter analyze` (apps/dev_harness_2d)

```
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)
```

### `dart format --output=none --set-exit-if-changed .` (jet_cad_2d_flutter)

```
Formatted 49 files (0 changed) in 0.09 seconds.
```

### `git status` — no PNG modified, no trap file staged

Before commit:

```
Changes not staged for commit:
	modified:   apps/dev_harness/analysis_options.yaml
	modified:   apps/dev_harness/macos/Podfile
	modified:   apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
	modified:   apps/dev_harness_2d/lib/main.dart
	modified:   packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart
	modified:   packages/jet_cad_2d_flutter/test/draft_canvas_test.dart
```

`git status --porcelain -- '*.png'` returned nothing. Staged and committed
only the three real-fix files; the three pre-existing trap files were never
staged.

After commit, `git status --porcelain -- '*.png'` again returned nothing, and
the only remaining modified files are the same three pre-existing trap files
found at session start.

## Commit

`4cd23da` — "fix: pin the borrowed measurer's identity, and two review nits"

3 files changed, 41 insertions(+), 21 deletions(-).
