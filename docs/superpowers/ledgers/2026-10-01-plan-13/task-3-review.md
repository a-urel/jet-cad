# Task 3 review: PdfDrawSink geometry and the content reader (spec D3 without text, T-3, T-3b)

**Scope**
- Reviewer: independent.
- Commits: `ff0d853` (the Task 2 follow-ups) and `babfcc1` (`PdfDrawSink`, the reader and the tests). The range is `64bb01c..babfcc1`.
- Reviewed in the detached worktree `.claude/worktrees/plan-13-review`, at `babfcc1`.
- I ran a workspace `flutter pub get` there because the package config had no `pdf`. It rewrote `packages/jet_cad/analysis_options.yaml`, which was left unstaged.
- Nothing was committed or staged. At the end, `git diff --cached` was empty and `git status --short` showed only that `analysis_options.yaml`.

**How mutants were run**
- The runner is `scratchpad/r3/mut.py`. It copies the file to `scratchpad/r3/`, makes one exact-string replacement (aborting unless the match count is the expected one), and runs the named test file in the foreground.
- It then copies the file back and diffs it. Every run printed `RESTORED diff=0`.
- I wrote two temporary tests, `test/zz_review_tmp_test.dart` and `test/zz_review_tmp2_test.dart`. Copies are kept in `scratchpad/r3/`, and both were deleted from the tree.

## 1. `ff0d853` closes Task 2 review findings 1, 2 and 4

**Finding 1**
- The new test "with a definition omitted (the container route) the painter does not report a skipped container leaf to debugOnVisit" asserts:
  - `instanceLine`, `instancePolyline` and `pointInInstance` are not visited;
  - `f.instance` and `outerInstanceLeaf` are visited.
- Re-fired R-visit-cont (`draft_painter.dart:482-483`, `debugOnVisit` moved before the skip):
  ```
  RED: with a definition omitted (the container route) the painter does not report a skipped container leaf to debugOnVisit [E]
  Expected: not contains <30>
  SUMMARY: 00:00 +18 -1: Some tests failed.   RESTORED diff=0
  ```

**Finding 2**
- A new group adds an ATTRIB under the instance and omits `{a.instance}`.
- Re-fired R-attrib (`reference_walk.dart:110`, `_ownLeaves(child)` → `leaves[child] ?? const <int>[]`):
  ```
  RED: with an instance omitted (its attribute) the painter and the reference draw the same drawing [E]
  RED: with an instance omitted (its attribute) the reference drops the attribute and keeps the definition's leaves [E]
  Expected: <18>  Actual: <17>  /  Expected: not contains <43>
  SUMMARY: 00:00 +17 -2: Some tests failed.   RESTORED diff=0
  ```
- The group also includes a default-set case, in which both routes draw the attribute. So the group is not vacuous.

**Finding 4**
- The comment at `test/support/differential.dart:137` is reworded correctly.

**Result:** all three findings are closed.

## 2. `PdfDrawSink` against D3, point by point (`lib/src/export/pdf_draw_sink.dart`)

| D3 point | Verdict |
|---|---|
| Page set-up | **Correct.**<br>- At construction (`:47-51`) it writes `cm [1 0 0 -1 0 H]`, `0 J`, `0 j`, `4 M`, once and outside any `q`.<br>- Every `q` comes after it, so a `Q` never loses J/j/M.<br>- `_set` (`:122-130`) puts a, b, c, d, e, f at Matrix4 storage indices 0, 1, 4, 5, 12, 13. That is exactly what `PdfGraphics.setTransform` reads (pdf 3.13.1 `graphics.dart:825-833`). |
| Deferred residual | **Correct.**<br>- `beginResidual` only records the residual.<br>- `_pushTransform` writes `q` and `cm` on the first primitive; `endResidual` writes `Q` only if it pushed.<br>- A nested begin first pops the open `q`, a defensive choice that keeps `q`/`Q` balanced.<br>- Outside a residual nothing is pushed. The painter never draws there (see 6b). |
| Width | **Identical to `CanvasDrawSink._widthFor`** (`canvas_draw_sink.dart:263-270`) except for the measurement-only `lineweightScale` (1.0).<br>- The formula is `lw/100·u`, divided by `scaleMagnitude` = `sqrt(|det|)`.<br>- Residual scale 0 falls back to the device width, which is finite.<br>- A NaN or ∞ result becomes `0`, so `PdfNum`'s `!isNaN` and `!isInfinite` asserts are never reached from the width.<br>- `0 w` is written as `0`: `toStringAsFixed`, then trimmed. |
| Arc | **Correct.**<br>- The sweep is signed.<br>- n = `ceil(|s|/(π/2) − 1e-9)`, at least 1, so each cubic covers at most 90°, and an exact quarter turn is one cubic.<br>- θ = s/n and k = `4/3·tan(θ/4)`, signed.<br>- The controls are `P0 + k·r·(−sin a0, cos a0)` and `P3 − k·r·(−sin a1, cos a1)`. That is the standard construction, and it is right for either sign.<br>- Angles are those of the local frame, `centre + r(cos, sin)`, which is `Canvas.drawArc`'s convention in the same frame.<br>- A zero or NaN sweep draws nothing; Skia draws nothing for a butt-capped zero sweep.<br>- `|sweep| > 2π` is clamped to a full turn, as Skia does.<br>- I checked this independently under a rotated, mirrored, anisotropic `cm` with a temporary test (§3, finding 1). The polyline vertices and the −110° arc's ends and mid-points land on `residual(centre + r(cos, sin))`. |
| Circle | Four 90° cubics from angle 0 with the quadrant handle, closed with `h`. |
| Fills | `fillPolygon`: `m l… h f`. `fillCircle`: four cubics, `h`, `f`. Both are non-zero (`f`, not `f*`). |
| Point | **Matches `CanvasDrawSink.point` (`:140-152`).**<br>- Same residual-by-hand formula, same `_widthFor(lw, 1.0)` side, centred square, never under `cm`.<br>- At lineweight 0 the PDF sink returns early. Canvas draws a zero-area rect, which Skia does not paint, so the result is the same.<br>- The PDF sink also pops an open `cm` before the point (`:140`). Canvas does not, which is a latent difference noted in 6b. |
| Full state per primitive | **Correct.**<br>- Strokes write `RG`, `w` and `gs`; fills and points write `rg` and `gs`.<br>- There is no cache, and `gs` is written at alpha 255. `PdfGraphicState(opacity:)` sets both CA and ca.<br>- The package deduplicates equal states as `/aN` entries in one `ExtGState` dictionary. That is report item 2, accepted. |
| Dashes and text | `shadesDashes` is false; `beginDash` and `endDash` throw `UnsupportedError`; `text` throws `UnimplementedError`. |

**Numeric edge cases**
- A residual of scale 0 gives a finite width.
- A NaN residual scale gives `0 w`.
- A zero or NaN sweep is a no-op, and `|sweep| > 2π` is clamped.
- `count <= 0` and `count < 3` (fills) return early.
- Not guarded, as on Canvas: NaN in the coordinates or in the residual entries themselves. That would trip `PdfNum`'s debug assert, or write `NaN` in release. It is upstream of the sink and not reachable from the painter today.

## 3. The reader (P-2), `lib/src/export/testing/pdf_content.dart`

**What is honest**
- `cm` builds `M.times(ctm)` (`:775-777`). `times` is the row-vector product, so the new CTM = cm × CTM, which is PDF order.
- `q` pushes a full copy and `Q` restores it whole.
- Hex strings are read, including whitespace inside them.
- FlateDecode goes through the callback, and any other filter throws.
- Text: `Td` premultiplies the line matrix; the advance is `(w/1000 − TJ/1000)·Tfs·Th`, with Tc and Tw rejected; the next run starts at `[1 0 0 1 adv 0] × Tm`.
- Strictness: unmodelled geometry operators throw.
- `lib/export_testing.dart` is the only file that names it: `grep -rn "export_testing\|testing/pdf_content" packages/jet_cad_2d_flutter/lib apps/*/lib` hits only `lib/export_testing.dart:8`.
- T-3's expected points are computed from `Transform2.transformPoint` and `H − y`, never through the reader's matrix code.

**Reader mutants** (test file `test/export/pdf_content_test.dart`)

| id | mutation | result |
|---|---|---|
| RD-cm | `cm` post-multiplies (`_state.ctm.times(M)`) | RED "cm premultiplies the CTM…": `Actual: [[220.0, 20.0], [240.0, 20.0]]`, `00:00 +18 -1` |
| RD-Q | `Q` restores only the CTM | RED "Q restores colour, width and the ExtGState alpha…": `Expected: [1, 0, 0] Actual: [0.0, 0.0, 1.0]`, `00:00 +18 -1` |
| RD-flate | FlateDecode returns the raw bytes | RED "a FlateDecode content stream is inflated…": `Expected: <1> Actual: <0>`, `00:00 +18 -1` |
| RD-transpose (mine) | `apply` uses `a·x + b·y + e, c·x + d·y + f` | **survives**: `00:00 +19: All tests passed!`. It also survives `pdf_draw_sink_test.dart`: `00:00 +15: All tests passed!` |
| RD-signed-scale (mine) | `scale => sqrt(determinant)` (no `abs`) | **survives the reader's own tests** (`+19`). It is caught by the sink test only (`Actual: <NaN>`, `+13 -2`). The test named "…mirrored or not (a reader that reports … a signed scale)" uses `0 -3 3 0 cm`, whose determinant is +9: it is not mirrored. |
| RD-hex-odd (mine) | odd hex digit padded at the front | survives (`+19`). No test has an odd-length hex string. The package never writes one, so this is info only. |

**Can a reader bug and a sink bug cancel?**
- RD-transpose survives **every** test, so a reader with a transposed matrix convention makes every sink test pass. That is exactly what P-2 says must not happen. See finding 1 for why T-3 cannot see it.

## 4. The tolerance helper (`test/support/pdf_tolerance.dart`)

**Derivation**
- It follows spec T-3 literally:
  - screen space: `2·5e-6`;
  - under a residual: `5e-6·(|x|+|y|+1)` for the matrix entries, plus `5e-6·max(|a|+|c|, |b|+|d|)` for the operands, plus `5e-6` for `H`.
- The width bound is the first-order error of `w̃·sqrt|det|`. I checked that derivation and it is right.
- `PdfNum` is `toStringAsFixed(5)` (`num.dart:26-38`), so 5e-6 per number is exact.
- It is not loosened beyond the spec.

**The 1e-3 pt shift**

| mutant | mutation | result |
|---|---|---|
| OWN-1 | `H + 1e-3` in the page set-up | RED: page set-up, polylines (`Expected: <= 0.000952889… Actual: 0.000996…`), both point tests. `00:00 +11 -4` |
| OWN-2 | every polyline vertex `x + 1e-3` | RED: polylines, `Expected: <= 0.0009528893275590556 Actual: <0.0009996850392894885>`. `00:00 +14 -1` |
| OWN-3 | first vertex of every polyline and fill `x + 5e-4` | **survives**, `00:00 +15: All tests passed!` |

- OWN-2 is red, but with a 5 % margin.
- **Why it is so tight:** every T-3 polyline and fill is under a pure-translation residual. The formula still charges each matrix entry 5e-6·|x|, although `1` and `0` are written exactly. The real worst case there is about 1.5e-5 pt; the bound is about 9.5e-4 to 1.3e-3 pt, roughly 60× looser.
- This is finding 2. It is spec-conformant, but there is a cheap way to tighten it that is still derived.

## 5. Mutants fired (sink: `lib/src/export/pdf_draw_sink.dart`; test file `test/export/pdf_draw_sink_test.dart`)

| id | mutation | result (real lines) |
|---|---|---|
| M-13h | page set-up `setTransform` line deleted | RED: set-up, polylines, circle, arc, T-3 point, T-3b point (`Expected: 'cm' Actual: 'J'`; `Actual: <368.50…>`). `00:00 +9 -6` |
| M-13i | `_pushTransform` never pushes (`\|\| true`) | RED: polylines, circle, arc, after-Q. `00:00 +11 -4` |
| M-13b (sink) | `device = lw / 100.0` | RED ×6, `Expected: … within <0.0000099…> of <0.99212…> Actual: <0.35>`. `00:00 +9 -6` |
| M-13j | `theta = s.abs() / n` | RED: the −110° arc, `Actual: <49.806…>` vs bound 0.0559. `00:00 +14 -1` |
| M-13k | `if (closed && false)` | RED: T-3b `h` before `S`, `Expected: 'h' Actual: 'l'`. `00:00 +14 -1` |
| M-13y | `gs` only when opacity < 1 | RED: opaque after fill (`Actual: [0.50196, 0.50196]`) and after-Q (`no match for 'gs'`). `00:00 +13 -2` |
| M-13z | stroke-state cache (`_lastStroke`) | RED: T-3 polylines (`Actual: <0.0>` red channel), after-Q (`no match for 'RG'`). `00:00 +13 -2` |
| M-13ad | point: `_pushTransform(); sx = x; sy = y;` | RED: T-3b rotated point only, `Actual: <1.190550000001167>`. `00:00 +14 -1` |
| OWN-5 (mine) | residual written transposed, `_set(r.a, r.c, r.b, r.d, …)` | **survives**, `00:00 +15: All tests passed!` (finding 1) |
| OWN-6 (mine) | handle unsigned, `tan(theta.abs() / 4)` | RED: the arc, `Actual: <125.339…>` vs bound 2.034. `00:00 +14 -1` |
| OWN-1, OWN-2, OWN-3 | see §4 | |

**The temporary test** (`zz_review_tmp2_test.dart`)
- It draws a polyline and the −110° arc under T-3b's rotated, mirrored and anisotropic residual. It checks vertices, cubic ends and cubic mid-points against `residual(...)`, with a 0.1 / 0.15 pt bound.
- On `babfcc1`: `REVIEW-OK n=2`, `00:00 +1: All tests passed!`.
- OWN-5 against it: RED, `Actual: <5058.003…>`.
- OWN-6 against it: RED, `Actual: <18.297…>`.
- So the sink is right and the gap is only in the tests.

**The residual dump** (`zz_review_tmp_test.dart`, at the T-3 camera)
- Every T-3 polyline, fill and point is under `[1 0 0 1 294.35 510.24]`, a pure translation.
- The circle and the arc are under `[0.05669 0 0 −0.05669 …]`, which is diagonal.
- The two text residuals are `[0 0 0 0 …]`, as the implementer reported.

## 6. The implementer's claims

**(a) The Flutter floor. Confirmed.**
- I fetched `releases_linux.json` with curl and listed the stable channel:
  ```
  3.41.0 3.11.0 2026-02-11 … 3.41.9 3.11.5 2026-04-30
  3.44.0 3.12.0 2026-05-18
  3.47.2 3.13.2 2026-08-27
  ```
- `pdf-3.13.1/pubspec.yaml` declares `sdk: ">=3.12.0 <4.0.0"`.
- So 3.44.0 is the first stable release with Dart 3.12, and `flutter: ">=3.44.0"` is the right bound.
- Spec R-4's "Flutter ≥ 3.41" is wrong for `pdf`. Task 10 should raise the app to `>=3.44.0`, and the results note should say so.
- Local toolchain: `Flutter 3.47.2 • channel stable`, `Dart 3.13.2`.

**(b) The unmatched `canvas.save` in `CanvasDrawSink`. Not a real screen defect today; latent.**
- `_pushTransform` (`canvas_draw_sink.dart:113-120`) has no "in a residual" guard, and `endResidual` is the only `restore`.
- So a primitive drawn outside a residual would leave one unmatched `save` per call.
- No caller does that:
  - The only caller is `DraftPainter`. Every sink primitive is inside a begin/end pair: `draft_painter.dart:597-607` (`_emit`, including every circle and arc at `:830-916`), `:634-681`, `:760-766`, `:790-793` and `:990-995`.
  - `VerticesDrawSink` forwards both `beginResidual` and `endResidual` to its Canvas fallback (`vertices_draw_sink.dart:314, 321`).
- The save stack therefore does not grow per frame. Even if it did, a `PictureRecorder` balances leftover saves at `endRecording`, so the growth would not carry across frames.
- **A related latent issue (info):** `CanvasDrawSink.point` (`:140-152`) does not undo an already-pushed residual. A point drawn after another primitive under the same residual would be transformed twice.
  - It is unreachable, because the painter gives every point its own residual (`:634-638`).
  - `PdfDrawSink.point` handles this correctly with `_popTransform()`.
- Neither issue was changed.

## 7. Gates (re-run by me at `babfcc1`, `CI=true`, Flutter 3.47.2)

**Render (`packages/jet_cad_2d_flutter`)**
- `flutter test`: `00:54 +1078 ~1 -7: Some tests failed.` The `[E]` lines, deduplicated, are exactly text_ladder rung 1-5 and text_lod_ladder rung 1-2 (canvas).
- `flutter analyze`: `No issues found! (ran in 3.4s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 194 files (0 changed)`.
- `paint_allocation_test` is not among the failures.

**Engine and other packages**
- Engine `dart test test/invariants/query_allocation_test.dart`: `00:06 +6: All tests passed!`.
- `apps/dev_harness_2d` `flutter analyze`: `No issues found! (ran in 2.1s)`.

**App (`apps/floor_planner`)**
- `flutter build web --release`: exit 0, `✓ Built build/web`.
- `flutter test`: `03:11 +885: All tests passed!`.

**Licences** (from the pub cache `LICENSE` files; the resolved versions come from `.dart_tool/package_config.json`)

| package | version | licence |
|---|---|---|
| pdf | 3.13.1 | Apache License 2.0 |
| barcode | 2.2.9 | Apache License 2.0 |
| bidi | 2.0.13 | MIT (Copyright (c) 2020 Mahdi K. Fard) |
| qr | 3.0.2 | BSD-3-clause ("Copyright 2014, the Dart QR project authors") |

They agree with the report.

## 8. Scope

- `git diff --stat 64bb01c..babfcc1 -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants` printed nothing. The engine, the app, the goldens and both allocation invariant tests are unchanged.
- No `analysis_options.yaml` is in the range.
- `pubspec.lock` is git-ignored (`.gitignore:3:*.lock`), so it is correctly not committed.
- `vector_math`, which the sink imports, is already a declared dependency.
- Trailers are correct on both commits.

## Findings

1. **Medium (test gap; degenerate fixture): nothing checks a primitive drawn under a non-diagonal `cm`.**
   - Where:
     - `test/export/pdf_draw_sink_test.dart:155-282` (T-3) and `:341-362` (T-3b after-Q);
     - `test/export/pdf_content_test.dart:110-120`;
     - `lib/src/export/testing/pdf_content.dart:112`.
   - In T-3 every residual is a translation or the camera's diagonal (§5 dump), because the painter carries instance leaves to screen space.
   - T-3b's rotated, mirrored residual is used only for widths and the point. The polyline it draws under that `cm` is never located.
   - So:
     - a sink that writes the residual transposed (OWN-5) survives;
     - a reader whose `apply` is transposed (RD-transpose) survives both files. Under the page flip, a conformal or diagonal CTM is symmetric, so a transposition is invisible.
   - D3's "exactly what `Canvas.drawArc` draws in the same frame" is never exercised under a rotation or mirror. P-2's "a reader bug cannot make a sink test pass" is broken by RD-transpose.
   - The code is correct; my temporary test proves it.
   - Fix (test-only):
     - (a) In `pdf_content_test.dart`, add a non-symmetric `cm`, e.g. `1 2 3 4 5 6 cm 10 20 m … S` → (75, 106), named for the transposed-apply bug.
     - (b) Make the device-width test actually mirrored, e.g. `0 3 3 0 cm`, det −9, so RD-signed-scale goes red in the reader's own file.
     - (c) In T-3b, under the existing `residual`, assert the polyline's vertices and an arc's ends, cubic samples and mid-point side against `pageSetUp(residual(p))` within `pdfTolerance`. My scratch test `scratchpad/r3/zz_review_tmp2_test.dart` is a template. It kills OWN-5 and OWN-6.
   - Fire OWN-5 and RD-transpose red afterwards.
2. **Low (test strength): `pdfTolerance` charges 5e-6 for matrix entries the package writes exactly.**
   - Where: `test/support/pdf_tolerance.dart:28-38`.
   - For T-3's translation residuals the bound is about 1e-3 pt against a real worst case of about 1.5e-5 pt.
   - A 5e-4 pt shift of every path's first vertex survives (OWN-3), and the planned 1e-3 pt shift is red with only a 5 % margin (OWN-2).
   - Fix: charge each entry its actual rounding error `|v − round5(v)|` instead of 5e-6. That is still derived from the 5-decimal rule, and it is 0 for `1` and `0`. Do the same for the operands where they are known. Re-fire OWN-3.
   - Otherwise, record the looseness in the results note.
3. **Info: the reader has no odd-length hex string test** (RD-hex-odd survives).
   - Where: `pdf_content.dart:583`.
   - The package never writes one, so either add a one-line test or leave it.
4. **Info, carried to Task 10 and the results note.**
   - The toolchain floor is Flutter 3.44.0 (Dart 3.12.0), confirmed from the official index. Spec R-4 and F-16's "3.41" are wrong for `pdf`.
   - The text residual under `InsertionPointMeasurer` is singular (`[0 0 0 0 e f]`). Task 4 must use a real measurer, as the implementer said.
5. **Info (latent, not this task): two `CanvasDrawSink` issues.**
   - Where: `lib/src/canvas_draw_sink.dart:113-120` and `:140-152`.
   - `_pushTransform` outside a residual would leave an unmatched `save`.
   - `point` after another primitive in the same residual would be transformed twice.
   - Neither is reachable from `DraftPainter` today (§6b), so neither is a screen defect.
   - Fix (later, in a plan allowed to touch it): guard `_pushTransform` the way `PdfDrawSink` does, and pop before `point`. Each fix needs a direct-call test.

## Verdict

**Needs fixes (test-only, small).**
- `PdfDrawSink` meets D3 on every point I checked. Its arc, width, point and state handling are correct, including under a rotated, mirrored and anisotropic `cm`, which I verified with a temporary test.
- The reader composes `cm` and `q`/`Q` correctly.
- All gates match the expected counts, and every named mutant goes red.
- **What blocks:** finding 1 is the degenerate-fixture failure mode CLAUDE.md names.
  - No committed test places a path under a non-diagonal `cm`.
  - A transposed residual in the sink, and a transposed matrix in the reader, both pass the whole suite.
  - Task 4's text under rotated residuals depends on the same reader convention.
- Close finding 1 (a)-(c) in a test-only commit before Task 4 builds on the reader. Finding 2 can come in the same commit or be recorded.

## Re-review (3b): `d61d567`

**Scope**
- Reviewed in the detached review worktree, at `d61d567`. Mutants were run as before (`scratchpad/r3/mut.py`), and every run printed `RESTORED diff=0`.
- Nothing was committed or staged. `git status --short` shows only the `analysis_options.yaml` rewritten by `pub get`.
- **The diff is test-only.** `git diff --name-only babfcc1..d61d567` lists exactly three files:
  - `test/export/pdf_content_test.dart`
  - `test/export/pdf_draw_sink_test.dart`
  - `test/support/pdf_tolerance.dart`
- `git diff --stat babfcc1..d61d567` over `lib/`, the engine, the apps, the goldens and the invariants printed nothing.
- Trailers are correct.

### The new tests
- **Finding 1(a).** "a non-symmetric cm maps (x, y) to (a·x + c·y + e, b·x + d·y + f)…" uses `1 2 3 4 5 6 cm` and expects (75, 106) and (76, 108). I checked both values by hand.
- **Finding 1(b).** The width test now has a `0 3 3 0` case. It asserts the determinant is −9 and the device width is 1.5.
- **Finding 1(c).** The new T-3b test uses `translate·scale(0.8, 0.8)·instance·translate`.
  - It asserts its own preconditions: det < 0, |b| > 0.1 and |b − c| > 0.1.
  - It checks the polyline's vertices, the arc's start and end, cubic samples on the circle and the mid-point's side, all against `Transform2` and `H − y`, independently of the reader's matrices.
  - The implementer's point is right: the old T-3b residual, with scale(0.8, −0.8), has two mirrors and det > 0.
- **Finding 3.** `<901FA> ri` must read as the bytes 90 1F A0.

### The tolerance
`pdfTolerance` now charges each written number its actual rounding error, `pdfRoundingError(v) = |v − double.parse(v.toStringAsFixed(5))|`. That is `PdfNum`'s own rule (`num.dart`: `toStringAsFixed(precision)`, trailing zeros trimmed without changing the value).

**It is still derived.**
- Page x is `ã·x̃ + c̃·ỹ + ẽ` through the page set-up's exact `1/0` entries, so the first-order error is `δa|x| + |a|δx + δc|y| + |c|δy + δe`.
- Page y has the same form with `b, d, f`, plus `δH`.
- Second-order terms (≤ 2.5e-11) and double arithmetic are covered by `1e-9·(1 + |x| + |y|)`.
- The bound is exact to first order, so it is neither loose nor wished smaller.
- Cubic samples, whose control operands the test does not know, keep the 5e-6 worst case (`operandsKnown: false`), which is correct.

**It is not too tight.** The whole render suite is green at the new bound (below).

**One theoretical fragility (info, not a finding).**
- The arc's end point is computed by the sink as `start + (sweep/n)·n` and by the test as `start + sweep`. They can differ by an ulp.
- If that double ever sat exactly on a 5th-decimal half-boundary, the two would round differently: one grid step (1e-5) apart, against a bound that charges the test's own rounding.
- The fixture is deterministic and passes, so nothing needs to change.

### Re-fired mutants

| id | mutation | test file | result (real lines) |
|---|---|---|---|
| OWN-5 | sink writes the residual transposed (`_set(r.a, r.c, r.b, …)`) | pdf_draw_sink_test | RED "a polyline and the -110 degree arc under a rotated and mirrored residual…", `Expected: <= 0.026754905338989346 Actual: <1685.996605154587>`. `00:00 +15 -1` |
| RD-transpose | reader `apply` transposed | pdf_content_test | RED "a non-symmetric cm…", `Expected: [[75, 106], [76, 108]] Actual: [[55.0, 116.0], [56.0, 119.0]]`. `00:00 +20 -1` |
| RD-transpose | same | pdf_draw_sink_test | RED (same new T-3b test), `Actual: <5058.003394845411>`. `00:00 +15 -1` |
| RD-signed-scale | `scale => sqrt(determinant)` | pdf_content_test | RED width test, `Expected: <1.5> Actual: <NaN>`. `00:00 +20 -1` |
| OWN-3 | first vertex of every polyline and fill `x + 5e-4` | pdf_draw_sink_test | RED T-3 polylines/fills, `Expected: <= 0.000006881176351630475 Actual: <0.0005066141731902007>`. `00:00 +15 -1` |
| OWN-7 (new) | the same shift at only 2e-5 | pdf_draw_sink_test | RED, `Actual: <0.00002661417320837245>` vs bound 6.88e-6. `00:00 +15 -1` |
| RD-hex-odd | odd hex padded at the front | pdf_content_test | RED odd-hex test, `Expected: [144, 31, 160] Actual: [9, 1, 250]`. `00:00 +20 -1` |

### Gates (render, `CI=true`, re-run by me)
- `flutter test`: `00:53 +1081 ~1 -7: Some tests failed.` The `[E]` lines, deduplicated, are exactly text_ladder rung 1-5 and text_lod_ladder rung 1-2 (canvas).
- `flutter analyze`: `No issues found! (ran in 1.7s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 194 files (0 changed)`.

### Re-review verdict

**Approved.**
- Findings 1, 2 and 3 are closed. Each mutant that survived before is now red in the test named for it, and OWN-5 and RD-transpose die in both files where applicable.
- The tolerance is still derived from the 5-decimal rule, is now tight to first order, and keeps the whole suite green.
- Findings 4 and 5 stay as info, carried to Task 10, Task 4 and the results note.
