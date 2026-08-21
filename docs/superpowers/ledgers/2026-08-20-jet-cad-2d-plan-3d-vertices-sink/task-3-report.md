# Task 3 report: Hoist the `Paint`, and measure what a frame allocates

Commit: `aeb2373` — "test: measure what the paint path allocates, and hoist the Paint"

## What was implemented

1. `VerticesDrawSink._paint` — a `Paint()..color = const Color(0xFFFFFFFF)` field
   held for the life of the sink, mirroring `CanvasDrawSink`'s comment ("the
   whole reason this is an object"). `flush()` now passes `_paint` to
   `canvas.drawVertices` instead of constructing a fresh `Paint()` every call.
2. `VerticesDrawSink.debugCapacityVertices` — `int get => _colors.length`, a
   debug accessor beside the other `debug*` getters, exposing the buffer's
   capacity so a test can assert it stops changing in steady state.
3. `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` —
   new test file, verbatim from the brief, that measures the paint path the
   same way `query_allocation_test.dart` measures the query path.
4. A new "What a steady-state frame allocates" section in
   `VerticesDrawSink`'s class doc comment, stating the residue as a dated
   fact: three objects per flush (`Vertices.raw` and the two `sublistView`
   wrappers), nothing per entity, `3 * (textOps + 1)` per frame.

Files changed:
- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` (modified)
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` (new)

## TDD evidence

### RED

Before implementing `debugCapacityVertices`, running the new test:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
...
test/invariants/paint_allocation_test.dart:71:25: Error: The getter 'debugCapacityVertices' isn't defined for the type 'VerticesDrawSink'.
 - 'VerticesDrawSink' is from 'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart' ('lib/src/vertices_draw_sink.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'debugCapacityVertices'.
    final before = sink.debugCapacityVertices;
                        ^^^^^^^^^^^^^^^^^^^^^
...
00:00 +0 -1: Some tests failed.
```

This is exactly the failure the brief's Step 2 predicted — a compile error
naming the missing getter, not a runtime assertion failure. Expected, because
the test references an accessor that does not exist yet.

### GREEN

After adding `debugCapacityVertices` and hoisting `_paint`:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
00:00 +0: loading .../test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: All tests passed!
```

## Mutation run

**Mutation:** in `VerticesDrawSink._reserve`, drop the capacity-sufficiency
guard (`if (_vertices + moreVertices <= _colors.length) return;`) and make the
capacity computation unconditional — `var capacity = _colors.length * 2;` on
every call, instead of only growing when the existing capacity is
insufficient. This is the mutation named in the test's `// MUTATION:` comment
above the `debugCapacityVertices` assertion.

Procedure: backed the file up with `cp`, applied the mutation, ran the test,
restored from the backup afterward (confirmed restored by re-running the test
green and diffing against the committed file — clean).

**Real red transcript:**

```
$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
...
00:00 +0: loading .../test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
Shell: Exhausted heap space, trying to allocate 34359738400 bytes.
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═══════════════════════════════
The following OutOfMemoryError was thrown running a test:
Out of Memory

When the exception was thrown, this was the stack:
#0      new Float32List (dart:typed_data-patch/typed_data_patch.dart:2891:3)
#1      VerticesDrawSink._reserve (package:jet_cad_2d_flutter/src/vertices_draw_sink.dart:310:23)
#2      VerticesDrawSink._emitSegment (package:jet_cad_2d_flutter/src/vertices_draw_sink.dart:280:5)
#3      VerticesDrawSink._flatten (package:jet_cad_2d_flutter/src/vertices_draw_sink.dart:485:7)
#4      VerticesDrawSink.circle (package:jet_cad_2d_flutter/src/vertices_draw_sink.dart:437:7)
...
00:00 +0 -1: a steady-state frame allocates O(1) per flush, not O(entities) [E]
  Test failed. See exception logs above.

Failing tests:
  .../test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
```

**Why this is the expected failure, not a weaker one.** With the guard gone,
every `_emitSegment` call (one per stroke segment, of which the corpus draws
thousands) re-doubles `_colors.length` unconditionally. That compounds
geometrically across the frame — 2^n growth over n segment emissions — and the
buffer's requested size overflows available heap long before the frame
finishes, let alone before either `expect` runs. The test fails with
`OutOfMemoryError` rather than a clean `expect` mismatch, but it is the same
underlying property failing as loudly as it can: a mutation that makes the
buffer regrow when it should hold steady turns this test red. A milder
mutation (grow-when-not-needed exactly once) would produce the cleaner
"Expected: N, Actual: M" form; I chose the guard removal because it is the
most direct inversion of the property under test and it is unambiguous that
the mutation, not test flakiness, caused the failure.

After restoring the file from the backup, the test passes again (confirmed
above under GREEN, re-run after restore, and `git diff` against the committed
file is empty).

## Full-gate output

```
$ cd packages/jet_cad_2d && dart test
... 720 tests ...
00:03 +720: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.18 seconds.

$ cd ../jet_cad_2d_flutter && flutter test
... 189 tests, 1 skipped ...
00:02 +189 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)

$ dart format --output=none --set-exit-if-changed .
Formatted 38 files (0 changed) in 0.06 seconds.
```

189 passing + 1 skipped in `jet_cad_2d_flutter`, up from the stated baseline of
188 passing + 1 skipped by exactly the one new test added. No regression.
`analysis_options.yaml` was not modified in either package (confirmed via
`git status --short` before commit).

## The measured allocation residue

**Three objects per flush** — the `Vertices.raw` and the two
`Float32List.sublistView` / `Int32List.sublistView` wrappers `flush()` builds
it from — and **nothing per entity**. The buffers themselves (`_positions`,
`_colors`) are grown once (doubling, never given back) and reused; the new
test fails if they grow in a measured steady-state frame. With text present in
the corpus, a frame flushes once per text op (via `_flushBeforeUnbatchable`)
plus once at the end, so the frame's total is `3 * (textOps + 1)`.

**Proposed `CLAUDE.md` amendment**, per the brief's exact wording — not
applied, per Step 8's instruction to stop rather than amend it myself:

> **The frame path allocates nothing per entity in steady state, and O(1) per
> flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
> `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
> measure it.

This is reported to the human running the plan for an explicit yes/no, per the
brief. `CLAUDE.md` has not been touched.

## Self-review

- Diff matches the brief's Step 3 code verbatim: the `debugCapacityVertices`
  getter, the `_paint` field, and the `flush()` call-site swap are exactly as
  specified, in the same locations (beside the other `debug*` accessors,
  beside the buffers).
- The class-comment addition is placed after the last existing bullet list
  ("This sink is authoritative...") and before `class VerticesDrawSink`,
  matching the brief's Step 5 text exactly, including the trailing formula.
- No other behavior changed. `git diff` for the production file is 22 lines
  added, 1 changed (the `Paint()` literal replaced by `_paint`), 0 removed
  beyond that — a minimal, YAGNI-respecting change.
- The test file matches the brief's Step 1 text verbatim except for one
  addition: a `// MUTATION:` comment above the growth assertion, documenting
  the mutation actually run and why it manifests as an `OutOfMemoryError`
  rather than a plain `expect` mismatch. This follows the task's own
  instruction to name the mutation in the test as a comment, following the
  pattern in `vertices_draw_sink_test.dart`; the brief's literal text did not
  include this comment, but the surrounding task instructions require it and
  it does not change any assertion or fixture.
- `dart format` reformatted one line in the test file after I wrote it (a
  line-length wrap in the `sink =` construction); applied and reverified
  clean.
- Confirmed the file was fully restored after the mutation run: `git diff`
  against the committed production file is empty, and the test passes green
  post-restore.
- No changes to `apps/dev_harness_2d`, `analysis_options.yaml`, or anything
  outside the two files the brief named.

## Concerns

- The mutation I ran produces a crash (`OutOfMemoryError`) rather than a clean
  `expect(...).toEqual(...)` mismatch, because removing the guard causes
  geometric (2^n) regrowth across thousands of per-frame segment emissions
  rather than a single extra doubling. I judged this an honest and stronger
  demonstration that the test catches the mutation class it targets (buffer
  regrowth in steady state), but a reviewer wanting to see the assertion's
  own `Expected: X / Actual: Y` message fire might consider it a less
  "textbook" red than a milder mutation would produce. I did not additionally
  run a milder mutation (e.g., an off-by-one in the doubling threshold) given
  the difficulty of guaranteeing it manifests deterministically against this
  corpus's generic vertex counts — happy to run one if requested.
- Task 3 does not resolve the `CLAUDE.md` wording question; that is by
  design (Step 8) and awaits the human's yes/no.

## Fix: review finding on the file header (Important)

**Finding.** The reviewer confirmed the mutation question is settled (my OOM
red reproduced exactly, plus two smaller variants they tried: an off-by-one
guard stays green but is a benign difference, and an additive non-doubling
variant hangs instead of failing cleanly — the OOM is accepted as the right
red for this property, which is inherently unbounded at corpus size once it
regresses). The one Important finding was the file header at
`test/invariants/paint_allocation_test.dart:1-11`: it described a mechanism
("ratio against a control", "the VM's allocation profiler has a documented
low-read artefact") that the test does not use — the test is a deterministic
equality check on `debugCapacityVertices` before and after a frame, no
`AllocationMeter`, no VM service, no ratio. The reviewer traced this to the
brief itself (one mechanism stated in the header, a different one specified in
the test body) but asked for it fixed here since it ships in this file, and
`query_allocation_test.dart`'s own header trains a reader to trust the header
as the methodology.

**Fix.** Rewrote the header to describe what the test actually does: the
property has an exact answer (once the buffers have grown, `_reserve` never
gives capacity back, so `debugCapacityVertices` either holds still across a
later frame or it does not), so no sampling profiler, control run or ratio is
needed — one would only add noise to a question with an exact answer. States
what the warm-up is for and what the residue is (three objects per flush,
nothing per entity, `3 * (textOps + 1)` per frame), without restating the
assertions line by line. Nothing outside the header comment (lines 1–11)
changed.

**Verification — re-ran the test, comment-only change confirmed green:**

```
$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
...
00:00 +0: loading .../test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: All tests passed!
```

Also re-ran `dart format --output=none --set-exit-if-changed .` (0 files
changed) and `flutter analyze` (`No issues found!`) in
`packages/jet_cad_2d_flutter` after the edit — both clean.

Commit: `aca6d22` — "fix: correct the paint_allocation_test.dart header's stated mechanism"
