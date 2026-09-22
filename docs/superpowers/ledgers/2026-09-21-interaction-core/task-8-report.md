# Task 8 — `SelectionOverlay` — implementation report

## What I implemented

`packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart` — `class
SelectionOverlay` (renamed to `SelectionOverlayPainter` in fix round 1), a
`CustomPainter` over the four controllers (`SelectionController`,
`ToolController`, `CameraController`, `OutlineCache`), with `super.repaint`
taking the caller's `Listenable.merge([selection, tools, camera])` and an
optional `onPaintForTest` frame counter.

`paint(canvas, size)` does exactly the brief's body:

1. `onPaintForTest?.call()`.
2. `origin = rebaseOriginFor(cam.visibleWorld(size))`.
3. Refills the reusable `Float64List(16)` with `worldToScreen ∘
   translate(origin)` — `[0] [1] [4] [5]` from `m.a..m.d`, `[12] [13]` from
   the brief's index formula; `[10]` and `[15]` are set once at construction.
4. Sets the two field `Paint`s' `strokeWidth` to `kSelectionStrokePixels /
   cam.scale` and `kHoverStrokePixels / cam.scale`.
5. `save` → `clipRect(Offset.zero & size)` → `transform(_matrix)` →
   `drawPath` per selected key from `outlines.pathFor(key, origin)` → the
   hover key, **skipped when it is already selected** → `restore`.
6. Screen space: re-strokes the same two paints at the raw pixel widths and
   draws a cross per key whose `outlines.worldPointOf(key)` is non-null —
   half-length `3 * kSelectionStrokePixels` (`3 * kHoverStrokePixels` for
   hover), centred on the camera matrix applied to the **absolute** world
   point (the cross pass runs after `restore()`, so it must not use the
   rebased matrix). Only the derived screen coordinates reach `dart:ui`.
7. `tools.active.paintOverlay(canvas, cam, size)`.

`shouldRepaint(old) => false`.

No `Paint`, `Path` or matrix is allocated per frame or per key. `Offset`s for
the cross arms are allocated only for keys that actually are lone points.

`packages/jet_cad_2d_flutter/test/selection_overlay_test.dart` — the brief's
six tests, plus the ledger's point-cross test, plus one for `shouldRepaint`
(see departures). A `Rig` helper wires everything in the ledger's order:
`SelectionController` **before** `OutlineCache`, so the controller prunes
before the cache walks.

## Departures

Three, all local and obvious:

1. **`import 'package:flutter/widgets.dart' hide SelectionOverlay;` in the
   test.** Flutter's own `SelectionOverlay` (text selection) is exported from
   `widgets.dart` and collides with ours. The lib file avoids the collision by
   importing `package:flutter/rendering.dart show CustomPainter` instead.
   **Superseded in fix round 1**: the class is now `SelectionOverlayPainter`
   and the `hide` is gone.
2. **Colour assertions compare `Color.toARGB32()`, not `Color`.** Direct
   `Color` equality failed with expected and actual printing *identically*
   (`Color(alpha: 1.0000, red: 0.1176, green: 0.4353, blue: 0.9098,
   colorSpace: ColorSpace.sRGB)` on both sides) — a float-component /
   colour-space equality artefact of this Flutter version, not a defect in the
   painter. The packed-ARGB comparison asserts the same thing without it.
3. **One extra test, `'shouldRepaint is false'`.** The brief's six tests all
   survive the mutation `shouldRepaint => true`, which is a real defect (it
   repaints the overlay on every ancestor rebuild — the cost the second
   `RepaintBoundary` exists to avoid). One line, and mutation 8 below kills
   it.

Also: `flutter analyze` flagged the test's `dart:ui` import as redundant once
`widgets.dart` was imported; removed.

## TDD evidence

### RED — the tests before the painter existed

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart
00:00 +0: loading .../test/selection_overlay_test.dart
test/selection_overlay_test.dart:15:8: Error: Error when reading 'lib/src/selection_overlay.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
       ^
test/selection_overlay_test.dart:54:3: Error: Type 'SelectionOverlay' not found.
```

(An earlier run of the same file, before `hide SelectionOverlay` was added,
resolved the name to Flutter's own text-selection `SelectionOverlay` and
failed with `The method 'paint' isn't defined for the type 'SelectionOverlay'
- 'SelectionOverlay' is from 'package:flutter/src/widgets/text_selection.dart'`
on every direct-paint test. That is what put the `hide` in.)

### GREEN — after implementing

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart
00:00 +0: a selection change repaints the overlay and not the canvas
00:00 +1: stroke width is 2 px at any zoom
00:00 +2: the two Paints are reused across frames
00:00 +3: hover on a selected key draws once
00:00 +4: the outline coincides with the drawn line at 4.5e6
00:00 +5: the tool's band is painted after the outlines, in screen space
00:00 +6: a selected point draws a screen-space cross on its position
00:00 +7: shouldRepaint is false
00:00 +8: All tests passed!
```

### Mutation sweep — eight mutations, eight kills, one test each

Each mutation was applied to `lib/src/selection_overlay.dart`, the file was
run, and the file was restored from a scratchpad copy before the next one.
Each line below is the `Failing tests:` name the run printed.

| # | Mutation | Test that went red |
|---|---|---|
| 1 | `_selected.strokeWidth = kSelectionStrokePixels` (no `/ scale`) | `stroke width is 2 px at any zoom` |
| 2 | `canvas.drawPath(path, Paint()..color = kSelectionColor..style = stroke..strokeWidth = _selected.strokeWidth)` — a per-frame `Paint` | `the two Paints are reused across frames` |
| 3 | `hoverOnly = hover` — the `!selection.contains(hover)` guard dropped | `hover on a selected key draws once` |
| 4 | `_matrix[12] = m.e` — the rebase origin dropped from the matrix | `the outline coincides with the drawn line at 4.5e6` |
| 5 | `tools.active.paintOverlay(...)` moved above `canvas.restore()` | `the tool's band is painted after the outlines, in screen space` |
| 6 | the cross's x taken from `_matrix` (rebased) instead of the camera matrix — i.e. rebased twice | `a selected point draws a screen-space cross on its position` |
| 7 | `Object? repaint` in place of `super.repaint` — the merge never wired | `a selection change repaints the overlay and not the canvas` |
| 8 | `shouldRepaint(...) => true` | `shouldRepaint is false` |

Every run reported exactly one failing test — no mutation killed two, so no
test in the file is a duplicate of another.

## Gate line

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**`CI=true flutter test`** — `00:10 +752 ~1 -5: Some tests failed.`, exit code
non-zero, failing on exactly the five pre-existing `text_ladder_golden_test.dart`
goldens and nothing else:

```
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

752 passed, 1 skipped, 5 failed — the five known goldens.

**`flutter analyze`**

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
ANALYZE_EXIT=0
```

**`dart format --output=none --set-exit-if-changed .`**

```
Formatted 134 files (0 changed) in 0.25 seconds.
FORMAT_EXIT=0
```

## Allocation invariant

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=62ms
00:00 +3: All tests passed!
ALLOC_EXIT=0
```

## Trailer check

```
$ git log -1 --format=%B | grep -c "Fable 5.1"
1
```

Commit: `feat(overlay): SelectionOverlay over the rebased cache`.

`git status --short` before the commit listed only the two new files — no
`analysis_options.yaml` was rewritten by the `flutter pub get` that each
`flutter test` / `flutter analyze` ran.

## Files changed

- **Created** `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`
- **Created** `packages/jet_cad_2d_flutter/test/selection_overlay_test.dart`

Nothing else was touched. The painter is deliberately **not** added to
`lib/jet_cad_2d_flutter.dart`'s export barrel — `selection.dart`, `tool.dart`,
`select_tool.dart`, `outline_cache.dart` and `selection_style.dart` are all
unexported too, and Task 10's view is what decides the plan's public surface.

## Self-review

- **Fixtures are off the identity and off the origin.** Every direct-paint
  test uses a camera at scale 2, 3 or 4 with a non-zero translation (the
  cross test also carries `kPlacement`'s translate-rotate-scale on the owning
  group, and asserts the cross does *not* land on the untransformed point via
  `worldPointOf`). The criterion-14 test sits at `kDefaultOriginX` and asserts
  the path's own bounds stay below `kDefaultOriginX / 2` — so the rebase is
  load-bearing rather than incidental.
- **`Canvas` paint mutation after the fact is safe.** The screen-space pass
  re-strokes `_selected` and `_hover` after `restore()`. `Canvas` serialises a
  paint at call time, so the world-space `drawPath`s already carry their own
  divided widths; `SpyCanvas` snapshots `strokeWidth` into `RecordedCall` for
  the same reason, and the M-02m test reads that snapshot at `2 / 4 = 0.5`.
- **The hover guard is computed once** into `hoverOnly` and reused by both the
  path pass and the cross pass, so the two cannot drift apart.
- **Construction order** is fixed in the test `Rig` itself
  (`SelectionController` before `OutlineCache`), not left to each test.
- **`DraftCanvas` in the widget test** gets a `FlutterTextMeasurer`-backed
  document, and the test asserts `tester.getSize(...) == Size(400, 300)` on
  the overlay's own `CustomPaint` before it asserts anything about paints —
  01's zero-size trap. No `pumpWidget` happens between the
  `selection.replace` and the counter assertions; only `pump()`.

## Concerns

1. **`worldPointOf` allocates a `Vector2` per *point* key per frame.** It is
   the affordance the ledger's ruling names, and it returns `null` without
   allocating for everything else, so an ordinary selection of lines, arcs,
   text and groups stays allocation-free. A selection of many point entities
   would allocate one `Vector2` per point per frame. If that matters,
   `OutlineCache` would need an out-parameter overload (`bool
   worldPointInto(key, Vector2 out)`); that is a cache-side change and outside
   this task.
2. **`clipRect` is not tested.** No brief test pins it, and I did not invent
   one — a clip assertion over a `SpyCanvas` would only restate the source.
3. **The painter is not yet mounted anywhere in the app**; Task 10's view is
   what builds the `Listenable.merge` and the `Stack`. Until then the only
   caller is the test.
4. The five `text_ladder_golden_test.dart` failures are pre-existing and
   untouched by this task.

---

# Fix round 1

All of R, 1, 2, 3 and minors (a), (b), (c) applied. The other tests are
unchanged except for the rename.

## What changed

### R — `SelectionOverlay` → `SelectionOverlayPainter`

`lib/src/selection_overlay.dart` (file name unchanged): the class, the
`shouldRepaint` parameter type and the `covariant` are renamed, and a new
paragraph at the top of the class doc records *why* the spec's name is not
used — Flutter's own `SelectionOverlay` (text selection) is exported from
`package:flutter/widgets.dart`, so an app importing Material plus this
package's barrel would have to `hide` one of them at every consumer. The
test's `hide SelectionOverlay` is gone; the import is a plain
`import 'package:flutter/widgets.dart';` again. Departure 1 above is marked
superseded.

### 1 — zero-size guard

`if (size.isEmpty) return;` immediately after `onPaintForTest?.call()`, with a
comment naming the chain it breaks: `visibleWorld(Size.zero)` collapses to a
point → `rebaseOriginFor` answers `Vector2.zero()` → `pathFor(key, zero)`
rebuilds **every** cached path in absolute world space and hands x ≈ 4.5e6 to
float32 `ui.Path` → the next real frame has to rebuild them all again.

The counter is placed *before* the guard deliberately: a frame the painter
declined is still a frame the criterion-6 counting sees, and moving it below
would make `onPaintForTest` mean two different things depending on layout.

### 2 — the screen-space pass is clipped

A second `save` / `clipRect(Offset.zero & size)` / … / `restore` bracket
around the point crosses **and** `tools.active.paintOverlay`, rather than one
bracket over the whole method. Two reasons for the second form: the rebased
pass still needs its own `transform` popped before the crosses are drawn, and
the recorded call sequence stays `save, clipRect, transform, drawPath…,
restore, save, clipRect, drawLine…, drawRect…, restore` — so a clip is
provably in effect at the moment the cross is drawn, with no `restore`
between, which is what the finding asked to be able to assert.

### 3 — a rotated, non-uniform camera fixture

New sibling test `'the outline coincides under a rotated, non-uniform
camera'`. The camera is
`Transform2.translation(tx, ty).multiply(Transform2.rotation(0.3)).multiply(Transform2.scale(s, -2.4 * s))`
with `s = 1.5`, and `tx, ty` solved so the line's midpoint lands at the centre
of the 400×300 viewport (otherwise the rebase origin would not sit beside the
geometry the way it does in a real frame, and the float32 residual would eat
the 0.01 px tolerance).

**A uniform mirror-scale would have made this fixture useless**, and the test
says so and asserts it. `R · diag(s, -s)` is *symmetric* — it works out to
`[[s cos, s sin], [s sin, -s cos]]`, i.e. `b == c` — so a transposed matrix
paints identically under it. My first attempt used `scale(s, -1.6 * s)` and
the test's own guard caught that the asymmetry was thin:

```
00:00 +5 -1: the outline coincides under a rotated, non-uniform camera [E]
  Expected: a value greater than <0.5>
    Actual: <0.2659681859952058>
     Which: is not a value greater than <0.5>
  the fixture is worthless unless the off-diagonal entries differ...
```

`-2.4 * s` fixes it. The test keeps that guard (`|b - c| > 0.5`) plus
`m[1] != 0` and `m[4] != 0` on the recorded matrix, so the fixture cannot
silently decay back to axis-aligned.

On the bounds question the finding raised: the comparison stays a
point-to-point one and needs no `computeMetrics`, because the rotation lives
in `m`, not in the path. In **rebased** space the segment is still horizontal
— the test asserts `bounds.height ≈ 0` to pin that — so the bounds rect's two
ends *are* the two endpoints, and mapping `(left, top)` and `(right, top)`
through `m` yields exactly the two screen endpoints.

### Minors

- **(a)** `expect(canvasBefore, greaterThan(0))` in the criterion-6 test — a
  canvas that never painted would otherwise satisfy the "unchanged"
  assertion for the wrong reason.
- **(b)** the recorded matrix is copied at the read, in a shared
  `matrixOf(spy)` helper whose doc comment says why: the spy records the
  argument by reference and the painter refills that same `Float64List` next
  frame.
- **(c)** both criterion-14 tests put the line at `kDefaultOriginX + 10.37`,
  and `lessThan(kDefaultOriginX / 2)` is now `lessThan(1e4)`.

## Covering tests

| Finding | Test |
|---|---|
| R | the whole file compiles against `SelectionOverlayPainter` with no `hide` |
| 1 | `a zero-size paint draws nothing and leaves the cache rebased` |
| 2 | `the screen-space pass is clipped to the viewport` |
| 3 | `the outline coincides under a rotated, non-uniform camera` |
| (a) | `a selection change repaints the overlay and not the canvas` |
| (b) | `matrixOf` helper, used by both criterion-14 tests |
| (c) | `the outline coincides with the drawn line at 4.5e6` |

## Mutations — the RED for the three new tests

Each was applied to `lib/src/selection_overlay.dart`, run, and reverted. Each
run printed exactly one failing test, which is the pre-fix behaviour of the
code the finding describes.

**Mutation 9 — transpose (`_matrix[1] = m.c; _matrix[4] = m.b;`)** — the
mutation finding 3 asked for:

```
00:00 +9 -1: shouldRepaint is false
00:00 +10 -1: Some tests failed.

Failing tests:
  .../test/selection_overlay_test.dart: the outline coincides under a rotated, non-uniform camera
```

Only the new rotated test dies. The original criterion-14 test passes under
the transpose, which is precisely the gap finding 3 named.

**Mutation 10 — the zero-size guard removed** (i.e. the code as reviewed):

```
Failing tests:
  .../test/selection_overlay_test.dart: a zero-size paint draws nothing and leaves the cache rebased
```

**Mutation 11 — the second `save`/`clipRect`/`restore` removed** (i.e. the
code as reviewed):

```
Failing tests:
  .../test/selection_overlay_test.dart: the screen-space pass is clipped to the viewport
```

The eight mutations from the first round were not re-run individually; the
paint body's other branches are untouched by this round apart from the clip
bracket, and all eleven tests pass together below.

## Commands and output

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart
00:00 +0: a selection change repaints the overlay and not the canvas
00:00 +1: stroke width is 2 px at any zoom
00:00 +2: the two Paints are reused across frames
00:00 +3: hover on a selected key draws once
00:00 +4: the outline coincides with the drawn line at 4.5e6
00:00 +5: the outline coincides under a rotated, non-uniform camera
00:00 +6: the tool's band is painted after the outlines, in screen space
00:00 +7: a selected point draws a screen-space cross on its position
00:00 +8: the screen-space pass is clipped to the viewport
00:00 +9: a zero-size paint draws nothing and leaves the cache rebased
00:00 +10: shouldRepaint is false
00:00 +11: All tests passed!
```

### Gate line

**`CI=true flutter test`** — `00:10 +755 ~1 -5: Some tests failed.`, exit code
non-zero, on exactly the five pre-existing goldens (755 passed, 1 skipped,
5 failed — three more passing than round 1's 752, the three new tests):

```
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

**`flutter analyze`**

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
ANALYZE_EXIT=0
```

**`dart format --output=none --set-exit-if-changed .`**

```
Formatted 134 files (0 changed) in 0.26 seconds.
FORMAT_EXIT=0
```

### Allocation invariant

```
$ CI=true flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=67ms
00:00 +3: All tests passed!
ALLOC_EXIT=0
```

`git status --short` before the commit listed only the two modified files —
no `analysis_options.yaml` was rewritten.

## Files changed in this round

- `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart` (modified)
- `packages/jet_cad_2d_flutter/test/selection_overlay_test.dart` (modified)

## Concerns after this round

1. **The second `clipRect` costs a save layer's worth of bookkeeping per
   frame even when nothing off-screen is drawn.** It is a rect clip, not a
   layer, so the cost is small — but if a later profile says otherwise, the
   cheaper form is to skip the whole screen-space bracket when no selected
   key is a point and `tools.active.phase == ToolPhase.idle`. I did not add
   that condition: it is an optimisation with two ways to go stale, and
   nothing has measured it.
2. **`tools.active.paintOverlay` is now clipped**, which is a behaviour
   change for `SelectTool`: a band dragged past the viewport edge is cut at
   the edge rather than drawn beyond it. That is the intent of finding 2 and
   matches what the band means, but it is worth a line in the ledger in case
   a later tool wants to paint outside the overlay's bounds deliberately.
3. The `worldPointOf` per-point-key `Vector2` from round 1 stands unchanged.
