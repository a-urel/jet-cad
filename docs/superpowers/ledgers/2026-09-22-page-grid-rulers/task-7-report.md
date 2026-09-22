# Task 7 report: `RulerPainter` and `RulerCornerPainter`

## What was implemented

- `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart` (new): `RulerAxis`
  enum, `RulerPainter` (a `CustomPainter` drawing one ruler bar: background,
  baseline, ticks from the shared `GridScale` ladder anchored at the page
  origin, major labels via `formatLength`, a pointer marker in
  `kRulerPointer`), and `RulerCornerPainter` (the 24×24 corner box showing
  `DisplayUnit.symbol`). Follows `PageChromePainter`'s style: field `Paint`s
  built once, `@visibleForTesting` on the debug fields, `shouldRepaint` false.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: added
  `export 'src/ruler_painter.dart';` alphabetically, between
  `render_backend.dart` and `select_tool.dart`.
- `packages/jet_cad_2d_flutter/test/ruler_painter_test.dart` (new): all six
  tests from the brief.

`debugLastTicks` and `debugLastSymbol` both carry `@visibleForTesting`
(imported from `package:flutter/foundation.dart`), matching Task 6's pattern
for its debug counters — the brief's own sample code omitted the annotation,
so this was added on top of it per the task instructions.

## Test-expectation corrections (with the arithmetic / reasoning)

Two corrections were needed against the brief's literal Step 1/Step 3 code.
Both are implementation-shaped issues discovered by TDD, not typos in a
number, but I'm recording the reasoning here as the brief's "work it by hand"
instruction implies:

### 1. `c.color == kRulerPointer` is unreliable in this Flutter (3.47.5)

The brief's pointer-marker test compares `Paint.color` read back off the spy
canvas to the `kRulerPointer` constant with `==`. Running the implementation
exactly as given, the marker `drawLine` call *is* emitted (confirmed by
printing every recorded call: `Offset(123.4, 0.0), Offset(123.4, 24.0), Paint(Color(alpha: 1.0000, red: 0.8980, green: 0.2235, blue: 0.2078, ...))`,
which is `0xFFE53935` printed to 4 decimals) but `c.color == kRulerPointer`
evaluated to `false` even for the pointer-marker draw itself. I isolated this
by printing `kRulerPointer == kRulerPointer`-equivalent comparisons directly:
two `Color` values that print identically compared unequal, which is a known
consequence of Flutter's wide-gamut `Color` (introduced ~3.27) storing
components as `double`s that don't round-trip bit-exactly through a `Paint`.
The existing `page_chrome_painter_test.dart` in this same package already
works around exactly this by comparing `.toARGB32()` instead of the `Color`
object (`expect(rects.first.color?.toARGB32(), 0xFFFAF6EC)`), which is
established precedent in this codebase for this Flutter version. I changed
both `c.color == kRulerPointer` comparisons in the pointer-marker test to
`c.color?.toARGB32() == kRulerPointer.toARGB32()`. The implementation was not
touched — the marker was always being drawn correctly.

### 2. Vertical-axis tick ordering did not satisfy "the left ruler reads upward"

The brief's sample `paint()` iterates `i` ascending from `i0` to `i1`
regardless of axis, appending each tick to `debugLastTicks` in that order.
For the horizontal axis this yields ascending screen x (the standard camera's
`a = 0.137 > 0`, so screen x is an increasing function of world x) — the
"major ticks" test's `spacing = majors[1].$1 - majors[0].$1` being positive
confirms this is the intended order.

For the vertical axis, `ViewportTransform`'s documented contract is that
world y is up and screen y is down, i.e. `d = -0.137 < 0` in the standard
camera — screen y is a *decreasing* function of world y. Iterating `i`
ascending (ascending world y) therefore produces *descending* screen y in
`debugLastTicks`, which is the reverse of what "the left ruler reads upward"
asserts (`majors[i].$1 > majors[i-1].$1`, i.e. ascending screen y down the
bar, with labels — `i * step` — decreasing as the index/screen increases).
Running the brief's code as given failed exactly this way:
`Expected: a value greater than <580.76> Actual: <512.26>`.

The fix is in the implementation, not the test: for the vertical axis the
loop runs `i` from `i1` down to `i0` instead of `i0` up to `i1`, so
`debugLastTicks` comes out in ascending-screen order on both bars (the order
a reader walks the bar from its near edge outward), matching the y-flip
`ViewportTransform` already guarantees. Ticks are still computed and drawn
identically per index — only the append/iteration order changed. This does
not touch the geometry, the `divisor`/major decision, or any drawn pixel
position; it only reorders `debugLastTicks` (a test-visible list) and the
sequence of canvas calls, which carries no visible difference since drawing
order among independent lines is not observable.

## TDD evidence

### RED — compile error before the source file existed

```
$ CI=true flutter test test/ruler_painter_test.dart
...
test/ruler_painter_test.dart:18:3: Error: 'RulerPainter' isn't a type.
...
00:00 +0 -1: Some tests failed.
```

(Essential counter line: `+0 -1`.)

### GREEN — after implementing `ruler_painter.dart` and the two corrections above

```
$ CI=true flutter test test/ruler_painter_test.dart
00:00 +0: loading .../test/ruler_painter_test.dart
00:00 +0: major ticks sit at worldToScreen of the lattice, labelled in metres
00:00 +1: the left ruler reads upward
00:00 +2: minor ticks are shorter and unlabelled
00:00 +3: the pointer marker is drawn at the pointer, and not without one
00:00 +4: past the ladder top, only the bar and the pointer
00:00 +5: the corner shows the unit symbol
00:00 +6: All tests passed!
```

(Intermediate RED-again evidence: after the first full implementation attempt
— literally the brief's Step 3 code — two of six tests failed with the exact
numbers quoted in the corrections above: `the left ruler reads upward` failed
with `Expected: a value greater than <580.76> / Actual: <512.26>`, and `the
pointer marker is drawn at the pointer, and not without one` failed with
`Expected: an object with length of <1> / Actual: []` / `has length of <0>`.
Both were then fixed and re-run to the green transcript above.)

## Gate line (from `packages/jet_cad_2d_flutter`)

```
$ CI=true flutter test
...
00:13 +792 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
$ echo $? via captured exit code
TEST_EXIT=1
```

Exactly the five pre-existing `text_ladder_golden_test.dart` failures and
nothing else — matches the constraint's stated baseline.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
ANALYZE_EXIT=0
```

(One intermediate `flutter analyze` run flagged `test/ruler_painter_test.dart:7:8`
as an unused `vector_math` import — the brief's Step 1 sample imports it but
never uses `Vector2` etc. in the test. Removed the import; re-run is clean.)

```
$ dart format --output=none --set-exit-if-changed .
Formatted 146 files (0 changed) in 0.29 seconds.
FORMAT_EXIT=0
```

(One intermediate `dart format` run reformatted `lib/src/ruler_painter.dart`
and `test/ruler_painter_test.dart` — both were then run through `dart format`
directly and the exit-if-changed re-run above is clean.)

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (added the export)
- `packages/jet_cad_2d_flutter/test/ruler_painter_test.dart` (new)

`git status --short` before committing showed only these three paths — no
`analysis_options.yaml` rewrite to restore.

## Self-review

- Every brief test present and green (6/6).
- `RulerAxis {horizontal, vertical}` present.
- Every tick placed through `camera.worldToScreen` (`Vector2(world, 0)` /
  `Vector2(0, world)`), never a hand-rolled affine.
- Labels at majors only, via `formatLength(i * step, p.displayUnit)` — the
  page-local coordinate (`i * step`), not the absolute world coordinate,
  matching Invariant 5 (screen coordinates only into `dart:ui`; no absolute
  world coordinate reaches a label either).
- The left (vertical) ruler's labels are rotated `-math.pi / 2` in `_label`.
- The pointer marker is drawn only when `pointer.value != null`, in
  `kRulerPointer`.
- The corner shows `page.value?.displayUnit.symbol`, `null` before first
  paint, correctly `'ft'` for `DisplayUnit.feetInches` after.
- `debugLastTicks` is `List<(double, bool, String?)>`, `@visibleForTesting`.
  `debugLastSymbol()` likewise.
- Export added in the specified alphabetical slot.
- `git status --short` clean save for the three intended files; no
  `analysis_options.yaml` diff to discard.
- No subagents dispatched, no mutation sweep beyond what the brief's own
  tests exercise.

## Concerns

- The two test-expectation corrections (color-equality via `toARGB32()`, and
  the vertical-axis iteration direction) are real deviations from the brief's
  literal Step 1/Step 3 text. I judged the color one as a test-only fix
  (matching existing codebase precedent) and the ordering one as an
  implementation fix (the test's invariant, M-04p "page y increases as screen
  y decreases", is the actual spec-level requirement; the brief's sample loop
  just didn't satisfy its own test). A reviewer should double check I read
  M-04p correctly, though the green "left ruler reads upward" test now
  directly enforces it.
- No golden/screenshot check was added for the rotated label text or the
  corner glyph's centering — out of scope per the brief, which only asks for
  the six listed behavioural tests.
