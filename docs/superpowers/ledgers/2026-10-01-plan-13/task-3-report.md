# Task 3 report — PdfDrawSink geometry and the content reader (spec D3 without text, T-3, T-3b)

## Part 1: Task 2 review follow-ups

**Commit:** `ff0d853` test(render): omitOwners follow-ups (Task 2 review). It is test-only.

**Files**
- `packages/jet_cad_2d_flutter/test/export/omit_owners_test.dart`
  - `painted`/`walked` now take an optional `document:`.
  - Finding 1: new test "with a definition omitted (the container route) the painter does not report a skipped container leaf to debugOnVisit".
    - It asserts that instanceLine, instancePolyline and pointInInstance are not visited.
    - It asserts that `f.instance` and `outerInstanceLeaf` are visited.
  - Finding 2: new group "with an instance omitted (its attribute)". It uses its own `exportFixture()` and adds an ATTRIB (owner `a.instance`, instance-local (400, -250), 120 mm high, "D-01", tag REF) with `{a.instance}` omitted.
    - The painter and the reference draw the same drawing (`expectSameDrawing`).
    - Each route drops the attribute and keeps the definition's three leaves.
    - With the default set, both routes draw the attribute, so the group is not vacuous.
    - Attributes can be built in the render tests: `AddEntityCommand` with `kind: EntityKind.attrib`, `tag:` and `textPayload`.
- `packages/jet_cad_2d_flutter/test/support/differential.dart:137`: the comment is reworded. A shading sink's dash brackets are skipped, so its polyline compares whole (finding 4).

**Gate** (render, `CI=true flutter test`):
```
00:47 +1044 ~1 -7: Some tests failed.
```
- That is 1,039 + 5 new.
- The 7 failures are exactly text_ladder rung 1-5 and text_lod_ladder rung 1-2 (canvas).
- Analyze: `No issues found! (ran in 1.2s)`.
- Format: `Formatted 188 files (0 changed)`, exit 0.

**Mutants** (`scratchpad/e3/mut.py`: cp backup, one replacement, the named file run in the foreground, cp back, diff):

| id | file:line | mutation | red test | real output |
|---|---|---|---|---|
| R-visit-cont | draft_painter.dart:482-483 | `debugOnVisit` before the skip inside containers | "...container route) the painter does not report a skipped container leaf to debugOnVisit" | `00:00 +18 -1: Some tests failed.` / `RESTORED diff=0` |
| R-attrib | reference_walk.dart:110 | walk's ATTRIB site `leaves[child] ?? const <int>[]` (ignores the set) | "(its attribute) the painter and the reference draw the same drawing" + "the reference drops the attribute..." | `00:00 +17 -2: Some tests failed.` / `RESTORED diff=0` |

## Part 2: plan Task 3

**Commit:** `babfcc1` feat(render): PdfDrawSink geometry.

### Dependency
- `packages/jet_cad_2d_flutter/pubspec.yaml`:
  - `pdf: ^3.13.1`. pub.dev's API lists 3.13.1 as `latest`.
  - `flutter: ">=3.44.0"` (was `">=3.24.0"`). `sdk: ^3.5.0` is unchanged.
- `pubspec.lock` is not tracked (`git ls-files | grep pubspec.lock` is empty), so only the pubspec was staged. `analysis_options.yaml` (rewritten by pub get) was never staged.
- New packages in the workspace lock (the lock's package list diffed before and after `flutter pub add pdf`): `barcode`, `bidi`, `pdf`, `qr`. pdf's other dependencies (archive, crypto, image, meta, path_parsing, vector_math, xml) were already resolved in the workspace.
- Licences, read from the pub cache's `LICENSE` files:

| package | version | licence (first lines of LICENSE) |
|---|---|---|
| pdf | 3.13.1 | Apache License, Version 2.0 |
| barcode | 2.2.9 | Apache License, Version 2.0 |
| bidi | 2.0.13 | MIT License (Copyright (c) 2020 Mahdi K. Fard) |
| qr | 3.0.2 | BSD 3-clause ("Copyright 2014, the Dart QR project authors"; three conditions, the third being the "Neither the name of Google Inc." clause) |

### Files
- `lib/src/export/pdf_draw_sink.dart` (new): `PdfDrawSink`, exported from `jet_cad_2d_flutter.dart`.
- `lib/src/export/testing/pdf_content.dart` (new): the reader (`PdfContent.parse(bytes, inflate:)`). It exposes:
  - `mediaBox`;
  - `operators` (and `operatorNames`);
  - `paths`: subpaths in page space; the paint kind; the state with CTM, `w`, RG/rg, CA/ca and the `gs` names applied; `deviceLineWidth = w·sqrt|det CTM|`;
  - `textRuns`: font resource and dict, size, `Tz`, the text matrix, the CTM, the codes, the string through `/ToUnicode`, and the advance from `/W` (or `/Widths`) with the TJ kerning.
- `lib/export_testing.dart` (new): exports the reader only. `grep -rn "export_testing\|testing/pdf_content" lib` finds no importer.
- `test/export/pdf_content_test.dart` (new, 19 tests): the reader on hand-written PDFs.
- `test/export/pdf_draw_sink_test.dart` (new, 15 tests): T-3 (6) and T-3b (9).
- `test/support/pdf_tolerance.dart` (new): `pdfTolerance(x, y, residual)` and `pdfWidthTolerance(width, residual)`.

### Gates at `babfcc1` (real tails)
- Engine (`CI=true dart test`):
  - `00:16 +1121 -2: Some tests failed.` The 2 are the standing failures in `generate_document_test.dart`.
  - analyze: `No issues found!`
  - format: `Formatted 160 files (0 changed)`, exit 0.
- Render (`CI=true flutter test`):
  - `00:54 +1078 ~1 -7: Some tests failed.` That is 1,044 + 19 + 15. The 7 are exactly text_ladder rung 1-5 and text_lod_ladder rung 1-2 (canvas), deduplicated from `[E]`.
  - analyze: `No issues found! (ran in 1.4s)`.
  - format: `Formatted 194 files (0 changed)`, exit 0.
  - Both allocation invariant tests ran inside this suite, green and unedited.
- App (`CI=true flutter test`):
  - `03:03 +885: All tests passed!`
  - analyze: `No issues found! (ran in 3.9s)`.
  - format: `Formatted 153 files (0 changed)`, exit 0.
- `CI=true flutter build web --release` (app): exit 0, `✓ Built build/web`.
- `apps/dev_harness_2d`, `CI=true flutter analyze`: `No issues found! (ran in 2.1s)`.

### T-3 and T-3b as built
**T-3**
- Setup:
  - The fixture is painted with `pageCamera(f.page, 72/25.4)`, `minTextCapPixels: 0` and `DocumentStyleResolver(foreground: 0x000000)`.
  - It records into `RecordingDrawSink()` (`shadesDashes: false`), so the dashed polyline arrives as 21 cut spans, as it will in the export.
  - The ops are replayed into `PdfDrawSink` on `PdfDocument(compress: false)`, with a page of `PdfPageFormat(size)`. **TextOps are skipped**, because text belongs to Task 4.
  - The bytes come from `document.write(PdfStream)`.
- Checks:
  - There is one path per primitive, in order, and every primitive kind the painter emits is reached.
  - The first four operators are the page set-up.
  - Every polyline and fill vertex is `pageSetUp(residual(p))` within `pdfTolerance`, with colour, alpha and the device width `lw/100·u` (M-13b).
  - Circle: four cubics, closed, endpoints at 0/90/180/270 degrees, and samples at t = 0, .25, .5, .75 and 1 on the circle within the bound carried back through the residual (÷ smallest singular value) + `2.7e-4·r`.
  - The -110° arc:
    - two cubics;
    - start and end points;
    - the samples on its circle;
    - the mid-point at `start + sweep/2`, within 1e-3 rad.
  - The point: an axis-aligned square of side `0.70·u` around `pageSetUp(residual(p))`.

**T-3b** (direct calls on an A4-landscape page)
- `closed: true` writes `h` immediately before `S`; `false` does not.
- An opaque stroke after a 0x80 fill (both in screen space) is under CA = ca = 1, with its own `gs` written.
- After a residual's `Q`, `RG`, `w` and `gs` are all rewritten before the next `S`. The colour and the width read back correctly, and the width under the residual is the same page width.
- An empty residual writes no `q` and no `Q`.
- A point drawn while a rotated, mirrored residual's `cm` is open is still an axis-aligned square of side `0.70·u` in page space, and lineweight 0 draws nothing.
- Lineweight 0 writes `0 w`.
- `fillCircle` is four closed, filled cubics.
- Arc cubic counts: 90° → 1, 90°+ε → 2, -110° → 2, 270° → 3, 7 rad → 4 (clamped to a full turn).
- `beginDash`/`endDash` throw `UnsupportedError`, `text` throws `UnimplementedError`, and `shadesDashes` is false.

**Tolerances** (test/support/pdf_tolerance.dart, derived from `PdfNum.precision = 5`, half-unit 5e-6):
- Screen space: `1e-5`.
- Under a residual: `5e-6·(|x|+|y|+1) + 5e-6·max(|a|+|c|, |b|+|d|) + 5e-6` (H), plus 1e-9 arithmetic slack.
- Width: `5e-6·s + dw·½·5e-6·(|a|+|b|+|c|+|d|)/|det|`.
- Under the arc's residual (scale 0.0567, local coordinates around 6,300) the bound is about 0.056 pt. That is honest: the written `0.05669` entry times x 6,308 really moves a point by about 0.02 pt.

### Mutants (Task 3)
Same procedure as above: `mut.py` cp-backs-up the file, applies one replacement, runs the named file in the foreground, cps the file back, and diffs. Every run printed `RESTORED diff=0`. The sink is `lib/src/export/pdf_draw_sink.dart` and the T file is `test/export/pdf_draw_sink_test.dart`, unless noted.

| id | file:line | mutation | red tests | real output |
|---|---|---|---|---|
| M-13h | pdf_draw_sink.dart:48 | page set-up `..setTransform(_set(1,0,0,-1,0,height))` deleted | T-3 page set-up, polylines/fills, circle, arc, point; T-3b rotated point | `00:00 +9 -6: Some tests failed.` |
| M-13i | :106 | `_pushTransform` never pushes (`|| true`): residual ignored | T-3 polylines/fills, circle, arc; T-3b "after a residual's Q" | `00:00 +11 -4: Some tests failed.` |
| M-13b (sink) | :287 | `device = lw / 100.0` (u dropped) | T-3 width assertions (`Expected: ... within <0.0000099...> of <0.99212...> Actual: <0.35>`, "polyline of 18: the stroke is lw / 100 · u wide on the page"), circle, arc, point; T-3b ×2 | `00:00 +9 -6: Some tests failed.` |
| M-13j | :192 | `theta = s.abs() / n` | T-3 arc ("arc end: x 605.626... vs 655.432... (bound 0.0558...)") | `00:00 +14 -1: Some tests failed.` |
| M-13k | :163 | `if (closed && false) _g.closePath();` | T-3b "closed: true writes h before S" (`Expected: 'h' Actual: 'l'`) | `00:00 +14 -1: Some tests failed.` |
| M-13y | :277 | `if (opacity < 1) _g.setGraphicState(...)` | T-3b opaque-after-fill (`Expected: [1, 1] Actual: [0.50196, 0.50196]`) and after-Q (`contains all of ['RG','w','gs']`) | `00:00 +13 -2: Some tests failed.` |
| M-13z | :_strokeState (2 sites: a `_lastStroke` field + `if (style == _lastStroke) return;`) | state cached across `Q` | T-3 polylines (the instance's line and polyline share a style in separate residuals, so the second is drawn in the black Q left), T-3b after-Q (`Expected: ... of <1.0> Actual: <0.0>` stroke red channel, black left by Q) | `00:00 +13 -2: Some tests failed.` |
| M-13ad | :140-142 (3 lines) | point: `_pushTransform(); sx = x; sy = y;` (under cm) | T-3b rotated point only (`Expected: <= 0.00002 Actual: 1.19055`, edge not axis-aligned). **T-3's fixture point survives**: its residual is a pure translation | `00:00 +14 -1: Some tests failed.` |
| X-scale | :288 | width not divided by the residual scale | T-3 circle, arc; T-3b after-Q (`Actual: <0.02089>`) | `00:00 +12 -3: Some tests failed.` |
| X-eager | beginResidual | `_pushTransform()` in `beginResidual` (not deferred) | T-3b empty residual (`not contains 'q'`) | `00:00 +14 -1: Some tests failed.` |
| X-pt0 | point | `if (side < 0) return;` (draws at lw 0) | T-3b rotated point (`length of <2>`) | `00:00 +14 -1: Some tests failed.` |
| X-circ-h | _circlePath | no `closePath` | T-3 circle; T-3b fill circle | `00:00 +13 -2: Some tests failed.` |

Reader mutants (`lib/src/export/testing/pdf_content.dart`, test file `test/export/pdf_content_test.dart`):

| id | line | mutation | red test | real output |
|---|---|---|---|---|
| RD-cm | 775-777 | `cm` post-multiplies | "cm premultiplies the CTM..." | `00:00 +18 -1: Some tests failed.` |
| RD-Q | 773 | `Q` restores the CTM only | "Q restores colour, width and the ExtGState alpha..." | `00:00 +18 -1: Some tests failed.` |
| RD-flate | 440 | FlateDecode returns raw bytes | "a FlateDecode content stream is inflated..." | `00:00 +18 -1: Some tests failed.` |
| RD-scan | 403 | scan resumes inside the stream data | "stream data is never scanned for objects..." | `00:00 +18 -1: Some tests failed.` |
| RD-width | 171 | `deviceLineWidth` = `w` alone | "the device width is w times the CTM scale..." | `00:00 +18 -1: Some tests failed.` |
| RD-byte | 942 | one byte per code for Type0 | TJ, ToUnicode, Td, run-advance tests | `00:00 +15 -4: Some tests failed.` |
| RD-kern | 950 | kerning sign flipped | "TJ: two-byte CIDs..." | `00:00 +18 -1: Some tests failed.` |
| RD-dw | 1031 | missing width → 0, not `/DW` | "TJ: two-byte CIDs..." | `00:00 +18 -1: Some tests failed.` |
| RD-td | 851 | `Td` replaces the line matrix | "Td composes with the line matrix..." | `00:00 +18 -1: Some tests failed.` |
| RD-adv | 972 | no advance between runs | "a run starts where the previous one ended..." | `00:00 +18 -1: Some tests failed.` |
| RD-re | 814-815 | `re` left open | "re is a closed subpath..." (and, run against pdf_draw_sink_test, T-3 point + T-3b point: `00:00 +13 -2`) | `00:00 +18 -1: Some tests failed.` |

### What the spec / plan got wrong or left open
1. **The toolchain floor is Flutter 3.44.0, not 3.41.** Spec R-4 and F-16 say `printing` needs Flutter ≥ 3.41 and `pdf` 3.13 needs Dart ≥ 3.12.
   - The official releases index (`storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`) shows that 3.41.0–3.41.9 ship Dart 3.11.x and that 3.44.0 is the first stable release with Dart 3.12.0.
   - So `pdf` alone already requires Flutter ≥ 3.44.0. The render package's bound is now `">=3.44.0"`.
   - **Task 10** should raise the app's `flutter:` bound to `>=3.44.0` as well, not to printing's 3.41.
   - The human's macOS Flutter must be ≥ 3.44 (R-4 / the results note).
   - The app's and dev_harness_2d's pubspecs still say lower bounds. Resolution enforces the real floor through the render package anyway.
2. **"One ExtGState object per distinct alpha" (D3).** The package writes **one** `PdfGraphicStates` dictionary object holding `/a0`, `/a1`, … entries, deduplicated by equality. These are entries, not separate objects. The meaning is the same, and the reader resolves either form.
3. **A page that paints nothing has no `/Contents`.** The pdf package drops a content stream that was never "altered", page set-up included. The reader reads such a page as empty. Task 5 should not expect the set-up `cm` on an empty page.
4. **The fixture replay cannot kill three named mutants.**
   - **M-13ad**: the painter carries an instance's points into screen space, so the fixture's point sits under a translation-only residual.
   - **M-13y**: every fixture primitive runs inside its own `q … Q`, which resets alpha.
   - **M-13k**: the painter always passes `closed: false`.
   - The T-3b direct calls kill all three. The spec's mutant table lists M-13ad under T-3; in practice it is T-3b's.
5. **CanvasDrawSink pushes `save` + an identity transform for a primitive drawn outside any residual, with no matching `restore`.** PdfDrawSink cannot mirror that, because an unbalanced `q` is malformed PDF. It pushes only inside a residual, and T-3b pins "no q/Q for an empty residual".
   - The canvas behaviour is probably harmless: the recorder unwinds saves.
   - Observed, not changed.
6. **For Task 4: text residuals are degenerate with the fixture's default measurer.** With `InsertionPointMeasurer` the recorded text residual is `(0, 0, 0, 0, e, f)`. Task 4's T-5 must build the fixture with a real (Ahem) `FlutterTextMeasurer`, or the text cm is singular.

### Decisions
- **Bytes in the tests:** `write(PdfStream)`, as Task 5 will use.
- **Text in the replay:** T-3's replay skips `TextOp` (`text` throws until Task 4). Its `begin`/`endResidual` still replay and write nothing, because they are deferred.
- **`point` while a residual's `cm` is open:** the `cm` is closed with `Q` first, and the next primitive pushes it again. This mirrors CanvasDrawSink, whose `point` never draws under the transform.
- **A nested `beginResidual`:** closes an open `q` first (defensive). The painter never nests.
- **Arc edge cases:**
  - A sweep of 0 or NaN draws nothing.
  - |sweep| > 2π is clamped to a full turn.
  - The split uses `ceil(|s|/(π/2) − 1e-9)`, so an exact quarter turn is one cubic.
  - The 2π clamp matches Skia's documented `drawArc` behaviour. No canvas experiment was run.
- **Reader strictness:** the reader throws `UnsupportedError` on geometry-moving operators it does not model (`Tc Tw Ts TL T* TD ' " d Do BI sh W W*`), so they are never silently skipped.
- **Reader filters:** it decodes FlateDecode only. ASCII85 support was removed because nothing tested needs it: the package uses it only for the uncompressed font file, which the reader never decodes. Any other filter throws.
- **`PdfDrawSink.document`:** kept as a public getter for Task 4's `PdfTtfFont`.

## Task 3b — review fixes (test-only)

**Commit:** `d61d567` test(render): PdfDrawSink and reader under rotated and mirrored matrices (Task 3 review). It sits on top of `babfcc1`, not pushed.

**Files**
- `test/support/pdf_tolerance.dart`
- `test/export/pdf_content_test.dart`
- `test/export/pdf_draw_sink_test.dart`

No `lib/` file changed.

**Finding 1 (a): a non-symmetric `cm`.** New reader test "a non-symmetric cm maps (x, y) to (a·x + c·y + e, b·x + d·y + f)...". `1 2 3 4 5 6 cm` maps (10, 20) to (75, 106) and (11, 20) to (76, 108).

**Finding 1 (b): the misnamed width test.** It was named "mirrored or not" but used `0 -3 3 0 cm`, whose determinant is +9. It is now "rotated or mirrored..." and has three cases:
- `2 0 0 2`;
- `0 -3 3 0` (det +9);
- `0 3 3 0` (det -9, asserted).

The device width is 1.5 in both of the last two.

**Finding 1 (c): T-3b under a rotated, mirrored residual.** New T-3b test "a polyline and the -110 degree arc under a rotated and mirrored residual...".
- The residual is `translate(300, 200) · scale(0.8, 0.8) · instance (30°, (1.5, -0.75)) · translate(-7000, -5600)`. The test asserts det < 0, |b| > 0.1 and |b − c| > 0.1.
- The existing T-3b residual uses scale(0.8, **−0.8**). It has det +0.72 (two mirrors make a rotation), so it could not serve.
- Assertions, all against `pageSetUp(residual(p))` computed from `Transform2`:
  - the polyline's 3 vertices, within the tight `pdfTolerance`;
  - the arc has 2 cubics;
  - its start and end points;
  - samples at t = .25, .5 and .75 lie on the circle in the local frame;
  - the mid-point is at start + sweep/2 (within 1e-3 rad).

**Finding 2: `pdfTolerance` charges each number its actual rounding error.**
- Each matrix entry, operand and `H` is charged `pdfRoundingError(v) = |v − double.parse(v.toStringAsFixed(5))|`, which is `PdfNum`'s own rule. That is 0 for `1` and `0`, and at most 5e-6.
- The bound per component is now:
  - x: `δa·|x| + |a|·δx + δc·|y| + |c|·δy + δe`;
  - y: `δb·|x| + |b|·δx + δd·|y| + |d|·δy + δf + δH`;
  - the larger of the two is returned, plus 1e-9·(1 + |x| + |y|) slack.
- New named parameters:
  - `pageHeight:` charges `H`'s actual rounding error.
  - `operandsKnown: false` is for samples on cubics, whose control operands the test does not know. Their operands keep the 5e-6 worst case.
- All T-3 call sites pass `pageHeight`. The cubic-sample checks pass `operandsKnown: false`.

**Finding 3: odd-length hex strings.** New reader test "an odd-length hex string ends in an implied 0 digit...". `<901FA> ri` reads as the bytes 90 1F A0.

**Gate** (render, `CI=true flutter test`):
```
00:53 +1081 ~1 -7: Some tests failed.
```
- The count is 1,078 + 3. The new tests are the T-3b one, the non-symmetric `cm` and the odd hex. The width test was replaced in place.
- The 7 failures are exactly text_ladder rung 1-5 and text_lod_ladder rung 1-2 (canvas).
- `flutter analyze`: `No issues found! (ran in 2.0s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 194 files (0 changed)`, exit 0.

**Mutants** (`scratchpad/e3/mut.py`, which now takes an expected match count; every run printed `RESTORED diff=0`)

| id | file:line | mutation | test file | red test | real output |
|---|---|---|---|---|---|
| OWN-5 | pdf_draw_sink.dart:110 | residual written transposed, `_set(r.a, r.c, r.b, r.d, r.e, r.f)` | pdf_draw_sink_test | T-3b rotated/mirrored (`Expected: <= 0.02675... Actual: <1685.9966...>`) | `00:00 +15 -1: Some tests failed.` |
| RD-transpose | pdf_content.dart:112-113 | `apply` → `(a·x + b·y + e, c·x + d·y + f)` | pdf_content_test | non-symmetric cm (`Expected: [[75, 106], [76, 108]] Actual: [[55.0, 116.0], [56.0, 119.0]]`) | `00:00 +20 -1: Some tests failed.` |
| RD-transpose | same | same | pdf_draw_sink_test | T-3b rotated/mirrored (`Actual: <5058.0033...>`) | `00:00 +15 -1: Some tests failed.` |
| RD-signed-scale | pdf_content.dart:122 | `scale => sqrt(determinant)` | pdf_content_test | width test (`Expected: <1.5> Actual: <NaN>`) | `00:00 +20 -1: Some tests failed.` |
| OWN-3 | pdf_draw_sink.dart:159, 215 (both `moveTo` sites, count 2) | first vertex `x + 5e-4` | pdf_draw_sink_test | T-3 polylines/fills ("polyline of 18 vertex 0: x 56.69342 vs 56.692913... (bound 0.00000688...)", `Actual: <0.000506...>`) | `00:00 +15 -1: Some tests failed.` |
| RD-hex-odd | pdf_content.dart:583 | odd hex padded at the front | pdf_content_test | odd-hex test (`Expected: [144, 31, 160] Actual: [9, 1, 250]`) | `00:00 +20 -1: Some tests failed.` |
| OWN-6 | pdf_draw_sink.dart (arc `k`) | `tan(theta.abs() / 4)` | pdf_draw_sink_test | T-3 arc and T-3b rotated/mirrored (`Actual: <125.339...>`) | `00:00 +14 -2: Some tests failed.` |

**The tight bound in numbers:** under T-3's translation residual, the first polyline vertex's bound is now 6.9e-6 pt. Before it was about 9.5e-4 pt. Every test stays green at the tight bound: 37 of 37 in the two files, and the full render suite above.
