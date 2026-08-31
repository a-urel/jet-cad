# Task 1 report: the dash seam on `DrawSink`

Branch: `plan-c/shaded-dashes`. Commit: `436a416` — "feat(sink): a dash
bracket, for a sink that shades rather than consumes spans".

## What changed and why

Added the seam Plan C's later tasks build on: `DrawSink` gains
`bool get shadesDashes`, `void beginDash(DashPattern pattern, double
patternToLocal)` and `void endDash()`, plus two new `DrawOp` subclasses,
`BeginDashOp` and `EndDashOp`, so `RecordingDrawSink`'s equality oracle can
carry a dash bracket the same way it carries every other call.

All six `implements DrawSink` classes were given the three members, per the
brief's "facts you would otherwise have to rediscover":

- `lib/src/draw_sink.dart` — the interface, the two new `DrawOp`s, and
  `RecordingDrawSink` + `NullDrawSink`.
- `lib/src/canvas_draw_sink.dart` — `CanvasDrawSink`.
- `lib/src/vertices_draw_sink.dart` — `VerticesDrawSink`.
- `lib/src/gpu/geometry_collector.dart` — `GeometryCollector`.
- `test/support/text_key_sink.dart` — `TextKeySink`.

Five of the six (everything except `GeometryCollector`) answer
`shadesDashes => false` and throw `UnsupportedError` from both `beginDash`
and `endDash`, with a per-class message naming the class and repeating the
brief's rationale ("a wiring mistake that routed undashed geometry to a
span-consuming sink would otherwise draw a solid line where the document
says dashed"). `RecordingDrawSink` is the one exception among the five: it
gained a constructor, `RecordingDrawSink({this.shadesDashes = false})`, so a
sink built with `shadesDashes: true` records the bracket as ops instead of
throwing — that is what lets the oracle assert on it at all.

`GeometryCollector` — declaration only, per Ruling 2 in the task message.
`shadesDashes => true`; `beginDash`/`endDash` are empty bodies, each with a
`// Task 5` comment. Verified it writes no instance: added a test that calls
`beginDash`/`endDash` on a fresh `GeometryCollector` and asserts
`instanceCount` stays `0` before and after.

`DashPattern` was consumed as-is from `package:jet_cad_2d`
(`packages/jet_cad_2d/lib/src/document/tables.dart:208`), already exported
through the barrel `draw_sink.dart` already imports. `packages/jet_cad_2d`
was not touched — confirmed by `git status --short` and by the diff below
only ever touching `packages/jet_cad_2d_flutter`.

### What the brief did not mention, found by the compiler

`DrawOp` is `sealed`. Two test-support files switch over it exhaustively
without a wildcard case, and adding `BeginDashOp`/`EndDashOp` broke both at
compile time the moment the new subclasses existed — independent of whether
any test ever constructs one:

- `test/support/differential.dart` — `flatten()`, the oracle
  `expectPainterSupersetOfReference` is built on.
- `test/support/vertices_differential.dart` — the ink-sampling switch inside
  its reference walk (line ~123).

A third switch, `test/large_coordinate_test.dart:_localPointsOf`, and a
fourth, `test/support/vertices_differential.dart:widestHalfStroke`, both
already carried a `_ =>` wildcard arm and needed no change.

Fixed by adding a `case BeginDashOp(): case EndDashOp(): break;` (or
equivalent) to the two switches, each with a comment explaining that no
sink compared through that particular oracle shades dashes yet, so the
bracket cannot reach the branch today — Task 5 gives the shading sink its
own reference and differential test. No behaviour changed by this fix: both
arms were unreachable before this task (the ops did not exist) and stay
unreachable now (nothing constructs them outside the two direct
`RecordingDrawSink(shadesDashes: true)` tests and `GeometryCollector`'s
still-empty bracket).

## Ruling P4 — resolved by narrowing the sinks in the test, matching the ruling's preferred first option

The brief's sample test named itself "every non-shading sink in this package
refuses the bracket" but its body constructed only `NullDrawSink` and
`RecordingDrawSink`. Per the ruling, constructed all five non-shading sinks
instead of narrowing the name:

```dart
test(
    'every non-shading sink in this package refuses the bracket '
    '(CanvasDrawSink, VerticesDrawSink, RecordingDrawSink, NullDrawSink, '
    'TextKeySink)', () {
  final canvas = SpyCanvas();
  final sinks = <DrawSink>[
    CanvasDrawSink(
        canvas: canvas,
        pixelsPerPaperMm: 4.0,
        measurer: FlutterTextMeasurer(),
        textStyleOf: (Handle handle) => _standard),
    VerticesDrawSink(pixelsPerPaperMm: 4.0, canvas: canvas),
    RecordingDrawSink(),
    NullDrawSink(),
    TextKeySink(),
  ];
  for (final sink in sinks) {
    expect(sink.shadesDashes, isFalse, reason: '$sink');
    expect(() => sink.beginDash(pattern, 1.0), throwsUnsupportedError,
        reason: '$sink');
  }
});
```

`CanvasDrawSink` and `VerticesDrawSink` are constructed with the existing
`test/support/spy_canvas.dart`'s `SpyCanvas`, matching the pattern already
used elsewhere in `test/draw_sink_test.dart`. `TextKeySink` is imported from
`test/support/text_key_sink.dart`. The test's name is now exactly what its
body checks — five named classes, five constructed instances.

I kept the brief's title language ("every non-shading sink in this package
refuses the bracket") as the lead sentence and appended the five class names
in parentheses, rather than inventing new wording, since the ruling's own
example ("Either construct all five ... or narrow the test's name") treats
constructing all five as satisfying the original name outright.

## Test file

`test/draw_sink_test.dart` already existed (contrary to the brief's "may not
exist" hedge) with 27 pre-existing tests across `RecordingDrawSink`,
`NullDrawSink`, `flatten`, and `CanvasDrawSink` groups. Appended a new
`group('dash bracket', ...)` with 6 tests: the brief's four (adjusted per
Ruling P4) plus one added test asserting `GeometryCollector`'s bracket is a
true no-op (`instanceCount` unchanged across both calls).

## Exact commands run, with output and exit codes

### 1. New test file alone, before the sealed-switch fix (failure, as expected)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart
...
test/support/differential.dart:79:13: Error: The type 'DrawOp' is not exhaustively matched by the switch cases since it doesn't match 'BeginDashOp()'.
 - 'DrawOp' is from 'package:jet_cad_2d_flutter/src/draw_sink.dart' ('lib/src/draw_sink.dart').
Try adding a default case or cases that match 'BeginDashOp()'.
    switch (op) {
            ^
00:00 +0 -1: loading .../draw_sink_test.dart [E]
  Failed to load ...: Compilation failed ...
00:00 +0 -1: Some tests failed.
```
Exit code: 1 (implicit from "Some tests failed").

### 2. New test file alone, after fixing both sealed switches (pass)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart
...
00:00 +32: dash bracket every non-shading sink in this package refuses the bracket (CanvasDrawSink, VerticesDrawSink, RecordingDrawSink, NullDrawSink, TextKeySink)
00:00 +33: dash bracket GeometryCollector shades dashes and the bracket is a no-op today (Task 5 implements it)
00:00 +33: All tests passed!
```
Exit code: 0.

### 3. `jet_cad_2d_flutter` full suite

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:08 +484 ~1: All tests passed!
```
484 passed, 1 skip (the same pre-existing skip STATUS.md records at 479
before this task — 479 + 5 new tests = 484). Exit code: 0.

### 4. `jet_cad_2d_flutter` analyze

```
$ cd packages/jet_cad_2d_flutter && flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```
Exit code: 0.

### 5. `jet_cad_2d_flutter` format check

First run, before running `dart format` on the two files I'd hand-edited:

```
$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Changed lib/src/draw_sink.dart
Changed test/draw_sink_test.dart
Formatted 89 files (2 changed) in 0.16 seconds.
EXIT: 1
```
This is a real failure, not a status line — logged per the "never synthesize
test output" / "`(1 changed)` is a failure" instruction. Fixed:

```
$ dart format lib/src/draw_sink.dart test/draw_sink_test.dart
Formatted lib/src/draw_sink.dart
Formatted test/draw_sink_test.dart
Formatted 2 files (2 changed) in 0.01 seconds.

$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.19 seconds.
EXIT: 0
```

Re-ran the full suite after formatting to make sure the reformat changed
nothing behaviourally:

```
$ flutter test
...
00:08 +484 ~1: All tests passed!
```
Exit code: 0.

### 6. `dev_harness_2d` gate

```
$ cd apps/dev_harness_2d && flutter test --concurrency=1
...
00:18 +72: All tests passed!
```
72 tests, matching STATUS.md's baseline count exactly. Exit code: 0.

```
$ flutter analyze
...
Analyzing dev_harness_2d...
No issues found! (ran in 1.2s)
```
Exit code: 0.

### 7. `analysis_options.yaml` trap

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart
 M packages/jet_cad_2d_flutter/lib/src/draw_sink.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
 M packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart
 M packages/jet_cad_2d_flutter/test/draw_sink_test.dart
 M packages/jet_cad_2d_flutter/test/support/differential.dart
 M packages/jet_cad_2d_flutter/test/support/text_key_sink.dart
 M packages/jet_cad_2d_flutter/test/support/vertices_differential.dart
```
No `analysis_options.yaml` present. Nothing to `git checkout --`.

## Commit

```
git add packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test
git commit -m "feat(sink): a dash bracket, for a sink that shades rather than consumes spans" ...
```
SHA: `436a416` on `plan-c/shaded-dashes`, parent `d52d2a9`.

## Note on pre-existing untracked files

`apps/dev_harness_2d/lib/widget_arm.dart` and
`apps/dev_harness_2d/lib/widget_arm_rig.dart` were untracked in the working
tree before this task started (visible in the session's initial `git
status`) and are unrelated to this task's scope. They were not touched,
staged, or committed.

## Anything the brief got wrong

1. **"`test/draw_sink_test.dart` may not exist. Create it if not."** — it
   already existed, with 27 tests. Appended rather than created.
2. **The sealed-`DrawOp` exhaustiveness fallout was not mentioned anywhere
   in the brief or the two rulings.** Two test-support files
   (`test/support/differential.dart`, `test/support/vertices_differential.dart`)
   needed a new case each to stay compiling once `BeginDashOp`/`EndDashOp`
   existed, since `DrawOp` is `sealed` and both switches lacked a wildcard.
   This is exactly the shape of thing "the task ends green" gates for, and
   it did surface immediately once `flutter test` ran against the whole
   suite rather than just the new file — worth calling out for whichever
   later task (Task 5, most likely) starts actually constructing
   `BeginDashOp`/`EndDashOp` through a real walk, since these two switches
   will need real cases then rather than `break`.
