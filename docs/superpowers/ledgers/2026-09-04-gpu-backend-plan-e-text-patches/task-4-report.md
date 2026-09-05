# Task 4 report: the compositor, and the region arithmetic it draws by

BASE: e16b5ba. Branch: plan-e/text-patches. Commit created: 18ba40d.

## What was implemented

1. **`lib/src/gpu/text_patches.dart`** (Step 2): added `PatchRegion`,
   `patchRegionFor`, `patchTargetSizeFor` exactly as the brief specifies,
   **except** the region arithmetic's four-corner bound is delegated to
   `boundTransformedBox` (Ruling P2) instead of the brief's inline `corner(...)`
   closure — the brief's own amending note requires this. `patchRegionFor`
   allocates a local `Float64List(4)` scratch per call (the task note's
   explicit choice over a module-level scratch or an owner-supplied one).
   Updated `boundTransformedBox`'s doc comment to name its now-real callers
   (the collector's `text()`, `patchRegionFor`, and `text_compositor.dart`'s
   `labelBoundsLogical`) instead of the old "arrives in Task 4" placeholder.

2. **`lib/src/gpu/text_compositor.dart`** (new, Step 4): `PatchImage`,
   `labelBoundsLogical`, `TextCompositor` (fields `measurer`, `textStyleOf`,
   reused `_matrix`/`_imagePaint`/`_patchPaint`/`_layerPaint`,
   `patchesComposited` diagnostic counter, `paint()`, private `_drawLabel`
   helper). Same deviation as above: `labelBoundsLogical` calls
   `boundTransformedBox` with its own local `Float64List(4)` scratch rather
   than reimplementing the four-corner loop a third time. Everything else —
   the `paint()` walk (main image, then labels in list order with a
   single patch cursor matched by `textIndex`, `saveLayer` outside
   `_drawLabel` per the revision-5 Copilot-review note in the brief), and
   the hand-composed `outer ∘ residual` matrix in `_drawLabel` — is the
   brief's code verbatim.

3. **`lib/jet_cad_2d_flutter.dart`**: added
   `export 'src/gpu/text_compositor.dart';`.

4. **Tests**: appended the brief's `patchRegionFor`/`patchTargetSizeFor`
   groups to `test/gpu/text_patches_test.dart` verbatim (the file's existing
   `_label` helper already matched the brief's calling convention). Created
   `test/gpu/text_compositor_test.dart` with the brief's six tests plus the
   task's mandated seventh: `SpyCanvas`-recorded proof that the matrix
   reaching `Canvas.transform` equals `outer.multiply(Transform2(t.a, t.b,
   t.c, t.d, t.e, t.f))`, read the same way
   `canvas_draw_sink_test.dart:_transformBeforeDraw` reads it.

## A compile bug in the brief's Step 3 test code, fixed

The brief's test file used `const Size(_w.toDouble(), _h.toDouble())` at
seven call sites and `const ResidentTextRecord(..., boxMaxX: _w.toDouble(),
...)` once — `int.toDouble()` is not a compile-time constant expression in
Dart, so this fails to compile ("Method invocation is not a constant
expression"). Fixed by dropping `const` at all eight sites (the `Handle(11)`
inside `_label` keeps its own `const`, since that one *is* a literal). No
other change to the brief's test logic.

## TDD evidence

**RED (region/size tests), before Step 2's implementation** — appended the
tests to `text_patches_test.dart`, ran against the pre-existing
`text_patches.dart`:

```
test/gpu/text_patches_test.dart:255:17: Error: Method not found: 'patchRegionFor'.
...
test/gpu/text_patches_test.dart:298:14: Error: Method not found: 'patchTargetSizeFor'.
...
00:00 +0 -1: Some tests failed.
```

**GREEN (region/size tests), after Step 2**:

```
$ flutter test test/gpu/text_patches_test.dart
...
00:00 +18: patchTargetSizeFor is clamped to the viewport
00:00 +19: All tests passed!
```
(19 tests: 11 pre-existing `classifyTextPatches` tests + 8 new region/size
tests, all passing.)

**RED (compositor tests), before Step 4's implementation** — created
`text_compositor_test.dart` against the pre-existing package (no
`text_compositor.dart`, no barrel export):

```
test/gpu/text_compositor_test.dart:34:5: Error: The method 'TextCompositor' isn't defined
...
test/gpu/text_compositor_test.dart:107:11: Error: Method not found: 'PatchImage'.
...
test/gpu/text_compositor_test.dart:210:15: Error: Method not found: 'labelBoundsLogical'.
...
00:00 +0 -1: Some tests failed.
```
(Full transcript also showed the `const Size(_w.toDouble(), ...)` compile
errors described above, before that fix was applied.)

**GREEN (compositor tests), after Step 4 + the fix above**:

```
$ flutter test test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart
...
00:00 +6: labelBoundsLogical is the four corners under the outer transform
00:00 +7: the composed matrix is outer.multiply(residual), applied once
...
00:00 +25: patchTargetSizeFor is clamped to the viewport
00:00 +26: All tests passed!
```
(26 tests: 7 compositor + 19 text_patches, all passing.)

## Gate commands and output

```
$ flutter test
...
00:07 +607 ~1: All tests passed!
```
(607 passed, 1 skipped — the skip is pre-existing and unrelated to this
task; exit 0.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```
(exit 0.)

```
$ dart format --output=none --set-exit-if-changed .
Formatted 98 files (0 changed) in 0.15 seconds.
```
(exit 0 — reached only after running `dart format .` once, which reformatted
the three touched files: the wrapped `_image((c) => ...)` calls in the test
file needed reflowing, and one line in `text_compositor.dart` was over the
line-length limit. Re-ran `--set-exit-if-changed` after, confirmed 0
changed / exit 0.)

## Files changed (commit 18ba40d)

- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (+1)
- `packages/jet_cad_2d_flutter/lib/src/gpu/text_compositor.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart` (+`PatchRegion`,
  `patchRegionFor`, `patchTargetSizeFor`; doc comment updated)
- `packages/jet_cad_2d_flutter/test/gpu/text_compositor_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/gpu/text_patches_test.dart` (+2 groups,
  8 tests)

`analysis_options.yaml` was not modified (`flutter pub get` ran during
`flutter test`/`flutter analyze` but did not touch it in this workspace on
this run); `git status --short` before staging showed no such file, and none
was staged or committed.

## Self-review findings (fixed before commit)

- **Ruling P2 violation in my first draft.** I initially transcribed the
  brief's Step 4 `labelBoundsLogical` verbatim, which — like the brief's own
  Step 2 snippet — writes the four-corner bound loop inline via a local
  `corner(...)` closure. The task's amending note is explicit that this is
  wrong: `boundTransformedBox` is the ONE place that loop exists, and both
  `patchRegionFor` and `labelBoundsLogical` must call it. Caught on
  self-review before running the gate a second time; fixed by replacing the
  closure with a call to `boundTransformedBox` plus a local `Float64List(4)`
  scratch (mirroring what I'd already done correctly for `patchRegionFor`),
  and adding `import 'text_patches.dart' show boundTransformedBox;`. Re-ran
  the full test file, `flutter analyze`, and `dart format` after the fix —
  all green (see the GREEN transcript above, which is post-fix).
- Checked the hand-composed matrix in `_drawLabel` term-by-term against
  `Transform2.multiply` (`transform2.dart:62-69`) before committing, per the
  brief's explicit instruction — it matches
  `o.multiply(Transform2(t.a, t.b, t.c, t.d, t.e, t.f))` exactly, and the
  added `SpyCanvas` test now asserts that independently at runtime rather
  than by inspection alone.
- Confirmed `saveLayer` is opened with `patch.layerBounds` — a logical-pixel
  `Rect` in the OUTER frame — before `_drawLabel` applies the label's own
  residual, matching the brief's note about the revision-5 Copilot-review
  finding (a layer opened after the residual double-transforms).
- Confirmed draw order: `paint()` walks `texts` in list order with a single
  monotonic patch cursor matched by `textIndex`, never by position — the
  "labels and patches walk in list order, with one cursor" test exercises
  exactly this by patching only the second of two labels.
- Confirmed no `Transform2` object is constructed inside the per-label
  `_drawLabel` hot path — the composition is six scalar multiplies into the
  reused `_matrix`, matching invariant 1.

## Concerns

None. The one deviation from the brief's literal Step 3/4 code (the `const`
fix, and honoring Ruling P2 over the brief's Step 4 snippet) is required by
the task's own amending notes or by a genuine Dart compile error, not a
judgment call against the brief's intent.
