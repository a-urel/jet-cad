# Task 2 report: Dispose the submitted `Vertices`

## Summary

`VerticesDrawSink.flush()` built a `Vertices.raw(...)` per flush, submitted it
to `Canvas.drawVertices`, and dropped the reference without calling
`dispose()`. `Vertices` is native-backed (`NativeFieldWrapperClass1`,
`Vertices::dispose`), so the buffers it carries would otherwise wait for a
finalizer — about 1,140 undisposed objects a second at 19 flushes/frame, 60
fps.

The open question — may a `Vertices` be disposed immediately after the
`drawVertices` call that submitted it, or does the recorded output still
reference it — is answered **yes** by the `PictureRecorder` test: disposing
the `Vertices` right after `drawVertices` returns does not throw when the
picture is later recorded, so the engine copies what it needs by the time the
call returns.

Implemented exactly as the brief specified: dispose immediately, no
"hold one frame" fallback needed.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
  - Added `bool _lastFlushDisposed` field and `lastFlushDisposed` getter.
  - `flush()`: resets `_lastFlushDisposed = false` on entry (beside
    `_lastFlushVertices = 0`), builds `Vertices.raw` into a local `vertices`
    variable, calls `canvas.drawVertices(vertices, ...)`, then
    `vertices.dispose(); _lastFlushDisposed = true;` immediately after.
  - The inline `Paint()..color = const Color(0xFFFFFFFF)` was left untouched
    per the brief (Task 3 introduces `_paint`).
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`
  - Added the two tests verbatim from the brief:
    `'the submitted Vertices is disposed, and the picture still records'` and
    `'a flush with nothing batched disposes nothing'`.

## TDD evidence

### RED

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Real output (excerpt):

```
test/vertices_draw_sink_test.dart:235:17: Error: The getter 'lastFlushDisposed' isn't defined for the type 'VerticesDrawSink'.
 - 'VerticesDrawSink' is from 'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart' ('lib/src/vertices_draw_sink.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'lastFlushDisposed'.
    expect(sink.lastFlushDisposed, isTrue);
                ^^^^^^^^^^^^^^^^^
test/vertices_draw_sink_test.dart:249:17: Error: The getter 'lastFlushDisposed' isn't defined for the type 'VerticesDrawSink'.
...
00:00 +0 -1: Some tests failed.
```

This is exactly the failure the brief predicted: `lastFlushDisposed` did not
exist yet, so the whole test file failed to compile — the right reason to
fail before any implementation exists.

### GREEN

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Real output (tail):

```
00:00 +22: the fade multiplies the style alpha rather than replacing it
00:00 +23: the submitted Vertices is disposed, and the picture still records
00:00 +24: a flush with nothing batched disposes nothing
00:00 +25: a 45-degree segment gets a normal of the right length
00:00 +26: All tests passed!
```

26 tests, matching the brief's expectation. Both new tests pass without
throwing on the `recorder.endRecording()` call, which is the load-bearing
assertion: it means the picture recording did not retain a reference into the
disposed `Vertices`' buffers.

## Full gate

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Real output (tails):

```
00:03 +719: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +720: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +720: All tests passed!
---ANALYZE---
Analyzing jet_cad_2d...
No issues found!
---FORMAT---
Formatted 105 files (0 changed) in 0.18 seconds.
```

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Real output (tails):

```
00:02 +186 ~1: .../test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:02 +187 ~1: All tests passed!
---ANALYZE---
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
---FORMAT---
Formatted 37 files (0 changed) in 0.08 seconds.
```

187 passing, 1 skipped — up from the stated baseline of 185 passing, 1 skipped
by exactly the 2 new tests. No regression.

Note: on the first `flutter test` run after adding the new tests, `dart
format --output=none --set-exit-if-changed .` reported one file needing a
reformat (the wrapped `test(...)` header line the editor tool inserted did not
match `dart format`'s wrapping). Ran `dart format
test/vertices_draw_sink_test.dart` to apply it, then re-ran
`--set-exit-if-changed .` to confirm a clean tree before the final gate run
recorded above.

## Step 7: device verification

Attempted per ruling 2. `apps/dev_harness_2d/lib/main.dart:176` still passes
`useVertices: kVertices` to `DraftCanvas`, which is Task 1's old constructor
parameter; Task 1 replaced it with `RenderBackend? backend`. Confirmed with a
static check rather than a live `flutter run` (which would only fail at the
same compile step, after a much longer wait for the toolchain):

```sh
cd apps/dev_harness_2d && flutter analyze lib/main.dart
```

```
Analyzing main.dart...
  error • The named parameter 'useVertices' isn't defined. Try correcting the
  name to an existing named parameter's name, or defining a named parameter
  with the name 'useVertices' • lib/main.dart:176:17 • undefined_named_parameter

1 issue found. (ran in 0.7s)
```

The harness does not compile, so `flutter run --profile -d macos ...` cannot
reach a device at all — this is the expected-red state ruling 1 describes,
and Task 7's job to repair. No `flutter run` was launched (it would fail
before touching the CocoaPods project), so
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` was never
touched by this task; `git status --porcelain` is clean.

The `PictureRecorder` test in step 1/4 is therefore the only evidence
available in this task for whether disposal is safe. It shows disposal
immediately after `drawVertices` does not corrupt the recording. Per the
brief, this is necessary but not sufficient — a real rasterisation could in
principle behave differently — so this remains open until Task 7 repairs the
harness and someone runs step 7 against a live Impeller backend.

## Self-review

- Implementation matches the brief's code verbatim: field name, getter name,
  getter placement, comment text, reset point (`_lastFlushDisposed = false`
  alongside `_lastFlushVertices = 0`), and the `vertices.dispose();
  _lastFlushDisposed = true;` sequence immediately after `drawVertices`.
- No per-entity allocation added: `_lastFlushDisposed` is a single `bool`
  field set at most twice per flush, not per segment/vertex — the frame-path
  allocation invariant is untouched (`jet_cad_2d`'s allocation test doesn't
  cover this file, but the change is O(1) per flush by inspection, same as
  the existing counters).
  - `Vertices.raw` itself is unavoidably one allocation per flush already
    (pre-existing, not part of this task); this task changes only its
    lifetime, not its allocation count.
- Draw order untouched: no reordering of the buffer, no new unbatchable op,
  nothing added before/after `drawVertices` that could change when it fires
  relative to other ops.
- Both new tests carry `// MUTATION:` comments naming the exact mutation that
  makes each one fail, per `CLAUDE.md`'s testing bar:
  - "drop the dispose call" → `lastFlushDisposed` reads false.
  - "dispose unconditionally" → throws on a null `Vertices` in the
    nothing-batched path.
  These are genuine behavioural mutations, not restatements of the
  implementation — I did not add or alter the `// MUTATION:` wording from
  what the brief specified verbatim.
- `analysis_options.yaml`: not modified, verified via `git status --porcelain`
  before and after the pub-get runs the test commands triggered.
- Did not touch `apps/dev_harness_2d` per ruling 1.
- No `git checkout` used anywhere in this task (no device run occurred, so
  the pbxproj exception in ruling 2 did not apply).

## Concerns

- **Step 7 (device verification) could not be completed.** The harness does
  not compile against the current `DraftCanvas` API (Task 1's `useVertices` →
  `backend` rename), confirmed via `flutter analyze`, not run to a live
  device. This task's disposal-timing conclusion rests solely on the
  `PictureRecorder` test, which the brief itself flags as necessary but not
  sufficient — "a recorder may retain what a rasterisation does not." This
  should be re-verified against a real device once Task 7 repairs the
  harness.

---

## Fix report: response to review (Not Approved, 2 Critical findings)

Review verified both findings empirically. Both are fixed below.

### Finding 1: `_lastFlushDisposed = true` was unconditional, not derived

**Problem.** `_lastFlushDisposed = true;` sat beside `vertices.dispose();` as
a bare assignment, not read from the object. The reviewer removed
`dispose()`, left the assignment, and all 26 tests still passed — the flag
had nothing to do with whether disposal actually happened, so the suite
could not detect the exact regression the task exists to prevent.

**Fix.** `Vertices` carries `bool get debugDisposed`
(`dart:ui`/`painting.dart:6786` in this Flutter checkout, 3.27.3), which
reads the private `_disposed` field but only inside an `assert(...)` block,
and throws `StateError` if read with asserts off. Changed `flush()` to:

```dart
vertices.dispose();
// Read the object's own state rather than assert the flag beside the
// call above -- an unconditional `= true` here would stay true even if
// `dispose()` were deleted, which is the exact regression this field
// exists to catch. `debugDisposed` throws outside asserts, so it must
// never execute in a release build.
assert(() {
  _lastFlushDisposed = vertices.debugDisposed;
  return true;
}());
```

`lastFlushDisposed`'s doc comment now says it is debug-only and why: outside
asserts the getter body never runs, so `_lastFlushDisposed` stays `false`
whichever way disposal actually went in a release build. It is a test-only
signal, not something the frame path may rely on -- which matches how it is
actually used (only from `vertices_draw_sink_test.dart`).

**Mutation verified empirically**, as the reviewer's finding asked for:

1. Backed up `lib/src/vertices_draw_sink.dart` to a scratchpad path
   (`cp`, not `git`).
2. Deleted the `vertices.dispose();` line (replaced with a comment marking
   the deliberate mutation), leaving the `assert` block and everything else
   untouched.
3. Ran:
   ```sh
   cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
   ```
   Real output (relevant lines):
   ```
   00:00 +23: the submitted Vertices is disposed, and the flag reads its state
   00:00 +23 -1: the submitted Vertices is disposed, and the flag reads its state [E]
     Expected: true
       Actual: <false>

     package:matcher                                     expect
     package:flutter_test/src/widget_tester.dart 473:18  expect
     test/vertices_draw_sink_test.dart 237:5             main.<fn>

   00:00 +23 -1: the disposed Vertices rasterises the same pixels a retained one would
   00:00 +23 -2: the disposed Vertices rasterises the same pixels a retained one would [E]
     Expected: true
       Actual: <false>
   ...
   00:00 +25 -2: Some tests failed.
   ```
   Both tests that assert `lastFlushDisposed` went red for the right reason:
   the flag now genuinely reads `false` when `dispose()` is skipped.
4. Restored the file from the scratchpad backup with `cp` (not
   `git checkout`, per the no-`git checkout`-on-own-work rule), verified
   `git diff` against the pre-mutation state was empty, then re-applied the
   real fix (the diff shown above) on top of the restored file.
5. Re-ran the full suite to confirm green again (see "Full gate, post-fix"
   below).

### Finding 2: the recorder test never rasterised

**Problem.** The original test called `recorder.endRecording()` and asserted
`isNotNull` — `endRecording()` only finalises a display-list op list; it
does not dereference vertex data, so the test could not tell whether
disposal had freed a buffer a rasteriser would later read.

**Fix.** Split into two tests:

- `'the submitted Vertices is disposed, and the flag reads its state'` keeps
  the narrow `lastFlushDisposed` check (now meaningful after Finding 1's
  fix) and just disposes the recording; it no longer claims to answer the
  rasterisation question.
- `'the disposed Vertices rasterises the same pixels a retained one would'`
  (new) does the real comparison the finding asked for:
  - **Treatment**: draws one segment through the real sink, calls
    `sink.flush()` (which submits and disposes via the actual production
    code path), `endRecording()`s the picture, then `await
    picture.toImage(16, 16)` and `toByteData()` to get raw pixels.
  - **Control**: builds the identical two triangles `polyline` would have
    emitted for that exact segment and style (derived by hand from the
    first test in the file, `'a segment becomes two triangles a half-width
    either side of it'`, and cross-checked against `_halfWidthFor` /
    `_coveredArgb`'s arithmetic for the default style), submits them the
    same way (`Canvas.drawVertices`, `BlendMode.dst`, same paint), but is
    **never disposed** — this is exactly what `flush()` did before this
    task.
  - Compares the two `Uint8List`s of pixel bytes with `orderedEquals`.
  - Kept to one segment / two triangles / a 16x16 image, per the finding's
    warning about the software rasteriser's cost on a large
    `drawVertices` (1,007 segments took over 7.5 minutes in this
    environment per the brief). Measured: the whole file, including this
    new rasterising test, runs in about 2 seconds under `flutter test`
    (see timing below) — no hang.

**Mutation verified empirically**, again by deliberate mutation and restore:

1. Backed up `lib/src/vertices_draw_sink.dart` again.
2. Swapped the order in `flush()` so `vertices.dispose();` runs *before*
   `canvas.drawVertices(vertices, ...)` instead of after (a real,
   nameable production mutation: dispose-before-submit rather than
   dispose-after-submit).
3. Ran:
   ```sh
   cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart --name "disposed Vertices rasterises"
   ```
   Real output:
   ```
   00:00 +0: the disposed Vertices rasterises the same pixels a retained one would
   00:00 +0 -1: the disposed Vertices rasterises the same pixels a retained one would [E]
     'dart:ui/painting.dart': Failed assertion: line 8257 pos 12: '<optimized out>': is not true.
     dart:ui                                                        _NativeCanvas.drawVertices
     package:jet_cad_2d_flutter/src/vertices_draw_sink.dart 363:12  VerticesDrawSink.flush
     test/vertices_draw_sink_test.dart 268:10                       main.<fn>

   00:00 +0 -1: Some tests failed.
   ```
   This is a stronger failure than a pixel mismatch: `Canvas.drawVertices`
   itself asserts `!vertices.debugDisposed` in `dart:ui`
   (`painting.dart:8257`), so disposing before submission never reaches the
   pixel comparison at all -- the mutation is caught before the assertion
   this test was written to make. The test's `// MUTATION:` comment was
   corrected to describe this observed behaviour precisely (a thrown
   assertion, not a silently different image) rather than the originally
   guessed "different or garbage image" outcome.
4. Restored the file from backup with `cp`, verified the diff against the
   pre-mutation state was empty, confirmed the diff against the committed
   version still matched only the intended Finding 1 fix.

### Full gate, post-fix

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Real output (tail):

```
00:00 +18: a sub-pixel stroke gets one device pixel and loses alpha for it
00:00 +19: the floor is device pixels, so it moves with the ratio
00:00 +20: a lineweight of zero is a hairline at full alpha
00:00 +21: every emitter fades, not just the straight one
00:00 +22: the fade multiplies the style alpha rather than replacing it
00:00 +23: the submitted Vertices is disposed, and the flag reads its state
00:00 +24: the disposed Vertices rasterises the same pixels a retained one would
00:00 +25: a flush with nothing batched disposes nothing
00:00 +26: a 45-degree segment gets a normal of the right length
00:00 +27: All tests passed!
```

27 tests in this file now (one more than the pre-fix 26: the rasterisation
test is new, the original "picture still records" assertion was folded into
the renamed disposed-flag test rather than dropped).

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Real output (tails):

```
00:03 +719: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +720: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +720: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 105 files (0 changed) in 0.18 seconds.
```

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Real output (tails):

```
00:02 +187 ~1: .../test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:02 +188 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
Formatted 37 files (0 changed) in 0.06 seconds.
```

188 passing, 1 skipped -- up from the 187/1 recorded in the original report
by exactly the one new rasterisation test. No regression.

`git status --porcelain` before committing showed only the two intended
files modified; no `analysis_options.yaml` churn.

### Files touched by the fix

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — `flush()`
  now derives `_lastFlushDisposed` from `vertices.debugDisposed` inside an
  `assert` block instead of asserting it unconditionally; `lastFlushDisposed`
  doc comment documents the debug-only caveat.
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — the
  disposed-flag test renamed and trimmed to what it actually checks; new
  rasterising pixel-comparison test added; both carry corrected
  `// MUTATION:` comments matching behaviour verified by hand.

### Scope discipline

Touched only the two files above, as instructed. Did not touch
`apps/dev_harness_2d` and did not attempt a device run — both remain
Task 7's responsibility, per the coordinator's message carrying that ruling
forward.
