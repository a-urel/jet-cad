# Task 3 report — `DraftCanvas` takes the resident path

Status: **NEEDS_CONTEXT**. Everything in the brief's Step 3 is implemented as
specified, plus two small, justified additions the brief's own facts assumed
were already true and one production fix the tests exposed as missing. Five
of the six new tests pass; the sixth's very first assertion checks a state
that cannot exist given Task 2's already-landed `ResidentRebuilder` /
`FakeUploader` and Flutter's real frame-callback timing. Not committed —
Step 5's gate is not green.

## What was implemented

`lib/src/draft_canvas.dart`, exactly per the brief's Step 3:
- `import 'gpu/resident_rebuilder.dart';`
- `DraftCanvas.residentUploader` (test seam, not compared in
  `didUpdateWidget`), `DraftCanvas.debugResidentFallbackReports`,
  `DraftCanvas.debugResetResidentFallbackReport()`,
  `DraftCanvas._reportResidentFallback` (static one-shot latch).
- `DraftCanvasState.resident` field and `_onResidentLanded` listener.
- `_attach()` rebuilt to: report the platform-capability fallback when
  `requested == residentGpu` and `resolvedBackend` is not; build `resident`
  (a `ResidentRebuilder`) when resolved to `residentGpu`, wired to
  `widget.residentUploader ?? uploadResidentCollection`; suppress the tile
  cache when `resident != null`; mark the rebuilder dirty on every
  `DocChange` from `_changes`'s `onChange`; merge `resident` into `_repaint`.
- `_detach()`: `resident?.removeListener(_onResidentLanded); resident?.dispose(); resident = null;` before `tileCache?.dispose()`.
- `build()`/`_DraftCustomPainter`: `resident` threaded through as a new
  field; `paint()` calls `resident.noteFrame(...)` right after the clip and
  paints through `resident.backend` when non-null, falling through to the
  existing vertices/tiles/canvas paths otherwise.
- `didUpdateWidget`: unchanged, as directed (`residentUploader` deliberately
  not compared).

`lib/src/render_backend.dart`: the `residentGpu` doc paragraph replaced
verbatim with the brief's Plan-F text.

`test/gpu/draft_canvas_resident_test.dart`: created verbatim from the
brief's Step 1, minus one line (see Deviations).

## Deviations from the brief's literal diff, and why

1. **`lib/jet_cad_2d_flutter.dart`: added `export 'src/gpu/gpu_facade.dart' show debugSetGpuAvailable;`.**
   The brief's test (verbatim) imports only the main barrel and calls
   `debugSetGpuAvailable` directly. `gpu_facade.dart` was deliberately never
   exported wholesale from the barrel (commit `2775aa6`, "review fixes --
   `@internal` leak, barrel comment, stale citations" — the file's own
   `export 'package:flutter_scene/src/gpu/gpu.dart';` would leak that
   package's internal shim through `jet_cad_2d_flutter`'s public API). Task
   2's own plan section only exported `resident_rebuilder.dart`, not this
   symbol, and every test that currently uses `debugSetGpuAvailable`
   (`gpu_facade_test.dart`, `backend_selection_test.dart`) imports
   `gpu_facade.dart` directly rather than through the barrel — the barrel
   export never happened. Without it the given test file does not compile:
   `Method not found: 'debugSetGpuAvailable'`. Fixed with a `show`-scoped
   export of the one symbol, which does not re-admit the wildcard
   `flutter_scene` re-export the barrel comment warns about.

2. **`lib/src/draft_canvas.dart`: `_DraftCustomPainter.shouldRepaint` changed from unconditional `false` to a resident-scoped comparison.**
   As given, `shouldRepaint` always returns `false`. `RenderCustomPaint`'s
   `painter=` setter only calls `markNeedsPaint()` when `shouldRepaint`
   returns true (or the delegate's `runtimeType` changed, which it never
   does here) — so a rebuild that changes only the delegate's *fields*
   (a new `devicePixelRatio` from `MediaQuery`, or a freshly re-attached
   `resident`) produces a new `_DraftCustomPainter` object that is **never
   painted**, because nothing else in that scenario fires the merged
   `repaint` listenable. Confirmed against the Flutter SDK source
   (`packages/flutter/lib/src/scheduler/binding.dart`, `handleDrawFrame`)
   and empirically with three instrumented copies of the test (see
   `/tmp` scratch scripts, not checked in): after a `pumpWidget` that only
   changes the ambient `MediaQueryData.devicePixelRatio`, or only replaces
   `resident` via a re-attach, `onPaintForTest`'s counter does not
   increment at all — `paint()` never runs, so `noteFrame` never runs, so
   `RebuildTrigger.devicePixelRatio` and the re-attach's own
   `RebuildTrigger.initial` can never fire. This is not a hypothetical: it
   is exactly why "a device pixel ratio change rebuilds" and "a re-attach
   ... " failed before this fix, and both pass after it. The fix:
   ```dart
   bool shouldRepaint(_DraftCustomPainter old) {
     final r = resident;
     if (r == null) return false;
     return old.resident != r || old.devicePixelRatio != devicePixelRatio;
   }
   ```
   Scoped to `resident != null` so every non-resident path (and the
   existing `draft_canvas_test.dart` test that asserts
   `shouldRepaint(painter)` is false for a plain canvas) is untouched.

3. **`test/render_backend_test.dart`: two tests now intercept `FlutterError.onError` locally, and a `setUp` resets the fallback latch.**
   Not in the brief's file list, but two pre-existing tests
   (`'an explicit backend is honoured, not clamped'` and `'an explicit
   residentGpu request resolves to vertices when unavailable'`) request
   `RenderBackend.residentGpu` on a platform with no GPU — exactly Ruling
   F5's fallback case, which now correctly calls
   `FlutterError.reportError` once per process. `flutter_test` fails a test
   on any reported `FlutterError` unless it is caught, so both tests newly
   failed (only the first alphabetically, because the static latch made the
   second's call a no-op). Fixed by resetting the latch per test and
   locally swallowing `FlutterError.onError` for the two tests that
   legitimately exercise the fallback; no existing assertion changed.

4. **`test/gpu/draft_canvas_resident_test.dart`: dropped the `import 'dart:ui';` line.**
   `flutter analyze` (this workspace treats `info` as a failing exit code)
   flagged it as `unnecessary_import`: `Offset`/`Size` are already provided
   by `package:flutter/widgets.dart`, also imported. No test code changed.

None of these loosen an assertion or change the resident path's stated
triggers; (1) and (4) are plumbing/lint fixes, (2) is a production fix that
makes two of the brief's own required triggers reachable at all, (3) is
test-only accommodation for (2)'s correct new side effect.

## The one test that cannot pass as specified

`test/gpu/draft_canvas_resident_test.dart`, `'the first frame paints through
vertices; the landed rebuild paints through the backend'`, line 82 (after
dropping the `dart:ui` import; line 82 in the file as committed to disk):

```dart
expect(uploader.painters, isEmpty,
    reason: 'the first frame drew before any rebuild landed');
```

**Actual:** `[Instance of 'RecordingFramePainter']` — non-empty, right after
`await t.pumpWidget(canvas())` and before any call to `land(t)`.

**Root cause, verified two ways:**

- *From the Flutter SDK source* (`packages/flutter/lib/src/scheduler/binding.dart`,
  `SchedulerBinding.handleDrawFrame`): persistent callbacks (build + layout +
  paint) run first; `_postFrameCallbacks` is snapshotted and drained
  **in the same `handleDrawFrame()` call**, immediately after. `_DraftCustomPainter.paint()`
  calls `resident.noteFrame(...)` → `markDirty(initial)` →
  `SchedulerBinding.instance.addPostFrameCallback(...)` from *inside* the
  paint sub-phase of the widget's very first frame — the same frame
  `pumpWidget()` itself drives. That callback therefore fires, and
  `ResidentRebuilder._run()` starts, before `pumpWidget()` returns. This
  matches `resident_rebuilder.dart`'s own `_schedule()` comment
  (`ensureVisualUpdate` is a no-op during `persistentCallbacks`, "the frame
  is already running and its end is the callback's cue") — the design is
  correct and deliberate for the rebuilder in isolation; it is the
  *combination* with the widget's first-frame paint that makes the "first
  frame draws before anything lands" property false for `DraftCanvas`
  specifically, unlike the standalone `resident_rebuilder_test.dart` tests,
  where `noteFrame` is called directly from the test body *outside* any
  frame, so its `markDirty` genuinely does need a subsequent `t.pump()` to
  fire — that is the scenario `land()`'s doc comment describes, and it does
  not hold for a `noteFrame` call sourced from the mounting widget's own
  paint.
- *Empirically*, with three instrumented copies of this scenario (not
  checked in): after `await t.pumpWidget(canvas())` alone, with no further
  pump, `DraftCanvasState.resident!.landed == 1` and
  `uploader.painters.length == 1` — the entire walk-classify-upload-swap-
  notify cycle completes inside the single `pumpWidget()` call, because
  `FakeUploader.call` (Task 2's fixture, `test/support/recording_frame_painter.dart`,
  out of this task's file list) has no `gate` set in this test and its body
  contains no real `await` before `painters.add(p)`; per Dart's async
  execution rules an `async` function's body runs synchronously up to its
  first genuine suspension point, so the side effect is visible immediately
  on the same call stack, well before `pumpWidget()`'s returned `Future`
  resolves.

**Why I did not change this:** the two facts that make the assertion false —
Flutter's same-frame post-frame-callback semantics, and `FakeUploader`'s
synchronous-when-ungated body — are both fixed points outside Task 3's
scope (platform behaviour and Task 2's already-landed fixture,
respectively). Making the assertion pass would require either editing this
specific test assertion (test/support file listed as prior art, and the
task's own instructions say not to loosen a test unilaterally) or adding a
real asynchronous gap to `FakeUploader.call` for the ungated case (editing
Task 2's fixture, likely breaking its own currently-green
`resident_rebuilder_test.dart` suite in ways I have not verified, and
changing behaviour a landed task's tests depend on). Per this task's own
brief: *"if something in the brief cannot be made to pass without changing
the stated behaviour ... stop and report the exact failing assertion with
NEEDS_CONTEXT rather than loosening the test or the code."* This is that
case.

Every other assertion in this test, and all five other new tests, pass —
including the checks right after this one in the same test body (`p.paints
>= 1`, `p.lastDpr`, `p.lastViewport`, `uploader.collections.single...`),
once `land(t)` is actually called. The only thing wrong is the specific
claim that nothing has landed *before* `land(t)` runs.

## Test results

RED (Step 2, before any implementation):
```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/draft_canvas_resident_test.dart
...
test/gpu/draft_canvas_resident_test.dart:76:14: Error: The getter 'resident' isn't defined for the type 'DraftCanvasState'.
...
  Failed to load ".../test/gpu/draft_canvas_resident_test.dart":
  Compilation failed ...
```
Expected failure per the brief (`residentUploader` not a named parameter;
`resident` undefined) — confirmed.

After Step 3's wiring (barrel export + `_attach`/`_detach`/`build`/paint
changes), before the `shouldRepaint` fix:
```
$ flutter test test/gpu/draft_canvas_resident_test.dart test/draft_canvas_test.dart
...
Failing tests:
  .../draft_canvas_resident_test.dart: a device pixel ratio change rebuilds, with the new ratio
  .../draft_canvas_resident_test.dart: a re-attach replaces the rebuilder and leaves one table listener; an unmount leaves none
  .../draft_canvas_resident_test.dart: the first frame paints through vertices; the landed rebuild paints through the backend
```
(`draft_canvas_test.dart`'s 17 tests all passed, unmodified, as the brief
requires.)

After the `shouldRepaint` fix:
```
$ flutter test test/gpu/draft_canvas_resident_test.dart test/draft_canvas_test.dart
...
Failing tests:
  .../draft_canvas_resident_test.dart: the first frame paints through vertices; the landed rebuild paints through the backend
```
Five of six new tests green; `draft_canvas_test.dart` still fully green.

Full package run after the `render_backend_test.dart` accommodation:
```
$ flutter test
...
00:08 +644 ~1 -1: Some tests failed.
Failing tests:
  .../draft_canvas_resident_test.dart: the first frame paints through vertices; the landed rebuild paints through the backend
```
644 total (~1 is the pre-existing skip STATUS.md already accounts for), one
failure — the one documented above. No other file in the package regressed.

## The three gates

```
$ cd packages/jet_cad_2d_flutter && flutter test
... 644 run, 1 pre-existing skip, 1 failure (documented above) — exit 1
```
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s) — exit 0
```
```
$ dart format --output=none --set-exit-if-changed .
Formatted 107 files (0 changed) in 0.17s — exit 0
```
`flutter analyze` and `dart format` are clean. `flutter test` is not, so the
chained gate (`flutter test && flutter analyze && dart format ...`) does not
reach exit 0, and I have not committed.

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart
 M packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart
 M packages/jet_cad_2d_flutter/lib/src/render_backend.dart
 M packages/jet_cad_2d_flutter/test/render_backend_test.dart
?? packages/jet_cad_2d_flutter/test/gpu/draft_canvas_resident_test.dart
```
No `analysis_options.yaml` in the diff.

## Files changed (all uncommitted)

- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` — Step 3's wiring,
  plus the `shouldRepaint` fix (deviation 2).
- `packages/jet_cad_2d_flutter/lib/src/render_backend.dart` — doc comment,
  exactly per the brief.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` — one `show`
  export (deviation 1).
- `packages/jet_cad_2d_flutter/test/gpu/draft_canvas_resident_test.dart` —
  new, per the brief's Step 1 minus one import (deviation 4).
- `packages/jet_cad_2d_flutter/test/render_backend_test.dart` — two tests
  accommodate the new fallback report; one `setUp` added (deviation 3).

## Self-review

- **Completeness:** every element of Step 3's diff is present verbatim
  (imports, both statics, the fallback method, `resident` field and
  listener, `_attach`/`_detach`/`build`/paint changes, the
  `render_backend.dart` doc swap). `didUpdateWidget` left untouched as
  directed.
- **Quality:** no change beyond what the failing tests demanded; each
  deviation is documented above with its exact cause.
- **Discipline:** did not touch `packages/jet_cad_2d`,
  `vertices_draw_sink.dart`, `canvas_draw_sink.dart`, or any shader.
  `draft_canvas.dart` grew by ~150 lines net — the brief's own diff is most
  of that; the `shouldRepaint` fix adds about a dozen more (mostly comment).
- **Testing:** five of six new tests pass and are not vacuous — each was
  watched fail first (compile error, then the two `shouldRepaint`-driven
  failures, confirmed fixed by that one change and nothing else). The sixth
  is not "loosened"; it is reported, with the exact assertion, the two
  independent lines of evidence for why it cannot hold, and what would be
  required to change it (either edit the assertion, or add a real
  asynchronous gap to Task 2's `FakeUploader`).

## Concerns for the controller

1. Please confirm the intended resolution for the one failing assertion:
   drop/reword it (recognising that `DraftCanvas`'s own first-frame paint
   makes the walk-to-landing cycle synchronous within `pumpWidget()` when
   `FakeUploader` is ungated), or add a forced asynchronous gap to
   `FakeUploader.call` for the no-`gate` case (which I have not attempted,
   since it touches Task 2's already-landed, already-tested fixture and
   might change `resident_rebuilder_test.dart`'s own timings).
2. The barrel-export gap (deviation 1) and the `shouldRepaint` gap
   (deviation 2) both look like real, minimal omissions in the plan
   document itself, not disagreements with its design — worth a plan
   erratum so Task 4's and Task 8's tests inherit a `shouldRepaint` that
   photographs the resident path correctly and a barrel that already
   exports the seam they need.
3. I did not attempt Step 5 (commit) since the full-suite gate is not
   green; all changes are left in the worktree, uncommitted, per the "never
   synthesize test output" and "stop rather than loosen" instructions.

## Fix report — controller rulings applied

Status after fixes: **DONE**. Commit `03a7b31` on `plan-f/rebuild-and-band`.

### Ruling F3-a — the "first frame" assertion

Replaced the false assertion in `test/gpu/draft_canvas_resident_test.dart`
(`'the first frame paints through vertices; the landed rebuild paints
through the backend'`) exactly as directed:

```dart
expect(paints, 1);
// The first paint's noteFrame registered a post-frame callback; it fired
// inside this same frame, and the ungated fake upload completed
// synchronously, so the rebuild has already LANDED here -- but the frame
// itself drew before that, through the vertices sink, and the landing
// only asked for a frame that has not been pumped yet. That is Ruling F3:
// the frame never waits, and the rebuild runs after the paint.
expect(s.resident!.landed, 1);
expect(uploader.painters.single.paints, 0,
    reason: 'the landed backend has not been asked to paint yet: the '
        'first frame went through vertices');
```

`s.resident!.landed` reads exactly `1` at that point — no surprise there;
matches the ruling's own prediction, so nothing further to report. Everything
from `await land(t);` onward is untouched.

### Ruling F3-b — `shouldRepaint` doc comment

Accepted as a plan erratum; the implementation was already exactly the
resident-scoped comparison the ruling describes, and the doc comment already
in place (added during the NEEDS_CONTEXT pass) already states the two facts
the ruling asks for: `RenderCustomPaint` never repaints a delegate whose
only change is a field unless `shouldRepaint` says so, the dpr trigger reads
exactly that field, and the comparison is scoped to `resident != null` so
every non-resident path keeps the "repaint is the only trigger" behaviour
unchanged. No further edit made; left as-is.

### Deviations 1 and 4

Accepted as filed; unchanged (the barrel's `show debugSetGpuAvailable`
export, and the dropped unnecessary `dart:ui` import).

### Ruling on `render_backend_test.dart` (deviation 3)

Both affected tests are `testWidgets` (confirmed:
`testWidgets('an explicit backend is honoured, not clamped', ...)` and
`testWidgets('an explicit residentGpu request resolves to vertices when
unavailable', ...)`). Per the ruling, switched from swapping
`FlutterError.onError` to `tester.takeException()`:

```dart
// 'an explicit backend is honoured, not clamped', after the loop:
expect(tester.takeException(), isA<FlutterError>());

// 'an explicit residentGpu request resolves to vertices when unavailable', at the end:
expect(tester.takeException(), isA<FlutterError>());
```

This is the more idiomatic fix: `TestWidgetsFlutterBinding` already installs
its own `FlutterError.onError` that stores a reported error into
`_pendingExceptionDetails` (see
`packages/flutter/lib/src/flutter_test/lib/src/binding.dart` around line
1774); `takeException()` reads and clears that slot, and an unclaimed
pending exception fails the test at the end of `_runTestBody`. Swapping
`onError` myself was unnecessary and slightly riskier (a forgotten restore
would leak across tests); `takeException()` uses the mechanism the binding
already provides. The `setUp(DraftCanvas.debugResetResidentFallbackReport)`
stays, so each test's own request is what gets reported and consumed,
independent of run order.

### Verification

Targeted run:
```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/draft_canvas_resident_test.dart test/draft_canvas_test.dart test/render_backend_test.dart
...
00:00 +29: All tests passed!
```
29/29 pass (6 resident + 17 draft_canvas + 6 render_backend).

Full package gate:
```
$ flutter test
...
00:07 +645 ~1: All tests passed!
```
645 run, 1 pre-existing skip, 0 failures — exit 0.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```
Exit 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 107 files (0 changed) in 0.18 seconds.
```
Exit 0.

```
$ git status --short
```
No `analysis_options.yaml` present in the diff, before or after staging.

### Commit

```
$ git add packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/render_backend.dart packages/jet_cad_2d_flutter/test/render_backend_test.dart packages/jet_cad_2d_flutter/test/gpu/draft_canvas_resident_test.dart
$ git commit -m "feat(gpu): DraftCanvas paints residentGpu through the rebuilder, on five triggers and no pan

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
[plan-f/rebuild-and-band 03a7b31] feat(gpu): DraftCanvas paints residentGpu through the rebuilder, on five triggers and no pan
 5 files changed, 415 insertions(+), 32 deletions(-)
 create mode 100644 packages/jet_cad_2d_flutter/test/gpu/draft_canvas_resident_test.dart
```

Working tree clean after the commit (`git status --short` empty).
